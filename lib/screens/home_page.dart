import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:clush/screens/discover_page.dart';
import 'package:clush/screens/likes_page.dart';
import 'package:clush/screens/matches_page.dart';
import 'package:clush/screens/profile_tab.dart'; 
import 'package:clush/screens/setting_sub_pages.dart';
import 'package:clush/services/matching_service.dart';
import 'package:clush/theme/colors.dart'; 
import 'package:clush/widgets/heart_loader.dart'; 
import 'package:google_fonts/google_fonts.dart'; 
import 'package:clush/l10n/app_localizations.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; 
  bool _isVerified = false;
  bool _isLoading = true;
  int _unreadCount = 0;
  final MatchingService _matchingService = MatchingService();

  final List<Widget> _pages = [
    const DiscoverPage(),
    const LikesPage(),
    const MatchesPage(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    final count = await _matchingService.getTotalUnreadCount();
    if (mounted) {
      setState(() => _unreadCount = count);
    }
  }

  Future<void> _checkVerificationStatus() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final data = await Supabase.instance.client
          .from('profile_discovery')
          .select('is_verified')
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isVerified = data?['is_verified'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error checking verification: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: const Center(child: HeartLoader()),
      );
    }

    // --- GATEKEEPER LOGIC ---
    Widget activeBody;

    if (_isVerified) {
      // 1. If verified, show everything
      activeBody = _pages[_selectedIndex];
    } else {
      // 2. If NOT verified...
      if (_selectedIndex == 3) {
        // ...Allow Profile Tab
        activeBody = _pages[_selectedIndex];
      } else {
        // ...Block everything else
        activeBody = _buildVerificationPopup();
      }
    }

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.025), end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey('${_selectedIndex}_$_isVerified'),
          child: activeBody,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: kCream, // Updated
          border: Border(top: BorderSide(color: kBone, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (idx) {
            setState(() => _selectedIndex = idx);
            // Re-check verification whenever they switch tabs to ensure they haven't 
            // bypassed the gate (e.g. by changing photo in edit profile)
            _checkVerificationStatus();
            _fetchUnreadCount();
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: kCream, // Updated
          elevation: 0,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          selectedItemColor: kRose,
          unselectedItemColor: kInkMuted,
          iconSize: 26,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.style_rounded),        activeIcon: Icon(Icons.style_rounded),         label: ''),
            const BottomNavigationBarItem(icon: Icon(Icons.favorite),            activeIcon: Icon(Icons.favorite),              label: ''),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: _unreadCount > 0,
                label: Text('$_unreadCount'),
                backgroundColor: kRose,
                child: const Icon(Icons.chat_bubble_rounded),
              ),
              activeIcon: Badge(
                isLabelVisible: _unreadCount > 0,
                label: Text('$_unreadCount'),
                backgroundColor: kRose,
                child: const Icon(Icons.chat_bubble_rounded),
              ),
              label: '',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.person_rounded),       activeIcon: Icon(Icons.person_rounded),        label: ''),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationPopup() {
    return Container(
      color: kTan,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kCream,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBone, width: 1),
            boxShadow: [
              BoxShadow(
                color: kBlack.withOpacity(0.15),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 60, color: kRose),
              const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context)?.verificationRequired ?? "Verification Required",
                  style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 22, color: kBlack),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)?.verificationRequiredMessage ?? "To access Matches, Likes, and Discovery, you must verify your identity first.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: kInkMuted, fontSize: 15),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    // Navigate to the real Verification Page
                    await Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, animation, __) => const VerificationPage(),
                        transitionDuration: const Duration(milliseconds: 350),
                        reverseTransitionDuration: const Duration(milliseconds: 280),
                        transitionsBuilder: (_, animation, __, child) {
                          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                          return FadeTransition(
                            opacity: curved,
                            child: SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
                              child: child,
                            ),
                          );
                        },
                      ),
                    );
                    // Check status again when they return
                    _checkVerificationStatus();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRose,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: Text(
                    AppLocalizations.of(context)?.verifyNow ?? "Verify Now",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
