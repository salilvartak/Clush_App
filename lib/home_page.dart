import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'discover_page.dart';
import 'likes_page.dart';
import 'matches_page.dart';
import 'profile_tab.dart'; 
import 'setting_sub_pages.dart'; // REQUIRED for VerificationPage

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; 
  bool _isVerified = false;
  bool _isLoading = true;

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
  }

  Future<void> _checkVerificationStatus() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final data = await Supabase.instance.client
          .from('profiles')
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
        body: Center(child: CircularProgressIndicator(color: Color(0xFFCD9D8F))),
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
      body: activeBody,
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE9E6E1),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.style_outlined), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Likes'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildVerificationPopup() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 60, color: Color(0xFFCD9D8F)),
              const SizedBox(height: 20),
              const Text(
                "Verification Required",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "To access Matches, Likes, and Discovery, you must verify your identity first.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15),
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
                      MaterialPageRoute(builder: (context) => const VerificationPage()),
                    );
                    // Check status again when they return
                    _checkVerificationStatus();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCD9D8F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: const Text("Verify Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}