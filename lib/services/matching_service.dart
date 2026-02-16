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
    // 1. UPDATED PARAMETER NAMES HERE:
    final response = await _client.rpc('handle_swipe', params: {
      'p_swiper_id': myId,          // <--- Changed to p_swiper_id
      'p_target_user_id': targetUserId, // <--- Changed to p_target_user_id
      'p_swipe_type': type,         // <--- Changed to p_swipe_type
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

      final List<String> userIds = likesData
          .map((e) => e['user_id'].toString())
          .toList();

      // 2. Get their profile details
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