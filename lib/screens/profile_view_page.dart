import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:clush/widgets/activity_badge.dart';
import 'package:clush/widgets/heart_loader.dart';
import 'package:clush/theme/colors.dart';

class ProfileViewPage extends StatefulWidget {
  final Map<String, dynamic> profile;
  final bool showBackButton;
  final bool showScaffold;

  const ProfileViewPage({
    super.key, 
    required this.profile,
    this.showBackButton = true,
    this.showScaffold = true,
  });

  @override
  State<ProfileViewPage> createState() => _ProfileViewPageState();
}

class _ProfileViewPageState extends State<ProfileViewPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showFloatingName = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.offset > 120;
      if (show != _showFloatingName) {
        setState(() => _showFloatingName = show);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    
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
      'Location': (() { final loc = profile['location'] as String?; if (loc == null) return null; final idx = loc.indexOf('('); return idx != -1 ? loc.substring(0, idx).trim().split(',').take(2).join(',').trim() : loc; })(),
      'Job': profile['job_title'],
      'Education': profile['education'],
      'Height': profile['height'],
      'Gender': profile['gender'],
      'Pronouns': profile['pronouns'],
      'Orientation': profile['sexual_orientation'],
      'Looking For': intent.isNotEmpty ? intent : null,
      'Religion': profile['religion'],
      'Ethnicity': profile['ethnicity'],
      'Languages': profile['languages'],
      'Star Sign': profile['star_sign'],
      'Exercise': profile['exercise'],
      'Drink': profile['drink'],
      'Smoke': profile['smoke'],
      'Weed': profile['weed'],
      'Kids': profile['kids'],
      'Pets': profile['pets'],
      'Politics': profile['political_views'],
    };

    // Prepare content
    List<String> remainingPhotos = photoUrls.length > 1 ? List<String>.from(photoUrls.sublist(1)) : [];
    List<Map<String, dynamic>> remainingPrompts = prompts.map((p) => p as Map<String, dynamic>).toList();

    List<Widget> contentList = [];
    
    // First Profile Card (Full bleed)
    contentList.add(_buildFirstProfileCard(profile, allInterests));

    // Essentials card
    final customMessage = profile['custom_message'] as String?;
    if (allEssentials.values.any((v) => v != null && v.isNotEmpty)) {
      contentList.add(_buildUnifiedEssentialsCard(allEssentials, customMessage));
    }

    // Mix in photos and prompts
    while (remainingPhotos.isNotEmpty || remainingPrompts.isNotEmpty) {
      if (remainingPrompts.isNotEmpty) {
        contentList.add(_buildPromptCard(remainingPrompts.removeAt(0)));
      }
      if (remainingPhotos.isNotEmpty) {
        contentList.add(_buildPhotoCard(remainingPhotos.removeAt(0)));
      }
    }

    contentList.add(const SizedBox(height: 100));

    final mainContent = Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          child: Column(children: contentList),
        ),
        
        // Floating Header (Pill)
        if (_showFloatingName)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0, right: 0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: kCream.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: kBorderLight.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.gabarito(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: kInk,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, color: kGold, size: 14),
                        ],
                      ],
                    ),
                  ),
                ),
              ).animate().fade(duration: 200.ms).scale(begin: const Offset(0.9, 0.9)),
            ),
          ),

        // Back Button
        if (widget.showBackButton)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: kCream.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: kBorderLight, width: 0.5),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: kInk),
              ),
            ),
          ),
      ],
    );

    if (widget.showScaffold) {
      return Scaffold(backgroundColor: kCream, body: mainContent);
    }
    return mainContent;
  }

  Widget _buildFirstProfileCard(Map<String, dynamic> profile, List allInterests) {
    final List photoUrls = profile['photo_urls'] ?? [];
    final String name = profile['full_name'] ?? 'User';
    final int age = _calculateAge(profile['birthday']);
    final bool isVerified = profile['is_verified'] ?? true;
    final String? jobTitle = profile['job_title'] as String?;
    final String? location = (() {
      final loc = profile['location'] as String?;
      if (loc == null) return null;
      final idx = loc.indexOf('(');
      final clean = idx != -1 ? loc.substring(0, idx).trim() : loc;
      final parts = clean.split(',').map((e) => e.trim()).toList();
      return parts.length >= 2 ? '${parts[0]}, ${parts[1]}' : clean;
    })();

    final String photoUrl = photoUrls.isNotEmpty ? photoUrls[0].toString() : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderLight, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Column(
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 520,
                  width: double.infinity,
                  child: photoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(child: HeartLoader(size: 40)),
                          errorWidget: (_, __, ___) => const Icon(Icons.person, size: 80, color: kBone),
                        )
                      : Container(color: kParchment),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xCC000000), Colors.transparent],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '$name, $age',
                              style: GoogleFonts.gabarito(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.verified_rounded, color: kGold, size: 24),
                            ],
                          ],
                        ),
                        if (jobTitle != null && jobTitle.isNotEmpty)
                          Text(
                            jobTitle,
                            style: GoogleFonts.figtree(color: Colors.white70, fontSize: 16),
                          ),
                        if (location != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
                                const SizedBox(width: 4),
                                Text(location, style: GoogleFonts.figtree(color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (allInterests.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "INTERESTS",
                      style: GoogleFonts.figtree(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kInkMuted,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allInterests.take(6).map((e) => _buildChip(e.toString())).toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedEssentialsCard(Map<String, String?> allData, String? customMessage) {
    const verticalKeys = ['Looking For', 'Religion', 'Ethnicity', 'Star Sign'];
    final Map<String, String> verticalData = {};
    final Map<String, String> horizontalData = {};

    allData.forEach((key, value) {
      if (value != null && value.isNotEmpty) {
        if (verticalKeys.contains(key)) verticalData[key] = value;
        else horizontalData[key] = value;
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderLight),
      ),
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
                  color: kBorderLight,
                  indent: 4,
                  endIndent: 4,
                ),
                itemBuilder: (context, index) {
                  final key = horizontalData.keys.elementAt(index);
                  final value = horizontalData[key]!;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icons[key] ?? Icons.circle_outlined, color: kInk, size: 16),
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
            Divider(height: 1, thickness: 1, color: kBorderLight),
          if (verticalData.isNotEmpty)
            Column(
              children: verticalData.entries.map((entry) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Icon(icons[entry.key] ?? Icons.circle_outlined, size: 18, color: kInk),
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
                          const Spacer(),
                          Text(
                            entry.value,
                            style: GoogleFonts.figtree(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: kInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (entry.key == 'Looking For' && customMessage != null && customMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(52, 0, 20, 14),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            customMessage,
                            style: GoogleFonts.figtree(
                              fontSize: 14,
                              height: 1.4,
                              color: kInk.withOpacity(0.8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    if (entry.key != verticalData.keys.last)
                      Divider(height: 1, thickness: 1, color: kBorderLight),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(String url) {
    return Container(
      height: 480,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderLight),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => const Center(child: HeartLoader(size: 40)),
          errorWidget: (_, __, ___) => const Icon(Icons.person, size: 50, color: kBone),
        ),
      ),
    );
  }

  Widget _buildPromptCard(Map<String, dynamic> prompt) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt['question'] as String,
            style: GoogleFonts.figtree(color: kInkMuted, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            prompt['answer'],
            style: GoogleFonts.gabarito(fontSize: 24, fontWeight: FontWeight.bold, color: kInk, height: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _buildCardLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w700, color: kInkMuted, letterSpacing: 2.0),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: kParchment,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderLight, width: 0.5),
      ),
      child: Text(label, style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w500, color: kInk)),
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
