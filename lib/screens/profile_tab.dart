import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart'; // Typography
import 'package:flutter_animate/flutter_animate.dart'; // Animations
import 'package:clush/screens/profile_view_page.dart'; 
import 'package:clush/screens/settings_page.dart';
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
        .from('profiles')
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
