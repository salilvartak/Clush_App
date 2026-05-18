import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:clush/theme/colors.dart';
import 'package:clush/widgets/heart_loader.dart';
import 'package:clush/l10n/app_localizations.dart';
import 'package:clush/services/language_service.dart';
import 'package:clush/screens/setting_sub_pages.dart';
import 'package:clush/screens/edit_profile_page.dart';
import 'package:clush/main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _userPhone;
  String? _userEmail;
  Map<String, dynamic>? _userLocation;
  Map<String, dynamic>? _fullProfileData;
  bool _isLoadingProfile = true;

  bool activityStatus = true;
  bool notificationsEnabled = true;
  bool emailUpdates = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', user.uid)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _fullProfileData = data;
          _userPhone = data['phone'];
          _userEmail = data['email'];
          _userLocation = data['location'];
          _isLoadingProfile = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  void _navTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page))
        .then((_) => _loadUserProfile());
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const LanguageSelectorSheet(),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'en': return 'English';
      case 'es': return 'Español';
      case 'hi': return 'हिन्दी';
      default: return 'English';
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.logOut ?? "Logout"),
        content: Text(AppLocalizations.of(context)?.logOutConfirm ?? "Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context)?.cancel ?? "Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(AppLocalizations.of(context)?.logOut ?? "Logout", style: const TextStyle(color: kDestructive))),
        ],
      ),
    );

    if (confirmed == true) {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuraApp()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => notificationsEnabled = value);
    // Logic to update on server would go here
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
                  _sectionLabel(AppLocalizations.of(context)?.account ?? "Account"),
                  _card([
                    _tile(icon: Icons.edit_outlined, title: AppLocalizations.of(context)?.editProfile ?? "Edit Profile",
                        trailing: _isLoadingProfile
                            ? const SizedBox(width: 18, height: 18, child: HeartLoader(size: 20))
                            : null,
                        onTap: _isLoadingProfile ? null : () {
                          if (_fullProfileData != null) {
                            _navTo(EditProfilePage(currentData: _fullProfileData!));
                          }
                        }),
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
                  ]),

                  _sectionLabel(AppLocalizations.of(context)?.discovery ?? "Discovery"),
                  _card([
                    _tile(icon: Icons.location_on_outlined, title: AppLocalizations.of(context)?.location ?? "Location",
                        subtitle: _userLocation != null ? _formatLocation(_userLocation) : (AppLocalizations.of(context)?.notSet ?? "Not set"),
                        onTap: () => _navTo(const CurrentLocationPage())),
                  ]),

                  _sectionLabel(AppLocalizations.of(context)?.privacyAndSafety ?? "Privacy & Safety"),
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
                  ]),

                  _sectionLabel(AppLocalizations.of(context)?.notifications ?? "Notifications"),
                  _card([
                    _tile(icon: Icons.notifications_none_rounded, title: AppLocalizations.of(context)?.pushNotifications ?? "Push Notifications",
                        trailing: Switch.adaptive(value: notificationsEnabled, activeColor: kRose,
                            onChanged: _toggleNotifications)),
                    _divider(),
                    _tile(icon: Icons.mail_outline_rounded, title: AppLocalizations.of(context)?.emailUpdates ?? "Email Updates",
                        trailing: Switch.adaptive(value: emailUpdates, activeColor: kRose,
                            onChanged: (v) => setState(() => emailUpdates = v))),
                  ]),

                  _sectionLabel(AppLocalizations.of(context)?.appSettings ?? "App Settings"),
                  _card([
                    _tile(
                      icon: Icons.language_rounded, 
                      title: AppLocalizations.of(context)?.language ?? "Language",
                      subtitle: _getLanguageName(LanguageService().localeNotifier.value.languageCode),
                      onTap: _showLanguageSelector,
                    ),
                  ]),

                  _sectionLabel("Subscriptions"),
                  _card([
                    _tile(icon: Icons.star_rounded, title: "Subscriptions",
                        subtitle: "Upgrade to Gold or Platinum",
                        onTap: () => _navTo(const SubscriptionsPage())),
                  ]),

                  _sectionLabel("Privacy & Data"),
                  _card([
                    _tile(icon: Icons.download_outlined, title: "Download My Data",
                        subtitle: "Export a copy of your data",
                        onTap: () => _navTo(const DownloadMyDataPage())),
                  ]),

                  _sectionLabel(AppLocalizations.of(context)?.legal ?? "Legal"),
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
                  ]),

                  const SizedBox(height: 48),
                  _buildLogoutButton(),
                  const SizedBox(height: 12),
                  Center(child: TextButton(
                    onPressed: () {}, // Delete account logic
                    child: Text("Delete Account", style: GoogleFonts.figtree(color: kBlack, fontSize: 13)),
                  )),
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
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 15, left: 20, right: 20),
      decoration: BoxDecoration(
        color: kCream.withOpacity(0.9),
        border: const Border(bottom: BorderSide(color: kBone)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kRose, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(AppLocalizations.of(context)?.settings ?? "Settings",
              style: GoogleFonts.gabarito(fontSize: 24, fontWeight: FontWeight.bold, color: kRose)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 12, left: 4),
      child: Text(label.toUpperCase(),
          style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.bold, color: kRose, letterSpacing: 1.2)),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderLight),
      ),
      child: Column(children: children),
    );
  }

  Widget _tile({required IconData icon, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap, bool isExternal = false}) {
    return ListTile(
      leading: Icon(icon, color: kRose, size: 22),
      title: Text(title, style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w500, color: kRose)),
      subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.figtree(fontSize: 13, color: kBlack)) : null,
      trailing: trailing ?? (isExternal ? const Icon(Icons.open_in_new_rounded, size: 16, color: kRose) : const Icon(Icons.chevron_right_rounded, color: kRose)),
      onTap: onTap,
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 56, color: kBorderLight);

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleLogout,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(AppLocalizations.of(context)?.logOut ?? "Logout",
                style: GoogleFonts.figtree(color: kDestructive, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  String _formatLocation(Map<String, dynamic>? loc) {
    if (loc == null) return "";
    final city = loc['city'];
    final state = loc['state'];
    if (city != null && state != null) return "$city, $state";
    return loc['address'] ?? "";
  }

  void _handleEditProfile() {
    // This is already handled by _navTo(const EditProfilePage()) in the build method
  }
}

class LanguageSelectorSheet extends StatelessWidget {
  const LanguageSelectorSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = LanguageService();
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context)?.selectLanguage ?? "Select Language",
              style: GoogleFonts.gabarito(fontSize: 20, fontWeight: FontWeight.bold, color: kRose)),
          const SizedBox(height: 24),
          _langTile(context, 'English', 'en', languageService),
          _langTile(context, 'Español', 'es', languageService),
          _langTile(context, 'हिन्दी', 'hi', languageService),
        ],
      ),
    );
  }

  Widget _langTile(BuildContext context, String name, String code, LanguageService service) {
    final isSelected = service.localeNotifier.value.languageCode == code;
    return ListTile(
      title: Text(name, style: GoogleFonts.figtree(fontSize: 16, color: kRose, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: kRose) : null,
      onTap: () {
        service.changeLanguage(code);
        Navigator.pop(context);
      },
    );
  }
}
