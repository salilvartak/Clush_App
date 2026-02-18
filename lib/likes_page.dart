import 'package:flutter/material.dart';
import 'services/matching_service.dart';

const Color kRose = Color(0xFFCD9D8F);

class LikesPage extends StatefulWidget {
  const LikesPage({super.key});

  @override
  State<LikesPage> createState() => _LikesPageState();
}

class _LikesPageState extends State<LikesPage> {
  final MatchingService _matchingService = MatchingService();
  List<Map<String, dynamic>> _likedByUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLikes();
  }

  Future<void> _fetchLikes() async {
    final users = await _matchingService.fetchWhoLikedMe();
    if (mounted) {
      setState(() {
        _likedByUsers = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleReject(String userId) async {
    // Optimistically remove from list immediately for better UI flow
    setState(() {
      _likedByUsers.removeWhere((user) => user['id'] == userId);
    });
    
    // Perform backend operation
    await _matchingService.swipeLeft(userId);
  }

  Future<void> _handleAccept(String userId) async {
    // 1. Perform Swipe Right
    final isMatch = await _matchingService.swipeRight(userId);
    
    // 2. Show User Feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isMatch ? "It's a Match! Check your Chats." : "You liked them back!"),
          backgroundColor: kRose,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // 3. Remove from this list (they move to Matches now)
      setState(() {
        _likedByUsers.removeWhere((user) => user['id'] == userId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E6E1), // kTan
      appBar: AppBar(
        title: const Text("Likes You", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: kRose))
          : _likedByUsers.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _likedByUsers.length,
                itemBuilder: (context, index) {
                  final user = _likedByUsers[index];
                  // Ensure we have a valid key for lists
                  return _buildUserTile(user, key: ValueKey(user['id'])); 
                },
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "No pending likes",
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Go swipe to find more matches!",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, {Key? key}) {
    final photoUrl = (user['photo_urls'] != null && (user['photo_urls'] as List).isNotEmpty)
        ? user['photo_urls'][0]
        : 'https://via.placeholder.com/150';
    final name = user['full_name'] ?? 'User';
    final age = _calculateAge(user['birthday']);
    final userId = user['id']; // Needed for actions

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundImage: NetworkImage(photoUrl),
            backgroundColor: Colors.grey.shade200,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$name, $age",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  user['job_title'] ?? "No job title",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Action Buttons
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent),
            onPressed: () => _handleReject(userId),
          ),
          IconButton(
            icon: const Icon(Icons.favorite, color: Color(0xFF00BFA5)),
            onPressed: () => _handleAccept(userId),
          ),
        ],
      ),
    );
  }

  int _calculateAge(String? birthdayString) {
    if (birthdayString == null) return 24;
    try {
      final birthday = DateTime.parse(birthdayString);
      final now = DateTime.now();
      int age = now.year - birthday.year;
      if (now.month < birthday.month || (now.month == birthday.month && now.day < birthday.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 24;
    }
  }
}