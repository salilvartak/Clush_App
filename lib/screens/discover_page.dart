import 'dart:math' show cos, sqrt, asin, pi;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; // For blur effects
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clush/services/matching_service.dart';
import 'package:clush/widgets/heart_loader.dart';
import 'package:clush/widgets/match_animation_dialog.dart';
import 'package:clush/widgets/activity_badge.dart';

import 'package:clush/theme/colors.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Service for handling likes/matches
  final MatchingService _matchingService = MatchingService();

  List<Map<String, dynamic>> _profiles = [];
  Map<String, dynamic>? _lastDislikedProfile;
  bool _isLoading = true;
  bool _isActionLoading = false;
  int _likesRemaining = 6;
  bool _isPremium = false;
  String _lastSwipeDirection = 'like';

  String? _myPhotoUrl;

  // Filter States
  RangeValues _filterAge = const RangeValues(18, 60);
  double _filterDistance = 50;
  String _filterIntent = '';
  String? _filterReligion;
  RangeValues _filterHeight = const RangeValues(100, 250);
  String? _filterEthnicity;
  // Premium filters
  String? _filterPolitics;
  String? _filterStarSign;
  String? _filterEducation;
  String? _filterKids;
  String? _filterPets;
  String? _filterExercise;
  String? _filterDrinks;
  String? _filterSmoke;
  String? _filterWeed;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
  }

  Future<void> _fetchProfiles() async {
    final stopwatch = Stopwatch()..start();
    try {
      final myId = FirebaseAuth.instance.currentUser?.uid;
      if (myId == null) {
        if (mounted) setState(() => _errorMessage = "User not logged in");
        return;
      }

      final List<String> ignoreIds = [];
      ignoreIds.add(myId);

      final alreadySwipedResponse = await Supabase.instance.client
          .from('likes')
          .select('target_user_id')
          .eq('user_id', myId);

      final List<String> swipedIds = (alreadySwipedResponse as List)
          .map((e) => e['target_user_id'].toString())
          .toList();
      ignoreIds.addAll(swipedIds);

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

      try {
        final savedResponse = await Supabase.instance.client
            .from('saved_profiles')
            .select('saved_user_id')
            .eq('user_id', myId);
        final List<String> savedIds = (savedResponse as List).map((e) => e['saved_user_id'].toString()).toList();
        ignoreIds.addAll(savedIds);
      } catch (e) {
        print("Saved profiles check failed: $e");
      }

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

      final myProfileResponse = await Supabase.instance.client
          .from('profiles')
          .select('gender, is_premium, location, intent, photo_urls, blocked_phones')
          .eq('id', myId)
          .maybeSingle();

      if (myProfileResponse == null) {
        if (mounted) {
          final elapsed = stopwatch.elapsedMilliseconds;
          if (elapsed < 2200) await Future.delayed(Duration(milliseconds: 2200 - elapsed));
          setState(() {
            _isLoading = false;
            _errorMessage = "Profile not found. Please complete your profile.";
          });
        }
        return;
      }

      // Fetch IDs for pre-blocked phone numbers
      final blockedPhones = myProfileResponse['blocked_phones'] as List<dynamic>? ?? [];
      if (blockedPhones.isNotEmpty) {
        try {
          final blockedIdsResponse = await Supabase.instance.client
              .rpc('get_blocked_ids_by_phone', params: {
                'phones': blockedPhones.cast<String>()
              });
              
          if (blockedIdsResponse != null) {
            final List<String> fetchedIds = (blockedIdsResponse as List)
                .map((e) => e['id'].toString())
                .toList();
            ignoreIds.addAll(fetchedIds);
          }
        } catch (e) {
          debugPrint("Blocked phone IDs check failed: $e");
        }
      }

      final myLocationStr = myProfileResponse['location'] as String?;
      final Map<String, double>? myCoords = _parseCoordinates(myLocationStr);

      final myGender = myProfileResponse['gender'] as String?;
      final myIntent = myProfileResponse['intent'] as String?;

      final premiumVal = myProfileResponse['is_premium'];
      bool parsedPremium = false;
      if (premiumVal is bool) {
        parsedPremium = premiumVal;
      } else if (premiumVal is String) {
        parsedPremium = premiumVal.toLowerCase() == 'true';
      }
      
      final currentLikes = await _matchingService.getLikesRemaining(parsedPremium);

      if (mounted) {
        setState(() {
          _isPremium = parsedPremium;
          _likesRemaining = currentLikes;
          final photos = myProfileResponse['photo_urls'];
          if (photos is List && photos.isNotEmpty) {
            _myPhotoUrl = photos[0] as String?;
          }
        });
      }

      // Prioritize user's intent from profile if _filterIntent is not set
      if (_filterIntent.isEmpty) {
        if (myIntent != null && myIntent.isNotEmpty) {
          String mappedIntent = myIntent;
          if (mappedIntent.toLowerCase() == 'man') mappedIntent = 'Men';
          if (mappedIntent.toLowerCase() == 'woman') mappedIntent = 'Women';
          if (mappedIntent.toLowerCase() == 'men') mappedIntent = 'Men';
          if (mappedIntent.toLowerCase() == 'women') mappedIntent = 'Women';
          if (mappedIntent.toLowerCase() == 'everyone') mappedIntent = 'Everyone';
          
          if (['Men', 'Women', 'Everyone'].contains(mappedIntent)) {
            _filterIntent = mappedIntent;
          }
        }
        
        // If _filterIntent is still empty, default based on gender
        if (_filterIntent.isEmpty) {
          if (myGender?.toLowerCase() == 'woman') {
            _filterIntent = 'Men';
          } else if (myGender?.toLowerCase() == 'man') {
            _filterIntent = 'Women';
          } else {
            _filterIntent = 'Everyone';
          }
        }
      }

      final uniqueIgnoreIds = ignoreIds.toSet().toList();

      var query = Supabase.instance.client
          .from('profile_discovery')
          .select()
          .not('id', 'in', uniqueIgnoreIds);

      if (_filterIntent != 'Everyone') {
        query = query.eq('gender', _filterIntent == 'Men' ? 'Man' : 'Woman');
      }

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

      final response = await query.limit(150); // Increased limit from 40 to 150 to find local users first

      List<Map<String, dynamic>> filteredProfiles = List<Map<String, dynamic>>.from(response);

      if (_filterHeight.start > 100 || _filterHeight.end < 250) {
        filteredProfiles = filteredProfiles.where((p) {
          if (p['height'] == null) return false;
          final match = RegExp(r'\d+').firstMatch(p['height'].toString());
          if (match != null) {
            int h = int.parse(match.group(0)!);
            if (h < 40) return true;
            return h >= _filterHeight.start && h <= _filterHeight.end;
          }
          return true;
        }).toList();
      }

      // --- DISTANCE FILTERING ---
      debugPrint("📍 My Coordinates: $myCoords");
      debugPrint("🔍 Filtering profiles vs distance: ${_filterDistance}km");

      if (myCoords != null) {
        filteredProfiles = filteredProfiles.where((p) {
          final otherLocationStr = p['location'] as String?;
          final otherCoords = _parseCoordinates(otherLocationStr);
          final name = p['full_name'] ?? 'Unknown';

          if (otherCoords == null) {
            debugPrint("❌ $name: No coordinates found. Hiding.");
            return false;
          }

          final distance = _calculateDistance(
            myCoords['lat']!,
            myCoords['lng']!,
            otherCoords['lat']!,
            otherCoords['lng']!,
          );
          
          p['calculated_distance'] = distance;
          
          final isWithin = distance <= _filterDistance;
          if (isWithin) {
            debugPrint("✅ $name: ${distance.toStringAsFixed(2)}km away. Keeping.");
          } else {
            debugPrint("🚫 $name: ${distance.toStringAsFixed(2)}km away. Filtered out.");
          }

          return isWithin;
        }).toList();

        // --- SORT BY DISTANCE ---
        filteredProfiles.sort((a, b) {
          final distA = a['calculated_distance'] as double? ?? 99999.0;
          final distB = b['calculated_distance'] as double? ?? 99999.0;
          return distA.compareTo(distB);
        });
        debugPrint("📊 Found ${filteredProfiles.length} users within ${_filterDistance}km");
      } else {
        debugPrint("⚠️ My coordinates are null. Hiding everyone.");
        filteredProfiles = [];
      }

      if (mounted) {
        final elapsed = stopwatch.elapsedMilliseconds;
        if (elapsed < 2200) await Future.delayed(Duration(milliseconds: 2200 - elapsed));
        setState(() {
          _profiles = filteredProfiles.take(20).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final elapsed = stopwatch.elapsedMilliseconds;
        if (elapsed < 2200) await Future.delayed(Duration(milliseconds: 2200 - elapsed));
        setState(() {
          _errorMessage = 'Error loading profiles: $e';
          _isLoading = false;
        });
      }
    }
  }

  // --- SWIPE LOGIC ---
  void _onSwipe(String targetUserId, String swipeType, {String? message}) async {
    if (_profiles.isEmpty) return;

    if ((swipeType == 'like' || swipeType == 'pulse') && _likesRemaining <= 0) {
      _showThemedToast('Out of likes! Save them for later or wait until they replenish.', isError: true);
      return;
    }

    final droppedProfile = _profiles.first;

    setState(() {
      _lastSwipeDirection = swipeType == 'dislike' ? 'dislike' : 'like';
      if (swipeType == 'like' || swipeType == 'pulse') _likesRemaining--;
      if (swipeType == 'dislike') {
        _lastDislikedProfile = Map<String, dynamic>.from(droppedProfile);
      }
      if (_profiles.isNotEmpty) {
        _profiles.removeAt(0);
      }
    });

    try {
      Map<String, dynamic> result;
      if (swipeType == 'like') {
        result = await _matchingService.swipeRight(targetUserId);
      } else if (swipeType == 'pulse') {
        result = await _matchingService.pulse(targetUserId, message);
      } else {
        result = await _matchingService.swipeLeft(targetUserId);
      }

      if (result['success'] == false) {
        if (result['error'] == 'limit_exceeded') {
          _showThemedToast('You have reached your weekly limit for this feature.', isError: true);
        }
      } else if (result['match'] == true && mounted) {
        _showMatchDialog(droppedProfile);
      }
    } catch (e) {
      print("Error recording swipe: $e");
    }
  }

  void _handleRewind() async {
    if (_lastDislikedProfile == null) {
      _showThemedToast('Nothing to rewind!', isError: true);
      return;
    }

    setState(() => _isActionLoading = true);
    
    final result = await _matchingService.rewind(_lastDislikedProfile!['id'].toString());
    
    setState(() => _isActionLoading = false);

    if (result['success'] == true) {
      setState(() {
        _profiles.insert(0, _lastDislikedProfile!);
        _lastDislikedProfile = null;
      });
      _showThemedToast('Profile brought back!', isError: false);
    } else {
      if (result['error'] == 'limit_exceeded') {
        _showThemedToast('Weekly rewind limit reached! Get Clush+ for unlimited rewinds.', isError: true);
      } else {
        _showThemedToast('Failed to rewind.', isError: true);
      }
    }
  }

  void _showPulseDialog(String targetUserId, String targetName) {
    final TextEditingController pulseController = TextEditingController();
    final FocusNode focusNode = FocusNode();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: kInk.withOpacity(0.5),
      builder: (ctx) {
        // Delay focus slightly to let bottom sheet animation start smoothly
        Future.delayed(350.ms, () {
          if (ctx.mounted) focusNode.requestFocus();
        });
        
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: kCream,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: kInk.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: SafeArea(
              bottom: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: kBone.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kGold.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.bolt_rounded, color: kGold, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Send a Pulse",
                                style: GoogleFonts.gabarito(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  color: kInk,
                                ),
                              ),
                              Text(
                                "To $targetName",
                                style: GoogleFonts.figtree(
                                  fontSize: 14,
                                  color: kInkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: pulseController,
                      focusNode: focusNode,
                      maxLines: 4,
                      style: GoogleFonts.figtree(color: kInk, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: "Write a message...",
                        hintStyle: GoogleFonts.figtree(
                          color: kInkMuted.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: kParchment,
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: kGold.withOpacity(0.3), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          final message = pulseController.text.trim();
                          Navigator.pop(ctx);
                          _onSwipe(targetUserId, 'pulse', message: message.isEmpty ? null : message);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGold,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "Send Pulse",
                          style: GoogleFonts.figtree(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fade(duration: 250.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
      },
    );
  }

  void _showMatchDialog(Map<String, dynamic> profile) {
    final matchPhotoUrl = (profile['photo_urls'] is List &&
            (profile['photo_urls'] as List).isNotEmpty)
        ? profile['photo_urls'][0] as String
        : '';

    showMatchAnimation(
      context,
      myPhotoUrl: _myPhotoUrl ?? '',
      matchPhotoUrl: matchPhotoUrl,
      matchName: profile['full_name'] as String? ?? 'them',
      onMessage: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    if (_isLoading) {
      return Scaffold(
        backgroundColor: kCream,
        body: const Center(
          child: HeartLoader(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: kCream,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(color: kInkMuted, fontSize: 15),
            ),
          ),
        ),
      );
    }

    if (_profiles.isEmpty) {
      return Scaffold(
        backgroundColor: kCream,
        body: RefreshIndicator(
          onRefresh: _fetchProfiles,
          color: kRose,
          backgroundColor: kParchment,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: kRosePale,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_border_rounded, color: kRose, size: 32),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "You've seen everyone",
                      style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 26,
                        color: kInk,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Check back soon for new profiles",
                      style: GoogleFonts.figtree(
                        fontSize: 14,
                        color: kInkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Header spacer or just the header on top of Stack if we use Stack in ListView
            ],
          ),
        ),
      );
    }

    final profile = _profiles.first;

    return Scaffold(
      backgroundColor: kCream,
      body: RefreshIndicator(
        onRefresh: _fetchProfiles,
        color: kRose,
        backgroundColor: kParchment,
        child: Stack(
          children: [
          // 1. SCROLLABLE PROFILE CONTENT (Animated Transition)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              final isIncoming = child.key == ValueKey(profile['id'] ?? profile['full_name']);

              if (isIncoming) {
                final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(animation);
                final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(animation);
                return FadeTransition(
                  opacity: fadeAnimation,
                  child: ScaleTransition(scale: scaleAnimation, child: child),
                );
              } else {
                final isLike = _lastSwipeDirection == 'like';
                final outOffset = Tween<Offset>(
                  begin: isLike ? const Offset(1.5, 0.1) : const Offset(-1.5, 0.1),
                  end: Offset.zero,
                ).animate(animation);
                final rotationAnimation = Tween<double>(
                  begin: isLike ? 0.1 : -0.1,
                  end: 0.0,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
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
            top: 0, left: 0, right: 0,
            child: _buildHeader(context),
          ),

          // 3. FLOATING ACTION BUTTONS
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: _buildFloatingButtons(),
          ),
        ],
      ),
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

    final String name = profile['fullName'] ?? profile['full_name'] ?? 'User';
    final String? birthdayString = profile['birthday'];
    final int age = _calculateAge(birthdayString);
    final String intent = profile['intent'] ?? '';
    final bool isVerified = profile['is_verified'] ?? true;

    final Map<String, String?> allEssentials = {
      'Age': age > 0 ? age.toString() : null,
      'Location': (() { 
        final loc = profile['location'] as String?; 
        if (loc == null) return null; 
        final idx = loc.indexOf('('); 
        return idx != -1 ? loc.substring(0, idx).trim().split(',').take(2).join(',').trim() : loc;
      })(),
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

    List<Widget> contentList = [];
    
    // Header spacer
    contentList.add(const SizedBox(height: 106));

    // ── Name, Age, Verification & Rewind ──────────────────────────────────────
    contentList.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: kRosePale,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_rounded, color: kRose, size: 22),
                        ),
                      ],
                      if (_likesRemaining <= 0) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                             if (_isActionLoading) return;
                             setState(() => _isActionLoading = true);
                             try {
                               final succ = await _matchingService.saveProfileForLater(profile['id'].toString());
                               setState(() => _isActionLoading = false);
                               if (succ && mounted) {
                                 _showThemedToast('Profile saved for later!', isError: false);
                                 setState(() { 
                                    if (_profiles.isNotEmpty) _profiles.removeAt(0);
                                 });
                               } else if (mounted) {
                                  _showThemedToast('Already saved or failed to save.', isError: true);
                                }
                             } catch (e) {
                               setState(() => _isActionLoading = false);
                               if (mounted) _showThemedToast('Error saving profile.', isError: true);
                             }
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: kGold.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                               _isActionLoading ? Icons.hourglass_empty_rounded : Icons.bookmark_add_rounded, 
                               color: kGold, 
                               size: 20
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_lastDislikedProfile != null)
                  GestureDetector(
                    onTap: _isActionLoading ? null : _handleRewind,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kParchment,
                        shape: BoxShape.circle,
                        border: Border.all(color: kGold.withOpacity(0.5), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: kGold.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(Icons.undo_rounded, color: kGold, size: 24),
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
    final customMessage = profile['custom_message'] as String?;
    if (allEssentials.values.any((v) => v != null && v.isNotEmpty)) {
      contentList.add(_buildUnifiedEssentialsCard(allEssentials, customMessage));
    }

    // Interests/Hobbies
    if (allInterests.isNotEmpty) {
      contentList.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Increased vertical padding
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

    // Block / Report footer
    contentList.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Divider(color: kBone, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kGold.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: kBone, thickness: 1)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTextAction(
                  Icons.flag_outlined,
                  "Report",
                  () => _showReportDialog(profile),
                ),
                Container(width: 1, height: 20, color: kBone),
                _buildTextAction(
                  Icons.block_outlined,
                  "Block",
                  () => _showBlockConfirmation(profile),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    contentList.add(const SizedBox(height: 140));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contentList,
      ),
    );
  }

  Widget _buildTextAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: kInkMuted.withOpacity(0.6), size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.figtree(
              color: kInkMuted.withOpacity(0.6),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ================= HEADER =================

  Widget _buildHeader(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: kCream.withOpacity(0.88),
            border: Border(
              bottom: BorderSide(color: kBone, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _showFiltersModal(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: kParchment,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBone, width: 1),
                  ),
                  child: const Icon(Icons.tune_rounded, color: kInk, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildFilterChip('Age', () => _showFiltersModal(focusedFilter: 'Age')),
                    _buildFilterChip('Intention', () => _showFiltersModal(focusedFilter: 'Intention')),
                    _buildFilterChip('Religion', () => _showFiltersModal(focusedFilter: 'Religion')),
                    _buildFilterChip('Interested In', () => _showFiltersModal(focusedFilter: 'Interested In')),
                    _buildFilterChip('Ethnicity', () => _showFiltersModal(focusedFilter: 'Ethnicity')),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: kParchment,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBone, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.figtree(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: kInk,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down_rounded, color: kRose, size: 16),
          ],
        ),
      ),
    );
  }

  // --- ACTIONS ---

  void _showBlockConfirmation(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      barrierColor: kInk.withOpacity(0.5),
      builder: (ctx) => AlertDialog(
        backgroundColor: kCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: kBone),
        ),
        title: Text(
          'Block ${profile['full_name']}?',
          style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 22,
            color: kInk,
          ),
        ),
        content: Text(
          'They will be removed from your Discover feed and won\'t be able to see you.',
          style: GoogleFonts.figtree(
            fontSize: 14,
            color: kInkMuted,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.figtree(color: kInkMuted, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _matchingService.blockUser(profile['id']);
              if (success && mounted) {
                _showThemedToast('${profile['full_name']} blocked', isError: false);
                setState(() { _profiles.removeAt(0); });
              } else if (mounted) {
                _showThemedToast('Failed to block. Try again.', isError: true);
              }
            },
            child: Text(
              'Block',
              style: GoogleFonts.figtree(color: Colors.red.shade400, fontWeight: FontWeight.w600),
            ),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: kCream,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: kBone, width: 0.5)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: kBone,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Text(
                    "Report",
                    style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 24,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile['full_name'] ?? '',
                    style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 18,
                      fontStyle: FontStyle.italic,
                      color: kInkMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...reasons.asMap().entries.map((entry) {
                    final isLast = entry.key == reasons.length - 1;
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            entry.value,
                            style: GoogleFonts.figtree(
                              color: kInk,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kInkMuted),
                          onTap: () async {
                            Navigator.pop(ctx);
                            final success = await _matchingService.reportUser(profile['id'], entry.value);
                            if (success && mounted) {
                              _showThemedToast('Report submitted. User has been blocked.', isError: false);
                              setState(() { _profiles.removeAt(0); });
                            } else if (mounted) {
                              _showThemedToast('Failed to report.', isError: true);
                            }
                          },
                        ),
                        if (!isLast) Divider(height: 1, color: kBone),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showThemedToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.figtree(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade400 : kRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        elevation: 6,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    if (_profiles.isEmpty) return const SizedBox();

    final currentProfileId = _profiles.first['id'].toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // DISLIKE
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 8,
            shadowColor: kBone,
            child: InkWell(
              onTap: () => _onSwipe(currentProfileId, 'dislike'),
              customBorder: const CircleBorder(),
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                child: const Icon(Icons.close_rounded, color: kInkMuted, size: 32),
              ),
            ),
          ),

          const SizedBox(width: 32),

          // PULSE (Super Like)
          Material(
            color: _likesRemaining > 0 ? kGold : Colors.grey.shade300,
            shape: const CircleBorder(),
            elevation: _likesRemaining > 0 ? 12 : 2,
            shadowColor: _likesRemaining > 0 ? kGold.withOpacity(0.5) : Colors.transparent,
            child: InkWell(
              onTap: () {
                final profile = _profiles.first;
                final name = profile['fullName'] ?? profile['full_name'] ?? 'them';
                _showPulseDialog(currentProfileId, name);
              },
              customBorder: const CircleBorder(),
              child: Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                child: Icon(
                  Icons.bolt_rounded, 
                  color: _likesRemaining > 0 ? Colors.white : Colors.grey.shade500, 
                  size: 40
                ),
              ),
            ),
          ),

          const SizedBox(width: 32),

          // LIKE
          Material(
            color: _likesRemaining > 0 ? kRose : Colors.grey.shade300,
            shape: const CircleBorder(),
            elevation: _likesRemaining > 0 ? 8 : 2,
            shadowColor: _likesRemaining > 0 ? kRose.withOpacity(0.4) : Colors.transparent,
            child: InkWell(
              onTap: () => _onSwipe(currentProfileId, 'like'),
              customBorder: const CircleBorder(),
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                child: Icon(
                  _likesRemaining > 0 ? Icons.favorite_rounded : Icons.lock_rounded, 
                  color: _likesRemaining > 0 ? Colors.white : Colors.grey.shade500, 
                  size: 32
                ),
              ),
            ),
          ),
        ],
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

  Widget _buildUnifiedEssentialsCard(Map<String, String?> allData, String? customMessage) {
    final verticalKeys = ['Looking For', 'Religion', 'Ethnicity', 'Star Sign'];
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

  void _showFiltersModal({String? focusedFilter}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        focusedFilter: focusedFilter,
        initialAge: _filterAge,
        initialDistance: _filterDistance,
        initialIntent: _filterIntent,
        initialReligion: _filterReligion,
        initialHeight: _filterHeight,
        initialEthnicity: _filterEthnicity,
        initialPolitics: _filterPolitics,
        initialStarSign: _filterStarSign,
        initialEducation: _filterEducation,
        initialKids: _filterKids,
        initialPets: _filterPets,
        initialExercise: _filterExercise,
        initialDrinks: _filterDrinks,
        initialSmoke: _filterSmoke,
        initialWeed: _filterWeed,
        isPremium: _isPremium,
        onApply: (age, dist, intent, rel, eth, ht, politics, starSign, education, kids, pets, exercise, drinks, smoke, weed) {
          setState(() {
            _filterAge = age;
            _filterDistance = dist;
            _filterIntent = intent;
            _filterReligion = rel;
            _filterEthnicity = eth;
            _filterHeight = ht;
            _filterPolitics = politics;
            _filterStarSign = starSign;
            _filterEducation = education;
            _filterKids = kids;
            _filterPets = pets;
            _filterExercise = exercise;
            _filterDrinks = drinks;
            _filterSmoke = smoke;
            _filterWeed = weed;
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

  // --- LOCATION HELPERS ---

  Map<String, double>? _parseCoordinates(String? locationStr) {
    if (locationStr == null || !locationStr.contains('(')) return null;
    try {
      final start = locationStr.indexOf('(') + 1;
      final end = locationStr.indexOf(')');
      if (start <= 0 || end <= start) return null;
      
      final coordsPart = locationStr.substring(start, end);
      final parts = coordsPart.split(',');
      if (parts.length < 2) return null;

      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());

      if (lat != null && lng != null) {
        return {'lat': lat, 'lng': lng};
      }
    } catch (e) {
      debugPrint("Error parsing coordinates: $e");
    }
    return null;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = pi / 180;
    const c = cos;
    final a = 0.5 - c((lat2 - lat1) * p) / 2 + 
              c(lat1 * p) * c(lat2 * p) * 
              (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}

// ─── FILTER BOTTOM SHEET ──────────────────────────────────────────────────────

class _FilterBottomSheet extends StatefulWidget {
  final String? focusedFilter;
  final RangeValues initialAge;
  final double initialDistance;
  final String initialIntent;
  final String? initialReligion;
  final RangeValues initialHeight;
  final String? initialEthnicity;
  final String? initialPolitics;
  final String? initialStarSign;
  final String? initialEducation;
  final String? initialKids;
  final String? initialPets;
  final String? initialExercise;
  final String? initialDrinks;
  final String? initialSmoke;
  final String? initialWeed;
  final bool isPremium;
  final Function(RangeValues, double, String, String?, String?, RangeValues, String?, String?, String?, String?, String?, String?, String?, String?, String?) onApply;

  const _FilterBottomSheet({
    this.focusedFilter,
    required this.initialAge,
    required this.initialDistance,
    required this.initialIntent,
    required this.initialReligion,
    required this.initialHeight,
    required this.initialEthnicity,
    required this.initialPolitics,
    required this.initialStarSign,
    required this.initialEducation,
    required this.initialKids,
    required this.initialPets,
    required this.initialExercise,
    required this.initialDrinks,
    required this.initialSmoke,
    required this.initialWeed,
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
  String? _politics;
  String? _starSign;
  String? _education;
  String? _kids;
  String? _pets;
  String? _exercise;
  String? _drinks;
  String? _smoke;
  String? _weed;

  static const _intents = ['Men', 'Women', 'Everyone'];
  static const _religions = ['Any', 'Christian', 'Muslim', 'Hindu', 'Buddhist', 'Jewish', 'Spiritual', 'Atheist', 'Other'];
  static const _ethnicities = ['Any', 'Asian', 'Black', 'Hispanic/Latino', 'Middle Eastern', 'White', 'Mixed', 'Other'];
  static const _politicsList = ['Any', 'Liberal', 'Moderate', 'Conservative', 'Non-political', 'Other'];
  static const _starSignList = ['Any', 'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo', 'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces'];
  static const _educationList = ['Any', 'High School', 'Some College', 'Bachelor\'s', 'Master\'s', 'PhD', 'Trade School'];
  static const _kidsList = ['Any', 'Have kids', 'Don\'t have kids', 'Want kids', 'Don\'t want kids', 'Open to it'];
  static const _petsList = ['Any', 'Dogs', 'Cats', 'Birds', 'Reptiles', 'None', 'Other'];
  static const _exerciseList = ['Any', 'Daily', 'Often', 'Sometimes', 'Rarely', 'Never'];
  static const _drinksList = ['Any', 'Never', 'Rarely', 'Socially', 'Often'];
  static const _smokeList = ['Any', 'Never', 'Sometimes', 'Often'];
  static const _weedList = ['Any', 'Never', 'Sometimes', 'Often'];

  @override
  void initState() {
    super.initState();
    _age = widget.initialAge;
    _dist = widget.initialDistance;
    _intent = widget.initialIntent;
    _rel = widget.initialReligion;
    _ht = widget.initialHeight;
    _eth = widget.initialEthnicity;
    _politics = widget.initialPolitics;
    _starSign = widget.initialStarSign;
    _education = widget.initialEducation;
    _kids = widget.initialKids;
    _pets = widget.initialPets;
    _exercise = widget.initialExercise;
    _drinks = widget.initialDrinks;
    _smoke = widget.initialSmoke;
    _weed = widget.initialWeed;
  }

  void _showPremiumLockDialog() {
    showDialog(
      context: context,
      barrierColor: kInk.withOpacity(0.5),
      builder: (ctx) => AlertDialog(
        backgroundColor: kCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: kBone),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kGold.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_rounded, color: kGold, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Premium Feature',
                style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 22,
                  color: kInk,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Unlock advanced filters like Religion, Height, and Ethnicity with Clush Premium.',
          style: GoogleFonts.figtree(
            fontSize: 14,
            color: kInkMuted,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Maybe later',
              style: GoogleFonts.figtree(color: kInkMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRose,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Upgrade',
              style: GoogleFonts.figtree(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.focusedFilter != null ? null : MediaQuery.of(context).size.height * 0.87,
      decoration: BoxDecoration(
        color: kCream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: kBone, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: kBone,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Row(
              children: [
                Text(
                  widget.focusedFilter ?? "Discover",
                  style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 32,
                    color: kInk,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (widget.focusedFilter == null) ...[
                  const SizedBox(width: 8),
                  Text(
                    "Filters",
                    style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 32,
                      color: kRose,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Divider(height: 1, color: kBone),

          Flexible(
            fit: widget.focusedFilter != null ? FlexFit.loose : FlexFit.tight,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              physics: widget.focusedFilter != null ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
              shrinkWrap: widget.focusedFilter != null,
              children: [
                if (widget.focusedFilter == null) ...[
                  _buildSectionLabel("FREE FILTERS"),
                  const SizedBox(height: 16),
                ],

                // Intent / Interested In
                if (widget.focusedFilter == null || widget.focusedFilter == 'Interested In' || widget.focusedFilter == 'Intention') ...[
                  Text("Interested In", style: GoogleFonts.figtree(fontWeight: FontWeight.w600, fontSize: 15, color: kInk)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _intents.map((i) {
                      final selected = _intent == i;
                      return GestureDetector(
                        onTap: () => setState(() => _intent = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? kRose : kParchment,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selected ? kRose : kBone, width: 1),
                          ),
                          child: Text(i, style: GoogleFonts.figtree(color: selected ? Colors.white : kInk, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                ],

                // Age slider
                if (widget.focusedFilter == null || widget.focusedFilter == 'Age') ...[
                  _buildSliderLabel("Age Range", "${_age.start.round()} – ${_age.end.round()}"),
                  SliderTheme(
                    data: _sliderTheme(context),
                    child: RangeSlider(values: _age, min: 18, max: 100, onChanged: (val) => setState(() => _age = val)),
                  ),
                  const SizedBox(height: 16),
                ],

                // Distance slider
                if (widget.focusedFilter == null) ...[
                  _buildSliderLabel("Max Distance", "${_dist.round()} km"),
                  SliderTheme(
                    data: _sliderTheme(context),
                    child: Slider(value: _dist, min: 5, max: 100, onChanged: (val) => setState(() => _dist = val)),
                  ),
                  const SizedBox(height: 24),
                ],

                // Religion (free)
                if (widget.focusedFilter == null || widget.focusedFilter == 'Religion') ...[
                  _buildFreeDropdown("Religion", _religions, _rel, (v) => setState(() => _rel = v)),
                  const SizedBox(height: 20),
                ],

                // Ethnicity (free)
                if (widget.focusedFilter == null || widget.focusedFilter == 'Ethnicity') ...[
                  _buildFreeDropdown("Ethnicity", _ethnicities, _eth, (v) => setState(() => _eth = v)),
                  const SizedBox(height: 32),
                ],

                // ── PREMIUM SECTION ──
                if (widget.focusedFilter == null) ...[
                  Row(
                    children: [
                      _buildSectionLabel("CLUSH+ FILTERS"),
                      const SizedBox(width: 8),
                      if (!widget.isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kGold.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: kGold.withOpacity(0.3)),
                          ),
                          child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 11, color: kGold),
                            const SizedBox(width: 3),
                            Text("Unlock", style: GoogleFonts.figtree(fontSize: 10, fontWeight: FontWeight.w700, color: kGold, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Height (premium)
                _buildSliderLabel("Height Range (cm)", "${_ht.start.round()} – ${_ht.end.round()}", locked: !widget.isPremium),
                AbsorbPointer(
                  absorbing: !widget.isPremium,
                  child: GestureDetector(
                    onTap: widget.isPremium ? null : _showPremiumLockDialog,
                    child: SliderTheme(
                      data: _sliderTheme(context, locked: !widget.isPremium),
                      child: RangeSlider(values: _ht, min: 100, max: 250, onChanged: (val) => setState(() => _ht = val)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                _buildPremiumDropdown("Politics", _politicsList, _politics, (v) => setState(() => _politics = v)),
                const SizedBox(height: 20),
                _buildPremiumDropdown("Star Sign", _starSignList, _starSign, (v) => setState(() => _starSign = v)),
                const SizedBox(height: 20),
                _buildPremiumDropdown("Education Level", _educationList, _education, (v) => setState(() => _education = v)),
                const SizedBox(height: 20),
                _buildPremiumDropdown("Kids", _kidsList, _kids, (v) => setState(() => _kids = v)),
                const SizedBox(height: 20),
                _buildPremiumDropdown("Pets", _petsList, _pets, (v) => setState(() => _pets = v)),
                const SizedBox(height: 20),
                _buildPremiumDropdown("Exercise", _exerciseList, _exercise, (v) => setState(() => _exercise = v)),
                const SizedBox(height: 20),
                _buildPremiumDropdown("Drinks", _drinksList, _drinks, (v) => setState(() => _drinks = v)),
                const SizedBox(height: 20),
                _buildPremiumDropdown("Smoke", _smokeList, _smoke, (v) => setState(() => _smoke = v)),
                const SizedBox(height: 20),
                _buildPremiumDropdown("Weed", _weedList, _weed, (v) => setState(() => _weed = v)),
                const SizedBox(height: 48),
              ],
            ],
          ),
          ),

          // Apply button
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: BoxDecoration(
              color: kCream,
              border: Border(top: BorderSide(color: kBone, width: 0.5)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRose,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onApply(_age, _dist, _intent, _rel, _eth, _ht, _politics, _starSign, _education, _kids, _pets, _exercise, _drinks, _smoke, _weed);
                },
                child: Text("Apply Filters", style: GoogleFonts.figtree(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliderThemeData _sliderTheme(BuildContext context, {bool locked = false}) {
    return SliderTheme.of(context).copyWith(
      activeTrackColor: locked ? kBone : kRose,
      inactiveTrackColor: locked ? kBone.withOpacity(0.5) : kRosePale,
      thumbColor: locked ? kBone : kRose,
      overlayColor: kRose.withOpacity(0.12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      trackHeight: 3,
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.figtree(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: kInkMuted.withOpacity(0.6),
        letterSpacing: 2.0,
      ),
    );
  }

  Widget _buildSliderLabel(String label, String value, {bool locked = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.figtree(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: locked ? kInkMuted.withOpacity(0.4) : kInk,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.figtree(
              fontWeight: FontWeight.w700,
              color: locked ? kInkMuted.withOpacity(0.4) : kRose,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeDropdown(String label, List<String> options, String? value, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.figtree(fontWeight: FontWeight.w600, fontSize: 15, color: kInk)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: kParchment,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBone, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value ?? 'Any',
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kInkMuted, size: 18),
              dropdownColor: kCream,
              style: GoogleFonts.figtree(color: kInk, fontSize: 14, fontWeight: FontWeight.w500),
              items: options.map((String val) => DropdownMenuItem<String>(value: val, child: Text(val))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumDropdown(String label, List<String> options, String? value, Function(String?) onChanged) {
    return GestureDetector(
      onTap: widget.isPremium ? null : _showPremiumLockDialog,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.figtree(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: widget.isPremium ? kInk : kInkMuted.withOpacity(0.4),
                ),
              ),
              if (!widget.isPremium) ...[
                const SizedBox(width: 6),
                const Icon(Icons.lock_rounded, size: 13, color: kGold),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: widget.isPremium ? kParchment : kParchment.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBone, width: 1),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value ?? 'Any',
                icon: Icon(
                  widget.isPremium ? Icons.keyboard_arrow_down_rounded : Icons.lock_rounded,
                  color: widget.isPremium ? kInkMuted : kGold,
                  size: 18,
                ),
                dropdownColor: kCream,
                style: GoogleFonts.figtree(
                  color: widget.isPremium ? kInk : kInkMuted.withOpacity(0.4),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                items: options.map((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val),
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

// ─── BOUNCING BUTTON ──────────────────────────────────────────────────────────

class _BouncingButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final double size;
  final VoidCallback onTap;

  const _BouncingButton({
    super.key,
    required this.icon,
    required this.color,
    required this.iconColor,
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
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }
  void _onTapCancel() => _controller.reverse();

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
            color: kCream,
            shape: BoxShape.circle,
            border: Border.all(color: widget.color.withOpacity(0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 0,
                spreadRadius: 2,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: widget.iconColor,
            size: widget.size * 0.42,
          ),
        ),
      ),
    );
  }
}
