import 'package:flutter/material.dart';
import 'discover_page.dart';
import 'likes_page.dart';
import 'matches_page.dart'; // 1. Import the new Matches Page
import 'profile_tab.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; 

  // 2. Define the pages
  final List<Widget> _pages = [
    const DiscoverPage(),
    const LikesPage(),
    
    // 🔴 CHANGED: Instead of going straight to chat, we go to the "Contacts List"
    // Replace "Salil" with the actual logged-in user's name later!
    const MatchesPage(myUsername: "Salil"), 
    
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex], // Shows the selected page
      
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        elevation: 3,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.style_outlined), 
            selectedIcon: Icon(Icons.style),
            label: 'Discover'
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border), 
            selectedIcon: Icon(Icons.favorite),
            label: 'Likes'
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline), 
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat' // Now opens Matches List
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline), 
            selectedIcon: Icon(Icons.person),
            label: 'Profile'
          ),
        ],
      ),
    );
  }
}