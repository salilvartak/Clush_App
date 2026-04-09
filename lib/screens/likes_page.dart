import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:clush/services/matching_service.dart';
import 'package:clush/widgets/match_animation_dialog.dart';
import 'package:clush/widgets/heart_loader.dart';
import 'package:clush/widgets/activity_badge.dart';
import 'package:clush/screens/setting_sub_pages.dart';

import 'package:clush/theme/colors.dart';

class LikesPage extends StatefulWidget {
  const LikesPage({super.key});

  @override
  State<LikesPage> createState() => _LikesPageState();
}

class _LikesPageState extends State<LikesPage> with SingleTickerProviderStateMixin {
  final MatchingService _matchingService = MatchingService();
  late TabController _tabController;
  
  List<Map<String, dynamic>> _likedByUsers = [];
  List<Map<String, dynamic>> _savedUsers = [];
  bool _isLoading = true;
  int _likesRemaining = 6;
  bool _isPremium = false;
  String? _myPhotoUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    await Future.wait([
      _fetchMyPhoto(),
      _fetchLikes(),
      _fetchSaved(),
      _fetchProfileSettings(),
    ]);
  }

  Future<void> _fetchProfileSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('is_premium')
          .eq('id', uid)
          .maybeSingle();
      if (data != null && mounted) {
        final premiumVal = data['is_premium'];
        bool parsedPremium = false;
        if (premiumVal is bool) parsedPremium = premiumVal;
        else if (premiumVal is String) parsedPremium = premiumVal.toLowerCase() == 'true';
        
        final lr = await _matchingService.getLikesRemaining(parsedPremium);
        setState(() {
           _isPremium = parsedPremium;
           _likesRemaining = lr;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchMyPhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('photo_urls')
          .eq('id', uid)
          .maybeSingle();
      final photos = data?['photo_urls'];
      if (photos is List && photos.isNotEmpty && mounted) {
        setState(() => _myPhotoUrl = photos[0] as String?);
      }
    } catch (_) {}
  }

  Future<void> _fetchLikes() async {
    final sw = Stopwatch()..start();
    final users = await _matchingService.fetchWhoLikedMe();
    if (mounted) {
      final elapsed = sw.elapsedMilliseconds;
      if (elapsed < 1000) await Future.delayed(Duration(milliseconds: 1000 - elapsed));
      setState(() {
        _likedByUsers = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSaved() async {
    final users = await _matchingService.fetchSavedProfiles();
    if (mounted) {
      setState(() => _savedUsers = users);
    }
  }

  Future<void> _handleReject(String userId) async {
    setState(() {
      _likedByUsers.removeWhere((user) => user['id'] == userId);
    });
    await _matchingService.swipeLeft(userId);
  }

  Future<void> _handleUnsave(String userId) async {
    setState(() {
      _savedUsers.removeWhere((user) => user['id'] == userId);
    });
    await _matchingService.unsaveProfile(userId);
  }

  Future<void> _handleAccept(String userId, {bool fromSaved = false}) async {
    if (_likesRemaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Out of likes! Wait until they replenish to like back.',
            style: GoogleFonts.figtree(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final userList = fromSaved ? _savedUsers : _likedByUsers;
    final user = userList.firstWhere((u) => u['id'] == userId, orElse: () => {});

    final isMatch = await _matchingService.swipeRight(userId);

    if (!mounted) return;

    setState(() {
       userList.removeWhere((u) => u['id'] == userId);
       _likesRemaining--;
    });

    if (fromSaved) {
      await _matchingService.unsaveProfile(userId);
    }

    if (isMatch) {
      final photos = user['photo_urls'];
      final matchPhoto = (photos is List && photos.isNotEmpty)
          ? photos[0] as String
          : '';
      showMatchAnimation(
        context,
        myPhotoUrl: _myPhotoUrl ?? '',
        matchPhotoUrl: matchPhoto,
        matchName: user['full_name'] as String? ?? 'them',
        onMessage: () {},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Liked back! (${_likesRemaining} left)',
            style: GoogleFonts.figtree(color: Colors.white)),
        backgroundColor: kRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTan, 
      appBar: AppBar(
        title: Text(
          "Connections",
          style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 26, color: kBlack, letterSpacing: -0.5)
        ),
        backgroundColor: kTan,
        elevation: 0,
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kRose,
          labelColor: kRose,
          unselectedLabelColor: kInkMuted,
          labelStyle: GoogleFonts.figtree(fontWeight: FontWeight.bold, fontSize: 16),
          unselectedLabelStyle: GoogleFonts.figtree(fontWeight: FontWeight.w500, fontSize: 16),
          tabs: const [
            Tab(text: "Likes"),
            Tab(text: "Saved"),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: HeartLoader())
          : TabBarView(
              controller: _tabController,
              children: [
                _likedByUsers.isEmpty ? _buildEmptyState("Hearts are drifting just beyond your beam.", "assets/images/1.svg") : _buildList(_likedByUsers, false),
                _savedUsers.isEmpty ? _buildEmptyState("No saved profiles yet. Save them for later in Discover!", "assets/images/1.svg") : _buildList(_savedUsers, true),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> users, bool isSaved) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24, left: 16, right: 16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserTile(user, isSaved, key: ValueKey(user['id']))
            .animate()
            .fade(duration: 400.ms, delay: (50 * index).ms)
            .slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
      },
    );
  }

  Widget _buildEmptyState(String text, String asset) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(asset, width: 180, height: 180),
            const SizedBox(height: 28),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 20, color: kBlack),
            ),
            const SizedBox(height: 10),
            Text(
              "We can help you navigate to more connections, sooner.",
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(fontSize: 15, color: kInkMuted, height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsPage())),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A0010), Color(0xFF5C0030), kRose],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: kRose.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.auto_awesome_rounded, color: kGold, size: 18),
                  const SizedBox(width: 8),
                  Text("Get Clush+", style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 4),
                  Text("and see more profiles", style: GoogleFonts.figtree(color: Colors.white70, fontSize: 14)),
                ]),
              ),
            ),
          ],
        ),
      ).animate().fade(duration: 600.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, bool isSaved, {Key? key}) {
    final photoUrl = (user['photo_urls'] as List?)?.isNotEmpty == true
        ? user['photo_urls'][0] as String
        : 'https://via.placeholder.com/150';
    final name = user['full_name'] ?? 'User';
    final age = _calculateAge(user['birthday']);
    final userId = user['id'];

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kParchment,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: kInk.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 6)),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 18, color: kBlack),
                ),
                const SizedBox(height: 4),
                Text(
                  user['job_title'] ?? "No job title",
                  style: GoogleFonts.figtree(fontSize: 14, color: kInkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                ActivityBadge(lastSeenAt: user['last_seen_at'] as String?),
              ],
            ),
          ),
          // Action Buttons
          Container(
            decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
            child: IconButton(
              icon: Icon(isSaved ? Icons.delete_outline_rounded : Icons.close_rounded, color: Colors.redAccent, size: 22),
              onPressed: () => isSaved ? _handleUnsave(userId) : _handleReject(userId),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(color: const Color(0xFF00BFA5).withOpacity(0.1), shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.favorite_rounded, color: Color(0xFF00BFA5), size: 22),
              onPressed: () => _handleAccept(userId, fromSaved: isSaved),
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
