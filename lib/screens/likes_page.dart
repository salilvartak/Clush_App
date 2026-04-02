import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:clush/services/matching_service.dart';
import 'package:clush/widgets/match_animation_dialog.dart';
import 'package:clush/widgets/heart_loader.dart';

import 'package:clush/l10n/app_localizations.dart';

import 'package:clush/theme/colors.dart';

class LikesPage extends StatefulWidget {
  const LikesPage({super.key});

  @override
  State<LikesPage> createState() => _LikesPageState();
}

class _LikesPageState extends State<LikesPage> {
  final MatchingService _matchingService = MatchingService();
  List<Map<String, dynamic>> _likedByUsers = [];
  bool _isLoading = true;
  String? _myPhotoUrl;

  @override
  void initState() {
    super.initState();
    _fetchLikes();
    _fetchMyPhoto();
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
      if (elapsed < 2200) await Future.delayed(Duration(milliseconds: 2200 - elapsed));
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
    final user = _likedByUsers.firstWhere((u) => u['id'] == userId,
        orElse: () => {});

    final isMatch = await _matchingService.swipeRight(userId);

    if (!mounted) return;

    setState(() => _likedByUsers.removeWhere((u) => u['id'] == userId));

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
        content: Text(AppLocalizations.of(context)?.likedBack ?? 'You liked them back!',
            style: GoogleFonts.figtree(color: Colors.white)),
        backgroundColor: kRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTan, 
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.likesYou ?? "Likes You", 
          style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 26, color: kBlack, letterSpacing: -0.5)
        ),
        backgroundColor: kTan,
        elevation: 0,
        centerTitle: false,
      ),
      body: _isLoading 
          ? const Center(child: HeartLoader())
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/images/1.svg', width: 180, height: 180),
            const SizedBox(height: 28),
            Text(
              AppLocalizations.of(context)?.heartsDrifting ?? "Hearts are drifting just beyond your beam.",
              textAlign: TextAlign.center,
              style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 20, color: kBlack),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)?.helpNavigateConnection ?? "We can help you navigate to more connections, sooner.",
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(fontSize: 15, color: kInkMuted, height: 1.5),
            ),
          ],
        ),
      ).animate().fade(duration: 600.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, {Key? key}) {
    final photoUrl = (user['photo_urls'] as List?)?.isNotEmpty == true
        ? user['photo_urls'][0] as String
        : 'https://via.placeholder.com/150';
    final name = user['full_name'] ?? 'User';
    final age = _calculateAge(user['birthday']);
    final userId = user['id']; // Needed for actions

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
                  user['job_title'] ?? AppLocalizations.of(context)?.noJobTitle ?? "No job title",
                  style: GoogleFonts.figtree(fontSize: 14, color: kInkMuted),
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
