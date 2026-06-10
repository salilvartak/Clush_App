import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:clush/providers/likes_provider.dart';
import 'package:clush/providers/profile_provider.dart';
import 'package:clush/providers/wallet_provider.dart';
import 'package:clush/screens/profile_view_page.dart';
import 'package:clush/screens/setting_sub_pages.dart';
import 'package:clush/services/matching_service.dart';
import 'package:clush/theme/colors.dart';
import 'package:clush/widgets/heart_loader.dart';
import 'package:clush/widgets/match_animation_dialog.dart';

class LikesPage extends ConsumerStatefulWidget {
  const LikesPage({super.key});

  @override
  ConsumerState<LikesPage> createState() => _LikesPageState();
}

class _LikesPageState extends ConsumerState<LikesPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _matchingService = MatchingService();
  late TabController _tabController;
  RealtimeChannel? _likesChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupRealtime();
  }

  void _setupRealtime() {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    if (myId == null) return;

    _likesChannel = Supabase.instance.client
        .channel('likes_updates_$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'likes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'target_user_id',
            value: myId,
          ),
          callback: (_) {
            ref.read(likesProvider.notifier).refresh();
          },
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
          callback: (_) {
            ref.read(savedProfilesProvider.notifier).refresh();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _likesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _handleReject(String userId) async {
    ref.read(likesProvider.notifier).remove(userId);
    await _matchingService.swipeLeft(userId);
  }

  Future<void> _handleUnsave(String userId) async {
    ref.read(savedProfilesProvider.notifier).remove(userId);
    await _matchingService.unsaveProfile(userId);
  }

  Future<void> _handleAccept(String userId, {bool fromSaved = false}) async {
    final wallet = ref.read(walletProvider).value ?? const WalletState();

    if (wallet.likesRemaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Out of likes! Wait until they replenish to like back.',
          style: GoogleFonts.figtree(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final likes = ref.read(likesProvider).value ?? [];
    final saved = ref.read(savedProfilesProvider).value ?? [];
    final userList = fromSaved ? saved : likes;
    final user = userList.firstWhere(
      (u) => u['id'] == userId,
      orElse: () => {},
    );

    final result = await _matchingService.swipeRight(userId);
    final bool isMatch = result['match'] == true;

    if (!mounted) return;

    if (result['error'] == 'daily_limit' || result['error'] == 'exhausted') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          result['error'] == 'daily_limit'
              ? 'Out of likes! Wait until they replenish.'
              : 'No credits left! Get Clush+ or purchase more.',
          style: GoogleFonts.figtree(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    if (fromSaved) {
      ref.read(savedProfilesProvider.notifier).remove(userId);
      await _matchingService.unsaveProfile(userId);
    } else {
      ref.read(likesProvider.notifier).remove(userId);
    }
    ref.read(walletProvider.notifier).decrementLikes();

    if (isMatch && user.isNotEmpty) {
      final photos = user['photo_urls'];
      final matchPhoto =
          (photos is List && photos.isNotEmpty) ? photos[0] as String : '';
      final myPhoto = ref.read(myProfileProvider).value?['photo_urls'];
      final myPhotoUrl =
          (myPhoto is List && myPhoto.isNotEmpty) ? myPhoto[0] as String : '';
      showMatchAnimation(
        context,
        myPhotoUrl: myPhotoUrl,
        matchPhotoUrl: matchPhoto,
        matchName: user['full_name'] as String? ?? 'them',
        onMessage: () {},
      );
    } else {
      final remaining = (ref.read(walletProvider).value?.likesRemaining ?? 0);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Liked back! ($remaining left)',
          style: GoogleFonts.figtree(color: Colors.white),
        ),
        backgroundColor: kRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final likesAsync = ref.watch(likesProvider);
    final savedAsync = ref.watch(savedProfilesProvider);
    final wallet = ref.watch(walletProvider).value ?? const WalletState();

    final likedByUsers = likesAsync.value ?? [];
    final savedUsers = savedAsync.value ?? [];
    final isLoading = likesAsync.isLoading && likedByUsers.isEmpty;

    return Scaffold(
      backgroundColor: kCream,
      appBar: AppBar(
        title: Text(
          'Connections',
          style: GoogleFonts.gabarito(
            fontWeight: FontWeight.bold,
            fontSize: 26,
            color: kBlack,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: kCream,
        elevation: 0,
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kRose,
          labelColor: kRose,
          unselectedLabelColor: kInkMuted,
          labelStyle:
              GoogleFonts.figtree(fontWeight: FontWeight.bold, fontSize: 16),
          unselectedLabelStyle:
              GoogleFonts.figtree(fontWeight: FontWeight.w500, fontSize: 16),
          tabs: const [
            Tab(text: 'Likes'),
            Tab(text: 'Saved'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: HeartLoader())
          : TabBarView(
              controller: _tabController,
              children: [
                likedByUsers.isEmpty
                    ? _buildLikesEmptyState()
                    : _buildList(likedByUsers, false, wallet.isPremium),
                savedUsers.isEmpty
                    ? _buildSavedEmptyState()
                    : _buildList(savedUsers, true, wallet.isPremium),
              ],
            ),
    );
  }

  void _refreshAll() {
    ref.read(likesProvider.notifier).refresh();
    ref.read(savedProfilesProvider.notifier).refresh();
  }

  Widget _buildList(
    List<Map<String, dynamic>> users,
    bool isSaved,
    bool isPremium,
  ) {
    final pulses = users.where((u) => u['like_type'] == 'pulse').toList();
    final normals = users.where((u) => u['like_type'] != 'pulse').toList();

    return RefreshIndicator(
      onRefresh: () async => _refreshAll(),
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
                    return _buildPulseTile(user, isSaved, isPremium)
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
                    return _buildNormalTile(user, isSaved, isPremium)
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

  Widget _buildLikesEmptyState() {
    return RefreshIndicator(
      onRefresh: () async => _refreshAll(),
      color: kRose,
      backgroundColor: kParchment,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.04),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No likes',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSerifDisplay(fontWeight: FontWeight.bold, fontSize: 22, color: kAccent),
                ),
                const SizedBox(height: 4),
                Text(
                  "When someone likes you,\nyou'll see it here",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.figtree(fontWeight: FontWeight.normal, fontSize: 14, color: kAccent),
                ),
                Image.asset(
                  'assets/images/no_like.jpeg',
                  width: 300,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsPage())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      color: kAccent,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Get Clush', style: GoogleFonts.gabarito(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('+', style: GoogleFonts.gabarito(color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).animate().slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
        ],
      ),
    );
  }

  Widget _buildSavedEmptyState() {
    return RefreshIndicator(
      onRefresh: () async => _refreshAll(),
      color: kRose,
      backgroundColor: kParchment,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.04),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No saved profiles',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSerifDisplay(fontWeight: FontWeight.bold, fontSize: 22, color: kAccent),
                ),
                const SizedBox(height: 4),
                Text(
                  "Save profiles to revisit\nthem later",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.figtree(fontWeight: FontWeight.normal, fontSize: 14, color: kAccent),
                ),
                Image.asset(
                  'assets/images/no_save.jpeg',
                  width: 300,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsPage())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      color: kAccent,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Get Clush', style: GoogleFonts.gabarito(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('+', style: GoogleFonts.gabarito(color: kGold, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).animate().slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
        ],
      ),
    );
  }

  Widget _buildPulseTile(Map<String, dynamic> user, bool isSaved, bool isPremium) {
    final name = user['full_name'] ?? 'User';
    final age = _calculateAge(user['birthday']);
    final photos = user['photo_urls'] as List?;
    final photoUrl = (photos != null && photos.isNotEmpty) ? photos[0] : null;
    // Saved profiles were explicitly chosen by the user â€” never blur them.
    // The blur/upsell is only for the premium "Likes You" reveal.
    final blur = !isPremium && !isSaved;

    return GestureDetector(
      onTap: () {
        if (blur) {
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
                        if (blur)
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
                      if (blur)
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

  Widget _buildNormalTile(Map<String, dynamic> user, bool isSaved, bool isPremium) {
    final name = user['full_name'] ?? 'User';
    final age = _calculateAge(user['birthday']);
    final photos = user['photo_urls'] as List?;
    final photoUrl = (photos != null && photos.isNotEmpty) ? photos[0] : null;
    // Saved profiles were explicitly chosen by the user â€” never blur them.
    // The blur/upsell is only for the premium "Likes You" reveal.
    final blur = !isPremium && !isSaved;

    return GestureDetector(
      onTap: () {
        if (blur) {
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
                    if (blur)
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
                  if (blur)
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
    final wallet = ref.read(walletProvider).value ?? const WalletState();
    final outOfLikes = wallet.likesRemaining <= 0;

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
                        onPressed: outOfLikes
                            ? null
                            : () {
                                Navigator.pop(context);
                                _handleAccept(user['id'], fromSaved: isSaved);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kRose,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: kBone,
                          disabledForegroundColor: kInkMuted,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: outOfLikes
                            ? const Icon(Icons.lock_outline_rounded, size: 22, color: kInkMuted)
                            : Text(
                                isSaved ? "Send Like to $firstName" : "Match with $firstName",
                                style: GoogleFonts.gabarito(fontWeight: FontWeight.w600, fontSize: 18),
                              ),
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
