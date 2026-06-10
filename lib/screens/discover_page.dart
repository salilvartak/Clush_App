import 'dart:math' show cos, sqrt, asin, pi;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clush/services/matching_service.dart';
import 'package:clush/widgets/heart_loader.dart';
import 'package:clush/widgets/match_animation_dialog.dart';
import 'package:clush/widgets/animated_swipe_icon.dart';
import 'package:clush/services/cache_service.dart';
import 'package:clush/providers/likes_provider.dart';
// activity_badge import removed — badge moved into _buildFirstProfileCard overlay;

import 'package:clush/theme/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:clush/screens/setting_sub_pages.dart';
import 'package:clush/screens/home_page.dart';
import 'package:clush/screens/chat_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  // Service for handling likes/matches
  final MatchingService _matchingService = MatchingService();

  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  bool _isCurating = false;
  int _likesRemaining = 6;
  int _superLikesRemaining = 1;
  int _rewindsRemaining = 2;
  int _savesRemaining = 2;
  bool _isPremium = false;

  String? _myPhotoUrl;
  String _myName = 'Me';

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

  final ScrollController _scrollController = ScrollController();
  bool _showFloatingName = false;

  // ── Swipe animation ──────────────────────────────────────────────────────────
  // Cinematic sequential reveal, driven by ONE controller split into four phases:
  //   Phase 1 (exit)   0.00–0.30  card slides off, blurred backdrop fades in
  //   Phase 2 (icon in)0.30–0.55  heart/cross rises from below & scales in
  //   Phase 3 (icon out)0.55–0.75 icon holds briefly then fades away
  //   Phase 4 (next in)0.75–1.00  next profile fades in, backdrop fades out
  static const Duration _kSequenceDuration = Duration(milliseconds: 2800);
  static const Interval _kExitPhase = Interval(0.00, 0.22, curve: Curves.easeOutCubic);
  static const Interval _kIconInPhase = Interval(0.22, 0.48, curve: Curves.easeOutCubic);
  static const Interval _kIconOutPhase = Interval(0.48, 0.70, curve: Curves.easeIn);
  static const Interval _kNextInPhase = Interval(0.70, 1.00, curve: Curves.easeOutCubic);

  late AnimationController _sequenceController;
  bool _isSwiping = false;
  bool _isRewinding = false; // Card slide-in from left (rewind)
  String _swipeType = ''; // 'like' | 'dislike' | 'gem' | 'save'
  final ValueNotifier<double> _dragNotifier = ValueNotifier(0.0);
  late AnimationController _snapController;
  late AnimationController _rewindController;
  late Animation<double> _rewindProgress;
  String? _pendingTargetId;
  String? _pendingMessage;
  Map<String, dynamic>? _lastDislikedProfile;
  // Snapshot of the card mid-sequence so the backdrop/next-card don't shift under it
  Map<String, dynamic>? _departingProfile;
  Map<String, dynamic>? _incomingProfile;
  // Horizontal drag offset at the moment the swipe was triggered — lets the
  // cinematic exit continue smoothly from wherever the finger released the
  // card instead of snapping it back to centre first.
  double _exitStartOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _sequenceController = AnimationController(
      vsync: this,
      duration: _kSequenceDuration,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed && _isSwiping) {
        _onSequenceComplete();
      }
    });

    _rewindController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((status) {
      if (status == AnimationStatus.dismissed && _isRewinding) {
        setState(() => _isRewinding = false);
      }
    });
    _rewindProgress = CurvedAnimation(
      parent: _rewindController,
      curve: Curves.easeOutCubic,
    );

    _scrollController.addListener(() {
      if (_profiles.isEmpty) return;
      // Show floating name when scrolled past the main header name
      final show = _scrollController.offset > 120;
      if (show != _showFloatingName) {
        setState(() => _showFloatingName = show);
      }
    });

    _loadFilters().then((_) {
      _fetchProfiles();
    });
  }

  Future<void> _loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        final ageStart = prefs.getDouble('filter_age_start');
        final ageEnd = prefs.getDouble('filter_age_end');
        if (ageStart != null && ageEnd != null) {
          _filterAge = RangeValues(ageStart, ageEnd);
        }

        _filterDistance = prefs.getDouble('filter_distance') ?? 50;
        _filterIntent = prefs.getString('filter_intent') ?? '';
        _filterReligion = prefs.getString('filter_religion');
        _filterEthnicity = prefs.getString('filter_ethnicity');

        final heightStart = prefs.getDouble('filter_height_start');
        final heightEnd = prefs.getDouble('filter_height_end');
        if (heightStart != null && heightEnd != null) {
          _filterHeight = RangeValues(heightStart, heightEnd);
        }

        _filterPolitics = prefs.getString('filter_politics');
        _filterStarSign = prefs.getString('filter_star_sign');
        _filterEducation = prefs.getString('filter_education');
        _filterKids = prefs.getString('filter_kids');
        _filterPets = prefs.getString('filter_pets');
        _filterExercise = prefs.getString('filter_exercise');
        _filterDrinks = prefs.getString('filter_drinks');
        _filterSmoke = prefs.getString('filter_smoke');
        _filterWeed = prefs.getString('filter_weed');
      });
    }
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('filter_age_start', _filterAge.start);
    await prefs.setDouble('filter_age_end', _filterAge.end);
    await prefs.setDouble('filter_distance', _filterDistance);
    await prefs.setString('filter_intent', _filterIntent);
    
    if (_filterReligion != null) await prefs.setString('filter_religion', _filterReligion!);
    if (_filterEthnicity != null) await prefs.setString('filter_ethnicity', _filterEthnicity!);
    
    await prefs.setDouble('filter_height_start', _filterHeight.start);
    await prefs.setDouble('filter_height_end', _filterHeight.end);
    
    if (_filterPolitics != null) await prefs.setString('filter_politics', _filterPolitics!);
    if (_filterStarSign != null) await prefs.setString('filter_star_sign', _filterStarSign!);
    if (_filterEducation != null) await prefs.setString('filter_education', _filterEducation!);
    if (_filterKids != null) await prefs.setString('filter_kids', _filterKids!);
    if (_filterPets != null) await prefs.setString('filter_pets', _filterPets!);
    if (_filterExercise != null) await prefs.setString('filter_exercise', _filterExercise!);
    if (_filterDrinks != null) await prefs.setString('filter_drinks', _filterDrinks!);
    if (_filterSmoke != null) await prefs.setString('filter_smoke', _filterSmoke!);
    if (_filterWeed != null) await prefs.setString('filter_weed', _filterWeed!);
  }

  @override
  void dispose() {
    _sequenceController.dispose();
    _snapController.dispose();
    _rewindController.dispose();
    _dragNotifier.dispose();
    super.dispose();
  }

  Future<void> _fetchProfiles() async {
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
        debugPrint("Matches check failed: $e");
      }

      try {
        final savedResponse = await Supabase.instance.client
            .from('saved_profiles')
            .select('saved_user_id')
            .eq('user_id', myId);
        final List<String> savedIds = (savedResponse as List).map((e) => e['saved_user_id'].toString()).toList();
        ignoreIds.addAll(savedIds);
      } catch (e) {
        debugPrint("Saved profiles check failed: $e");
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
        debugPrint("Blocks check failed: $e");
      }

      final myProfileResponse = await Supabase.instance.client
          .from('profiles')
          .select('full_name, gender, is_premium, location, intent, photo_urls, blocked_phones')
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
          _myName = myProfileResponse['full_name'] as String? ?? 'Me';
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
      if (myCoords != null) {
        filteredProfiles = filteredProfiles.where((p) {
          final otherCoords = _parseCoordinates(p['location'] as String?);
          if (otherCoords == null) return false;
          final distance = _calculateDistance(
            myCoords['lat']!,
            myCoords['lng']!,
            otherCoords['lat']!,
            otherCoords['lng']!,
          );
          p['calculated_distance'] = distance;
          return distance <= _filterDistance;
        }).toList();

        filteredProfiles.sort((a, b) {
          final distA = a['calculated_distance'] as double? ?? 99999.0;
          final distB = b['calculated_distance'] as double? ?? 99999.0;
          return distA.compareTo(distB);
        });
      } else {
        filteredProfiles = [];
      }

      if (mounted) {
        // Fetch wallet to sync credits
        final wallet = await _matchingService.getWallet();

        // Check for CURATING_BATCH sentinel from server
        final bool curating = filteredProfiles.length == 1 &&
            filteredProfiles.first['__status'] == 'CURATING_BATCH';

        setState(() {
          _isCurating = curating;
          _profiles = curating ? [] : filteredProfiles.take(20).toList();
          _isLoading = false;
          if (wallet.isNotEmpty) {
            _likesRemaining = wallet['likes_remaining'] ?? 6;
            _superLikesRemaining = wallet['super_likes_remaining'] ?? 0;
            _rewindsRemaining = wallet['rewinds_remaining'] ?? 0;
            _savesRemaining = wallet['profile_saves_remaining'] ?? 0;
            _isPremium = wallet['is_premium'] ?? false;
          }
        });
        // Cache the newly fetched feed
        CacheService.instance.cacheDiscoveryFeed(_profiles);
        // Warm the image cache for the first couple of cards so they're
        // already decoded by the time they're shown — avoids the visible
        // pop-in / loading-spinner flash on first paint.
        _precacheUpcomingPhotos();
      }
    } catch (e) {
      // Fall back to cache only when the network fetch fails entirely
      final cached = await CacheService.instance.getCachedDiscoveryFeed();
      if (cached != null && cached.isNotEmpty && mounted) {
        setState(() {
          _profiles = cached;
          _isLoading = false;
        });
        _precacheUpcomingPhotos();
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Error loading profiles: $e';
          _isLoading = false;
        });
      }
    }
  }

  String? _firstPhotoUrl(Map<String, dynamic> profile) {
    final urls = profile['photo_urls'];
    if (urls is List && urls.isNotEmpty) {
      final url = urls.first;
      if (url is String && url.isNotEmpty) return url;
    }
    return null;
  }

  /// Warms the disk/memory cache for a profile's primary photo so
  /// `CachedNetworkImage` paints instantly once the card is shown —
  /// eliminates the load-in flash/spinner on first appearance.
  void _precacheProfilePhoto(Map<String, dynamic> profile) {
    final url = _firstPhotoUrl(profile);
    if (url == null || !mounted) return;
    precacheImage(CachedNetworkImageProvider(url), context).catchError((_) {});
  }

  /// Keeps the image pipeline a couple of cards ahead of what's on screen.
  void _precacheUpcomingPhotos({int count = 2}) {
    for (final p in _profiles.take(count)) {
      _precacheProfilePhoto(p);
    }
  }

  // --- SWIPE LOGIC ---

  void _triggerSwipe(String targetUserId, String swipeType, {String? message}) {
    if (_isSwiping || _isRewinding || _profiles.isEmpty) return;

    if (swipeType == 'gem') {
      if (_superLikesRemaining <= 0) {
        _snapBack();
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsPage())).then((_) => _fetchProfiles());
        return;
      }
    } else if (swipeType == 'like' && _likesRemaining <= 0) {
      _snapBack();
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsPage())).then((_) => _fetchProfiles());
      return;
    } else if (swipeType == 'save' && _savesRemaining <= 0) {
      _snapBack();
      _showThemedToast('No saves left! Get Clush+ or purchase more.', isError: true);
      return;
    }

    // Snapshot the departing + incoming profiles so the cinematic sequence
    // has stable content to render through every phase, independent of
    // `_profiles` mutating mid-flight.
    _pendingTargetId = targetUserId;
    _pendingMessage = message;
    _departingProfile = _profiles.first;
    _incomingProfile = _profiles.length > 1 ? _profiles[1] : null;
    // Stay one card ahead of the stack: by the time this swipe resolves,
    // `_profiles[1]` becomes current and `_profiles[2]` becomes "next" —
    // warm its photo now so it's ready well before it's ever shown.
    if (_profiles.length > 2) _precacheProfilePhoto(_profiles[2]);
    // Carry the live drag offset into the exit animation so a manual
    // release continues smoothly from the finger's position instead of
    // snapping the card back to centre before it flies off.
    _exitStartOffset = (swipeType == 'like' || swipeType == 'dislike')
        ? _dragNotifier.value
        : 0.0;

    if (_scrollController.hasClients) _scrollController.jumpTo(0);

    // Flip to the cinematic-sequence view FIRST — only then clear the drag
    // offset. Doing it in this order means the idle, drag-driven card is
    // already unmounted when `_dragNotifier` fires, so it never repaints at
    // identity (drag = 0) and visibly snaps back to centre before flying off.
    setState(() {
      _isSwiping = true;
      _swipeType = swipeType;
      _showFloatingName = false;
    });
    _dragNotifier.value = 0;
    _sequenceController.forward(from: 0);
  }

  void _onSequenceComplete() {
    final droppedProfile = _departingProfile;
    final swipeType = _swipeType;
    final targetId = _pendingTargetId;
    final message = _pendingMessage;
    if (droppedProfile == null || targetId == null) return;

    _sequenceController.reset();

    setState(() {
      _isSwiping = false;
      _swipeType = '';
      if (swipeType == 'like') _likesRemaining--;
      if (swipeType == 'gem') _superLikesRemaining--;
      if (swipeType == 'save') _savesRemaining--;
      if (swipeType == 'dislike') _lastDislikedProfile = droppedProfile;
      else _lastDislikedProfile = null;
      if (_profiles.isNotEmpty) _profiles.removeAt(0);
      _pendingTargetId = null;
      _pendingMessage = null;
      _departingProfile = null;
      _incomingProfile = null;
    });
    _recordSwipeInBackground(targetId, swipeType, droppedProfile, message: message);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isSwiping || _isRewinding || _profiles.isEmpty) return;
    // Cancel any in-progress snap-back so the new drag takes over cleanly.
    if (_snapController.isAnimating) _snapController.stop();
    _dragNotifier.value += details.delta.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isSwiping || _isRewinding || _profiles.isEmpty) {
      _snapBack();
      return;
    }
    final vx = details.velocity.pixelsPerSecond.dx;
    final drag = _dragNotifier.value;
    final targetId = _profiles.first['id'].toString();

    if (drag > 80 || vx > 500) {
      _triggerSwipe(targetId, 'like');
    } else if (drag < -80 || vx < -500) {
      _triggerSwipe(targetId, 'dislike');
    } else {
      _snapBack();
    }
  }

  void _onHorizontalDragCancel() => _snapBack();

  void _snapBack() {
    if (_dragNotifier.value == 0) return;
    _snapController.stop();
    final start = _dragNotifier.value;
    final snapAnim = Tween<double>(begin: start, end: 0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    );
    void listener() => _dragNotifier.value = snapAnim.value;
    snapAnim.addListener(listener);
    _snapController
      ..value = 0
      ..forward().then((_) {
        snapAnim.removeListener(listener);
        _dragNotifier.value = 0;
        _snapController.reset();
      });
  }

  void _triggerRewind() async {
    if (_isSwiping || _isRewinding || _lastDislikedProfile == null) return;
    if (_rewindsRemaining <= 0) {
      _showThemedToast('No rewinds left! Get Clush+ or purchase more.', isError: true);
      return;
    }
    final profileToRestore = _lastDislikedProfile!;
    setState(() {
      _profiles.insert(0, profileToRestore);
      _lastDislikedProfile = null;
      _isRewinding = true;
      _rewindsRemaining--;
      _showFloatingName = false;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _rewindController.forward(from: 0);
    final result = await _matchingService.rewind(profileToRestore['id'].toString());
    if (result['success'] == false && mounted) {
      // Roll back: remove the restored card and refund the credit.
      setState(() {
        if (_profiles.isNotEmpty && _profiles.first['id'] == profileToRestore['id']) {
          _profiles.removeAt(0);
        }
        _lastDislikedProfile = profileToRestore;
        _rewindsRemaining++;
      });
      _showThemedToast(
        result['error'] == 'no_rewinds'
            ? 'No rewinds left! Get Clush+ or purchase more.'
            : 'Failed to rewind.',
        isError: true,
      );
    }
  }

  void _recordSwipeInBackground(
    String targetUserId,
    String swipeType,
    Map<String, dynamic> droppedProfile, {
    String? message,
  }) async {
    try {
      Map<String, dynamic> result;
      if (swipeType == 'like') {
        result = await _matchingService.swipeRight(targetUserId);
      } else if (swipeType == 'gem') {
        // Map UI 'gem' to the backend 'pulse' endpoint
        result = await _matchingService.pulse(targetUserId, message);
      } else if (swipeType == 'save') {
        result = await _matchingService.saveProfile(targetUserId);
      } else {
        result = await _matchingService.swipeLeft(targetUserId);
      }
      if (!mounted) return;
      if (result['success'] == false) {
        final error = result['error'];
        if (error == 'daily_limit') {
          _showThemedToast('Out of likes! Wait until they replenish.', isError: true);
        } else if (error == 'exhausted') {
          _showThemedToast(
            swipeType == 'save'
                ? 'No saves left! Get Clush+ or purchase more.'
                : 'No ${result['type'] ?? 'feature'} credits left! Get Clush+ or purchase more.',
            isError: true,
          );
        } else if (swipeType == 'save') {
          _showThemedToast('Failed to save profile.', isError: true);
        }
      } else if (swipeType == 'save') {
        // Keep the Saved tab in sync — without this it shows stale data
        // until the user manually pulls to refresh.
        ProviderScope.containerOf(context, listen: false)
            .read(savedProfilesProvider.notifier)
            .refresh();
      } else if (result['match'] == true && mounted) {
        _showMatchDialog(droppedProfile);
      }
    } catch (e) {
      debugPrint('Error recording swipe: $e');
    }
  }

  void _showGemDialog(String targetUserId, String targetName) {
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
                          child: const Icon(Icons.diamond_rounded, color: kGold, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Send a Gem",
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
                          _triggerSwipe(targetUserId, 'gem', message: message.isEmpty ? null : message);
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
                          "Send Gem",
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
      onMessage: () {
        // 1. Switch HomePage to Matches tab (index 2)
        homeKey.currentState?.setIndex(2);

        // 2. Navigate to ChatScreen
        final myId = FirebaseAuth.instance.currentUser?.uid;
        if (myId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                myId: myId,
                matchId: profile['id'] as String,
                myName: _myName,
                matchName: profile['full_name'] as String? ?? 'Them',
                matchPhotoUrl: matchPhotoUrl,
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    if (_isLoading) {
      return Scaffold(
        backgroundColor: kCream,
        body: const Center(child: HeartLoader()),
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
          color: kAccent,
          backgroundColor: kCard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isCurating
                          ? "We're curating your next introductions"
                          : "You've seen everyone",
                      style: GoogleFonts.gabarito(
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                        color: kInk,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isCurating
                          ? "We're finding the best matches for you.\nCheck back in a little while."
                          : "Check back soon for new profiles",
                      style: GoogleFonts.figtree(fontSize: 14, color: kInkMuted),
                      textAlign: TextAlign.center,
                    ),
                    if (!_isCurating) ...[
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () => _showFiltersModal(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kInk,
                          foregroundColor: kCream,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                        child: Text(
                          "Broaden your view",
                          style: GoogleFonts.figtree(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
        color: kAccent,
        backgroundColor: kCard,
        child: Stack(
          children: [
            // 1. CARD LAYER — either the cinematic swipe sequence, or the
            //    plain interactive card (idle / dragging / rewinding).
            //    Crucially: only ONE profile is ever visible at a time —
            //    no card is ever stacked behind another.
            _isSwiping
                ? _buildSwipeSequence()
                : GestureDetector(
                    onHorizontalDragUpdate: _onHorizontalDragUpdate,
                    onHorizontalDragEnd: _onHorizontalDragEnd,
                    onHorizontalDragCancel: _onHorizontalDragCancel,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_rewindProgress, _dragNotifier]),
                      child: _buildProfileContent(profile),
                      builder: (context, currentCard) {
                        final double r    = _rewindProgress.value;
                        final double drag = _dragNotifier.value;
                        final double sw   = MediaQuery.of(context).size.width;

                        final Matrix4 mat;
                        if (_isRewinding) {
                          // Slide in from the left as r goes 0→1
                          mat = Matrix4.translationValues(-sw * 1.2 * (1.0 - r), 0, 0)
                            ..rotateZ(-0.12 * (1.0 - r));
                        } else if (drag != 0) {
                          final double normalizedX = drag / sw;
                          mat = Matrix4.translationValues(drag, 0, 0)
                            ..rotateZ(normalizedX * 0.12);
                        } else {
                          mat = Matrix4.identity();
                        }

                        return Transform(
                          transform: mat,
                          alignment: Alignment.bottomCenter,
                          child: currentCard,
                        );
                      },
                    ),
                  ),

            // 2. Floating Name Pill
            if (_showFloatingName && !_isSwiping)
              Positioned(
                top: 54, left: 0, right: 0,
                child: _buildFloatingNamePill(profile)
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
              ),

            // Rewind — bottom left (mirrors the gem button)
            Positioned(
              bottom: 40, left: 24,
              child: _buildRewindFAB(),
            ),

            // Save pill — center, only when daily likes are exhausted
            if (_likesRemaining <= 0)
              Positioned(
                bottom: 44, left: 84, right: 84,
                child: Center(child: _buildSavePill()),
              ),

            // Gem — bottom right FAB
            Positioned(
              bottom: 40, right: 24,
              child: _buildGemFAB(),
            ),

            // Fixed header overlay — drawn last so it sits on top of scroll content
            Positioned(
              top: 0, left: 0, right: 0,
              child: _buildHeader(context),
            ),
          ],
        ),
      ),
    );
  }

  // ================= CINEMATIC SWIPE SEQUENCE =================
  //
  // A single, locked, four-phase reveal driven by `_sequenceController`:
  //   1. Exit    — current card slides fully off-screen, a softly blurred /
  //                dimmed backdrop of its photo fades in behind it.
  //   2. Icon in — a heart (like/gem), cross (dislike), or bookmark (save)
  //                rises from below the centre and scales in with a pop.
  //   3. Icon out— the icon holds for a beat, then fades away.
  //   4. Next in — the next profile fades in over the backdrop, which
  //                simultaneously fades out beneath it.
  //
  // Input is locked for the whole sequence (`_isSwiping`), so nothing can
  // interrupt the choreography — keeping it slow and deliberate.
  Widget _buildSwipeSequence() {
    final departing = _departingProfile;
    if (departing == null) return const SizedBox.shrink();

    final bool isLike = _swipeType == 'like' || _swipeType == 'gem';
    final bool isSave = _swipeType == 'save';
    final IconData sequenceIcon = isSave
        ? Icons.bookmark_rounded
        : (isLike ? Icons.favorite_rounded : Icons.close_rounded);
    final Color sequenceColor = isSave ? kGold : (isLike ? kRose : kDestructive);

    return AnimatedBuilder(
      animation: _sequenceController,
      builder: (context, _) {
        final double progress = _sequenceController.value;
        final double sw = MediaQuery.of(context).size.width;
        final double sh = MediaQuery.of(context).size.height;

        // ── Phase 1: exit transform for the departing card ──
        final double exitT = _kExitPhase.transform(progress).clamp(0.0, 1.0);
        final bool goLeft = _swipeType == 'dislike';
        final Matrix4 exitMat;
        if (_swipeType == 'gem') {
          final double s = 1.0 - 0.1 * exitT;
          exitMat = Matrix4.translationValues(0, -sh * 1.2 * exitT, 0)
            ..scaleByDouble(s, s, s, 1.0);
        } else {
          // Blend from wherever the finger released the card (`_exitStartOffset`)
          // out to the full off-screen translation, so there's no jump back
          // to centre before the card continues on its way out.
          final double targetX = goLeft ? -sw * 1.4 : sw * 1.4;
          final double x = _exitStartOffset + (targetX - _exitStartOffset) * exitT;
          final double targetRotation = goLeft ? -0.16 : 0.16;
          final double startRotation = (_exitStartOffset / sw) * 0.12;
          final double rotation = startRotation + (targetRotation - startRotation) * exitT;
          exitMat = Matrix4.translationValues(x, 0, 0)..rotateZ(rotation);
        }
        // Card is fully gone once phase 1 completes — avoid lingering paints.
        final bool showDepartingCard = progress < _kExitPhase.end;

        // ── Phase 2 + 3: icon pop-in then fade-out ──
        final double iconInT = _kIconInPhase.transform(progress).clamp(0.0, 1.0);
        final double iconOutT = _kIconOutPhase.transform(progress).clamp(0.0, 1.0);
        double iconOpacity;
        double iconScale;
        double iconRise;
        if (progress < _kIconInPhase.begin) {
          iconOpacity = 0.0;
          iconScale = 0.4;
          iconRise = 60.0;
        } else if (progress < _kIconOutPhase.begin) {
          iconOpacity = iconInT;
          iconScale = 0.4 + 0.6 * iconInT;
          iconRise = 60.0 * (1.0 - iconInT);
        } else {
          iconOpacity = (1.0 - iconOutT);
          iconScale = 1.0;
          iconRise = 0.0;
        }

        // ── Phase 4: next profile fades in ──
        final double nextInT = _kNextInPhase.transform(progress).clamp(0.0, 1.0);

        return Stack(
          children: [
            // Plain background — same as the rest of the app, no blurred photo
            const Positioned.fill(child: ColoredBox(color: kCream)),

            // Next profile fading in (only once it exists)
            if (_incomingProfile != null && nextInT > 0)
              Positioned.fill(
                child: Opacity(
                  opacity: nextInT,
                  child: _buildProfileContent(_incomingProfile!, interactive: false),
                ),
              ),

            // Departing card sliding/flying away
            if (showDepartingCard)
              Transform(
                transform: exitMat,
                alignment: Alignment.bottomCenter,
                child: _buildProfileContent(departing, interactive: false),
              ),

            // Lottie animations for Gem
            if (iconOpacity > 0 && _swipeType == 'gem')
              IgnorePointer(
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, iconRise),
                    child: Opacity(
                      opacity: iconOpacity.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: iconScale,
                        child: SizedBox(
                          width: sw,
                          height: sw,
                          child: Lottie.asset(
                            'assets/Lottie/gem.lottie',
                            decoder: (bytes) => LottieComposition.decodeZip(
                              bytes,
                              filePicker: (files) => files.firstWhere(
                                (f) => f.name.endsWith('.json') && f.name != 'manifest.json',
                              ),
                            ),
                            repeat: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Native flutter_animate burst for Like and Dislike
            if (iconOpacity > 0 && (_swipeType == 'like' || _swipeType == 'dislike'))
              IgnorePointer(
                child: Center(
                  child: AnimatedSwipeIcon(
                    key: ValueKey('swipe_icon_$_swipeType'),
                    isLike: _swipeType == 'like',
                  ),
                ),
              ),

            // Bookmark icon for 'save' — rises from below, pops in, then fades away
            if (iconOpacity > 0 && _swipeType == 'save')
              IgnorePointer(
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, iconRise),
                    child: Opacity(
                      opacity: iconOpacity.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: iconScale,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kCream.withValues(alpha: 0.92),
                            boxShadow: [
                              BoxShadow(
                                color: kInk.withValues(alpha: 0.18),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(sequenceIcon, color: sequenceColor, size: 72),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingNamePill(Map<String, dynamic> profile) {
    final String name = profile['fullName'] ?? profile['full_name'] ?? 'User';
    final bool isVerified = profile['is_verified'] ?? true;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: kCream.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: kBone.withValues(alpha: 0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: kInk.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.gabarito(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: kInk,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, color: kGold, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ================= CONTENT BUILDER =================

  // [interactive] true for the live/draggable top card (uses the shared
  // `_scrollController` that drives the floating-name pill + jump-to-top).
  // Snapshot cards rendered during the cinematic sequence (departing /
  // incoming) must NOT share that controller — a ScrollController can only
  // be attached to one Scrollable at a time, and swapping subtrees between
  // the idle view and the sequence view would otherwise race two
  // SingleChildScrollViews over it, throwing a
  // "_lifecycleState == inactive" assertion. They get their own internal
  // scroll position and are non-scrollable since input is locked anyway.
  Widget _buildProfileContent(Map<String, dynamic> profile, {bool interactive = true}) {
    final List photoUrls = profile['photo_urls'] ?? [];
    final List prompts = profile['prompts'] ?? [];

    final List interests = profile['interests'] ?? [];
    final List foods = profile['foods'] ?? [];
    final List places = profile['places'] ?? [];
    final allInterests = [...interests, ...foods, ...places];

    final String? birthdayString = profile['birthday'];
    final int age = _calculateAge(birthdayString);
    final String intent = profile['intent'] ?? '';

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

    // Spacer so content starts below the fixed header overlay
    contentList.add(const SizedBox(height: 100));

    // First profile card: image with overlay + interests panel
    contentList.add(_buildFirstProfileCard(profile, allInterests));

    // Essentials card
    final customMessage = profile['custom_message'] as String?;
    if (allEssentials.values.any((v) => v != null && v.isNotEmpty)) {
      contentList.add(_buildUnifiedEssentialsCard(allEssentials, customMessage));
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
                _buildBlockAction(profile),
              ],
            ),
          ],
        ),
      ),
    );

    contentList.add(const SizedBox(height: 140));

    return SingleChildScrollView(
      controller: interactive ? _scrollController : null,
      physics: interactive
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
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

  Widget _buildBlockAction(Map<String, dynamic> profile) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showBlockConfirmation(profile),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block_outlined, color: kInkMuted.withOpacity(0.6), size: 16),
              const SizedBox(width: 6),
              Text(
                "Block",
                style: GoogleFonts.figtree(
                  color: kInkMuted.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= HEADER =================

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: kCream,
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
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
            const Icon(Icons.keyboard_arrow_down_rounded, color: kInkMuted, size: 16),
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
              style: GoogleFonts.figtree(color: kDestructive, fontWeight: FontWeight.w600),
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
        backgroundColor: isError ? kDestructive : kAccent,
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

  Widget _buildGemFAB() {
    final currentProfileId = _profiles.first['id'].toString();
    final hasGems = _superLikesRemaining > 0;
    return GestureDetector(
      onTap: () {
        if (!hasGems) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionsPage()),
          ).then((_) => _fetchProfiles());
          return;
        }
        final profile = _profiles.first;
        final name = profile['fullName'] ?? profile['full_name'] ?? 'them';
        _showGemDialog(currentProfileId, name);
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: kCard,
          shape: BoxShape.circle,
          border: Border.all(color: kBorderLight, width: 1),
          boxShadow: [
            BoxShadow(
              color: kInk.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.diamond_rounded,
          color: hasGems ? kGold : kBorderLight,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildRewindFAB() {
    final hasRewindTarget = _lastDislikedProfile != null && !_isSwiping && !_isRewinding;
    final hasCredits = _rewindsRemaining > 0;
    final canRewind = hasRewindTarget && hasCredits;
    return GestureDetector(
      onTap: !hasCredits
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionsPage()),
              ).then((_) => _fetchProfiles());
            }
          : !hasRewindTarget
              ? null
              : _triggerRewind,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: kCard,
          shape: BoxShape.circle,
          border: Border.all(
            color: canRewind ? kBorderLight : kBorderLight.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: canRewind
              ? [BoxShadow(color: kInk.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Icon(
          Icons.replay_rounded,
          color: canRewind ? kAccent : kBorderLight,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildSavePill() {
    return GestureDetector(
      onTap: () {
        if (_profiles.isEmpty) return;
        _triggerSwipe(_profiles.first['id'].toString(), 'save');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: kBorderLight, width: 1),
          boxShadow: [
            BoxShadow(
              color: kInk.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_border_rounded, color: kInk, size: 18),
            const SizedBox(width: 8),
            Text(
              'Save for Later',
              style: GoogleFonts.figtree(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: kInk,
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
      color: kCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kBorderLight, width: 1),
    );
  }

  // ── First profile card: full-bleed image + gradient overlay + interests ───────
  Widget _buildFirstProfileCard(
      Map<String, dynamic> profile, List allInterests) {
    final List photoUrls = profile['photo_urls'] ?? [];
    final String name = profile['fullName'] ?? profile['full_name'] ?? 'User';
    final int age = _calculateAge(profile['birthday']);
    final bool isVerified = profile['is_verified'] ?? true;
    final String? jobTitle = profile['job_title'] as String?;
    final String? location = (() {
      final loc = profile['location'] as String?;
      if (loc == null) return null;
      final idx = loc.indexOf('(');
      final clean = idx != -1 ? loc.substring(0, idx).trim() : loc;
      final parts =
          clean.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      return parts.length >= 2 ? '${parts[0]}, ${parts[1]}' : clean;
    })();

    final String photoUrl = photoUrls.isNotEmpty ? photoUrls[0].toString() : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderLight, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image + gradient overlay ──────────────────────────────────
            Stack(
              children: [
                SizedBox(
                  height: 420,
                  width: double.infinity,
                  child: photoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: kBorderLight,
                            child: const Center(child: HeartLoader(size: 40)),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: kBorderLight,
                            child: const Center(
                              child: Icon(Icons.person_outline_rounded,
                                  color: kCard, size: 64),
                            ),
                          ),
                        )
                      : Container(color: kBorderLight),
                ),
                // Gradient + name/job/location
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xD9000000), Colors.transparent],
                        stops: [0.0, 1.0],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 56, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '$name, $age',
                              style: GoogleFonts.gabarito(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.verified_rounded,
                                  color: kGold, size: 20),
                            ],
                          ],
                        ),
                        if (jobTitle != null && jobTitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            jobTitle,
                            style: GoogleFonts.figtree(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (location != null && location.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  size: 14),
                              const SizedBox(width: 4),
                              Text(
                                location,
                                style: GoogleFonts.figtree(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // ── Interests panel ───────────────────────────────────────────
            if (allInterests.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INTERESTS',
                      style: GoogleFonts.figtree(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kInkMuted,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allInterests
                          .map((e) => _buildChip(e.toString()))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.figtree(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: kInkMuted,
        letterSpacing: 1.8,
      ),
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
                      Divider(height: 1, thickness: 1, color: kBone),
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
      height: 500,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderLight, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: kBorderLight,
            child: const Center(child: HeartLoader(size: 40)),
          ),
          errorWidget: (context, url, error) => Container(
            color: kBorderLight,
            child: const Center(
              child: Icon(Icons.person_outline_rounded, color: kCard, size: 64),
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
              color: kAccent.withValues(alpha: 0.2),
              height: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            prompt['question'] as String,
            style: GoogleFonts.figtree(
              color: kBlush,
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
              color: kBlack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorderLight, width: 1),
        borderRadius: BorderRadius.circular(99),
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
          _saveFilters();
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
              backgroundColor: kAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      color: kAccent,
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
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? kAccent : kCard,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: selected ? kAccent : kBorderLight, width: 1),
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
                  backgroundColor: kAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      activeTrackColor: locked ? kBone : kAccent,
      inactiveTrackColor: locked ? kBone.withValues(alpha: 0.5) : kBorderLight,
      thumbColor: locked ? kBone : kAccent,
      overlayColor: kAccent.withValues(alpha: 0.1),
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
              color: locked ? kInkMuted.withValues(alpha: 0.4) : kAccent,
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
