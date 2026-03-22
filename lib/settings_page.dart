import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/notification_service.dart';
import 'main.dart';
import 'setting_sub_pages.dart';
import 'edit_profile_page.dart';

import 'theme/colors.dart';
import 'heart_loader.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool activityStatus = true;
  bool notificationsEnabled = true;
  bool emailUpdates = true;
  bool _isLoadingProfile = false;
  String? _userEmail, _userPhone, _userLocation;

  @override
  void initState() { super.initState(); _loadSettings(); }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    String? fetchedLocation, fetchedPhone = user?.phoneNumber;
    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('profiles').select('location, phone').eq('id', user.uid).maybeSingle();
        fetchedLocation = data?['location'];
        if (fetchedPhone == null || fetchedPhone.isEmpty) fetchedPhone = data?['phone'];
      } catch (_) {}
    }
    setState(() {
      notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _userEmail = user?.email;
      _userPhone = fetchedPhone;
      _userLocation = fetchedLocation;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => notificationsEnabled = value);
    await NotificationService().toggleNotifications(value);
  }

  Future<void> _logout() async {
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) { if (mounted) _toast("Error: $e", err: true); }
  }

  Future<void> _handleEditProfile() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    setState(() => _isLoadingProfile = true);
    try {
      final data = await Supabase.instance.client
          .from('profiles').select().eq('id', userId).single();
      if (!mounted) return;
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => EditProfilePage(currentData: data)));
    } catch (e) { _toast("Error loading profile: $e", err: true); }
    finally { if (mounted) setState(() => _isLoadingProfile = false); }
  }

  Future<void> _claimPremium() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('profiles').update({
        'is_premium': true,
        'premium_expiry': DateTime.now().add(const Duration(days: 7)).toIso8601String()
      }).eq('id', userId);
      if (mounted) _toast("1 Week Premium Claimed!");
    } catch (e) { if (mounted) _toast("Error: $e", err: true); }
  }

  void _showRetentionDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: kCream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: kBone)),
      title: Text("Leaving so soon?", textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(fontSize: 22, color: kInk)),
      content: Text("Delete your account?\n\nStay and get 1 WEEK OF PREMIUM FREE!", textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(color: kInkMuted, height: 1.5)),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.all(16),
      actionsAlignment: MainAxisAlignment.center,
      actions: [Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _solidBtn("Claim 1 Week Premium", () { Navigator.pop(ctx); _claimPremium(); }),
        const SizedBox(height: 10),
        _outlineBtn("Put Account on Hold", () { Navigator.pop(ctx); _navTo(const PauseAccountPage()); }),
        TextButton(onPressed: () { Navigator.pop(ctx); _confirmFinalDeletion(); },
            child: Text("Delete Anyway", style: GoogleFonts.montserrat(color: Colors.red.shade400))),
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.montserrat(color: kInkMuted))),
      ])],
    ));
  }

  void _confirmFinalDeletion() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: kCream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: kBone)),
      title: Text("Are you sure?", style: GoogleFonts.montserrat(fontSize: 22, color: kInk)),
      content: Text("This is permanent. All data, matches and messages will be lost.",
          style: GoogleFonts.montserrat(color: kInkMuted, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.montserrat(color: kInkMuted))),
        TextButton(onPressed: () async { Navigator.pop(ctx); await _deleteAccount(); },
            child: Text("Yes, Delete", style: GoogleFonts.montserrat(color: Colors.red.shade400, fontWeight: FontWeight.w600))),
      ],
    ));
  }

  Future<void> _deleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('profiles').delete().eq('id', user.uid);
        await user.delete();
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) { if (mounted) _toast("Error: $e", err: true); }
  }

  Future<void> _navTo(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _loadSettings();
  }

  void _toast(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w500)),
      backgroundColor: err ? Colors.red.shade400 : kRose,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _formatLocation(String? loc) {
    if (loc == null || loc.isEmpty) return "Not set";
    int parenIndex = loc.indexOf('(');
    if (parenIndex != -1) loc = loc.substring(0, parenIndex).trim();
    List<String> parts = loc.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0]}, ${parts[1]}';
    return loc;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      body: Stack(children: [
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _sectionLabel("Account"),
                  _card([
                    _tile(icon: Icons.edit_outlined, title: "Edit Profile",
                        trailing: _isLoadingProfile
                            ? SizedBox(width: 18, height: 18,
                                child: const HeartLoader(size: 20))
                            : null,
                        onTap: _isLoadingProfile ? null : _handleEditProfile),
                    _divider(),
                    _tile(icon: Icons.phone_outlined, title: "Phone Number",
                        subtitle: (_userPhone?.isNotEmpty == true) ? _userPhone : "Not provided",
                        onTap: () => _navTo(const PhoneNumberPage())),
                    _divider(),
                    _tile(icon: Icons.email_outlined, title: "Email Address",
                        subtitle: (_userEmail?.isNotEmpty == true) ? _userEmail : "Not provided",
                        onTap: () => _navTo(const EmailAddressPage())),
                    _divider(),
                    _tile(icon: Icons.pause_circle_outline, title: "Pause Account",
                        onTap: () => _navTo(const PauseAccountPage())),
                  ]),
                  _sectionLabel("Discovery"),
                  _card([
                    _tile(icon: Icons.location_on_outlined, title: "Location",
                        subtitle: _formatLocation(_userLocation),
                        onTap: () => _navTo(const CurrentLocationPage())),
                    _divider(),
                    _tile(icon: Icons.flight_takeoff_rounded, title: "Travel Mode",
                        trailing: _premiumBadge(),
                        onTap: () => _navTo(const TravelModePage())),
                  ]),
                  _sectionLabel("Privacy & Safety"),
                  _card([
                    _tile(icon: Icons.access_time_rounded, title: "Activity Status",
                        trailing: Switch.adaptive(value: activityStatus, activeColor: kRose,
                            onChanged: (v) => setState(() => activityStatus = v))),
                    _divider(),
                    _tile(icon: Icons.verified_user_outlined, title: "Verification",
                        subtitle: "Get that verified badge",
                        onTap: () => _navTo(const VerificationPage())),
                    _divider(),
                    _tile(icon: Icons.block_outlined, title: "Blocked Users",
                        onTap: () => _navTo(const BlockListPage())),
                  ]),
                  _sectionLabel("Notifications"),
                  _card([
                    _tile(icon: Icons.notifications_none_rounded, title: "Push Notifications",
                        trailing: Switch.adaptive(value: notificationsEnabled, activeColor: kRose,
                            onChanged: _toggleNotifications)),
                    _divider(),
                    _tile(icon: Icons.mail_outline_rounded, title: "Email Updates",
                        trailing: Switch.adaptive(value: emailUpdates, activeColor: kRose,
                            onChanged: (v) => setState(() => emailUpdates = v))),
                  ]),
                  _sectionLabel("Community"),
                  _card([
                    _tile(icon: Icons.favorite_border_rounded, title: "Safe Dating Tips",
                        onTap: () => _navTo(const LegalPage(title: "Safe Dating", content: "..."))),
                    _divider(),
                    _tile(icon: Icons.description_outlined, title: "Legal & Licenses",
                        onTap: () => _navTo(const LegalPage(title: "Legal", content: "..."))),
                  ]),
                  const SizedBox(height: 48),
                  _buildLogoutButton(),
                  const SizedBox(height: 12),
                  Center(child: TextButton(
                    onPressed: _showRetentionDialog,
                    child: Text("Delete Account", style: GoogleFonts.montserrat(
                        color: kInkMuted, fontSize: 14,
                        decoration: TextDecoration.underline, decorationColor: kInkMuted)),
                  )),
                  const SizedBox(height: 20),
                  Center(child: Text("Version 1.0.0 (Build 24)",
                      style: GoogleFonts.montserrat(color: kBone, fontSize: 12))),
                  const SizedBox(height: 60),
                ]),
              ),
            ),
          ],
        ),
        Positioned(top: 0, left: 0, right: 0, child: _buildHeader()),
      ]),
    );
  }

  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 108,
          decoration: BoxDecoration(
            color: kCream.withOpacity(0.88),
            border: Border(bottom: BorderSide(color: kBone, width: 0.5)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 52, 24, 12),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text("Settings", style: GoogleFonts.montserrat(
                color: kInk, fontSize: 30, fontWeight: FontWeight.w400, letterSpacing: -0.5)),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 28, bottom: 10),
      child: Row(children: [
        Container(width: 3, height: 14, color: kGold, margin: const EdgeInsets.only(right: 9)),
        Text(label.toUpperCase(), style: GoogleFonts.montserrat(
            fontSize: 11, fontWeight: FontWeight.w700, color: kInkMuted, letterSpacing: 1.8)),
      ]),
    );
  }

  Widget _card(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: kParchment,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: kBone, width: 1),
      boxShadow: [BoxShadow(color: kInk.withOpacity(0.09), blurRadius: 28, offset: const Offset(0, 8))],
    ),
    child: Column(children: children),
  );

  Widget _divider() => Divider(height: 1, thickness: 1, color: kBone, indent: 56);

  Widget _tile({required IconData icon, required String title,
      String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(color: kRosePale, shape: BoxShape.circle),
                child: Icon(icon, color: kRose, size: 18)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: kInk)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.montserrat(fontSize: 13, color: kInkMuted),
                    overflow: TextOverflow.ellipsis),
              ],
            ])),
            if (trailing != null) trailing
            else if (onTap != null) Icon(Icons.chevron_right_rounded, color: kBone, size: 22),
          ]),
        ),
      ),
    );
  }

  Widget _premiumBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: kGold.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: kGold.withOpacity(0.4)),
    ),
    child: Text("PREMIUM", style: GoogleFonts.montserrat(
        color: kGold, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );

  Widget _solidBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: kRose, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
    ),
  );

  Widget _outlineBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kRose, width: 1.5),
      ),
      child: Text(label, style: GoogleFonts.montserrat(color: kRose, fontWeight: FontWeight.w600, fontSize: 15)),
    ),
  );

  Widget _buildLogoutButton() => Center(
    child: GestureDetector(
      onTap: () => showDialog(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: kCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: kBone)),
        title: Text("Log Out?", style: GoogleFonts.montserrat(fontSize: 22, color: kInk)),
        content: Text("Are you sure you want to log out?", style: GoogleFonts.montserrat(color: kInkMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: GoogleFonts.montserrat(color: kInkMuted))),
          TextButton(onPressed: () { Navigator.pop(ctx); _logout(); },
              child: Text("Log Out", style: GoogleFonts.montserrat(color: Colors.red.shade400, fontWeight: FontWeight.w600))),
        ],
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
        decoration: BoxDecoration(
          color: kParchment,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBone, width: 1),
        ),
        child: Text("Log Out", style: GoogleFonts.montserrat(
            color: Colors.red.shade400, fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    ),
  );
}
