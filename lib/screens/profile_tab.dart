import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart'; // Typography
import 'package:flutter_animate/flutter_animate.dart'; // Animations
import 'package:clush/screens/profile_view_page.dart'; 
import 'package:clush/screens/settings_page.dart';
import 'package:clush/screens/setting_sub_pages.dart';
import 'dart:ui'; // For blur effects
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
                  _buildUpgradeSection(context),
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


  Widget _buildUpgradeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero banner ──────────────────────────────────────────────────────
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsPage())),
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF1A0010), Color(0xFF5C0030), kRose],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: kRose.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(top: -30, right: -30,
                  child: Container(width: 140, height: 140,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)))),
                Positioned(bottom: -40, left: -20,
                  child: Container(width: 160, height: 160,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.04)))),
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text("Clush", style: GoogleFonts.gabarito(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            Text("+", style: GoogleFonts.gabarito(color: kGold, fontSize: 22, fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 6),
                          Text("Get noticed sooner and\nmatch 3x faster",
                              style: GoogleFonts.figtree(color: Colors.white.withValues(alpha: 0.9), fontSize: 15, height: 1.4, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      // Upgrade button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                        child: Text("Upgrade", style: GoogleFonts.figtree(color: kRose, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ).animate().fade(duration: 500.ms, delay: 500.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

        const SizedBox(height: 14),

        // ── Feature tiles ─────────────────────────────────────────────────────
        ...[
          (Icons.back_hand_rounded, kRose, "High Five", "Stand out from the crowd"),
        ].map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsPage())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: kParchment,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kBone),
                boxShadow: [BoxShadow(color: kInk.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: item.$2.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.$1, color: item.$2, size: 22),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.$3, style: GoogleFonts.figtree(fontSize: 15, fontWeight: FontWeight.w700, color: kInk)),
                  Text(item.$4, style: GoogleFonts.figtree(fontSize: 13, color: kInkMuted)),
                ]),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, color: kBone, size: 22),
              ]),
            ),
          ).animate().fade(duration: 400.ms, delay: 600.ms).slideX(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
        )),
      ],
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
