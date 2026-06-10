import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clush/theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clush/screens/setting_sub_pages.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clush/services/stream_service.dart';

class ChatSettingsPage extends StatefulWidget {
  const ChatSettingsPage({super.key});

  @override
  State<ChatSettingsPage> createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends State<ChatSettingsPage> {
  bool _muteNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _muteNotifications = prefs.getBool('mute_chat_notifications') ?? false;
    });
  }

  Future<void> _toggleMute(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mute_chat_notifications', value);
    setState(() {
      _muteNotifications = value;
    });
  }

  void _confirmDeleteAllChats() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Delete All Chats?",
            style: GoogleFonts.gabarito(color: kInk, fontWeight: FontWeight.bold)),
        content: Text("This will permanently delete all your chat history. Your matches will remain.",
            style: GoogleFonts.figtree(color: kInkMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.figtree(color: kInk, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final myId = FirebaseAuth.instance.currentUser?.uid;
              if (myId != null) {
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator(color: kAccent)),
                );
                await StreamService.instance.deleteAllChats(myId);
                if (mounted) {
                  Navigator.pop(context); // Pop loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('All chats deleted', style: GoogleFonts.figtree()),
                      backgroundColor: kInk,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kDestructive,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text("Delete All", style: GoogleFonts.figtree(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      appBar: AppBar(
        backgroundColor: kCream,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kInk, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Chat Settings",
          style: GoogleFonts.gabarito(
            color: kInk,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionLabel("Privacy"),
          _buildCard([
            _buildTile(
              icon: Icons.notifications_off_outlined,
              title: "Mute Notifications",
              trailing: Switch.adaptive(value: _muteNotifications, onChanged: _toggleMute),
            ),
            _buildDivider(),
            _buildTile(
              icon: Icons.block_flipped,
              title: "Blocked Contacts",
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockListPage()));
              },
            ),
          ]),
          const SizedBox(height: 48),
          _buildDangerButton("Delete All Chats"),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.figtree(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: kInkMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderLight, width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: kInk, size: 22),
      title: Text(
        title,
        style: GoogleFonts.figtree(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: kInk,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: kInkMuted),
      onTap: onTap,
    );
  }

  Widget _buildDivider() => const Divider(height: 1, indent: 56, color: kBorderLight);

  Widget _buildDangerButton(String label) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDestructive.withOpacity(0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _confirmDeleteAllChats,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.figtree(
                color: kDestructive,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
