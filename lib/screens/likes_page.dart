import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:clush/services/matching_service.dart';
import 'package:clush/widgets/match_animation_dialog.dart';
import 'package:clush/widgets/heart_loader.dart';
import 'package:clush/screens/setting_sub_pages.dart';

import 'package:clush/theme/colors.dart';
import 'package:clush/screens/profile_view_page.dart';

class LikesPage extends StatefulWidget {
  const LikesPage({super.key});

  @override
  State<LikesPage> createState() => _LikesPageState();
}

class _LikesPageState extends State<LikesPage> with SingleTickerProviderStateMixin {
  final MatchingService _matchingService = MatchingService();
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  RealtimeChannel? _likesChannel;
  
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
    _setupRealtime();
  }

  void _setupRealtime() {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    if (myId == null) return;

    _likesChannel = _supabase
        .channel('likes_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'likes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'target_user_id',
            value: myId,
          ),
          callback: (payload) => _initData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'saved_profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: myId,
          ),
          callback: (payload) => _initData(),
        )
        .subscribe();
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
    
    // Sort Pulse to top
    users.sort((a, b) {
      if (a['like_type'] == 'pulse' && b['like_type'] != 'pulse') return -1;
      if (a['like_type'] != 'pulse' && b['like_type'] == 'pulse') return 1;
      return 0;
    });

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

    final result = await _matchingService.swipeRight(userId);
    final bool isMatch = result['match'] == true;

    if (!mounted) return;

    if (result['error'] == 'limit_exceeded') {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Weekly limit exceeded!',
            style: GoogleFonts.figtree(color: Colors.white)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

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
    _likesChannel?.unsubscribe();
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
    final pulses = users.where((u) => u['like_type'] == 'pulse').toList();
    final normals = users.where((u) => u['like_type'] != 'pulse').toList();

    return RefreshIndicator(
      onRefresh: _initData,
      color: kRose,
      backgroundColor: kParchment,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (pulses.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final user = pulses[index];
                    return _buildPulseTile(user, isSaved)
                        .animate()
                        .fade(duration: 400.ms, delay: (50 * index).ms)
                        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
                  },
                  childCount: pulses.length,
                ),
              ),
            ),
          if (normals.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.65,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final user = normals[index];
                    return _buildNormalTile(user, isSaved)
                        .animate()
                        .fade(duration: 400.ms, delay: (100 * index).ms)
                        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
                  },
                  childCount: normals.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text, String asset) {
    return RefreshIndicator(
      onRefresh: _initData,
      color: kRose,
      backgroundColor: kParchment,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
          Padding(
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
        ],
      ),
    );
  }

  Widget _buildPulseTile(Map<String, dynamic> user, bool isSaved) {
    final name = user['full_name'] ?? 'User';
    final age = _calculateAge(user['birthday']);
    final photos = user['photo_urls'] as List?;
    final photoUrl = (photos != null && photos.isNotEmpty) ? photos[0] : null;

    return GestureDetector(
      onTap: () {
        if (!_isPremium) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsPage()));
        } else {
          _showProfilePopup(user, isSaved);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20.0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kParchment,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kGold.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: kGold.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: kTan,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (photoUrl != null)
                          Image.network(photoUrl, fit: BoxFit.cover)
                        else
                          const Icon(Icons.person, color: kInkMuted),
                        if (!_isPremium)
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(color: Colors.transparent),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, color: kGold, size: 14),
                            const SizedBox(width: 4),
                            Text("PULSE", style: GoogleFonts.figtree(color: kGold, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (!_isPremium)
                        Container(
                          width: 80,
                          height: 14,
                          decoration: BoxDecoration(
                            color: kBone,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )
                      else
                        Text("$name, $age", style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 18, color: kBlack)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: kInkMuted, size: 16),
              ],
            ),
            if (user['like_message'] != null && user['like_message'].toString().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kTan.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBone.withValues(alpha: 0.5)),
                ),
                child: Text(
                  user['like_message'],
                  style: GoogleFonts.figtree(fontSize: 14, color: kInk, fontStyle: FontStyle.italic, height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNormalTile(Map<String, dynamic> user, bool isSaved) {
    final name = user['full_name'] ?? 'User';
    final age = _calculateAge(user['birthday']);
    final photos = user['photo_urls'] as List?;
    final photoUrl = (photos != null && photos.isNotEmpty) ? photos[0] : null;

    return GestureDetector(
      onTap: () {
        if (!_isPremium) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsPage()));
        } else {
          _showProfilePopup(user, isSaved);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: kParchment,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: kInk.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (photoUrl != null)
                      Image.network(photoUrl, fit: BoxFit.cover)
                    else
                      Container(color: kTan, child: const Icon(Icons.person, color: kInkMuted, size: 40)),
                    if (!_isPremium)
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(color: Colors.transparent),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isPremium)
                    Container(
                      width: 70,
                      height: 14,
                      decoration: BoxDecoration(
                        color: kBone,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )
                  else
                    Text(
                      "$name, $age",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 16, color: kBlack),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    user['location']?.toString().split(',')[0] ?? "Nearby",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.figtree(fontSize: 12, color: kInkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfilePopup(Map<String, dynamic> user, bool isSaved) {
    final firstName = user['full_name']?.split(' ').first ?? 'User';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: kCream,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: kBone, borderRadius: BorderRadius.circular(2))),
              Expanded(
                child: ProfileViewPage(
                  profile: user,
                  showBackButton: false,
                  showScaffold: false,
                ),
              ),
              // Action Buttons
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  color: kCream,
                  boxShadow: [BoxShadow(color: kInk.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleAccept(user['id'], fromSaved: isSaved);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kRose,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text("Match with $firstName", style: GoogleFonts.gabarito(fontWeight: FontWeight.w600, fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (isSaved) _handleUnsave(user['id']);
                          else _handleReject(user['id']);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: kInkMuted.withValues(alpha: 0.3)),
                          foregroundColor: kInkMuted,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(isSaved ? "Remove Saved" : "Not Interested", style: GoogleFonts.gabarito(fontWeight: FontWeight.w500, fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().slideY(begin: 1.0, end: 0, duration: 400.ms, curve: Curves.easeOutQuart);
      },
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
