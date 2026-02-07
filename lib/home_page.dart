import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_view_page.dart'; 
import 'settings_page.dart'; // IMPORT THE NEW PAGE

const Color kRose = Color(0xFFCD9D8F);
const Color kTan = Color(0xFFE9E6E1);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 3; 

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text("$title\nComing Soon", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 18)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildPlaceholder("Home"),
      _buildPlaceholder("Likes"),
      _buildPlaceholder("Chat"),
      const ProfileTab(), // The Profile Tab
    ];

    return Scaffold(
      backgroundColor: kTan,
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        indicatorColor: kRose.withOpacity(0.3),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.style_outlined), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Likes'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

// --- PROFILE TAB WIDGET ---
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<Map<String, dynamic>?> _fetchProfile() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;
    
    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kRose));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text("Error loading profile: ${snapshot.error}"));
          }

          final profile = snapshot.data!;
          final List photos = profile['photo_urls'] ?? [];
          final String firstPhoto = photos.isNotEmpty ? photos.first : '';
          final String name = profile['full_name'] ?? 'User';
          final int age = _calculateAge(profile['birthday']);

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER WITH SETTINGS ICON ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("My Profile", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                    IconButton(
                      // Navigate to Settings Page
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsPage()),
                        );
                      },
                      icon: const Icon(Icons.settings, color: Colors.black54), // CHANGED ICON
                      tooltip: "Settings",
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // --- PREVIEW CARD (Hinge Style) ---
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => ProfileViewPage(profile: profile))
                    );
                  },
                  child: Container(
                    height: 500,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Photo
                        ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: firstPhoto.isNotEmpty
                              ? Image.network(firstPhoto, fit: BoxFit.cover)
                              : Container(color: Colors.grey.shade300, child: const Icon(Icons.person, size: 50)),
                        ),
                        // Gradient
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                              stops: const [0.7, 1.0],
                            ),
                          ),
                        ),
                        // Text Info
                        Positioned(
                          bottom: 25,
                          left: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "$name, $age",
                                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2), 
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.5))
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.visibility, color: Colors.white, size: 14),
                                    SizedBox(width: 6),
                                    Text("Preview", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(child: Text("This is how you appear to others", style: TextStyle(color: Colors.grey))),
              ],
            ),
          );
        },
      ),
    );
  }

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