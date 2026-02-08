import 'package:flutter/material.dart';
import 'dart:ui'; // For blur effects

const Color kRose = Color(0xFFCD9D8F);
const Color kTan = Color(0xFFE9E6E1);

class ProfileViewPage extends StatelessWidget {
  final Map<String, dynamic> profile;

  const ProfileViewPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    // 1. Extract Data
    final List photoUrls = profile['photo_urls'] ?? [];
    final List prompts = profile['prompts'] ?? [];
    final List interests = profile['interests'] ?? [];
    final List foods = profile['foods'] ?? [];
    final List places = profile['places'] ?? [];
    
    final String name = profile['full_name'] ?? 'User';
    final int age = _calculateAge(profile['birthday']);
    final String intent = profile['intent'] ?? '';

    // 2. Prepare Lists for the "Mix" section
    List<String> remainingPhotos = [];
    if (photoUrls.length > 1) {
      remainingPhotos.addAll(List<String>.from(photoUrls.sublist(1)));
    }

    List<Map<String, dynamic>> remainingPrompts = [];
    if (prompts.length > 1) {
      for (var p in prompts.sublist(1)) {
        if (p != null) remainingPrompts.add(p as Map<String, dynamic>);
      }
    }

    // 3. Build Content List
    List<Widget> content = [];

    // -- 1. FIRST IMAGE CARD (Name + Age) --
    if (photoUrls.isNotEmpty) {
      content.add(
        _buildMainPhotoCard(
          url: photoUrls[0],
          name: name,
          age: age,
        )
      );
    }

    // -- 2. MY PASSIONS --
    final allInterests = [...interests, ...foods, ...places];
    if (allInterests.isNotEmpty) {
      content.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("My Passions"),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allInterests.map((e) => _buildPremiumChip(e)).toList(),
              ),
            ],
          ),
        )
      );
    }

    // -- 3. WHAT I'M LOOKING FOR (Intent) --
    if (intent.isNotEmpty) {
      content.add(_buildIntentCard(intent));
    }

    // -- 4. FIRST PROMPT ANSWER --
    if (prompts.isNotEmpty && prompts[0] != null) {
      content.add(_buildPremiumPromptCard(prompts[0]));
    }

    // -- 5. THE MIX (Organic Order) --
    // Mix Item 1: Photo 2
    if (remainingPhotos.isNotEmpty) content.add(_buildSecondaryPhotoCard(remainingPhotos.removeAt(0)));
    
    // Mix Item 2: Photo 3
    if (remainingPhotos.isNotEmpty) content.add(_buildSecondaryPhotoCard(remainingPhotos.removeAt(0)));

    // Mix Item 3: Prompt 2
    if (remainingPrompts.isNotEmpty) content.add(_buildPremiumPromptCard(remainingPrompts.removeAt(0)));

    // Mix Item 4: Photo 4
    if (remainingPhotos.isNotEmpty) content.add(_buildSecondaryPhotoCard(remainingPhotos.removeAt(0)));

    // Mix Item 5: Photo 5
    if (remainingPhotos.isNotEmpty) content.add(_buildSecondaryPhotoCard(remainingPhotos.removeAt(0)));

    // Mix Item 6: Prompt 3
    if (remainingPrompts.isNotEmpty) content.add(_buildPremiumPromptCard(remainingPrompts.removeAt(0)));

    // Leftovers
    while (remainingPhotos.isNotEmpty) {
      content.add(_buildSecondaryPhotoCard(remainingPhotos.removeAt(0)));
    }
    while (remainingPrompts.isNotEmpty) {
      content.add(_buildPremiumPromptCard(remainingPrompts.removeAt(0)));
    }

    content.add(const SizedBox(height: 60)); // Bottom padding

    return Scaffold(
      backgroundColor: kTan,
      body: Stack(
        children: [
          // SCROLLABLE CONTENT
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 80), // Push down for header
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content,
            ),
          ),

          // PREMIUM FLOATING HEADER
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 80,
                  color: kTan.withOpacity(0.8),
                  padding: const EdgeInsets.fromLTRB(10, 40, 10, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        "Preview",
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.black87,
                          letterSpacing: 0.5
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= PREMIUM WIDGETS =================

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: kRose,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // 1. MAIN PHOTO CARD (Large, with Gradient & Text)
  Widget _buildMainPhotoCard({required String url, required String name, required int age}) {
    return Container(
      height: 600,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: _premiumShadowDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(url, fit: BoxFit.cover),
            
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent, 
                    Colors.black.withOpacity(0.2), 
                    Colors.black.withOpacity(0.8)
                  ],
                  stops: const [0.6, 0.8, 1.0],
                ),
              ),
            ),
            
            // Name & Age
            Positioned(
              bottom: 30,
              left: 24,
              child: Text(
                "$name, $age",
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 34, 
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2))]
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. SECONDARY PHOTO CARD (Standard size, no text)
  Widget _buildSecondaryPhotoCard(String url) {
    return Container(
      height: 500,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _premiumShadowDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.network(url, fit: BoxFit.cover),
      ),
    );
  }

  // 3. INTENT CARD
  Widget _buildIntentCard(String intent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: _premiumShadowDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kRose.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_rounded, color: kRose, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "I'M LOOKING FOR",
                style: TextStyle(
                  color: Colors.grey, 
                  fontSize: 11, 
                  fontWeight: FontWeight.w700, 
                  letterSpacing: 1.0
                ),
              ),
              const SizedBox(height: 4),
              Text(
                intent,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          )
        ],
      ),
    );
  }

  // 4. PREMIUM PROMPT CARD
  Widget _buildPremiumPromptCard(Map<String, dynamic> prompt) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: _premiumShadowDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (prompt['question'] as String).toUpperCase(),
            style: const TextStyle(
              color: kRose, 
              fontSize: 13, 
              fontWeight: FontWeight.w800, 
              letterSpacing: 1.0
            ),
          ),
          const SizedBox(height: 20),
          // Serif Font for that "Editor's Choice" feel
          Text(
            prompt['answer'],
            style: const TextStyle(
              fontSize: 26, 
              height: 1.3, 
              fontWeight: FontWeight.w500, 
              color: Colors.black87,
              fontFamily: 'Georgia', // Using standard Serif fallback
            ),
          ),
        ],
      ),
    );
  }

  // 5. CHIPS
  Widget _buildPremiumChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Text(
        label, 
        style: TextStyle(
          fontSize: 14, 
          fontWeight: FontWeight.w600, 
          color: Colors.black.withOpacity(0.8)
        )
      ),
    );
  }

  // SHARED DECORATION STYLE
  BoxDecoration _premiumShadowDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06), // Very soft shadow
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
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