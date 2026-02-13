import 'dart:io';
import 'dart:convert'; // REQUIRED: For jsonDecode
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
                const Text("+1 (555) 123-4567", style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text("Update your phone number. We will send a verification code to the new number.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCD9D8F), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCD9D8F), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
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
            Icon(isPaused ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 64, color: isPaused ? Colors.red : const Color(0xFFCD9D8F)),
            const SizedBox(height: 20),
            Text(isPaused ? "Your account is paused" : "Your account is active", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text("Pausing your account means you won't be shown to new people, but you can still chat with existing matches.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
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
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
            child: const Center(child: Icon(Icons.map, size: 50, color: Colors.grey)),
          ),
          const SizedBox(height: 20),
          const ListTile(tileColor: Colors.white, leading: Icon(Icons.my_location, color: Color(0xFFCD9D8F)), title: Text("My Current Location"), subtitle: Text("San Francisco, CA")),
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
          const Text("Going somewhere?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Change your location to swipe in other cities before you arrive.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
             style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCD9D8F), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
            onPressed: () {},
            icon: const Icon(Icons.flight),
            label: const Text("Add a new spot"),
          ),
        ],
      ),
    );
  }
}

// ================= PRIVACY & VERIFICATION (UPDATED) =================

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  // Logic Variables
  File? _profileImage;
  File? _videoFile;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // 1. Pick Image Logic
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      setState(() => _profileImage = File(image.path));
    }
  }

  // 2. Record Video Logic
  Future<void> _recordVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front, // Force selfie camera
      maxDuration: const Duration(seconds: 5),   // Limit to 5 seconds
    );
    if (video != null) {
      setState(() => _videoFile = File(video.path));
    }
  }

  // 3. API Call Logic (Updated with JSON Parsing)
  Future<void> _submitVerification() async {
    if (_profileImage == null || _videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select both image and video.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
      print("🚀 Starting Verification for user: $userId");

      // 1. Prepare Request
      // NOTE: Using your Render URL
      var uri = Uri.parse('https://nina-unpumped-linus.ngrok-free.dev/verify'); 
      var request = http.MultipartRequest('POST', uri);

      // 2. Add Fields
      request.fields['user_id'] = userId;

      // 3. Add Files
      // IMPORTANT: Keys must match your Python code ('profile' & 'video')
      request.files.add(await http.MultipartFile.fromPath('profile', _profileImage!.path));
      request.files.add(await http.MultipartFile.fromPath('video', _videoFile!.path));

      // 4. Send and Wait
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print("📡 Server Status: ${response.statusCode}");
      print("📩 Server Response: ${response.body}");

      if (response.statusCode == 200) {
        // 5. PARSE THE RESULT
        var data = jsonDecode(response.body);
        
        // Handle potential nulls or type issues safely
        bool isMatch = data['match'] ?? false;
        double score = (data['score'] is num) ? (data['score'] as num).toDouble() : 0.0;

        if (isMatch) {
          if (mounted) {
            print("✅ VERIFICATION SUCCESSFUL! (Score: $score)");
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text("✅ Verification Successful! Score: ${score.toStringAsFixed(2)}")),
            );
            Navigator.pop(context); // Go back to settings
          }
        } else {
          if (mounted) {
            print("❌ VERIFICATION FAILED. Score: $score");
            _showErrorDialog("Verification Failed", "Faces do not match. Match Score: ${score.toStringAsFixed(2)}");
          }
        }
      } else {
        print("⚠️ Server Error: ${response.body}");
        if (mounted) {
           _showErrorDialog("Server Error", "Code: ${response.statusCode}\n${response.body}");
        }
      }
    } catch (e) {
      print("🔥 Connection Error: $e");
      if (mounted) {
        _showErrorDialog("Connection Error", e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Identity Verification",
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header
          const Icon(Icons.verified_user_rounded, size: 80, color: Color(0xFFCD9D8F)),
          const SizedBox(height: 20),
          const Text("Get the Blue Tick", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            "Upload a clear selfie and record a 5-second video turning your head to verify your identity.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black.withOpacity(0.6), height: 1.4),
          ),
          const SizedBox(height: 32),

          // --- STEP 1: UPLOAD PHOTO ---
          _buildStepCard(
            title: "Step 1: Upload Selfie",
            subtitle: _profileImage == null ? "Tap to select photo" : "Photo Selected",
            icon: Icons.photo_camera,
            isDone: _profileImage != null,
            onTap: _pickImage,
          ),

          const SizedBox(height: 16),

          // --- STEP 2: RECORD VIDEO ---
          _buildStepCard(
            title: "Step 2: Record Video",
            subtitle: _videoFile == null ? "Tap to record (5s)" : "Video Recorded",
            icon: Icons.videocam,
            isDone: _videoFile != null,
            onTap: _recordVideo,
          ),

          const SizedBox(height: 40),

          // --- VERIFY BUTTON ---
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: (_isLoading || _profileImage == null || _videoFile == null) 
                ? null 
                : _submitVerification,
            child: _isLoading 
                ? const CircularProgressIndicator(color: Color(0xFFCD9D8F))
                : const Text("Verify Me", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDone,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isDone ? Border.all(color: const Color(0xFFCD9D8F), width: 2) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDone ? const Color(0xFFCD9D8F) : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(isDone ? Icons.check : icon, color: isDone ? Colors.white : Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: isDone ? const Color(0xFFCD9D8F) : Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= REMAINING PAGES =================

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
                SwitchListTile(title: const Text("New Matches"), value: newMatches, activeColor: const Color(0xFFCD9D8F), onChanged: (v) => setState(() => newMatches = v)),
                const Divider(height: 1),
                SwitchListTile(title: const Text("Messages"), value: messages, activeColor: const Color(0xFFCD9D8F), onChanged: (v) => setState(() => messages = v)),
                const Divider(height: 1),
                SwitchListTile(title: const Text("Promotions"), value: promotions, activeColor: const Color(0xFFCD9D8F), onChanged: (v) => setState(() => promotions = v)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});
  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Subscription",
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFCD9D8F), Color(0xFFE9E6E1)]), borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            const Text("Clush Gold", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("You are currently on the Free plan.", style: TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black), onPressed: () {}, child: const Text("Upgrade Now"))
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

class LegalPage extends StatelessWidget {
  final String title;
  final String content;
  const LegalPage({super.key, required this.title, required this.content});
  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(title: title, body: Text(content, style: const TextStyle(fontSize: 16, height: 1.5)));
  }
}