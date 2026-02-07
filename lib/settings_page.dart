import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      // 1. Sign out of Google
      await GoogleSignIn().signOut();
      // 2. Sign out of Firebase
      await FirebaseAuth.instance.signOut();
      
      // Optional: Pop the settings page so if they log in again, they aren't stuck here
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error logging out: $e"))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E6E1), // kTan
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          _buildSectionHeader("Account"),
          _buildListTile(
            icon: Icons.logout,
            title: "Log Out",
            color: Colors.red,
            onTap: () => _logout(context),
          ),
          // You can add more settings here later (e.g., Notifications, Privacy)
          _buildSectionHeader("Support"),
           _buildListTile(
            icon: Icons.help_outline,
            title: "Help Center",
            onTap: () {}, 
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildListTile({required IconData icon, required String title, Color color = Colors.black87, required VoidCallback onTap}) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1), // Separator line effect
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
        onTap: onTap,
      ),
    );
  }
}