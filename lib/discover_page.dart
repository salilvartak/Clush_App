import 'package:flutter/material.dart';
import 'dart:ui'; // For blur effects
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/matching_service.dart'; 

const Color kRose = Color(0xFFCD9D8F);
const Color kTan = Color(0xFFE9E6E1);

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  // Service for handling likes/matches
  final MatchingService _matchingService = MatchingService();
  
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
  }

  /// FETCHING LOGIC:
  /// 1. Get IDs of people I've already swiped on.
  /// 2. Get my own gender.
  /// 3. Fetch new profiles that match my target gender AND are not in the "swiped" list.
  Future<void> _fetchProfiles() async {
    try {
      final myId = FirebaseAuth.instance.currentUser?.uid;
      if (myId == null) {
        if (mounted) setState(() => _errorMessage = "User not logged in");
        return;
      }

      // --- STEP 1: Get IDs of people I have ALREADY swiped ---
      final alreadySwipedResponse = await Supabase.instance.client
          .from('likes')
          .select('target_user_id')
          .eq('user_id', myId);

      final List<String> ignoreIds = (alreadySwipedResponse as List)
          .map((e) => e['target_user_id'].toString())
          .toList();

      // Always ignore myself (ensure list is never empty)
      ignoreIds.add(myId);

      // --- STEP 2: Get My Gender ---
      final myProfileResponse = await Supabase.instance.client
          .from('profiles')
          .select('gender')
          .eq('id', myId)
          .maybeSingle();

      if (myProfileResponse == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = "Profile not found. Please complete your profile.";
          });
        }
        return;
      }

      final myGender = myProfileResponse['gender'] as String?;
      String targetGender;

      if (myGender?.toLowerCase() == 'woman') {
        targetGender = 'Man';
      } else if (myGender?.toLowerCase() == 'man') {
        targetGender = 'Woman';
      } else {
        targetGender = 'Woman'; 
      }

      // --- STEP 3: Fetch Profiles with Exclusion Filter ---
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('gender', targetGender)
          .not('id', 'in', ignoreIds) // <--- FIXED LINE HERE
          .limit(20);

      if (mounted) {
        setState(() {
          _profiles = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading profiles: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _removeCurrentProfile() {
    setState(() {
      if (_profiles.isNotEmpty) {
        _profiles.removeAt(0);
      }
    });
  }

  // --- SWIPE LOGIC ---
  void _onSwipe(String targetUserId, String swipeType) async {
    if (_profiles.isEmpty) return;
    
    // A. Keep reference for the dialog
    final droppedProfile = _profiles.first;
    
    // B. Optimistic UI update (Remove card immediately)
    _removeCurrentProfile();

    // C. Call Backend
    bool isMatch = false;
    try {
      if (swipeType == 'like') {
        isMatch = await _matchingService.swipeRight(targetUserId);
      } else if (swipeType == 'dislike') {
        await _matchingService.swipeLeft(targetUserId);
      } else if (swipeType == 'super_like') {
        isMatch = await _matchingService.superLike(targetUserId);
      }
    } catch (e) {
      print("Error recording swipe: $e");
    }

    // D. Show Match Dialog if applicable
    if (isMatch && mounted) {
      _showMatchDialog(droppedProfile);
    }
  }

  void _showMatchDialog(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final photoUrl = (profile['photo_urls'] != null && (profile['photo_urls'] as List).isNotEmpty)
            ? profile['photo_urls'][0]
            : 'https://via.placeholder.com/150';

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("IT'S A MATCH!", 
                  style: TextStyle(color: kRose, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.0)
                ),
                const SizedBox(height: 24),
                CircleAvatar(
                  radius: 60,
                  backgroundImage: NetworkImage(photoUrl),
                  backgroundColor: Colors.grey[200],
                ),
                const SizedBox(height: 16),
                Text(
                  "You and ${profile['full_name']} like each other.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context), 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRose,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      elevation: 0,
                    ),
                    child: const Text("SEND A MESSAGE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("KEEP SWIPING", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Handling Loading and Empty States
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kTan,
        body: Center(child: CircularProgressIndicator(color: kRose)),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: kTan,
        body: Center(child: Text(_errorMessage!, textAlign: TextAlign.center)),
      );
    }

    if (_profiles.isEmpty) {
      return const Scaffold(
        backgroundColor: kTan,
        body: Center(child: Text("No more profiles found!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      );
    }

    // Get the first profile in the list
    final profile = _profiles.first;

    return Scaffold(
      backgroundColor: kTan,
      body: Stack(
        children: [
          // 1. SCROLLABLE PROFILE CONTENT
          KeyedSubtree(
            key: ValueKey(profile['id'] ?? profile['full_name']),
            child: _buildProfileContent(profile),
          ),

          // 2. HEADER
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(context),
          ),

          // 3. FLOATING ACTION BUTTONS
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: _buildFloatingButtons(),
          ),
        ],
      ),
    );
  }

  // ================= CONTENT BUILDER =================

  Widget _buildProfileContent(Map<String, dynamic> profile) {
    // 1. Extract Data safely
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
    
    // Top Padding for Header
    content.add(const SizedBox(height: 100));

    // -- 1. FIRST IMAGE CARD (Name + Age) --
    if (photoUrls.isNotEmpty) {
      content.add(_buildMainPhotoCard(url: photoUrls[0], name: name, age: age));
    } else {
       // Fallback if no photos
       content.add(_buildMainPhotoCard(url: 'https://via.placeholder.com/600x800', name: name, age: age));
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
                children: allInterests.map((e) => _buildPremiumChip(e.toString())).toList(),
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
    
    while (remainingPhotos.isNotEmpty) {
      content.add(_buildSecondaryPhotoCard(remainingPhotos.removeAt(0)));
    }
    while (remainingPrompts.isNotEmpty) {
      content.add(_buildPremiumPromptCard(remainingPrompts.removeAt(0)));
    }

    // Bottom Padding for Floating Buttons
    content.add(const SizedBox(height: 120));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      ),
    );
  }

  // ================= HEADER & FOOTER =================

  Widget _buildHeader(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 100,
          color: kTan.withOpacity(0.85),
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Discover",
                style: TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.w800, 
                  color: Colors.black87,
                  letterSpacing: -0.5
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.tune_rounded, color: Colors.black87, size: 24),
                  onPressed: () {
                    // Implement Filter logic here
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    if (_profiles.isEmpty) return const SizedBox();
    
    // Safely get the ID. Use 'id' from database.
    final currentProfileId = _profiles.first['id'].toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // DISLIKE BUTTON
          _buildActionButton(Icons.close_rounded, Colors.redAccent, 64, () {
            _onSwipe(currentProfileId, 'dislike');
          }),
          
          // SUPER LIKE BUTTON
          _buildActionButton(Icons.star_rounded, Colors.blueAccent, 52, () {
             _onSwipe(currentProfileId, 'super_like');
          }),

          // LIKE BUTTON
          _buildActionButton(Icons.favorite_rounded, const Color(0xFF00BFA5), 64, () {
            _onSwipe(currentProfileId, 'like');
          }),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, double size, VoidCallback onPressed) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Icon(icon, color: color, size: size * 0.5),
        ),
      ),
    );
  }

  // ================= REUSED WIDGETS =================

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
          const SizedBox(height: 24),
          if (horizontalData.isNotEmpty) ...[
            SizedBox(
              height: 60,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icons[key] ?? Icons.circle, color: kRose, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          value,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 13, 
                            color: Colors.black87
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (horizontalData.isNotEmpty && verticalData.isNotEmpty)
            Divider(height: 1, thickness: 1, color: Colors.grey.shade100),

          if (verticalData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: verticalData.entries.map((entry) {
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

  Widget _buildMainPhotoCard({required String url, required String name, required int age}) {
    return Container(
      height: 600,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: _premiumShadowDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(url, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[300])),
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

  Widget _buildSecondaryPhotoCard(String url) {
    return Container(
      height: 500,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _premiumShadowDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Image.network(url, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[300])),
      ),
    );
  }

  Widget _buildIntentCard(String intent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(24),
      decoration: _premiumShadowDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kRose.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.search_rounded, color: kRose, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded( 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "LOOKING FOR",
                  style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
                const SizedBox(height: 4),
                Text(
                  intent, 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                  softWrap: true,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

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
    if (birthdayString == null) return 24; // Default age if missing
    try {
      final birthday = DateTime.parse(birthdayString);
      final now = DateTime.now();
      int age = now.year - birthday.year;
      if (now.month < birthday.month || (now.month == birthday.month && now.day < birthday.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 24;
    }
  }
}