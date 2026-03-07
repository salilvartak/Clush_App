import 'package:flutter/material.dart';
import 'dart:ui'; // For blur effects
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/matching_service.dart'; 

const Color kRose = Color(0xFFCD9D8F);
const Color kTan = Color(0xFFE9E6E1);
const Color kBlack = Color(0xFF2C2C2C);

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
  
  // Track swipe direction for animation
  String _lastSwipeDirection = 'like';

  // Filter States
  bool _isPremium = false;
  RangeValues _filterAge = const RangeValues(18, 60);
  double _filterDistance = 50; // Placeholder for UI
  String _filterIntent = 'Default'; // 'Men', 'Women', 'Everyone', 'Default'
  String? _filterReligion;
  RangeValues _filterHeight = const RangeValues(100, 250);
  String? _filterEthnicity;

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
  }

  Future<void> _fetchProfiles() async {
    try {
      final myId = FirebaseAuth.instance.currentUser?.uid;
      if (myId == null) {
        if (mounted) setState(() => _errorMessage = "User not logged in");
        return;
      }

      // Initialize Exclusion List (Always ignore myself)
      final List<String> ignoreIds = [];
      ignoreIds.add(myId);

      // Get IDs from 'likes' table (Pending swipes)
      final alreadySwipedResponse = await Supabase.instance.client
          .from('likes')
          .select('target_user_id')
          .eq('user_id', myId);

      final List<String> swipedIds = (alreadySwipedResponse as List)
          .map((e) => e['target_user_id'].toString())
          .toList();
      ignoreIds.addAll(swipedIds);

      // Get IDs from 'matches' table (Confirmed matches)
      try {
        final matchesResponse = await Supabase.instance.client
            .from('matches')
            .select('user_a, user_b') 
            .or('user_a.eq.$myId,user_b.eq.$myId');

        final List<String> matchedIds = (matchesResponse as List).map((e) {
          final u1 = e['user_a'].toString();
          final u2 = e['user_b'].toString();
          return u1 == myId ? u2 : u1;
        }).toList();
        
        ignoreIds.addAll(matchedIds);
      } catch (e) {
        print("Matches check failed: $e");
      }

      // Get IDs from 'blocks' table (Blocked users)
      try {
        final blocksResponse = await Supabase.instance.client
            .from('blocks')
            .select('blocker_id, blocked_id')
            .or('blocker_id.eq.$myId,blocked_id.eq.$myId');

        final List<String> blockedIds = (blocksResponse as List).map((e) {
          final b1 = e['blocker_id'].toString();
          final b2 = e['blocked_id'].toString();
          return b1 == myId ? b2 : b1;
        }).toList();
        
        ignoreIds.addAll(blockedIds);
      } catch (e) {
        print("Blocks check failed: $e");
      }


      // Get My Profile Info
      final myProfileResponse = await Supabase.instance.client
          .from('profiles')
          .select('gender, is_premium')
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
      
      if (mounted) {
        setState(() {
          final premiumVal = myProfileResponse['is_premium'];
          if (premiumVal is bool) {
             _isPremium = premiumVal;
          } else if (premiumVal is String) {
             _isPremium = premiumVal.toLowerCase() == 'true';
          } else {
             _isPremium = false;
          }
        });
      }

      String targetGender;

      if (myGender?.toLowerCase() == 'woman') {
        targetGender = 'Man';
      } else if (myGender?.toLowerCase() == 'man') {
        targetGender = 'Woman';
      } else {
        targetGender = 'Woman'; 
      }

      // Fetch Profiles with Exclusion Filter
      final uniqueIgnoreIds = ignoreIds.toSet().toList();

      var query = Supabase.instance.client
          .from('profiles')
          .select()
          .not('id', 'in', uniqueIgnoreIds)
          .or('is_paused.eq.false,is_paused.is.null');

      if (_filterIntent != 'Default' && _filterIntent != 'Everyone') {
        query = query.eq('gender', _filterIntent == 'Men' ? 'Man' : 'Woman');
      } else if (_filterIntent == 'Default') {
        query = query.eq('gender', targetGender);
      } // If 'Everyone', don't filter by gender

      // Age Filter (Convert Age to Birthday Dates)
      DateTime now = DateTime.now();
      DateTime minDate = DateTime(now.year - _filterAge.start.round(), now.month, now.day);
      DateTime maxDate = DateTime(now.year - _filterAge.end.round() - 1, now.month, now.day + 1);
      
      query = query.lte('birthday', minDate.toIso8601String()).gte('birthday', maxDate.toIso8601String());

      if (_filterReligion != null && _filterReligion!.isNotEmpty && _filterReligion != 'Any') {
        query = query.eq('religion', _filterReligion!);
      }
      if (_filterEthnicity != null && _filterEthnicity!.isNotEmpty && _filterEthnicity != 'Any') {
        query = query.eq('ethnicity', _filterEthnicity!);
      }

      final response = await query.limit(40);

      // Post-query filtering for height
      List<Map<String, dynamic>> filteredProfiles = List<Map<String, dynamic>>.from(response);

      if (_filterHeight.start > 100 || _filterHeight.end < 250) {
        filteredProfiles = filteredProfiles.where((p) {
          if (p['height'] == null) return false;
          final match = RegExp(r'\d+').firstMatch(p['height'].toString());
          if (match != null) {
            int h = int.parse(match.group(0)!);
            // Height logic assumes cm. If parsed value is something small (like 5 for 5'10"), it skips strict filtering.
            if (h < 40) return true; 
            return h >= _filterHeight.start && h <= _filterHeight.end;
          }
          return true;
        }).toList();
      }

      if (mounted) {
        setState(() {
          _profiles = filteredProfiles.take(20).toList();
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

  // --- SWIPE LOGIC ---
  void _onSwipe(String targetUserId, String swipeType) async {
    if (_profiles.isEmpty) return;
    
    final droppedProfile = _profiles.first;
    
    // Optimistic UI update with direction tracking
    setState(() {
      _lastSwipeDirection = swipeType;
      if (_profiles.isNotEmpty) {
        _profiles.removeAt(0);
      }
    });

    // Call Backend
    bool isMatch = false;
    try {
      if (swipeType == 'like') {
        isMatch = await _matchingService.swipeRight(targetUserId);
      } else if (swipeType == 'dislike') {
        await _matchingService.swipeLeft(targetUserId);
      } 
    } catch (e) {
      print("Error recording swipe: $e");
    }

    // Show Match Dialog
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
      return Scaffold(
        backgroundColor: kTan,
        body: Stack(
          children: [
            const Center(child: Text("No more profiles found!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildHeader(context),
            ),
          ],
        ),
      );
    }

    final profile = _profiles.first;

    return Scaffold(
      backgroundColor: kTan,
      body: Stack(
        children: [
          // 1. SCROLLABLE PROFILE CONTENT (Animated Transition)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              // Determine if this widget is the incoming new profile or the outgoing old one
              final isIncoming = child.key == ValueKey(profile['id'] ?? profile['full_name']);
              
              if (isIncoming) {
                // Incoming profile: Fades in and scales up slightly
                final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(animation);
                final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(animation);
                
                return FadeTransition(
                  opacity: fadeAnimation,
                  child: ScaleTransition(scale: scaleAnimation, child: child),
                );
              } else {
                // Outgoing profile: Slides out left or right and fades
                final isLike = _lastSwipeDirection == 'like';
                final outOffset = Tween<Offset>(
                  // X offset positive (right) for like, negative (left) for dislike
                  begin: isLike ? const Offset(1.5, 0.1) : const Offset(-1.5, 0.1),
                  end: Offset.zero,
                ).animate(animation);
                
                // Add a slight rotation for that classic swipe feel
                final rotationAnimation = Tween<double>(
                  begin: isLike ? 0.1 : -0.1, 
                  end: 0.0
                ).animate(animation);

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: outOffset, 
                    child: RotationTransition(
                      turns: rotationAnimation,
                      child: child,
                    ),
                  ),
                );
              }
            },
            child: KeyedSubtree(
              key: ValueKey(profile['id'] ?? profile['full_name']),
              child: _buildProfileContent(profile),
            ),
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
            bottom: 40,
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
    final List photoUrls = profile['photo_urls'] ?? [];
    final List prompts = profile['prompts'] ?? [];
    
    final List interests = profile['interests'] ?? [];
    final List foods = profile['foods'] ?? [];
    final List places = profile['places'] ?? [];
    final allInterests = [...interests, ...foods, ...places];

    final String name = profile['full_name'] ?? 'User';
    final String? birthdayString = profile['birthday'];
    final int age = _calculateAge(birthdayString);
    final String intent = profile['intent'] ?? '';

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

    List<String> remainingPhotos = [];
    if (photoUrls.length > 1) remainingPhotos.addAll(List<String>.from(photoUrls.sublist(1)));

    List<Map<String, dynamic>> remainingPrompts = [];
    if (prompts.length > 1) {
      for (var p in prompts.sublist(1)) {
        if (p != null) remainingPrompts.add(p as Map<String, dynamic>);
      }
    }

    List<Widget> content = [];
    content.add(const SizedBox(height: 100)); // Header Spacer

    if (photoUrls.isNotEmpty) {
      content.add(_buildMainPhotoCard(url: photoUrls[0], name: name, age: age));
    } else {
       content.add(_buildMainPhotoCard(url: 'https://via.placeholder.com/600x800', name: name, age: age));
    }

    if (prompts.isNotEmpty && prompts[0] != null) content.add(_buildPremiumPromptCard(prompts[0]));
    if (allEssentials.values.any((v) => v != null && v.isNotEmpty)) content.add(_buildUnifiedEssentialsCard(allEssentials));
    if (intent.isNotEmpty) content.add(_buildIntentCard(intent));

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

    if (remainingPhotos.isNotEmpty) content.add(_buildSecondaryPhotoCard(remainingPhotos.removeAt(0)));
    if (remainingPhotos.isNotEmpty) content.add(_buildSecondaryPhotoCard(remainingPhotos.removeAt(0)));
    if (remainingPrompts.isNotEmpty) content.add(_buildPremiumPromptCard(remainingPrompts.removeAt(0)));
    
    while (remainingPhotos.isNotEmpty) content.add(_buildSecondaryPhotoCard(remainingPhotos.removeAt(0)));
    while (remainingPrompts.isNotEmpty) content.add(_buildPremiumPromptCard(remainingPrompts.removeAt(0)));

    content.add(const SizedBox(height: 140)); // Bottom Padding

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
                  color: kBlack,
                  letterSpacing: -0.5
                ),
              ),
              Row(
                children: [
                  if (_profiles.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, color: kBlack, size: 24),
                        onSelected: (value) {
                          if (value == 'block') {
                            _showBlockConfirmation(_profiles.first);
                          } else if (value == 'report') {
                            _showReportDialog(_profiles.first);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'report',
                            child: Text('Report User'),
                          ),
                          const PopupMenuItem(
                            value: 'block',
                            child: Text('Block User', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black.withOpacity(0.05)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.tune_rounded, color: kBlack, size: 24),
                      onPressed: () => _showFiltersModal(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- ACTIONS ---

  void _showBlockConfirmation(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block User?'),
        content: Text('Are you sure you want to block ${profile['full_name']}? They will be removed from your Discover feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx); 
              final success = await _matchingService.blockUser(profile['id']);
              if (success && mounted) {
                _showThemedToast('${profile['full_name']} blocked', isError: false);
                // Remove from feed
                setState(() {
                  _profiles.removeAt(0);
                });
              } else if (mounted) {
                _showThemedToast('Failed to block. Try again.', isError: true);
              }
            },
            child: const Text('Block', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(Map<String, dynamic> profile) {
    final List<String> reasons = [
      "Inappropriate photos",
      "Inappropriate bio/prompts",
      "Fake profile / Spam",
      "Underage",
      "Other"
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Report ${profile['full_name']}",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...reasons.map((reason) => ListTile(
                      title: Text(reason),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        Navigator.pop(ctx); 
                        final success = await _matchingService.reportUser(
                            profile['id'], reason);
                        if (success && mounted) {
                          _showThemedToast('Report submitted. This user has also been blocked.', isError: false);
                          // Remove from feed since they are now blocked
                          setState(() {
                            _profiles.removeAt(0);
                          });
                        } else if (mounted) {
                          _showThemedToast('Failed to report.', isError: true);
                        }
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- REUSABLE THEMED TOAST ---
  void _showThemedToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : kRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        elevation: 10,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    if (_profiles.isEmpty) return const SizedBox();
    
    final currentProfileId = _profiles.first['id'].toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          const Spacer(flex: 1),

          // THEMED DISLIKE BUTTON (Muted Dark Gray)
          _BouncingButton(
            icon: Icons.close_rounded,
            color: kBlack.withOpacity(0.8),
            size: 65, 
            onTap: () => _onSwipe(currentProfileId, 'dislike'),
          ),

          const Spacer(flex: 2),

          // THEMED LIKE BUTTON (Brand Rose)
          _BouncingButton(
            icon: Icons.favorite_rounded,
            color: kRose, 
            size: 65, 
            onTap: () => _onSwipe(currentProfileId, 'like'),
          ),

          const Spacer(flex: 1),
        ],
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
        if (verticalKeys.contains(key)) verticalData[key] = value;
        else horizontalData[key] = value;
      }
    });

    final Map<String, IconData> icons = {
      'Height': Icons.height, 'Education': Icons.school, 'Job': Icons.work,
      'Religion': Icons.church, 'Politics': Icons.gavel, 'Star Sign': Icons.auto_awesome,
      'Kids': Icons.child_care, 'Pets': Icons.pets, 'Drink': Icons.local_bar,
      'Smoke': Icons.smoking_rooms, 'Weed': Icons.grass, 'Location': Icons.location_on,
      'Gender': Icons.person, 'Orientation': Icons.favorite, 'Pronouns': Icons.record_voice_over,
      'Ethnicity': Icons.public, 'Languages': Icons.translate, 'Exercise': Icons.fitness_center,
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
                        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
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
                              decoration: BoxDecoration(color: kRose.withOpacity(0.1), shape: BoxShape.circle),
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
                      if (entry.key != verticalData.keys.last) Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
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
    final double cardHeight = MediaQuery.of(context).size.height * 0.65;

    return Container(
      height: cardHeight,
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
                  colors: [Colors.transparent, Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.8)],
                  stops: const [0.5, 0.7, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 60, 
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
                Text("LOOKING FOR", style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text(intent, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87), softWrap: true),
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

  void _showFiltersModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        initialAge: _filterAge,
        initialDistance: _filterDistance,
        initialIntent: _filterIntent,
        initialReligion: _filterReligion,
        initialHeight: _filterHeight,
        initialEthnicity: _filterEthnicity,
        isPremium: _isPremium,
        onApply: (age, dist, intent, rel, ht, eth) {
          setState(() {
            _filterAge = age;
            _filterDistance = dist;
            _filterIntent = intent;
            _filterReligion = rel;
            _filterHeight = ht;
            _filterEthnicity = eth;
            _isLoading = true;
          });
          _fetchProfiles();
        },
      ),
    );
  }

  int _calculateAge(String? birthdayString) {
    if (birthdayString == null) return 24; 
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

class _FilterBottomSheet extends StatefulWidget {
  final RangeValues initialAge;
  final double initialDistance;
  final String initialIntent;
  final String? initialReligion;
  final RangeValues initialHeight;
  final String? initialEthnicity;
  final bool isPremium;
  final Function(RangeValues, double, String, String?, RangeValues, String?) onApply;

  const _FilterBottomSheet({
    required this.initialAge,
    required this.initialDistance,
    required this.initialIntent,
    required this.initialReligion,
    required this.initialHeight,
    required this.initialEthnicity,
    required this.isPremium,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late RangeValues _age;
  late double _dist;
  late String _intent;
  String? _rel;
  late RangeValues _ht;
  String? _eth;

  final List<String> _intents = ['Men', 'Women', 'Everyone', 'Default'];
  final List<String> _religions = ['Any', 'Christian', 'Muslim', 'Hindu', 'Buddhist', 'Jewish', 'Spiritual', 'Atheist', 'Other'];
  final List<String> _ethnicities = ['Any', 'Asian', 'Black', 'Hispanic/Latino', 'Middle Eastern', 'White', 'Mixed', 'Other'];

  @override
  void initState() {
    super.initState();
    _age = widget.initialAge;
    _dist = widget.initialDistance;
    _intent = widget.initialIntent;
    _rel = widget.initialReligion;
    _ht = widget.initialHeight;
    _eth = widget.initialEthnicity;
  }

  void _showPremiumLockDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.star_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Premium Required', 
                style: TextStyle(fontWeight: FontWeight.bold),
                softWrap: true,
              )
            ),
          ],
        ),
        content: const Text('Unlock advanced filters like Religion, Height, and Ethnicity by upgrading to Clush Premium.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to Premium page logic here
            },
            child: const Text('Upgrade\nNow', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, height: 1.1)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
          ),
          const Text("Filters", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kBlack)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildSectionHeader("FREE FILTERS"),
                const SizedBox(height: 16),
                
                // Intent Filter
                const Text("Interested In", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _intents.map((i) => ChoiceChip(
                    label: Text(i),
                    selected: _intent == i,
                    selectedColor: kRose.withOpacity(0.2),
                    labelStyle: TextStyle(color: _intent == i ? kRose : Colors.black87, fontWeight: FontWeight.bold),
                    onSelected: (val) {
                      if (val) setState(() => _intent = i);
                    },
                  )).toList(),
                ),
                const SizedBox(height: 24),

                // Age Filter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Age Range", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    Text("${_age.start.round()} - ${_age.end.round()}", style: const TextStyle(fontWeight: FontWeight.bold, color: kRose)),
                  ],
                ),
                RangeSlider(
                  values: _age,
                  min: 18,
                  max: 100,
                  activeColor: kRose,
                  inactiveColor: kRose.withOpacity(0.2),
                  onChanged: (val) => setState(() => _age = val),
                ),
                const SizedBox(height: 16),

                // Distance Filter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Maximum Distance", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    Text("${_dist.round()} km", style: const TextStyle(fontWeight: FontWeight.bold, color: kRose)),
                  ],
                ),
                Slider(
                  value: _dist,
                  min: 5,
                  max: 100,
                  activeColor: kRose,
                  inactiveColor: kRose.withOpacity(0.2),
                  onChanged: (val) => setState(() => _dist = val),
                ),
                const SizedBox(height: 32),

                // PREMIUM FILTERS
                Row(
                  children: [
                    _buildSectionHeader("PREMIUM FILTERS "),
                    if (!widget.isPremium) const Icon(Icons.lock, size: 14, color: Colors.amber),
                  ],
                ),
                const SizedBox(height: 16),

                // Religion Filter
                _buildPremiumDropdown("Religion", _religions, _rel, (v) => setState(() => _rel = v)),
                const SizedBox(height: 24),

                // Ethnicity Filter
                _buildPremiumDropdown("Ethnicity", _ethnicities, _eth, (v) => setState(() => _eth = v)),
                const SizedBox(height: 24),

                // Height Filter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Height Range (cm)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black54)),
                    Text("${_ht.start.round()} - ${_ht.end.round()}", style: TextStyle(fontWeight: FontWeight.bold, color: widget.isPremium ? kRose : Colors.grey)),
                  ],
                ),
                AbsorbPointer(
                  absorbing: !widget.isPremium,
                  child: GestureDetector(
                    onTap: widget.isPremium ? null : _showPremiumLockDialog,
                    child: RangeSlider(
                      values: _ht,
                      min: 100,
                      max: 250,
                      activeColor: widget.isPremium ? kRose : Colors.grey.shade300,
                      inactiveColor: widget.isPremium ? kRose.withOpacity(0.2) : Colors.grey.shade100,
                      onChanged: (val) => setState(() => _ht = val),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          
          // Apply Button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRose,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onApply(_age, _dist, _intent, _rel, _ht, _eth);
                },
                child: const Text("Apply Filters", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
    );
  }

  Widget _buildPremiumDropdown(String label, List<String> options, String? value, Function(String?) onChanged) {
    return GestureDetector(
      onTap: widget.isPremium ? null : _showPremiumLockDialog,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: widget.isPremium ? Colors.white : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value ?? 'Any',
                icon: Icon(widget.isPremium ? Icons.keyboard_arrow_down : Icons.lock, color: widget.isPremium ? Colors.grey : Colors.amber),
                items: options.map((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val, style: TextStyle(color: widget.isPremium ? Colors.black87 : Colors.grey)),
                  );
                }).toList(),
                onChanged: widget.isPremium ? onChanged : (_) => _showPremiumLockDialog(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- NEW WIDGET FOR THEMED BOUNCY BUTTON ---
class _BouncingButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _BouncingButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: widget.color.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.12),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.size * 0.45,
          ),
        ),
      ),
    );
  }
}