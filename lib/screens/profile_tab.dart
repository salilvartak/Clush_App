import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart'; // Typography
import 'package:flutter_animate/flutter_animate.dart'; // Animations
import 'package:clush/screens/profile_view_page.dart'; 
import 'package:clush/screens/settings_page.dart';
import 'package:clush/screens/setting_sub_pages.dart';
import 'package:clush/widgets/heart_loader.dart';
import 'package:clush/l10n/app_localizations.dart';

import 'package:clush/theme/colors.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfile();
  }

  Future<Map<String, dynamic>?> _fetchProfile() async {
    final sw = Stopwatch()..start();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;
    
    final data = await Supabase.instance.client
        .from('profile_discovery')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;

    final elapsed = sw.elapsedMilliseconds;
    if (elapsed < 1200) await Future.delayed(Duration(milliseconds: 1200 - elapsed));
    return data;
  }

  @override
  Widget build(BuildContext context) {
    // Wrapped in a Scaffold to provide the kTan background consistent with other pages
    return Scaffold(
      backgroundColor: kTan,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: HeartLoader());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(child: Text("Error loading profile: ${snapshot.error}"));
            }

            final profile = snapshot.data!;
            final List photos = profile['photo_urls'] ?? [];
            final String firstPhoto = photos.isNotEmpty ? photos.first : '';
            final String name = profile['full_name'] ?? 'User';
            final int age = _calculateAge(profile['birthday']);
            
            // 1. EXTRACT VERIFICATION STATUS
            final bool isVerified = profile['is_verified'] ?? false; 

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.myProfile ?? "My Profile", 
                        style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 26, color: kBlack, letterSpacing: -0.5)
                      ),
                      Container(
                        decoration: BoxDecoration(color: kParchment, shape: BoxShape.circle, boxShadow: [BoxShadow(color: kInk.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SettingsPage()),
                            );
                          },
                          icon: const Icon(Icons.settings_rounded, color: kBlack),
                          tooltip: AppLocalizations.of(context)?.settings ?? "Settings",
                        ),
                      ),
                    ],
                  ).animate().fade(duration: 400.ms).slideY(begin: -0.2, end: 0, curve: Curves.easeOutQuad),
                  const SizedBox(height: 32),
                  
                  // Use InkWell for better hit testing and feedback
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(25),
                      onTap: () {
                        Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => ProfileViewPage(profile: profile))
                        );
                      },
                      child: _buildProfilePreviewCard(
                        firstPhoto, 
                        name, 
                        age, 
                        isVerified, 
                        (MediaQuery.sizeOf(context).height * 0.55).clamp(380.0, 520.0)
                      ),
                    ),
                  ).animate().fade(duration: 600.ms, delay: 200.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), curve: Curves.easeOutCubic),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      AppLocalizations.of(context)?.thisIsHowYouAppear ?? "This is how you appear to others",
                      style: GoogleFonts.figtree(color: kInkMuted, fontSize: 16, fontWeight: FontWeight.w500)
                    ).animate().fade(duration: 600.ms, delay: 400.ms),
                  ),
                  const SizedBox(height: 32),
                  _buildUpgradeSection(context, profile),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // 3. UPDATED WIDGET SIGNATURE
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
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : Container(color: kBone, child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kRose))),
                    errorBuilder: (context, error, stack) =>
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
              children: [
                Flexible(
                  child: Text(
                    "$name, $age",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.gabarito(
                      fontWeight: FontWeight.bold, 
                      color: Colors.white,
                      fontSize: 36,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(color: kInk.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                      ]
                    ),
                  ),
                ),

                if (isVerified) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.verified, color: Colors.blue, size: 28),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _showPurchaseSheet(BuildContext context, _PurchaseItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseSheet(item: item),
    );
  }

  Widget _buildFeatureTilesRow(BuildContext context, Map<String, dynamic> profile) {
    final superLikes = profile['super_likes_remaining'] as int? ?? 0;
    final rewinds    = profile['rewinds_remaining']     as int? ?? 0;
    final saves      = profile['profile_saves_remaining'] as int? ?? 0;

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

  Widget _buildUpgradeSection(BuildContext context, Map<String, dynamic> profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Feature tiles row ─────────────────────────────────────────────────
        _buildFeatureTilesRow(context, profile),
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
                  Text('Clush', style: GoogleFonts.gabarito(color: kInk, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('+', style: GoogleFonts.gabarito(color: kGold, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: kInk,
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
                          Text('Clush', style: GoogleFonts.gabarito(color: kInk, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('+', style: GoogleFonts.gabarito(color: kGold, fontSize: 12, fontWeight: FontWeight.bold)),
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
