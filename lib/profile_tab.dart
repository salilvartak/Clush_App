import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart'; // Typography
import 'package:flutter_animate/flutter_animate.dart'; // Animations
import 'profile_view_page.dart'; 
import 'settings_page.dart';
import 'dart:ui'; // For blur effects

const Color kRose = Color(0xFFCD9D8F);
const Color kBlack = Color(0xFF2D2D2D);
const Color kTan = Color(0xFFF8F9FA);

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<Map<String, dynamic>?> _fetchProfile() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;
    
    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return data;
  }

  @override
  Widget build(BuildContext context) {
    // Wrapped in a Scaffold to provide the kTan background consistent with other pages
    return Scaffold(
      backgroundColor: kTan,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _fetchProfile(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: kRose));
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
                      Text("My Profile", style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: kBlack, letterSpacing: -0.5)),
                      Container(
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SettingsPage()),
                            );
                          },
                          icon: const Icon(Icons.settings_rounded, color: kBlack),
                          tooltip: "Settings",
                        ),
                      ),
                    ],
                  ).animate().fade(duration: 400.ms).slideY(begin: -0.2, end: 0, curve: Curves.easeOutQuad),
                  const SizedBox(height: 32),
                  
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => ProfileViewPage(profile: profile)) // Assumes ProfileViewPage handles profile map
                      );
                    },
                    // 2. PASS STATUS TO WIDGET
                    child: _buildProfilePreviewCard(firstPhoto, name, age, isVerified).animate().fade(duration: 600.ms, delay: 200.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), curve: Curves.easeOutCubic),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      "This is how you appear to others", 
                      style: GoogleFonts.outfit(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w500)
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
  Widget _buildProfilePreviewCard(String photoUrl, String name, int age, bool isVerified) {
    return Container(
      height: 500,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: photoUrl.isNotEmpty
                ? Image.network(photoUrl, fit: BoxFit.cover)
                : Container(color: Colors.grey.shade300, child: const Icon(Icons.person, size: 50)),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                stops: const [0.7, 1.0],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 4. ROW FOR NAME + TICK
                Row(
                  children: [
                    Text(
                      "$name, $age", 
                      style: GoogleFonts.outfit(
                        color: Colors.white, 
                        fontSize: 36, 
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        shadows: [
                           Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                        ]
                      )
                    ),
                    
                    // --- THE BLUE TICK ---
                    if (isVerified) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.verified, color: Colors.blue, size: 28),
                    ],
                    // ---------------------
                  ],
                ),
                
                const SizedBox(height: 5),
                _buildPreviewBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBadge() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15), 
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.3))
          ),
          child: Row(
            children: [
              const Icon(Icons.visibility_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text("Preview", style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
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