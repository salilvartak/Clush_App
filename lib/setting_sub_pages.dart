import 'package:flutter/material.dart';
import 'main.dart'; // Imports kTan & kRose

// --- GENERIC TEMPLATE FOR SUB-PAGES ---
class BaseSettingsPage extends StatelessWidget {
  final String title;
  final Widget body;

  const BaseSettingsPage({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E6E1), // kTan
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: body,
        ),
      ),
    );
  }
}

// ================= ACCOUNT PAGES =================

class PhoneNumberPage extends StatelessWidget {
  const PhoneNumberPage({super.key});
  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Phone Number",
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Current Phone Number", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.phone, color: Colors.grey),
                SizedBox(width: 12),
                Text("+1 (555) 123-4567", style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Update your phone number. We will send a verification code to the new number.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCD9D8F), // kRose
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () {},
            child: const Text("Update Number"),
          ),
        ],
      ),
    );
  }
}

class EmailAddressPage extends StatelessWidget {
  const EmailAddressPage({super.key});
  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Email Address",
      body: Column(
        children: [
           TextField(
            decoration: InputDecoration(
              labelText: "Email",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCD9D8F),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () {},
            child: const Text("Save Email"),
          ),
        ],
      ),
    );
  }
}

class PauseAccountPage extends StatefulWidget {
  const PauseAccountPage({super.key});
  @override
  State<PauseAccountPage> createState() => _PauseAccountPageState();
}

class _PauseAccountPageState extends State<PauseAccountPage> {
  bool isPaused = false;
  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Pause Account",
      body: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Icon(
              isPaused ? Icons.pause_circle_filled : Icons.play_circle_fill,
              size: 64,
              color: isPaused ? Colors.red : const Color(0xFFCD9D8F),
            ),
            const SizedBox(height: 20),
            Text(
              isPaused ? "Your account is paused" : "Your account is active",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Pausing your account means you won't be shown to new people, but you can still chat with existing matches.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            SwitchListTile(
              title: const Text("Pause my account"),
              value: isPaused,
              activeColor: const Color(0xFFCD9D8F),
              onChanged: (v) => setState(() => isPaused = v),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= LOCATION PAGES =================

class CurrentLocationPage extends StatelessWidget {
  const CurrentLocationPage({super.key});
  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Location",
      body: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(child: Icon(Icons.map, size: 50, color: Colors.grey)),
          ),
          const SizedBox(height: 20),
          const ListTile(
            tileColor: Colors.white,
            leading: Icon(Icons.my_location, color: Color(0xFFCD9D8F)),
            title: Text("My Current Location"),
            subtitle: Text("San Francisco, CA"),
          ),
        ],
      ),
    );
  }
}

class TravelModePage extends StatelessWidget {
  const TravelModePage({super.key});
  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Travel Mode",
      body: Column(
        children: [
          const Text(
            "Going somewhere?",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Change your location to swipe in other cities before you arrive.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
             style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCD9D8F),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () {},
            icon: const Icon(Icons.flight),
            label: const Text("Add a new spot"),
          ),
        ],
      ),
    );
  }
}

// ================= PRIVACY PAGES =================

class VerificationPage extends StatelessWidget {
  const VerificationPage({super.key});
  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Verification",
      body: Column(
        children: [
          const Icon(Icons.verified_user, size: 80, color: Color(0xFFCD9D8F)),
          const SizedBox(height: 20),
          const Text("Get Verified", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text(
            "Take a selfie to prove you're the person in your photos. Verified profiles get 30% more matches.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
             style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () {},
            child: const Text("Take Selfie"),
          ),
        ],
      ),
    );
  }
}

class BlockListPage extends StatelessWidget {
  const BlockListPage({super.key});
  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Blocked Users",
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 100),
            Icon(Icons.block, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            const Text("No blocked users yet", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            const Text("Select 'Block' from a user's profile to add them here.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ================= COMMUNICATION PAGES =================

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool newMatches = true;
  bool messages = true;
  bool promotions = false;

  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Notifications",
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("New Matches"),
                  value: newMatches,
                  activeColor: const Color(0xFFCD9D8F),
                  onChanged: (v) => setState(() => newMatches = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text("Messages"),
                  value: messages,
                  activeColor: const Color(0xFFCD9D8F),
                  onChanged: (v) => setState(() => messages = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text("Promotions"),
                  value: promotions,
                  activeColor: const Color(0xFFCD9D8F),
                  onChanged: (v) => setState(() => promotions = v),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ================= SUBSCRIPTION & APP =================

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});
  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Subscription",
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFCD9D8F), Color(0xFFE9E6E1)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Text("Clush Gold", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("You are currently on the Free plan.", style: TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              onPressed: () {},
              child: const Text("Upgrade Now"),
            )
          ],
        ),
      ),
    );
  }
}

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});
  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Language",
      body: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            const ListTile(title: Text("English"), trailing: Icon(Icons.check, color: Color(0xFFCD9D8F))),
            const Divider(height: 1),
            ListTile(title: const Text("Spanish"), onTap: () {}),
            const Divider(height: 1),
            ListTile(title: const Text("French"), onTap: () {}),
          ],
        ),
      ),
    );
  }
}

// ================= LEGAL PAGES =================

class LegalPage extends StatelessWidget {
  final String title;
  final String content;
  const LegalPage({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: title,
      body: Text(content, style: const TextStyle(fontSize: 16, height: 1.5)),
    );
  }
}