import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Typography
import 'package:flutter_animate/flutter_animate.dart'; // Animations
import 'services/matching_service.dart';
import 'main.dart'; // For HeartLoader

const Color kRose = Color(0xFFCD9D8F);
const Color kBlack = Color(0xFF2D2D2D);
const Color kTan = Color(0xFFF8F9FA);

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
      backgroundColor: kTan, 
      appBar: AppBar(
        title: Text(
          "Likes You", 
          style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: kBlack, letterSpacing: -0.5)
        ),
        backgroundColor: kTan,
        elevation: 0,
        centerTitle: false,
      ),
      body: _isLoading 
          ? const Center(child: HeartLoader(size: 60))
          : _likedByUsers.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24, left: 16, right: 16),
                itemCount: _likedByUsers.length,
                itemBuilder: (context, index) {
                  final user = _likedByUsers[index];
                  return _buildUserTile(user, key: ValueKey(user['id']))
                      .animate()
                      .fade(duration: 400.ms, delay: (50 * index).ms)
                      .slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
                },
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))
              ]
            ),
            child: Icon(Icons.favorite_border_rounded, size: 60, color: kRose.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          Text(
            "No pending likes",
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: kBlack),
          ),
          const SizedBox(height: 8),
          Text(
            "Go swipe to find more matches!",
            style: GoogleFonts.outfit(fontSize: 16, color: Colors.black54),
          ),
        ],
      ).animate().fade(duration: 600.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundImage: NetworkImage(photoUrl),
            backgroundColor: kRose.withOpacity(0.1),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$name, $age",
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: kBlack),
                ),
                const SizedBox(height: 4),
                Text(
                  user['job_title'] ?? "No job title",
                  style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Action Buttons
          Container(
            decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 22),
              onPressed: () => _handleReject(userId),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(color: const Color(0xFF00BFA5).withOpacity(0.1), shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.favorite_rounded, color: Color(0xFF00BFA5), size: 22),
              onPressed: () => _handleAccept(userId),
            ),
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