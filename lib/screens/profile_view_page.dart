import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clush/widgets/activity_badge.dart';
import 'package:clush/theme/colors.dart';


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
    final bool isVerified = profile['is_verified'] ?? true;

    // Essentials Data
    final Map<String, String?> allEssentials = {
      'Age': age > 0 ? age.toString() : null,
      'Looking For': intent.isNotEmpty ? intent : null,
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
      'Location': (() { final loc = profile['location'] as String?; if (loc == null) return null; final idx = loc.indexOf('('); return idx != -1 ? loc.substring(0, idx).trim().split(',').take(2).join(',').trim() : loc; })(),
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
    if (prompts.isNotEmpty) {
      for (var p in prompts) {
        if (p != null) remainingPrompts.add(p as Map<String, dynamic>);
      }
    }

    // 3. Build Content List
    List<Widget> contentList = [];

    // Header margin spacer
    contentList.add(const SizedBox(height: 16));

    // Profile Header (Name, Badge, Active Pill)
    contentList.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 38,
                            color: kInk,
                            letterSpacing: -1.0,
                            height: 1.0,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 28, // Increased background size
                          height: 28,
                          decoration: const BoxDecoration(
                            color: kRosePale,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_rounded, color: kRose, size: 18), // Increased icon size
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ActivityBadge(lastSeenAt: profile['last_seen_at'] as String?),
            // Thin decorative rule under the name
            const SizedBox(height: 12),
            Row(
              children: [
                Container(width: 32, height: 1, color: kGold),
                const SizedBox(width: 8),
                Container(width: 8, height: 1, color: kBone),
              ],
            ),
          ],
        ),
      ),
    );

    // 1st Image
    if (photoUrls.isNotEmpty) {
      contentList.add(_buildPhotoCard(photoUrls[0], isFirst: true));
    } else {
      contentList.add(_buildPhotoCard('https://via.placeholder.com/600x800', isFirst: true));
    }

    // Essentials card
    if (allEssentials.values.any((v) => v != null && v.isNotEmpty)) {
      contentList.add(_buildUnifiedEssentialsCard(allEssentials));
    }

    // Interests/Hobbies
    if (allInterests.isNotEmpty) {
      contentList.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardLabel("Hobbies & Interests"),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: allInterests.map((e) => _buildChip(e.toString())).toList(),
              ),
            ],
          ),
        ),
      );
    }

    // 1st Prompt
    if (remainingPrompts.isNotEmpty) {
      contentList.add(_buildPromptCard(remainingPrompts.removeAt(0)));
    }

    // 2nd Image
    if (remainingPhotos.isNotEmpty) {
      contentList.add(_buildPhotoCard(remainingPhotos.removeAt(0)));
    }

    // 3rd Image
    if (remainingPhotos.isNotEmpty) {
      contentList.add(_buildPhotoCard(remainingPhotos.removeAt(0)));
    }

    // 2nd Prompt
    if (remainingPrompts.isNotEmpty) {
      contentList.add(_buildPromptCard(remainingPrompts.removeAt(0)));
    }

    // 4th Image
    if (remainingPhotos.isNotEmpty) {
      contentList.add(_buildPhotoCard(remainingPhotos.removeAt(0)));
    }

    // 3rd Prompt
    if (remainingPrompts.isNotEmpty) {
      contentList.add(_buildPromptCard(remainingPrompts.removeAt(0)));
    }

    while (remainingPhotos.isNotEmpty) {
      contentList.add(_buildPhotoCard(remainingPhotos.removeAt(0)));
    }

    while (remainingPrompts.isNotEmpty) {
      contentList.add(_buildPromptCard(remainingPrompts.removeAt(0)));
    }

    // Bottom spacing
    contentList.add(const SizedBox(height: 80));

    return Scaffold(
      backgroundColor: kCream,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 64, bottom: 40), // Increased top padding from 16 to 64
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: contentList,
              ),
            ),
            // Minimalist back button at top left
            Positioned(
              top: 16,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kCream.withOpacity(0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: kBone.withOpacity(0.5), width: 1),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: kInk, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= REUSED WIDGETS =================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: kParchment,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: kBone, width: 1),
      boxShadow: [
        BoxShadow(
          color: kInk.withOpacity(0.06),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        )
      ],
    );
  }

  Widget _buildCardLabel(String label) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: kGold, margin: const EdgeInsets.only(right: 10)),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.figtree(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: kInkMuted,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }

  Widget _buildUnifiedEssentialsCard(Map<String, String?> allData) {
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

    final Map<String, IconData> icons = {
      'Age': Icons.cake_outlined,
      'Looking For': Icons.search_rounded,
      'Height': Icons.straighten_outlined,
      'Education': Icons.school_outlined,
      'Job': Icons.work_outline,
      'Religion': Icons.auto_stories_outlined,
      'Politics': Icons.gavel_outlined,
      'Star Sign': Icons.auto_awesome_outlined,
      'Kids': Icons.child_care_outlined,
      'Pets': Icons.pets_outlined,
      'Drink': Icons.local_bar_outlined,
      'Smoke': Icons.smoking_rooms_outlined,
      'Weed': Icons.grass_outlined,
      'Location': Icons.location_on_outlined,
      'Gender': Icons.person_outline_rounded,
      'Orientation': Icons.favorite_border_rounded,
      'Pronouns': Icons.record_voice_over_outlined,
      'Ethnicity': Icons.public_outlined,
      'Languages': Icons.translate_outlined,
      'Exercise': Icons.fitness_center_outlined,
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (horizontalData.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: _buildCardLabel("At a Glance"),
            ),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                physics: const BouncingScrollPhysics(),
                itemCount: horizontalData.length,
                separatorBuilder: (context, index) => VerticalDivider(
                  width: 24,
                  thickness: 1,
                  color: kBone,
                  indent: 4,
                  endIndent: 4,
                ),
                itemBuilder: (context, index) {
                  String key = horizontalData.keys.elementAt(index);
                  String value = horizontalData[key]!;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icons[key] ?? Icons.circle_outlined, color: kRose, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        value,
                        style: GoogleFonts.figtree(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: kInk,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          if (horizontalData.isNotEmpty && verticalData.isNotEmpty)
            Divider(height: 1, thickness: 1, color: kBone),
          if (verticalData.isNotEmpty)
            Column(
              children: verticalData.entries.map((entry) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Icon(icons[entry.key] ?? Icons.circle_outlined, size: 18, color: kRose),
                          const SizedBox(width: 14),
                          Text(
                            entry.key,
                            style: GoogleFonts.figtree(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kInkMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              entry.value,
                              textAlign: TextAlign.end,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.figtree(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: kInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (entry.key != verticalData.keys.last)
                      Divider(height: 1, thickness: 1, color: kBone),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(String url, {bool isFirst = false}) {
    return Container(
      height: 520,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBone, width: 1),
        boxShadow: [
          BoxShadow(
            color: kInk.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(
            color: kParchment,
            child: const Center(
              child: Icon(Icons.person_outline_rounded, color: kBone, size: 64),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromptCard(Map<String, dynamic> prompt) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Opening quote mark
          Text(
            "\u201C",
            style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 48,
              color: kRose.withOpacity(0.3),
              height: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            prompt['question'] as String,
            style: GoogleFonts.figtree(
              color: kInkMuted,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            prompt['answer'],
            style: GoogleFonts.ledger(fontWeight: FontWeight.bold, fontSize: 26,
              height: 1.3,
              color: kInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: kCream,
        border: Border.all(color: kBone, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.figtree(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: kInk,
        ),
      ),
    );
  }

  int _calculateAge(String? birthdayString) {
    if (birthdayString == null) return 0;
    try {
      final birthday = DateTime.parse(birthdayString);
      final now = DateTime.now();
      int age = now.year - birthday.year;
      if (now.month < birthday.month || (now.month == birthday.month && now.day < birthday.day)) age--;
      return age;
    } catch (e) {
      return 0;
    }
  }
}
