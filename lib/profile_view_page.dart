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
    
    // Interests
    final List interests = profile['interests'] ?? [];
    final List foods = profile['foods'] ?? [];
    final List places = profile['places'] ?? [];
    final allInterests = [...interests, ...foods, ...places];

    // Basic Info
    final String name = profile['full_name'] ?? 'User';
    final String? birthdayString = profile['birthday'];
    final int age = _calculateAge(birthdayString);
    final String intent = profile['intent'] ?? '';

    // Essentials Data
    final Map<String, String?> allEssentials = {
      'Height': profile['height'],
      'Education': profile['education'],
      'Job': profile['job_title'],
      'Religion': profile['religion'],
      'Politics': profile['political_views'],
      'Star Sign': profile['star_sign'],
      'Kids': profile['kids'],
      'Pets': profile['pets'],
      'Drink': profile['drink'],
      'Smoke': profile['smoke'],
      'Weed': profile['weed'],
      'Location': profile['location'],
      'Gender': profile['gender'],
      'Orientation': profile['sexual_orientation'],
      'Pronouns': profile['pronouns'],
      'Ethnicity': profile['ethnicity'],
      'Languages': profile['languages'],
      'Exercise': profile['exercise'],
    };

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
      content.add(_buildMainPhotoCard(url: photoUrls[0], name: name, age: age));
    }

    // -- 2. FIRST PROMPT ANSWER --
    if (prompts.isNotEmpty && prompts[0] != null) {
      content.add(_buildPremiumPromptCard(prompts[0]));
    }

    // -- 3. ESSENTIALS CARD (Unified) --
    if (allEssentials.values.any((v) => v != null && v.isNotEmpty)) {
      content.add(_buildUnifiedEssentialsCard(allEssentials));
    }

    // -- 4. WHAT I'M LOOKING FOR (Intent) --
    if (intent.isNotEmpty) {
      content.add(_buildIntentCard(intent));
    }

    // -- 5. MY PASSIONS --
    if (allInterests.isNotEmpty) {
      content.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
        ),
      );
    }

    // -- 6. THE MIX (Organic Order) --
    if (remainingPhotos.isNotEmpty) content.add(_buildSecondaryPhotoCard(remainingPhotos.removeAt(0)));
    if (remainingPhotos.isNotEmpty) content.add(_buildSecondaryPhotoCard(remainingPhotos.removeAt(0)));
    if (remainingPrompts.isNotEmpty) content.add(_buildPremiumPromptCard(remainingPrompts.removeAt(0)));
    if (remainingPhotos.isNotEmpty) content.add(_buildSecondaryPhotoCard(remainingPhotos.removeAt(0)));
    if (remainingPhotos.isNotEmpty) content.add(_buildSecondaryPhotoCard(remainingPhotos.removeAt(0)));
    if (remainingPrompts.isNotEmpty) content.add(_buildPremiumPromptCard(remainingPrompts.removeAt(0)));

    while (remainingPhotos.isNotEmpty) {
      content.add(_buildSecondaryPhotoCard(remainingPhotos.removeAt(0)));
    }
    while (remainingPrompts.isNotEmpty) {
      content.add(_buildPremiumPromptCard(remainingPrompts.removeAt(0)));
    }

    content.add(const SizedBox(height: 80)); // Bottom padding

    return Scaffold(
      backgroundColor: kTan,
      body: Stack(
        children: [
          // SCROLLABLE CONTENT
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 0),
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
                  height: 90,
                  color: kTan.withOpacity(0.85),
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Preview",
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.w700, 
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
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: kRose,
        letterSpacing: 1.5,
      ),
    );
  }

  // NEW: Unified Essentials Card
  Widget _buildUnifiedEssentialsCard(Map<String, String?> allData) {
    // 1. Separate Data
    final verticalKeys = ['Religion', 'Location', 'Ethnicity', 'Star Sign'];
    final Map<String, String> verticalData = {};
    final Map<String, String> horizontalData = {};

    allData.forEach((key, value) {
      if (value != null && value.isNotEmpty) {
        if (verticalKeys.contains(key)) {
          verticalData[key] = value;
        } else {
          horizontalData[key] = value;
        }
      }
    });

    // Icons Map
    final Map<String, IconData> icons = {
      'Height': Icons.height,
      'Education': Icons.school,
      'Job': Icons.work,
      'Religion': Icons.church,
      'Politics': Icons.gavel,
      'Star Sign': Icons.auto_awesome,
      'Kids': Icons.child_care,
      'Pets': Icons.pets,
      'Drink': Icons.local_bar,
      'Smoke': Icons.smoking_rooms,
      'Weed': Icons.grass,
      'Location': Icons.location_on,
      'Gender': Icons.person,
      'Orientation': Icons.favorite,
      'Pronouns': Icons.record_voice_over,
      'Ethnicity': Icons.public,
      'Languages': Icons.translate,
      'Exercise': Icons.fitness_center,
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _premiumShadowDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Padding
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            
          ),

          // 1. Horizontal Scroll Section
          if (horizontalData.isNotEmpty) ...[
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: horizontalData.length,
                itemBuilder: (context, index) {
                  String key = horizontalData.keys.elementAt(index);
                  String value = horizontalData[key]!;
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50], // Subtle background to differentiate from white card
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icons[key] ?? Icons.circle, color: kRose, size: 20),
                        const SizedBox(height: 8),
                        Text(
                          value,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2. Divider between Horizontal and Vertical
          if (horizontalData.isNotEmpty && verticalData.isNotEmpty)
            Divider(height: 1, thickness: 1, color: Colors.grey.shade100),

          // 3. Vertical List Section
          if (verticalData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: verticalData.entries.map((entry) {
                  // Separator for items except the first one (optional, or put separator below each)
                  // Here we put separator BELOW every item except the last one to mimic a list
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: kRose.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icons[entry.key] ?? Icons.circle, size: 18, color: kRose),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.key.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(entry.value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Divider between vertical items (except the last one if you strictly check index)
                      // For simplicity, we just add a divider for all, looks neat enough or we can hide last.
                      if (entry.key != verticalData.keys.last)
                        Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
                    ],
                  );
                }).toList(),
              ),
            ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // 1. MAIN PHOTO CARD
  Widget _buildMainPhotoCard({required String url, required String name, required int age}) {
    return Container(
      height: 600,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 100, 16, 16),
      decoration: _premiumShadowDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(url, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.7)],
                  stops: const [0.6, 0.8, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              left: 24,
              child: Text(
                "$name, $age",
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 36, 
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

  // 2. SECONDARY PHOTO CARD
  Widget _buildSecondaryPhotoCard(String url) {
    return Container(
      height: 500,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _premiumShadowDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Image.network(url, fit: BoxFit.cover),
      ),
    );
  }

  // 3. INTENT CARD
  Widget _buildIntentCard(String intent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(24),
      decoration: _premiumShadowDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kRose.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.search_rounded, color: kRose, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "LOOKING FOR",
                style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0),
              ),
              const SizedBox(height: 4),
              Text(intent, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
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
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: _premiumShadowDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text((prompt['question'] as String).toUpperCase(), style: const TextStyle(color: kRose, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          Text(prompt['answer'], style: const TextStyle(fontSize: 24, height: 1.3, fontWeight: FontWeight.w600, color: Colors.black87)),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.8))),
    );
  }

  // SHARED DECORATION STYLE
  BoxDecoration _premiumShadowDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, spreadRadius: 0, offset: const Offset(0, 10)),
      ],
    );
  }

  int _calculateAge(String? birthdayString) {
    if (birthdayString == null) return 0;
    try {
      final birthday = DateTime.parse(birthdayString);
      final now = DateTime.now();
      int age = now.year - birthday.year;
      if (now.month < birthday.month || (now.month == birthday.month && now.day < birthday.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }
}