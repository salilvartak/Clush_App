import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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
// (Preserved as requested)
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

// ================= PRIVACY & VERIFICATION =================

class VerificationPage extends StatelessWidget {
  const VerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Identity Verification",
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: Icon(Icons.verified_user_rounded, size: 80, color: Color(0xFFCD9D8F))),
          const SizedBox(height: 20),
          const Center(child: Text("Get the Blue Tick", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          Text("To ensure our community stays safe, we use video verification to confirm you are the person in your photos.", textAlign: TextAlign.center, style: TextStyle(color: Colors.black.withOpacity(0.6), height: 1.4)),
          const SizedBox(height: 32),
          const Text("How it works:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          _buildRule(Icons.face_retouching_natural, "Keep your face within the oval frame."),
          _buildRule(Icons.light_mode_outlined, "Ensure you are in a well-lit room."),
          _buildRule(Icons.videocam_outlined, "Follow the on-screen prompts (e.g., turn your head)."),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VideoCapturePage())),
            child: const Text("I'm Ready", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRule(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFCD9D8F).withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFFCD9D8F), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}

class VideoCapturePage extends StatefulWidget {
  const VideoCapturePage({super.key});

  @override
  State<VideoCapturePage> createState() => _VideoCapturePageState();
}

class _VideoCapturePageState extends State<VideoCapturePage> {
  CameraController? _controller;
  bool isProcessing = false;
  bool isRecording = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    // Select front camera if available
    final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
    
    _controller = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    setState(() => isRecording = true);
    await _controller!.startVideoRecording();
    
    // Auto-stop after 3 seconds for verification
    await Future.delayed(const Duration(seconds: 3));
    
    if (isRecording) {
      final XFile video = await _controller!.stopVideoRecording();
      _processVideo(video);
    }
  }

  void _processVideo(XFile video) async {
    setState(() {
      isRecording = false;
      isProcessing = true;
    });
    
    // Simulate authentication/upload logic
    await Future.delayed(const Duration(seconds: 4));
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verification video submitted!")));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Feed
          if (_controller != null && _controller!.value.isInitialized)
            Positioned.fill(child: CameraPreview(_controller!))
          else
            const Center(child: CircularProgressIndicator(color: Color(0xFFCD9D8F))),

          // 2. Oval Frame Guide
          Center(
            child: Container(
              width: 280,
              height: 400,
              decoration: BoxDecoration(
                border: Border.all(color: isRecording ? Colors.red : Colors.white, width: 4),
                borderRadius: const BorderRadius.all(Radius.elliptical(140, 200)),
              ),
            ),
          ),

          // 3. UI Controls
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      const Spacer(),
                      const Text("Identity Verification", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                const Spacer(),
                if (!isProcessing) ...[
                  Text(isRecording ? "Recording... turn your head slowly" : "Position your face in the oval", style: const TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: isRecording ? null : _startRecording,
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(color: isRecording ? Colors.grey : Colors.red, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ]
              ],
            ),
          ),

          // 4. Processing Animation Overlay
          if (isProcessing)
            Container(
              color: Colors.black.withOpacity(0.85),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 80, height: 80, child: CircularProgressIndicator(strokeWidth: 6, color: Color(0xFFCD9D8F))),
                    SizedBox(height: 32),
                    Text("Sending for Authentication...", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text("Verifying your unique features", style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ================= REMAINING PAGES =================
// (Preserved as requested)
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