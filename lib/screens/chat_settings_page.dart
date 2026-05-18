import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clush/theme/colors.dart';

class ChatSettingsPage extends StatelessWidget {
  const ChatSettingsPage({super.key});

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
              trailing: Switch.adaptive(value: false, onChanged: (v) {}),
            ),
            _buildDivider(),
            _buildTile(
              icon: Icons.block_flipped,
              title: "Blocked Contacts",
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 32),
          _buildSectionLabel("Chat Preferences"),
          _buildCard([
            _buildTile(
              icon: Icons.wallpaper_rounded,
              title: "Chat Wallpaper",
              onTap: () {},
            ),
            _buildDivider(),
            _buildTile(
              icon: Icons.history_rounded,
              title: "Clear Chat History",
              onTap: () {},
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
          onTap: () {},
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
