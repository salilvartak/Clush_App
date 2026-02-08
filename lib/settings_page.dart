import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main.dart'; 
import 'setting_sub_pages.dart'; 

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

  void _navTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTan,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(), // iOS style bounce
        slivers: [
          // 1. PREMIUM HEADER (Large Title)
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
                      icon: Icons.phone_outlined,
                      title: "Phone Number",
                      subtitle: "Verified", // Example of status text
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
                      trailing: _buildPremiumBadge("Premium"), // Badge example
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

                  // --- LOGOUT BUTTON ---
                  _buildLogoutButton(),
                  
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
        borderRadius: BorderRadius.circular(20), // Softer corners
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
        borderRadius: BorderRadius.circular(20), // Matches container
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // 1. Soft Icon Container
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kRose.withOpacity(0.1), // Soft pastel background
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: kRose, size: 20),
              ),
              const SizedBox(width: 16),
              
              // 2. Text Content
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

              // 3. Trailing (Chevron or Switch)
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
      indent: 60, // Indent to align with text, skipping icon
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
          // Add a confirmation dialog for extra premium feel
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