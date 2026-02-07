import 'package:flutter/material.dart';

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

    // 2. Build the interspersed list of content widgets
    List<Widget> content = [];

    // -- HEADER (Back button) --
    content.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            const Text("Preview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );

    // -- MAIN CARD (1st Photo + Name/Age info) --
    content.add(
      _buildPhotoCard(
        url: photoUrls.isNotEmpty ? photoUrls[0] : null,
        name: name,
        age: age,
        intent: intent,
        isMain: true
      )
    );

    // -- PASSIONS SECTION --
    final allInterests = [...interests, ...foods, ...places];
    if (allInterests.isNotEmpty) {
      content.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("My Passions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allInterests.map((e) => _buildChip(e)).toList(),
              ),
            ],
          ),
        )
      );
    }

    // -- INTERLEAVED PROMPTS & REMAINING PHOTOS --
    int promptIndex = 0;
    int photoIndex = 1; // Start from the second photo

    // Loop until we run out of both
    while (promptIndex < prompts.length || photoIndex < photoUrls.length) {
      // Add a Prompt if available
      if (promptIndex < prompts.length && prompts[promptIndex] != null) {
        content.add(_buildPromptCard(prompts[promptIndex]));
        promptIndex++;
      }
      
      // Add a Photo if available
      if (photoIndex < photoUrls.length) {
        content.add(_buildPhotoCard(url: photoUrls[photoIndex]));
        photoIndex++;
      }
    }
    
    // Bottom padding for scrolling
    content.add(const SizedBox(height: 40));

    // 3. Final Scaffold Structure
    return Scaffold(
      backgroundColor: kTan, // The background color visible between cards
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: content,
        ),
      ),
    );
  }

  // ================= HELPER WIDGETS =================

  // Builder for both Main and Secondary photo cards
  Widget _buildPhotoCard({String? url, String? name, int? age, String? intent, bool isMain = false}) {
    return Container(
      height: isMain ? 580 : 450, // Main card is taller
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Margins create the "card" look
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // Rounded corners
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The Photo
            if (url != null)
              Image.network(url, fit: BoxFit.cover)
            else
              Container(color: Colors.grey.shade200, child: const Icon(Icons.image, size: 50, color: Colors.grey)),
            
            // Overlay & Text ONLY for the Main Card
            if (isMain) ...[
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
              Positioned(
                bottom: 30,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$name, $age",
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    if (intent != null && intent.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: Colors.white.withOpacity(0.9), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              intent,
                              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // Builder for Prompt cards
  Widget _buildPromptCard(Map<String, dynamic> prompt) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Margins
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // Rounded corners
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (prompt['question'] as String).toUpperCase(),
            style: const TextStyle(color: kRose, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            prompt['answer'],
            style: const TextStyle(fontSize: 24, height: 1.3, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          // Placeholder for a "Like" action
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200)
              ),
              child: Icon(Icons.favorite_border, color: Colors.grey.shade400, size: 24),
            ),
          )
        ],
      ),
    );
  }

  // Simple chip builder
  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))]
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
    );
  }

  // Age calculation helper
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