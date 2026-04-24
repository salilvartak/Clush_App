import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';


class MatchingService {
  final SupabaseClient _client = Supabase.instance.client;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  //  WALLET / INVENTORY
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetches the current user's wallet state after performing a lazy refill
  /// on the server. Returns a map with all free/paid balances and limits.
  Future<Map<String, dynamic>> getWallet() async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return {};

    try {
      final result = await _client.rpc('get_user_wallet', params: {
        'p_user_id': myId,
      });
      if (result is Map<String, dynamic>) return result;
      return {};
    } catch (e) {
      print('Error fetching wallet: $e');
      return {};
    }
  }

  /// Convenience: how many likes left today (after lazy refill on server).
  Future<int> getLikesRemaining(bool isPremium) async {
    final wallet = await getWallet();
    if (wallet.isEmpty) return isPremium ? 20 : 6;
    return (wallet['likes_remaining'] as int?) ?? (isPremium ? 20 : 6);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SWIPE ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> swipeRight(String targetUserId) async {
    return await _handleSwipeV2(targetUserId, 'like');
  }

  Future<Map<String, dynamic>> swipeLeft(String targetUserId) async {
    return await _handleSwipeV2(targetUserId, 'pass');
  }

  Future<Map<String, dynamic>> superLike(String targetUserId) async {
    return await _handleSwipeV2(targetUserId, 'super_like');
  }

  Future<Map<String, dynamic>> pulse(String targetUserId, String? message) async {
    return await _handleSwipeV2(targetUserId, 'pulse', message: message);
  }

  Future<Map<String, dynamic>> saveProfile(String targetUserId) async {
    return await _handleSwipeV2(targetUserId, 'save');
  }

  /// Central swipe handler calling handle_swipe_v2 RPC.
  /// Handles like, pass, super_like, pulse, save — all with wallet integration.
  Future<Map<String, dynamic>> _handleSwipeV2(
    String targetUserId,
    String swipeType, {
    String? message,
  }) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return {'success': false, 'error': 'auth_error'};

    try {
      final response = await _client.rpc('handle_swipe_v2', params: {
        'p_swiper_id': myId,
        'p_target_user_id': targetUserId,
        'p_swipe_type': swipeType,
        'p_message': message,
      }) as Map<String, dynamic>;

      return response;
    } catch (e) {
      print('Error recording swipe ($swipeType): $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  REWIND
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> rewind(String targetUserId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return {'success': false, 'error': 'auth_error'};

    try {
      final response = await _client.rpc('undo_swipe_v2', params: {
        'p_user_id': myId,
        'p_target_user_id': targetUserId,
      }) as Map<String, dynamic>;

      return response;
    } catch (e) {
      print('Error rewinding swipe: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DISCOVERY FEED  (server-side ordering via get_discovery_feed RPC)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetches the ordered discovery feed from the server.
  /// Returns a list of profile maps, already ordered by:
  ///   1) Super-like priority (profiles who super-liked you first)
  ///   2) Premium boost
  ///   3) Elo score + distance (distance still filtered client-side)
  ///
  /// The [genderPref] should be 'Men', 'Women', or 'Everyone'.
  Future<List<Map<String, dynamic>>> fetchDiscoveryFeed({
    required String genderPref,
    int limit = 40,
  }) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return [];

    try {
      // 1. Get ordered IDs from the server
      final List<dynamic> feedRows = await _client.rpc('get_discovery_feed', params: {
        'p_user_id': myId,
        'p_gender_pref': genderPref,
        'p_limit': limit,
      });

      if (feedRows.isEmpty) return [];

      final List<String> orderedIds = feedRows
          .map((row) => row['profile_id'].toString())
          .toList();

      // Build a map of feed metadata (priority, is_super_like)
      final Map<String, Map<String, dynamic>> feedMeta = {};
      for (var row in feedRows) {
        feedMeta[row['profile_id'].toString()] = {
          'feed_priority': row['feed_priority'],
          'is_super_like': row['is_super_like'],
        };
      }

      // 2. Fetch full profiles for those IDs
      final List<dynamic> profilesData = await _client
          .from('profile_discovery')
          .select()
          .inFilter('id', orderedIds);

      // Build a lookup map
      final Map<String, Map<String, dynamic>> profilesMap = {
        for (var p in profilesData) p['id'].toString(): Map<String, dynamic>.from(p)
      };

      // 3. Reassemble in the server's priority order, injecting metadata
      final List<Map<String, dynamic>> result = [];
      for (final id in orderedIds) {
        if (profilesMap.containsKey(id)) {
          final profile = profilesMap[id]!;
          profile['feed_priority'] = feedMeta[id]?['feed_priority'] ?? 2;
          profile['is_super_like_received'] = feedMeta[id]?['is_super_like'] ?? false;
          result.add(profile);
        }
      }

      return result;
    } catch (e) {
      print('Error fetching discovery feed: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  "LIKES YOU" ENDPOINT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetches users who liked the current user via the server-side RPC.
  /// Returns a map containing:
  ///   - `is_premium`: whether the current user is premium
  ///   - `blur_photos`: whether the frontend should blur profile photos
  ///   - `profiles`: list of profile maps with like_type, like_message, etc.
  Future<Map<String, dynamic>> fetchLikesYou() async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return {'is_premium': false, 'blur_photos': true, 'profiles': []};

    try {
      final result = await _client.rpc('get_likes_you', params: {
        'p_user_id': myId,
      });

      if (result is Map<String, dynamic>) return result;
      return {'is_premium': false, 'blur_photos': true, 'profiles': []};
    } catch (e) {
      print('Error fetching likes-you: $e');
      return {'is_premium': false, 'blur_photos': true, 'profiles': []};
    }
  }

  /// Legacy-compatible wrapper: returns the list of profile maps directly.
  /// Blurring is handled by the caller based on premium status.
  Future<List<Map<String, dynamic>>> fetchWhoLikedMe() async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return [];

    try {
      // 1. Get IDs of people who liked me
      final List<dynamic> likesData = await _client
          .from('likes')
          .select('user_id, type, message')
          .eq('target_user_id', myId) // I am the target
          .or('type.eq.like,type.eq.super_like,type.eq.pulse'); // They liked, super liked, or pulsed

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
          .inFilter('id', userIds);

      // 5. Merge like type/message with profile data
      final Map<String, dynamic> profilesMap = {
        for (var p in profilesData) p['id'] as String: Map<String, dynamic>.from(p)
      };

      final List<Map<String, dynamic>> results = [];
      for (var like in likesData) {
        final uid = like['user_id'].toString();
        if (profilesMap.containsKey(uid) && !interactedIds.contains(uid)) {
          final profile = profilesMap[uid]!;
          profile['like_type'] = like['type'];
          profile['like_message'] = like['message'];
          results.add(profile);
        }
      }

      return results;
    } catch (e) {
      print('Error fetching likes: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SAVED PROFILES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save a profile using the wallet system (deducts from free/paid saves).
  Future<bool> saveProfileForLater(String targetUserId) async {
    final result = await saveProfile(targetUserId);
    return result['success'] == true;
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
          .inFilter('id', savedUserIds);

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

  // ═══════════════════════════════════════════════════════════════════════════
  //  BLOCK, REPORT, UNMATCH
  // ═══════════════════════════════════════════════════════════════════════════

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

  /// Unmatch using the v2 function that also logs to action_log.
  Future<bool> unmatchUser(String targetUserId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return false;

    try {
      final result = await _client.rpc('unmatch_user_v2', params: {
        'p_user_id': myId,
        'p_target_user_id': targetUserId,
      }) as Map<String, dynamic>;

      return result['success'] == true;
    } catch (e) {
      print('Error unmatching user: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  UNREAD MESSAGE TRACKING
  // ═══════════════════════════════════════════════════════════════════════════

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
}
