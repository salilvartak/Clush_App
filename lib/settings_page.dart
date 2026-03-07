import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart'; // Typography
import 'services/notification_service.dart';

import 'main.dart'; 
import 'setting_sub_pages.dart'; 
import 'edit_profile_page.dart'; 

const Color kRose = Color(0xFFCD9D8F);
const Color kBlack = Color(0xFF2D2D2D);
const Color kTan = Color(0xFFF8F9FA);

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // State for toggles
  bool activityStatus = true;
  bool notificationsEnabled = true;
  bool emailUpdates = true;
  bool _isLoadingProfile = false; 

  // Dynamic user data
  String? _userEmail;
  String? _userPhone;
  String? _userLocation;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    
    String? fetchedLocation;
    String? fetchedPhone = user?.phoneNumber;

    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('location, phone')
            .eq('id', user.uid)
            .maybeSingle();
            
        fetchedLocation = data?['location'];
        // Fallback to Supabase phone if Firebase Auth doesn't have it
        if (fetchedPhone == null || fetchedPhone.isEmpty) {
          fetchedPhone = data?['phone'];
        }
      } catch (e) {
        print("Error fetching user data: $e");
      }
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
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error logging out: $e"))
        );
      }
    }
  }

  Future<void> _handleEditProfile() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoadingProfile = true);

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditProfilePage(currentData: data),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading profile: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  void _showRetentionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Leaving so soon?", textAlign: TextAlign.center),
        content: const Text(
            "Are you sure you want to delete your account?\n\n"
            "As a gift, stay with us and get 1 WEEK OF PREMIUM for FREE!",
            textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRose,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _claimPremium();
                },
                child: const Text("Claim 1 Week Premium", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kRose,
                  side: const BorderSide(color: kRose, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _navTo(const PauseAccountPage());
                },
                child: const Text("Put Account on Hold", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmFinalDeletion();
                },
                child: const Text("Delete Anyway", style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _claimPremium() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'is_premium': true, 
            'premium_expiry': DateTime.now().add(const Duration(days: 7)).toIso8601String()
          })
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("1 Week Premium Claimed! Enjoy your upgraded experience."),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error claiming premium: $e")));
    }
  }

  void _confirmFinalDeletion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Final Confirmation"),
        content: const Text("This action is permanent and cannot be undone. All your data, matches, and messages will be permanently lost. Are you absolutely sure?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Cancel")
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteAccount();
            }, 
            child: const Text("Yes, Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ]
      )
    );
  }

  Future<void> _deleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('profiles').delete().eq('id', user.uid);
        await user.delete();
      }
      
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting account: $e. You may need to log out and log back in to perform this action."))
        );
      }
    }
  }

  // Updated _navTo to reload settings upon returning
  Future<void> _navTo(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTan,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: kTan,
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            iconTheme: const IconThemeData(color: kBlack),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                "Settings",
                style: GoogleFonts.outfit(color: kBlack, fontWeight: FontWeight.w800, fontSize: 32, letterSpacing: -0.5),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- ACCOUNT ---
                  _buildSectionLabel("Account"),
                  _buildSectionContainer(children: [
                    _buildPremiumTile(
                      icon: Icons.edit_outlined,
                      title: "Edit Profile",
                      trailing: _isLoadingProfile 
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2, color: kRose)
                            ) 
                          : null,
                      onTap: _isLoadingProfile ? null : _handleEditProfile,
                    ),
                    _buildDivider(),
                    _buildPremiumTile(
                      icon: Icons.phone_outlined,
                      title: "Phone Number",
                      subtitle: (_userPhone != null && _userPhone!.isNotEmpty) ? _userPhone : "Not provided",
                      onTap: () => _navTo(const PhoneNumberPage()),
                    ),
                    _buildDivider(),
                    _buildPremiumTile(
                      icon: Icons.email_outlined,
                      title: "Email Address",
                      subtitle: (_userEmail != null && _userEmail!.isNotEmpty) ? _userEmail : "Not provided",
                      onTap: () => _navTo(const EmailAddressPage()),
                    ),
                    _buildDivider(),
                    _buildPremiumTile(
                      icon: Icons.pause_circle_outline,
                      title: "Pause Account",
                      onTap: () => _navTo(const PauseAccountPage()),
                    ),
                  ]),

                  // --- DISCOVERY ---
                  _buildSectionLabel("Discovery"),
                  _buildSectionContainer(children: [
                    _buildPremiumTile(
                      icon: Icons.location_on_outlined,
                      title: "Location",
                      subtitle: (_userLocation != null && _userLocation!.isNotEmpty) ? _userLocation : "Not set",
                      onTap: () => _navTo(const CurrentLocationPage()),
                    ),
                    _buildDivider(),
                    _buildPremiumTile(
                      icon: Icons.flight_takeoff,
                      title: "Travel Mode",
                      trailing: _buildPremiumBadge("Premium"),
                      onTap: () => _navTo(const TravelModePage()),
                    ),
                  ]),

                  // --- PRIVACY ---
                  _buildSectionLabel("Privacy & Safety"),
                  _buildSectionContainer(children: [
                    _buildPremiumTile(
                      icon: Icons.access_time,
                      title: "Activity Status",
                      trailing: Switch.adaptive(
                        value: activityStatus,
                        activeColor: kRose,
                        onChanged: (v) => setState(() => activityStatus = v),
                      ),
                    ),
                    _buildDivider(),
                    _buildPremiumTile(
                      icon: Icons.verified_user_outlined,
                      title: "Verification",
                      subtitle: "Get that blue tick",
                      onTap: () => _navTo(const VerificationPage()),
                    ),
                    _buildDivider(),
                    _buildPremiumTile(
                      icon: Icons.block_outlined,
                      title: "Blocked Contacts",
                      onTap: () => _navTo(const BlockListPage()),
                    ),
                  ]),

                  // --- NOTIFICATIONS ---
                  _buildSectionLabel("Notifications"),
                  _buildSectionContainer(children: [
                    _buildPremiumTile(
                      icon: Icons.notifications_none,
                      title: "Push Notifications",
                      trailing: Switch.adaptive(
                        value: notificationsEnabled,
                        activeColor: kRose,
                        onChanged: _toggleNotifications,
                      ),
                    ),
                    _buildDivider(),
                    _buildPremiumTile(
                      icon: Icons.mail_outline,
                      title: "Email Updates",
                      trailing: Switch.adaptive(
                        value: emailUpdates,
                        activeColor: kRose,
                        onChanged: (v) => setState(() => emailUpdates = v),
                      ),
                    ),
                  ]),

                  // --- COMMUNITY ---
                  _buildSectionLabel("Community"),
                  _buildSectionContainer(children: [
                    _buildPremiumTile(
                      icon: Icons.favorite_border,
                      title: "Safe Dating Tips",
                      onTap: () => _navTo(const LegalPage(title: "Safe Dating", content: "...")),
                    ),
                    _buildDivider(),
                    _buildPremiumTile(
                      icon: Icons.description_outlined,
                      title: "Legal & Licenses",
                      onTap: () => _navTo(const LegalPage(title: "Legal", content: "...")),
                    ),
                  ]),

                  const SizedBox(height: 40),

                  // --- LOGOUT & DELETE BUTTONS ---
                  _buildLogoutButton(),
                  
                  Center(
                    child: TextButton(
                      onPressed: _showRetentionDialog,
                      child: Text(
                        "Delete Account",
                        style: GoogleFonts.outfit(
                          color: Colors.grey, 
                          fontSize: 15, 
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // --- VERSION INFO ---
                  Center(
                    child: Text(
                      "Version 1.0.0 (Build 24)",
                      style: GoogleFonts.outfit(color: Colors.black38, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= PREMIUM WIDGETS =================

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 12, top: 32),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 13, 
          fontWeight: FontWeight.w800, 
          color: kRose,
          letterSpacing: 1.5
        ),
      ),
    );
  }

  Widget _buildSectionContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildPremiumTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kRose.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: kRose, size: 22),
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16, 
                        fontWeight: FontWeight.w600, 
                        color: kBlack
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          fontSize: 14, 
                          color: Colors.black54,
                          fontWeight: FontWeight.w400
                        ),
                      ),
                    ]
                  ],
                ),
              ),

              if (trailing != null) 
                trailing
              else 
                Icon(Icons.chevron_right_rounded, color: Colors.black.withOpacity(0.2), size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1, 
      thickness: 1, 
      color: Colors.grey.withOpacity(0.08), 
      indent: 64,
    );
  }

  Widget _buildPremiumBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kRose, Color(0xFFFFC3A0)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Center(
      child: TextButton(
        onPressed: () {
          showDialog(
            context: context, 
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text("Log Out?", style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              content: Text("Are you sure you want to log out?", style: GoogleFonts.outfit()),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: GoogleFonts.outfit(color: Colors.grey))),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _logout();
                  }, 
                  child: Text("Log Out", style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold))
                ),
              ],
            )
          );
        },
        child: Text(
          "Log Out",
          style: GoogleFonts.outfit(
            color: Colors.redAccent, 
            fontSize: 18, 
            fontWeight: FontWeight.w700
          ),
        ),
      ),
    );
  }
}