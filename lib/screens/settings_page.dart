import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:clush/services/notification_service.dart';
import 'package:clush/screens/setting_sub_pages.dart';
import 'package:clush/screens/edit_profile_page.dart';

import 'package:clush/theme/colors.dart';
import 'package:clush/widgets/heart_loader.dart';
import 'package:clush/services/language_service.dart';
import 'package:clush/l10n/app_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
          .from('profiles').select().eq('id', userId).maybeSingle();
      if (data == null) throw Exception('Profile not found');
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
      title: Text(AppLocalizations.of(context)?.leavingSoSoon ?? "Leaving so soon?", textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(fontSize: 22, color: kInk)),
      content: Text(AppLocalizations.of(context)?.deleteRetentionMessage ?? "Delete your account?\n\nStay and get 1 WEEK OF PREMIUM FREE!", textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(color: kInkMuted, height: 1.5)),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.all(16),
      actionsAlignment: MainAxisAlignment.center,
      actions: [Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _solidBtn(AppLocalizations.of(context)?.claimPremium ?? "Claim 1 Week Premium", () { Navigator.pop(ctx); _claimPremium(); }),
        const SizedBox(height: 10),
        _outlineBtn(AppLocalizations.of(context)?.putOnHold ?? "Put Account on Hold", () { Navigator.pop(ctx); _navTo(const PauseAccountPage()); }),
        TextButton(onPressed: () { Navigator.pop(ctx); _confirmFinalDeletion(); },
            child: Text(AppLocalizations.of(context)?.deleteAnyway ?? "Delete Anyway", style: GoogleFonts.montserrat(color: Colors.red.shade400))),
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)?.cancel ?? "Cancel", style: GoogleFonts.montserrat(color: kInkMuted))),
      ])],
    ));
  }

  void _confirmFinalDeletion() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: kCream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: kBone)),
      title: Text(AppLocalizations.of(context)?.areYouSure ?? "Are you sure?", style: GoogleFonts.montserrat(fontSize: 22, color: kInk)),
      content: Text(AppLocalizations.of(context)?.deleteWarning ?? "This is permanent. All data, matches and messages will be lost.",
          style: GoogleFonts.montserrat(color: kInkMuted, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)?.cancel ?? "Cancel", style: GoogleFonts.montserrat(color: kInkMuted))),
        TextButton(onPressed: () async { Navigator.pop(ctx); await _deleteAccount(); },
            child: Text(AppLocalizations.of(context)?.yesDelete ?? "Yes, Delete", style: GoogleFonts.montserrat(color: Colors.red.shade400, fontWeight: FontWeight.w600))),
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
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
    _loadSettings();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast('Could not open link', err: true);
    }
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
                  _sectionLabel(AppLocalizations.of(context)?.account ?? "Account")
                      .animate().fade(duration: 400.ms, delay: 100.ms).slideX(begin: 0.1, end: 0),
                  _card([
                    _tile(icon: Icons.edit_outlined, title: AppLocalizations.of(context)?.editProfile ?? "Edit Profile",
                        trailing: _isLoadingProfile
                            ? SizedBox(width: 18, height: 18,
                                child: const HeartLoader(size: 20))
                            : null,
                        onTap: _isLoadingProfile ? null : _handleEditProfile),
                    _divider(),
                    _tile(icon: Icons.phone_outlined, title: AppLocalizations.of(context)?.phoneNumber ?? "Phone Number",
                        subtitle: (_userPhone?.isNotEmpty == true) ? _userPhone : (AppLocalizations.of(context)?.notProvided ?? "Not provided"),
                        onTap: () => _navTo(const PhoneNumberPage())),
                    _divider(),
                    _tile(icon: Icons.email_outlined, title: AppLocalizations.of(context)?.emailAddress ?? "Email Address",
                        subtitle: (_userEmail?.isNotEmpty == true) ? _userEmail : (AppLocalizations.of(context)?.notProvided ?? "Not provided"),
                        onTap: () => _navTo(const EmailAddressPage())),
                    _divider(),
                    _tile(icon: Icons.pause_circle_outline, title: AppLocalizations.of(context)?.pauseAccount ?? "Pause Account",
                        onTap: () => _navTo(const PauseAccountPage())),
                  ]).animate().fade(duration: 500.ms, delay: 200.ms).slideY(begin: 0.05, end: 0),

                  _sectionLabel(AppLocalizations.of(context)?.discovery ?? "Discovery")
                      .animate().fade(duration: 400.ms, delay: 250.ms).slideX(begin: 0.1, end: 0),
                  _card([
                    _tile(icon: Icons.location_on_outlined, title: AppLocalizations.of(context)?.location ?? "Location",
                        subtitle: _userLocation != null ? _formatLocation(_userLocation) : (AppLocalizations.of(context)?.notSet ?? "Not set"),
                        onTap: () => _navTo(const CurrentLocationPage())),
                  ]).animate().fade(duration: 500.ms, delay: 350.ms).slideY(begin: 0.05, end: 0),

                  _sectionLabel(AppLocalizations.of(context)?.privacyAndSafety ?? "Privacy & Safety")
                      .animate().fade(duration: 400.ms, delay: 400.ms).slideX(begin: 0.1, end: 0),
                  _card([
                    _tile(icon: Icons.access_time_rounded, title: AppLocalizations.of(context)?.activityStatus ?? "Activity Status",
                        trailing: Switch.adaptive(value: activityStatus, activeColor: kRose,
                            onChanged: (v) => setState(() => activityStatus = v))),
                    _divider(),
                    _tile(icon: Icons.verified_user_outlined, title: AppLocalizations.of(context)?.verification ?? "Verification",
                        subtitle: AppLocalizations.of(context)?.getVerifiedBadge ?? "Get that verified badge",
                        onTap: () => _navTo(const VerificationPage())),
                    _divider(),
                    _tile(icon: Icons.block_outlined, title: AppLocalizations.of(context)?.blockedUsers ?? "Blocked Users",
                        onTap: () => _navTo(const BlockListPage())),
                  ]).animate().fade(duration: 500.ms, delay: 500.ms).slideY(begin: 0.05, end: 0),

                  _sectionLabel(AppLocalizations.of(context)?.notifications ?? "Notifications")
                      .animate().fade(duration: 400.ms, delay: 550.ms).slideX(begin: 0.1, end: 0),
                  _card([
                    _tile(icon: Icons.notifications_none_rounded, title: AppLocalizations.of(context)?.pushNotifications ?? "Push Notifications",
                        trailing: Switch.adaptive(value: notificationsEnabled, activeColor: kRose,
                            onChanged: _toggleNotifications)),
                    _divider(),
                    _tile(icon: Icons.mail_outline_rounded, title: AppLocalizations.of(context)?.emailUpdates ?? "Email Updates",
                        trailing: Switch.adaptive(value: emailUpdates, activeColor: kRose,
                            onChanged: (v) => setState(() => emailUpdates = v))),
                  ]).animate().fade(duration: 500.ms, delay: 650.ms).slideY(begin: 0.05, end: 0),

                  _sectionLabel(AppLocalizations.of(context)?.appSettings ?? "App Settings")
                      .animate().fade(duration: 400.ms, delay: 700.ms).slideX(begin: 0.1, end: 0),
                  _card([
                    _tile(
                      icon: Icons.language_rounded, 
                      title: AppLocalizations.of(context)?.language ?? "Language",
                      subtitle: _getLanguageName(LanguageService().localeNotifier.value.languageCode),
                      onTap: _showLanguageSelector,
                    ),
                  ]).animate().fade(duration: 500.ms, delay: 800.ms).slideY(begin: 0.05, end: 0),

                  _sectionLabel("Subscriptions")
                      .animate().fade(duration: 400.ms, delay: 850.ms).slideX(begin: 0.1, end: 0),
                  _card([
                    _tile(icon: Icons.star_rounded, title: "Subscriptions",
                        subtitle: "Upgrade to Gold or Platinum",
                        onTap: () => _navTo(const SubscriptionsPage())),
                  ]).animate().fade(duration: 500.ms, delay: 950.ms).slideY(begin: 0.05, end: 0),

                  _sectionLabel("Privacy & Data")
                      .animate().fade(duration: 400.ms, delay: 1000.ms).slideX(begin: 0.1, end: 0),
                  _card([
                    _tile(icon: Icons.download_outlined, title: "Download My Data",
                        subtitle: "Export a copy of your data",
                        onTap: () => _navTo(const DownloadMyDataPage())),
                  ]).animate().fade(duration: 500.ms, delay: 1100.ms).slideY(begin: 0.05, end: 0),

                  _sectionLabel(AppLocalizations.of(context)?.legal ?? "Legal")
                      .animate().fade(duration: 400.ms, delay: 1150.ms).slideX(begin: 0.1, end: 0),
                  _card([
                    _tile(icon: Icons.privacy_tip_outlined, title: AppLocalizations.of(context)?.privacyPolicy ?? "Privacy Policy",
                        isExternal: true, onTap: () => _launchUrl('https://clush-web.vercel.app/legal/privacy')),
                    _divider(),
                    _tile(icon: Icons.gavel_rounded, title: AppLocalizations.of(context)?.termsOfService ?? "Terms of Service",
                        isExternal: true, onTap: () => _launchUrl('https://clush-web.vercel.app/legal/terms')),
                    _divider(),
                    _tile(icon: Icons.people_outline_rounded, title: AppLocalizations.of(context)?.communityGuidelines ?? "Community Guidelines",
                        isExternal: true, onTap: () => _launchUrl('https://clush-web.vercel.app/legal/community')),
                    _divider(),
                    _tile(icon: Icons.favorite_border_rounded, title: AppLocalizations.of(context)?.safeDating ?? "Safe Dating",
                        isExternal: true, onTap: () => _launchUrl('https://clush-web.vercel.app/legal/safe-dating')),
                  ]).animate().fade(duration: 500.ms, delay: 1250.ms).slideY(begin: 0.05, end: 0),

                  const SizedBox(height: 48),
                  _buildLogoutButton().animate().fade(duration: 500.ms, delay: 1350.ms),
                  const SizedBox(height: 12),
                  Center(child: TextButton(
                    onPressed: _showRetentionDialog,
                    child: Text("Delete Account", style: GoogleFonts.montserrat(
                        color: kInkMuted, fontSize: 14,
                        decoration: TextDecoration.underline, decorationColor: kInkMuted)),
                  )).animate().fade(duration: 500.ms, delay: 1450.ms),
                  const SizedBox(height: 20),
                  Center(child: Text("Version 1.0.0 (Build 24)",
                      style: GoogleFonts.montserrat(color: kBone, fontSize: 12))).animate().fade(duration: 500.ms, delay: 1550.ms),
                  const SizedBox(height: 60),
                ]),
              ),
            ),
          ],
        ),
        Positioned(top: 0, left: 0, right: 0, child: _buildHeader().animate().fade(duration: 400.ms).slideY(begin: -0.2, end: 0)),
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
          padding: const EdgeInsets.fromLTRB(16, 52, 24, 12),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: kParchment,
                      shape: BoxShape.circle,
                      border: Border.all(color: kBone, width: 1),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 18, color: kInk),
                  ),
                ),
                const SizedBox(width: 12),
                Text("Settings", style: GoogleFonts.montserrat(
                    color: kInk, fontSize: 30, fontWeight: FontWeight.w400, letterSpacing: -0.5)),
              ],
            ),
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
      String? subtitle, Widget? trailing, VoidCallback? onTap, bool isExternal = false}) {
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
            else if (isExternal) Icon(Icons.open_in_new_rounded, color: kBone, size: 18)
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

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: kCream,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)?.selectLanguage ?? "Select Language",
              style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: kInk),
            ),
            const SizedBox(height: 20),
            _languageTile("en", "English", "English"),
            _divider(),
            _languageTile("hi", "Hindi", "हिंदी"),
            _divider(),
            _languageTile("mr", "Marathi", "मराठी"),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _languageTile(String code, String name, String nativeName) {
    bool isSelected = LanguageService().localeNotifier.value.languageCode == code;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      title: Text(name, style: GoogleFonts.montserrat(
          fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: kInk)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: kRose) : null,
      onTap: () {
        LanguageService().changeLanguage(code);
        Navigator.pop(context);
        setState(() {}); // Refresh settings page
      },
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'en': return 'English';
      case 'hi': return 'हिंदी (Hindi)';
      case 'mr': return 'मराठी (Marathi)';
      default: return code;
    }
  }

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
