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

      // 3. Filter the list: Only show people who liked me AND whom I haven't swiped on yet
      final List<String> userIds = likesData
          .map((e) => e['user_id'].toString())
          .where((id) => !interactedIds.contains(id))
          .toList();

      if (userIds.isEmpty) return [];

      // 4. Get their profile details
      final List<dynamic> profilesData = await _client
          .from('profiles')
          .select()
          .filter('id', 'in', userIds);

      return List<Map<String, dynamic>>.from(profilesData);
    } catch (e) {
      print('Error fetching likes: $e');
      return [];
    }
  }
}