import sys
import re

file_path = r'c:\Users\Salil\Desktop\Flutter\Clush_App\lib\discover_page.dart'
# read content
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add google_fonts import
if "import 'package:google_fonts/google_fonts.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:google_fonts/google_fonts.dart';")

# Replace constants
if "const Color kBgColor" not in content:
    content = content.replace(
        "const Color kTan = Color(0xFFE9E6E1);\nconst Color kBlack = Color(0xFF2C2C2C);",
        "const Color kTan = Color(0xFFE9E6E1);\nconst Color kBlack = Color(0xFF000000);\nconst Color kBgColor = Color(0xFFFFFBFB);\nconst Color kCardBg = Color(0xFFE8E5E0);\nconst Color kCardStroke = Color(0xFF818181);"
    )

# Replace Scaffolds background to kBgColor
content = content.replace("backgroundColor: kTan", "backgroundColor: kBgColor")
content = content.replace("color: kTan", "color: kBgColor") # For blurred header background
content = content.replace("color: kTan,", "color: kBgColor,")

# Let's replace _buildHeader
build_header_code = """  Widget _buildHeader(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 100,
          color: kBgColor.withOpacity(0.85),
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
          alignment: Alignment.center,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _showFiltersModal(),
                child: const Padding(
                  padding: EdgeInsets.only(right: 12.0),
                  child: Icon(Icons.tune_rounded, color: kBlack, size: 28),
                ),
              ),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildFilterChip('Age', () => _showFiltersModal()),
                    _buildFilterChip('Dating Intentions', () => _showFiltersModal()),
                    _buildFilterChip('Height', () => _showFiltersModal()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kCardStroke, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kBlack,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: kRose, size: 20),
          ],
        ),
      ),
    );
  }"""

start_idx = content.find("  Widget _buildHeader(BuildContext context) {")
end_idx = content.find("  // --- ACTIONS ---")
if start_idx != -1 and end_idx != -1:
    content = content[:start_idx] + build_header_code + "\n\n" + content[end_idx:]

# Now replace _buildProfileContent
profile_content_new = """  Widget _buildProfileContent(Map<String, dynamic> profile) {
    // 1. Extract Data
    final List photoUrls = profile['photo_urls'] ?? [];
    final List prompts = profile['prompts'] ?? [];
    
    // Interests
    final List interests = profile['interests'] ?? [];
    final List foods = profile['foods'] ?? [];
    final List places = profile['places'] ?? [];
    final allInterests = [...interests, ...foods, ...places];

    // Basic Info
    final String name = profile['fullName'] ?? profile['full_name'] ?? 'User';
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
    if (prompts.isNotEmpty) {
      for (var p in prompts) {
        if (p != null) remainingPrompts.add(p as Map<String, dynamic>);
      }
    }

    // 3. Build Content List
    List<Widget> contentList = [];

    // Header margin spacer
    contentList.add(const SizedBox(height: 110));

    // Name and Verification Badge
    contentList.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                   children: [
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w400,
                          color: kBlack,
                          letterSpacing: -1.0,
                          height: 1.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.verified_outlined, color: kBlack, size: 24),
                    ]
                   ]
                  )
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Active Today",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: kRose,
              ),
            ),
          ],
        ),
      )
    );

    // 1st Image
    if (photoUrls.isNotEmpty) {
      contentList.add(_buildPhotoCard(photoUrls[0], isFirst: true));
    } else {
      contentList.add(_buildPhotoCard('https://via.placeholder.com/600x800', isFirst: true));
    }

    // Information Tab
    if (allEssentials.values.any((v) => v != null && v.isNotEmpty)) {
      contentList.add(_buildUnifiedEssentialsCard(allEssentials));
    }

    if (allInterests.isNotEmpty) {
      contentList.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(24),
          decoration: _premiumCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hobbies", 
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: kBlack, letterSpacing: -0.5)
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: allInterests.map((e) => _buildPremiumChip(e.toString())).toList(),
              ),
            ],
          ),
        ),
      );
    }

    // 1st Prompt
    if (remainingPrompts.isNotEmpty) {
      contentList.add(_buildPremiumPromptCard(remainingPrompts.removeAt(0)));
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
      contentList.add(_buildPremiumPromptCard(remainingPrompts.removeAt(0)));
    }

    // 4th Image
    if (remainingPhotos.isNotEmpty) {
      contentList.add(_buildPhotoCard(remainingPhotos.removeAt(0)));
    }

    // 3rd Prompt
    if (remainingPrompts.isNotEmpty) {
      contentList.add(_buildPremiumPromptCard(remainingPrompts.removeAt(0)));
    }

    // Rest of images
    while (remainingPhotos.isNotEmpty) {
      contentList.add(_buildPhotoCard(remainingPhotos.removeAt(0)));
    }

    // Rest of prompts
    while (remainingPrompts.isNotEmpty) {
      contentList.add(_buildPremiumPromptCard(remainingPrompts.removeAt(0)));
    }

    // Block/Report Line
    contentList.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Divider(color: kCardStroke.withOpacity(0.2)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _showReportDialog(profile),
                  icon: const Icon(Icons.flag_outlined, color: kCardStroke),
                  label: Text("Report", style: GoogleFonts.inter(color: kCardStroke, fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: () => _showBlockConfirmation(profile),
                  icon: const Icon(Icons.block_outlined, color: kCardStroke),
                  label: Text("Block", style: GoogleFonts.inter(color: kCardStroke, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      )
    );

    contentList.add(const SizedBox(height: 140)); // Bottom Padding

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contentList,
      ),
    );
  }"""

p_start = content.find("  Widget _buildProfileContent(Map<String, dynamic> profile) {")
p_end = content.find("  // ================= HEADER & FOOTER =================")
if p_start != -1 and p_end != -1:
    content = content[:p_start] + profile_content_new + "\n\n" + content[p_end:]

# Now replace the widget helpers (Lines 746-988 roughly)
helpers_start = content.find("  // ================= REUSED WIDGETS =================")
helpers_end = content.find("  void _showFiltersModal() {")

helpers_new = """  // ================= REUSED WIDGETS =================
  
  BoxDecoration _premiumCardDecoration() {
    return BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: kCardStroke, width: 0.5),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        )
      ],
    );
  }

  Widget _buildUnifiedEssentialsCard(Map<String, String?> allData) {
    final verticalKeys = ['Religion', 'Location', 'Ethnicity', 'Star Sign'];
    final Map<String, String> verticalData = {};
    final Map<String, String> horizontalData = {};

    allData.forEach((key, value) {
      if (value != null && value.isNotEmpty) {
        if (verticalKeys.contains(key)) verticalData[key] = value;
        else horizontalData[key] = value;
      }
    });

    final Map<String, IconData> icons = {
      'Age': Icons.location_on_outlined, 'Looking For': Icons.search_rounded, 'Height': Icons.straighten_outlined, 'Education': Icons.school_outlined, 'Job': Icons.work_outline, 'Religion': Icons.church,
      'Politics': Icons.gavel, 'Star Sign': Icons.auto_awesome, 'Kids': Icons.child_care_outlined, 'Pets': Icons.pets_outlined,
      'Drink': Icons.local_bar_outlined, 'Smoke': Icons.smoking_rooms_outlined, 'Weed': Icons.grass_outlined, 'Location': Icons.location_on_outlined,
      'Gender': Icons.radio_button_unchecked, 'Orientation': Icons.favorite_border, 'Pronouns': Icons.record_voice_over_outlined,
      'Ethnicity': Icons.public_outlined, 'Languages': Icons.translate_outlined, 'Exercise': Icons.fitness_center_outlined,
    };

    return Container(
      width: double.infinity, 
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
      decoration: _premiumCardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (horizontalData.isNotEmpty) ...[
            SizedBox(
              height: 56, 
              child: ListView.separated(
                scrollDirection: Axis.horizontal, 
                padding: const EdgeInsets.symmetric(horizontal: 16), 
                physics: const BouncingScrollPhysics(), 
                itemCount: horizontalData.length, 
                separatorBuilder: (context, index) => VerticalDivider(width: 1, thickness: 1, color: kCardStroke.withOpacity(0.2), indent: 12, endIndent: 12),
                itemBuilder: (context, index) { 
                  String key = horizontalData.keys.elementAt(index); 
                  String value = horizontalData[key]!; 
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icons[key] ?? Icons.circle, color: kBlack, size: 20), 
                        const SizedBox(width: 6), 
                        Text(
                          value, 
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14, color: kBlack)
                        )
                      ]
                    )
                  ); 
                }
              )
            ),
          ],
          if (horizontalData.isNotEmpty && verticalData.isNotEmpty) 
            Divider(height: 1, thickness: 1, color: kCardStroke.withOpacity(0.2)),
            
          if (verticalData.isNotEmpty) 
            Column(
              children: verticalData.entries.map((entry) { 
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), 
                      child: Row(
                        children: [
                          Icon(icons[entry.key] ?? Icons.circle, size: 20, color: kBlack),
                          const SizedBox(width: 16), 
                          Expanded(
                            child: Text(
                              entry.value, 
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: kBlack)
                            )
                          )
                        ]
                      )
                    ), 
                    if (entry.key != verticalData.keys.last) 
                      Divider(height: 1, thickness: 1, color: kCardStroke.withOpacity(0.2))
                  ]
                ); 
              }).toList()
            ),
      ]),
    );
  }

  Widget _buildPhotoCard(String url, {bool isFirst = false}) {
    return Container(
      height: 500, 
      width: double.infinity, 
      margin: const EdgeInsets.symmetric(
        horizontal: 16, 
        vertical: 8
      ), 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: kCardStroke, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.network(url, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[300]))
      )
    );
  }

  Widget _buildPremiumPromptCard(Map<String, dynamic> prompt) {
    return Container(
      width: double.infinity, 
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
      padding: const EdgeInsets.all(24), 
      decoration: _premiumCardDecoration(), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Text(
            prompt['question'] as String, 
            style: GoogleFonts.inter(color: kBlack.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w400)
          ), 
          const SizedBox(height: 12), 
          Text(
            prompt['answer'], 
            style: GoogleFonts.notoRashiHebrew(fontSize: 28, height: 1.25, fontWeight: FontWeight.w500, color: kBlack)
          )
        ]
      )
    );
  }

  Widget _buildPremiumChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: kCardStroke.withOpacity(0.5), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label, 
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack)
      )
    );
  }

"""

if helpers_start != -1 and helpers_end != -1:
    content = content[:helpers_start] + helpers_new + "\n  " + content[helpers_end:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("success")
