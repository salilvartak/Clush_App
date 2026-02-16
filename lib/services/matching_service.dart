import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase

class MatchingService {
  final SupabaseClient _client = Supabase.instance.client;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Use Firebase Auth

  Future<bool> swipeRight(String targetUserId) async {
    return await _recordSwipe(targetUserId, 'like');
  }

  Future<bool> swipeLeft(String targetUserId) async {
    return await _recordSwipe(targetUserId, 'dislike');
  }

  Future<bool> superLike(String targetUserId) async {
    return await _recordSwipe(targetUserId, 'super_like');
  }

  Future<bool> _recordSwipe(String targetUserId, String type) async {
    final myId = _auth.currentUser?.uid; // Get Firebase UID
    if (myId == null) return false;

    try {
      // Call the updated SQL function
      final response = await _client.rpc('handle_swipe', params: {
        'swiper_id': myId,          // SEND MY ID
        'target_user_id': targetUserId,
        'swipe_type': type,
      });
      
      return response as bool;
    } catch (e) {
      print('Error recording swipe: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchWhoLikedMe() async {
    try {
      final myId = _auth.currentUser?.uid; // Get Firebase UID
      if (myId == null) return [];

      // 1. Get likes targeting ME
      final List<dynamic> likesData = await _client
          .from('likes')
          .select('user_id')
          .eq('liked_user_id', myId)
          .eq('type', 'like');

      if (likesData.isEmpty) return [];

      final List<String> userIds = likesData
          .map((e) => e['user_id'].toString())
          .toList();

      // 2. Fetch profiles using .filter()
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