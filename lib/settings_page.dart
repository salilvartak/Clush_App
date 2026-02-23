import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // REQUIRED: To fetch data
import 'main.dart'; 
import 'setting_sub_pages.dart'; 
import 'edit_profile_page.dart'; // REQUIRED: To navigate to editor

const Color kRose = Color(0xFFCD9D8F);
const Color kTan = Color(0xFFE9E6E1);

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
  bool _isLoadingProfile = false; // To show loading state

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

  // Fetch data before opening Edit Page
  Future<void> _handleEditProfile() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoadingProfile = true);

    try {
      // 1. Fetch the profile data from Supabase
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      if (!mounted) return;

      // 2. Navigate to EditProfilePage with the required data
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

  // --- RETENTION & DELETION LOGIC ---
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
      // Update the user's profile in Supabase to grant premium
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
        // 1. Delete from Supabase
        await Supabase.instance.client.from('profiles').delete().eq('id', user.uid);
        
        // 2. Delete from Firebase Auth
        await user.delete();
      }
      
      if (mounted) {
        // Navigate back to the very first screen (login/splash)
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

  void _navTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTan,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. PREMIUM HEADER
          const SliverAppBar(
            backgroundColor: kTan,
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                "Settings",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 28),
              ),
            ),
          ),

          // 2. SETTINGS CONTENT
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
                      subtitle: "Verified",
                      onTap: () => _navTo(const PhoneNumberPage()),
                    ),
                    _buildDivider(),
                    _buildPremiumTile(
                      icon: Icons.email_outlined,
                      title: "Email Address",
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
                      subtitle: "San Francisco, CA",
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
                      onTap: () => _navTo(const NotificationsPage()),
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
                      child: const Text(
                        "Delete Account",
                        style: TextStyle(
                          color: Colors.grey, 
                          fontSize: 14, 
                          decoration: TextDecoration.underline
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // --- VERSION INFO ---
                  const Center(
                    child: Text(
                      "Version 1.0.0 (Build 24)",
                      style: TextStyle(color: Colors.black38, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 40),
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
      padding: const EdgeInsets.only(left: 12, bottom: 10, top: 24),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14, 
          fontWeight: FontWeight.bold, 
          color: Colors.black.withOpacity(0.5),
          letterSpacing: 0.5
        ),
      ),
    );
  }

  Widget _buildSectionContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kRose.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: kRose, size: 20),
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.w600, 
                        color: Colors.black87
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13, 
                          color: Colors.black.withOpacity(0.4),
                          fontWeight: FontWeight.w500
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
      indent: 60,
    );
  }

  Widget _buildPremiumBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kRose, Color(0xFFFFC3A0)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
              title: const Text("Log Out?"),
              content: const Text("Are you sure you want to log out?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _logout();
                  }, 
                  child: const Text("Log Out", style: TextStyle(color: Colors.red))
                ),
              ],
            )
          );
        },
        child: const Text(
          "Log Out",
          style: TextStyle(
            color: Colors.redAccent, 
            fontSize: 16, 
            fontWeight: FontWeight.w600
          ),
        ),
      ),
    );
  }
}