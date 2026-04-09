import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';


class MatchingService {
  final SupabaseClient _client = Supabase.instance.client;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> swipeRight(String targetUserId) async {
    return await _recordSwipe(targetUserId, 'like');
  }

  Future<bool> swipeLeft(String targetUserId) async {
    // Dislikes rarely trigger a match, but we record them.
    return await _recordSwipe(targetUserId, 'dislike');
  }

  Future<bool> superLike(String targetUserId) async {
    return await _recordSwipe(targetUserId, 'super_like');
  }

  Future<bool> _recordSwipe(String targetUserId, String type) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return false;

    try {
      final response = await _client.rpc('handle_swipe', params: {
        'p_swiper_id': myId,
        'p_target_user_id': targetUserId,
        'p_swipe_type': type,
      });
      
      return response as bool;
    } catch (e) {
      print('Error recording swipe: $e');
      return false;
    }
  }

  // Fetch profiles that liked the current user (for a "Likes You" page)
  Future<List<Map<String, dynamic>>> fetchWhoLikedMe() async {
    try {
      final myId = _auth.currentUser?.uid;
      if (myId == null) return [];

      // 1. Get IDs of people who liked me
      final List<dynamic> likesData = await _client
          .from('likes')
          .select('user_id')
          .eq('target_user_id', myId) // I am the target
          .or('type.eq.like,type.eq.super_like'); // They liked or super liked

      if (likesData.isEmpty) return [];

      // 2. Get IDs of people *I* have already swiped on (Accepted or Rejected)
      final List<dynamic> mySwipes = await _client
          .from('likes')
          .select('target_user_id')
          .eq('user_id', myId);

      // Create a Set of IDs I have already interacted with
      final Set<String> interactedIds = mySwipes
          .map((e) => e['target_user_id'].toString())
          .toSet();

      // Fetch my profile to get blocked_phones, and lookup IDs corresponding to these phones
      final myProfileResponse = await _client
          .from('profiles')
          .select('blocked_phones')
          .eq('id', myId)
          .maybeSingle();

      if (myProfileResponse != null) {
        final blockedPhones = myProfileResponse['blocked_phones'] as List<dynamic>? ?? [];
        if (blockedPhones.isNotEmpty) {
           try {
             final blockedIdsResponse = await _client
                .rpc('get_blocked_ids_by_phone', params: {
                  'phones': blockedPhones.cast<String>()
                });
             if (blockedIdsResponse != null) {
               for (var e in blockedIdsResponse as List) {
                 interactedIds.add(e['id'].toString());
               }
             }
           } catch (e) {
             print('Error fetching blocked phone ids: $e');
           }
        }
      }

      // 3. Filter the list: Only show people who liked me AND whom I haven't swiped on yet
      final List<String> userIds = likesData
          .map((e) => e['user_id'].toString())
          .where((id) => !interactedIds.contains(id))
          .toList();

      if (userIds.isEmpty) return [];

      // 4. Get their profile details via the secure discovery view
      final List<dynamic> profilesData = await _client
          .from('profile_discovery')
          .select()
          .filter('id', 'in', userIds);

      return List<Map<String, dynamic>>.from(profilesData);
    } catch (e) {
      print('Error fetching likes: $e');
      return [];
    }
  }

  // --- BLOCK & REPORT FOR MATCHES / DISCOVER ---

  Future<bool> blockUser(String targetUserId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return false;

    try {
      // 1. Insert into blocks table
      await _client.from('blocks').insert({
        'blocker_id': myId,
        'blocked_id': targetUserId,
      });

      // 2. Remove from matches table if they were matched
      await _client
          .from('matches')
          .delete()
          .or('and(user_a.eq.$myId,user_b.eq.$targetUserId),and(user_a.eq.$targetUserId,user_b.eq.$myId)');

      return true;
    } catch (e) {
      print('Error blocking user: $e');
      return false;
    }
  }

  Future<bool> reportUser(String targetUserId, String reason) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return false;

    try {
      await _client.from('reports').insert({
        'reporter_id': myId,
        'reported_id': targetUserId,
        'reason': reason,
      });

      // Automatically block them too
      await blockUser(targetUserId);

      return true;
    } catch (e) {
      print('Error reporting user: $e');
      return false;
    }
  }

  // --- UNREAD MESSAGE TRACKING ---

  Future<void> updateLastRead(String roomId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;
    try {
      await _client.from('chat_read_status').upsert({
        'user_id': myId,
        'room_id': roomId,
        'last_read_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, room_id');
    } catch (e) {
      print('Error updating last read: $e');
    }
  }

  Future<int> getTotalUnreadCount() async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return 0;

    try {
      final matches = await _client
          .from('matches')
          .select('user_a, user_b')
          .or('user_a.eq.$myId,user_b.eq.$myId');

      int totalUnread = 0;
      for (final m in matches) {
        final roomId = _getRoomId(m['user_a'], m['user_b']);
        totalUnread += await getUnreadCountForRoom(roomId, myId, myId);
      }
      return totalUnread;
    } catch (e) {
      print('Error calculating unread count: $e');
      return 0;
    }
  }

  /// [senderId] is the current user's UID — messages with this sender are
  /// excluded from the unread count (they were sent by me).
  Future<int> getUnreadCountForRoom(String roomId, String senderId, String myId) async {
    try {
      final readStatus = await _client
          .from('chat_read_status')
          .select('last_read_at')
          .eq('user_id', myId)
          .eq('room_id', roomId)
          .maybeSingle();

      final lastRead = readStatus?['last_read_at'] ?? '1970-01-01T00:00:00Z';

      final response = await _client
          .from('messages')
          .select('id')
          .eq('room_id', roomId)
          .neq('sender', senderId)
          .gt('created_at', lastRead)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      print('Error getting unread count for room: $e');
      return 0;
    }
  }

  String _getRoomId(String id1, String id2) {
    List<String> ids = [id1, id2];
    ids.sort();
    return "${ids[0]}_${ids[1]}";
  }

  // --- DAILY LIKE LIMIT & SAVED PROFILES ---

  Future<int> getLikesRemaining(bool isPremium) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return 0;

    final limit = isPremium ? 20 : 6;
    const hours = 24;
    final timeLimit = DateTime.now().toUtc().subtract(const Duration(hours: hours)).toIso8601String();

    try {
      final response = await _client
          .from('likes')
          .select('id')
          .eq('user_id', myId)
          .gte('created_at', timeLimit)
          .or('type.eq.like,type.eq.super_like')
          .count(CountOption.exact);
          
      final likesUsed = response.count;
      return (limit - likesUsed).clamp(0, limit);
    } catch (e) {
      print('Error getting likes remaining: $e');
      return isPremium ? 20 : 6; // fallback
    }
  }

  Future<bool> saveProfileForLater(String targetUserId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return false;

    try {
      await _client.from('saved_profiles').insert({
        'user_id': myId,
        'saved_user_id': targetUserId,
      });
      return true;
    } catch (e) {
      print('Error saving profile: $e');
      return false;
    }
  }

  Future<bool> unsaveProfile(String targetUserId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return false;

    try {
      await _client
          .from('saved_profiles')
          .delete()
          .eq('user_id', myId)
          .eq('saved_user_id', targetUserId);
      return true;
    } catch (e) {
      print('Error unsaving profile: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchSavedProfiles() async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return [];

    try {
      final data = await _client
          .from('saved_profiles')
          .select('saved_user_id')
          .eq('user_id', myId)
          .order('created_at', ascending: false);

      final savedUserIds = (data as List).map((e) => e['saved_user_id'].toString()).toList();
      if (savedUserIds.isEmpty) return [];

      final profilesData = await _client
          .from('profile_discovery')
          .select()
          .filter('id', 'in', savedUserIds);

      // filter out ones we matched/liked since saving
      final interactedData = await _client
          .from('likes')
          .select('target_user_id')
          .eq('user_id', myId);
      final interactedIds = (interactedData as List).map((e) => e['target_user_id'].toString()).toSet();

      final Map<String, dynamic> profilesMap = {
        for (var p in profilesData) p['id'] as String: p
      };
      
      final List<Map<String, dynamic>> orderedResult = [];
      for (var id in savedUserIds) {
        if (profilesMap.containsKey(id) && !interactedIds.contains(id)) {
           orderedResult.add(profilesMap[id]);
        }
      }
      return orderedResult;
    } catch (e) {
      print('Error fetching saved profiles: $e');
      return [];
    }
  }
}
