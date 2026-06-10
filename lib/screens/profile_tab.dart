import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:clush/l10n/app_localizations.dart';
import 'package:clush/providers/profile_provider.dart';
import 'package:clush/providers/wallet_provider.dart';
import 'package:clush/screens/edit_profile_page.dart';
import 'package:clush/screens/profile_view_page.dart';
import 'package:clush/screens/settings_page.dart';
import 'package:clush/screens/setting_sub_pages.dart';
import 'package:clush/theme/colors.dart';
import 'package:clush/widgets/heart_loader.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final walletAsync = ref.watch(walletProvider);

    return profileAsync.when(
      loading: () => const Scaffold(
        backgroundColor: kCream,
        body: Center(child: HeartLoader()),
      ),
      error: (e, st) {
        debugPrint('Error loading profile: $e');
        debugPrint('$st');
        return Scaffold(
          backgroundColor: kCream,
          body: Center(child: Text('Error loading profile: $e')),
        );
      },
      data: (profile) {
        if (profile == null) {
          return const Scaffold(
            backgroundColor: kCream,
            body: Center(child: HeartLoader()),
          );
        }

        final wallet = walletAsync.value ?? const WalletState();
        final photos = profile['photo_urls'] as List? ?? [];
        final firstPhoto = photos.isNotEmpty ? photos.first as String : '';
        final name = profile['full_name'] as String? ?? 'User';
        final age = _calculateAge(profile['birthday'] as String?);
        final isVerified = profile['is_verified'] as bool? ?? false;
        final completion = _calculateCompletion(profile);

        return Scaffold(
          backgroundColor: kCream,
          body: SafeArea(
            child: RefreshIndicator(
              color: kAccent,
              onRefresh: () async {
                ref.invalidate(myProfileProvider);
                ref.invalidate(walletProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.myProfile ?? 'My Profile',
                          style: GoogleFonts.gabarito(
                            fontWeight: FontWeight.bold,
                            fontSize: 26,
                            color: kBlack,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: kParchment,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: kInk.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.push<void>(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (ctx, anim, _) =>
                                    const SettingsPage(),
                                transitionsBuilder: (ctx, anim, _, child) =>
                                    SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(1, 0),
                                    end: Offset.zero,
                                  ).chain(CurveTween(curve: Curves.easeInOutQuart))
                                      .animate(anim),
                                  child: child,
                                ),
                                transitionDuration:
                                    const Duration(milliseconds: 500),
                              ),
                            ),
                            icon: const Icon(Icons.settings_rounded, color: kBlack),
                            tooltip: AppLocalizations.of(context)?.settings ??
                                'Settings',
                          ),
                        ),
                      ],
                    ).animate().fade(duration: 400.ms).slideY(
                          begin: -0.2,
                          end: 0,
                          curve: Curves.easeOutQuad,
                        ),
                    const SizedBox(height: 32),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(25),
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ProfileViewPage(profile: profile),
                          ),
                        ),
                        child: _buildProfilePreviewCard(
                          firstPhoto,
                          name,
                          age,
                          isVerified,
                          (MediaQuery.sizeOf(context).height * 0.55)
                              .clamp(380.0, 520.0),
                        ),
                      ),
                    ).animate().fade(duration: 600.ms, delay: 200.ms).scale(
                          begin: const Offset(0.95, 0.95),
                          end: const Offset(1, 1),
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 16),
                    _buildCompletionCard(context, profile, completion),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        AppLocalizations.of(context)?.thisIsHowYouAppear ??
                            'This is how you appear to others',
                        style: GoogleFonts.figtree(
                          color: kInkMuted,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ).animate().fade(duration: 600.ms, delay: 400.ms),
                    ),
                    const SizedBox(height: 32),
                    _buildUpgradeSection(context, wallet),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfilePreviewCard(String photoUrl, String name, int age, bool isVerified, double cardHeight) {
    return Container(
      height: cardHeight,
      width: double.infinity,
      decoration: BoxDecoration(color: kParchment,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: kInk.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8))
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: photoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                        color: kBone, 
                        child: const Center(child: HeartLoader(size: 40))),
                    errorWidget: (context, url, error) =>
                        Container(color: kBone, child: const Icon(Icons.person, size: 50, color: kInkMuted)),
                  )
                : Container(color: kBone, child: const Icon(Icons.person, size: 50, color: kInkMuted)),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, kInk.withOpacity(0.6)],
                stops: const [0.7, 1.0],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    "$name, $age",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.gabarito(
                      fontWeight: FontWeight.bold, 
                      color: Colors.white,
                      fontSize: 32,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(color: kInk.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                      ]
                    ),
                  ),
                ),

                if (isVerified) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.verified, color: kRose, size: 28),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile completion ────────────────────────────────────────────────────
  // Weighs photos (50%), prompts/questions (30%) and bio + essentials (20%)
  // to produce a single completion percentage shown on the completion card.
  _ProfileCompletion _calculateCompletion(Map<String, dynamic> profile) {
    const maxPhotos = 6;
    const maxPrompts = 3;

    final photos = profile['photo_urls'] as List? ?? [];
    final prompts = profile['prompts'] as List? ?? [];

    final photoScore = (photos.length / maxPhotos).clamp(0.0, 1.0);
    final promptScore = (prompts.length / maxPrompts).clamp(0.0, 1.0);

    final hasBio = (profile['custom_message'] as String?)?.trim().isNotEmpty ?? false;
    const essentialKeys = [
      'job_title',
      'education',
      'location',
      'height',
      'interests',
    ];
    final filledEssentials = essentialKeys.where((key) {
      final value = profile[key];
      if (value is String) return value.trim().isNotEmpty;
      if (value is List) return value.isNotEmpty;
      return value != null;
    }).length;
    final aboutScore = ((hasBio ? 1 : 0) + filledEssentials) / (essentialKeys.length + 1);

    final overall = photoScore * 0.5 + promptScore * 0.3 + aboutScore * 0.2;

    return _ProfileCompletion(
      percent: (overall * 100).round().clamp(0, 100),
      photosAdded: photos.length,
      photosTarget: maxPhotos,
      promptsAdded: prompts.length,
      promptsTarget: maxPrompts,
      aboutComplete: hasBio && filledEssentials == essentialKeys.length,
    );
  }

  Widget _buildCompletionCard(BuildContext context, Map<String, dynamic> profile, _ProfileCompletion completion) {
    if (completion.percent >= 100) return const SizedBox.shrink();

    final missing = <String>[];
    if (completion.photosAdded < completion.photosTarget) {
      missing.add('Add ${completion.photosTarget - completion.photosAdded} more photo${completion.photosTarget - completion.photosAdded == 1 ? '' : 's'}');
    }
    if (completion.promptsAdded < completion.promptsTarget) {
      missing.add('Answer ${completion.promptsTarget - completion.promptsAdded} more prompt${completion.promptsTarget - completion.promptsAdded == 1 ? '' : 's'}');
    }
    if (!completion.aboutComplete) {
      missing.add('Fill out your bio & essentials');
    }

    return GestureDetector(
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => EditProfilePage(
            currentData: profile,
            highlightSections: completion.missingSections,
          ),
        ),
      ),
      child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kParchment,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBone, width: 1.5),
        boxShadow: [
          BoxShadow(color: kInk.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value: completion.percent / 100,
                        strokeWidth: 5,
                        backgroundColor: kBone,
                        valueColor: const AlwaysStoppedAnimation<Color>(kRose),
                      ),
                    ),
                    Text(
                      '${completion.percent}%',
                      style: GoogleFonts.gabarito(
                        color: kInk,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Strength',
                      style: GoogleFonts.gabarito(
                        color: kInk,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      missing.isNotEmpty
                          ? missing.first
                          : 'Looking good — keep it up!',
                      style: GoogleFonts.figtree(
                        color: kInkMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (missing.length > 1) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: kBone),
            const SizedBox(height: 12),
            ...missing.skip(1).map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 5, color: kInkMuted),
                      const SizedBox(width: 8),
                      Text(
                        tip,
                        style: GoogleFonts.figtree(
                          color: kInkMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
      ),
    ).animate().fade(duration: 500.ms, delay: 300.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }


  void _showPurchaseSheet(BuildContext context, _PurchaseItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseSheet(item: item),
    );
  }

  Widget _buildFeatureTilesRow(BuildContext context, WalletState wallet) {
    final superLikes = wallet.superLikesRemaining;
    final rewinds    = wallet.rewindsRemaining;
    final saves      = wallet.savesRemaining;

    final items = [
      _PurchaseItem(
        label: 'Super Likes',
        count: superLikes,
        icon: Icons.star_rounded,
        accentColor: const Color(0xFF5B8FF9),
        packs: [
          _Pack('1 Super Like',  '₹29'),
          _Pack('3 Super Likes', '₹75'),
          _Pack('10 Super Likes','₹149'),
        ],
      ),
      _PurchaseItem(
        label: 'Rewinds',
        count: rewinds,
        icon: Icons.replay_rounded,
        accentColor: const Color(0xFFB97FD4),
        packs: [
          _Pack('Pack of 3',  '₹39'),
          _Pack('Pack of 10', '₹89'),
        ],
      ),
      _PurchaseItem(
        label: 'Saves',
        count: saves,
        icon: Icons.bookmark_rounded,
        accentColor: kRose,
        packs: [
          _Pack('Pack of 5',  '₹29'),
          _Pack('Pack of 15', '₹59'),
        ],
      ),
    ];

    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = screenWidth - 40 - 30.0; // leaves ~30px peek of next card

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return Padding(
            padding: EdgeInsets.only(right: i == items.length - 1 ? 0 : 12),
            child: GestureDetector(
              onTap: () => _showPurchaseSheet(context, item),
              child: Container(
                width: cardWidth,
                decoration: BoxDecoration(
                  color: kParchment,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kBone, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: kInk.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: item.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: item.accentColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${item.count}',
                          style: GoogleFonts.gabarito(
                            color: kInk,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: GoogleFonts.figtree(
                            color: kInkMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: item.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'GET MORE',
                        style: GoogleFonts.figtree(
                          color: item.accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fade(duration: 400.ms, delay: (300 + i * 80).ms).slideX(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
          );
        },
      ),
    );
  }

  Widget _buildUpgradeSection(BuildContext context, WalletState wallet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFeatureTilesRow(context, wallet),
        const SizedBox(height: 14),

        // ── Clush+ comparison card ────────────────────────────────────────────
        _buildClushPlusCard(context),
      ],
    );
  }

  Widget _buildClushPlusCard(BuildContext context) {
    // (feature label, free value, clush+ value)
    const rows = [
      ('Right Swipes / 24 hrs', '6',       '20'),
      ('"Likes You" Screen',    'Blurred', 'Fully Visible'),
      ('Rewinds / week',        '2',       'Unlimited'),
    ];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionsPage()),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: kParchment,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kBone, width: 1.5),
          boxShadow: [BoxShadow(color: kInk.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          children: [
            // ── Header row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
              child: Row(
                children: [
                  Text('Clush', style: GoogleFonts.gabarito(color: kAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('+', style: GoogleFonts.gabarito(color: kAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: kAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('UPGRADE', style: GoogleFonts.figtree(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ),
                ],
              ),
            ),

            // ── Divider ─────────────────────────────────────────────────────
            Container(height: 1, color: kBone),

            // ── Column headers ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('What\'s Included',
                      style: GoogleFonts.figtree(color: kInk, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  SizedBox(
                    width: 52,
                    child: Center(child: Text('Free', style: GoogleFonts.figtree(color: kInkMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                  ),
                  SizedBox(
                    width: 64,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Clush', style: GoogleFonts.gabarito(color: kAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('+', style: GoogleFonts.gabarito(color: kAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Feature rows ─────────────────────────────────────────────────
            ...rows.asMap().entries.map((e) {
              final isLast = e.key == rows.length - 1;
              final label    = e.value.$1;
              final freeVal  = e.value.$2;
              final plusVal  = e.value.$3;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(label,
                            style: GoogleFonts.figtree(color: kInk, fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                        SizedBox(
                          width: 52,
                          child: Center(
                            child: Text(freeVal,
                              style: GoogleFonts.figtree(color: kInkMuted, fontSize: 11, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Center(
                            child: Text(plusVal,
                              style: GoogleFonts.figtree(color: kRose, fontSize: 11, fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) Container(height: 1, color: kBone, margin: const EdgeInsets.symmetric(horizontal: 16)),
                ],
              );
            }),

            // ── See all features ─────────────────────────────────────────────
            Container(height: 1, color: kBone),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'See all Features',
                style: GoogleFonts.figtree(color: kInkMuted, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ).animate().fade(duration: 500.ms, delay: 500.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
    );
  }

  int _calculateAge(String? birthdayString) {
    if (birthdayString == null) return 0;
    final birthday = DateTime.parse(birthdayString);
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month || (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _ProfileCompletion {
  final int percent;
  final int photosAdded;
  final int photosTarget;
  final int promptsAdded;
  final int promptsTarget;
  final bool aboutComplete;

  const _ProfileCompletion({
    required this.percent,
    required this.photosAdded,
    required this.photosTarget,
    required this.promptsAdded,
    required this.promptsTarget,
    required this.aboutComplete,
  });

  /// Section keys (matching [EditProfilePage.highlightSections]) that are
  /// still incomplete, in the order they appear on the edit page.
  Set<String> get missingSections => {
        if (photosAdded < photosTarget) 'photos',
        if (!aboutComplete) 'essentials',
        if (promptsAdded < promptsTarget) 'prompts',
      };
}

class _Pack {
  final String label;
  final String price;
  const _Pack(this.label, this.price);
}

class _PurchaseItem {
  final String label;
  final int count;
  final IconData icon;
  final Color accentColor;
  final List<_Pack> packs;

  const _PurchaseItem({
    required this.label,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.packs,
  });
}

// ── Purchase bottom sheet ─────────────────────────────────────────────────────

class _PurchaseSheet extends StatelessWidget {
  final _PurchaseItem item;
  const _PurchaseSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      height: screenHeight * 0.82,
      decoration: const BoxDecoration(
        color: kTan,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: kBone,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Icon circle + title
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: item.accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.accentColor, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            item.label,
            style: GoogleFonts.gabarito(
              color: kInk,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a pack to get started',
            style: GoogleFonts.figtree(color: kInkMuted, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),

          // Divider
          Container(height: 1, color: kBone, margin: const EdgeInsets.symmetric(horizontal: 20)),
          const SizedBox(height: 16),

          // Pack list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: item.packs.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final pack = item.packs[index];
                final isPopular = item.packs.length > 2 && index == 1;
                return _PackTile(
                  pack: pack,
                  accentColor: item.accentColor,
                  isPopular: isPopular,
                );
              },
            ),
          ),

          // Maybe later
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: kBone,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'Maybe Later',
                    style: GoogleFonts.figtree(
                      color: kInkMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  final _Pack pack;
  final Color accentColor;
  final bool isPopular;

  const _PackTile({
    required this.pack,
    required this.accentColor,
    required this.isPopular,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: kParchment,
          borderRadius: BorderRadius.circular(18),
          border: isPopular
              ? Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5)
              : Border.all(color: kBone, width: 1.5),
          boxShadow: [
            BoxShadow(color: kInk.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isPopular) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'MOST POPULAR',
                        style: GoogleFonts.figtree(
                          color: accentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    pack.label,
                    style: GoogleFonts.figtree(
                      color: kInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                pack.price,
                style: GoogleFonts.figtree(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
