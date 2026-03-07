import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

class PhoneNumberPage extends StatefulWidget {
  const PhoneNumberPage({super.key});

  @override
  State<PhoneNumberPage> createState() => _PhoneNumberPageState();
}

class _PhoneNumberPageState extends State<PhoneNumberPage> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPhoneNumber();
  }

  Future<void> _fetchPhoneNumber() async {
    final user = FirebaseAuth.instance.currentUser;
    String? phone = user?.phoneNumber;

    // Fallback to supabase if Firebase Auth is empty
    if (user != null && (phone == null || phone.isEmpty)) {
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('phone')
            .eq('id', user.uid)
            .maybeSingle();
        phone = data?['phone'];
      } catch (e) {
        print("Error fetching phone from Supabase: $e");
      }
    }

    if (mounted && phone != null) {
      setState(() {
        _phoneController.text = phone!;
      });
    }
  }

  Future<void> _savePhoneNumber() async {
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        // Save preferred contact number in Supabase
        await Supabase.instance.client
            .from('profiles')
            .update({'phone': _phoneController.text})
            .eq('id', userId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Phone number saved!"))
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Phone Number",
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Update your phone number", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: "Phone Number",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCD9D8F), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
            onPressed: _isLoading ? null : _savePhoneNumber,
            child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Save Number"),
          ),
        ],
      ),
    );
  }
}

class EmailAddressPage extends StatefulWidget {
  const EmailAddressPage({super.key});

  @override
  State<EmailAddressPage> createState() => _EmailAddressPageState();
}

class _EmailAddressPageState extends State<EmailAddressPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill email from Firebase Auth
    _emailController.text = FirebaseAuth.instance.currentUser?.email ?? '';
  }

  Future<void> _saveEmail() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _emailController.text.isNotEmpty) {
        // Updates Firebase Authentication Email (Sends a verification link)
        await user.verifyBeforeUpdateEmail(_emailController.text);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Verification email sent! Check your inbox to confirm the change."))
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Email Address",
      body: Column(
        children: [
           TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
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
            onPressed: _isLoading ? null : _saveEmail,
            child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Save Email"),
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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPauseStatus();
  }

  Future<void> _fetchPauseStatus() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final data = await Supabase.instance.client
          .from('profiles')
          .select('is_paused')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          isPaused = data['is_paused'] ?? false;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _togglePauseStatus(bool status) async {
    setState(() => isPaused = status);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await Supabase.instance.client
          .from('profiles')
          .update({'is_paused': status})
          .eq('id', userId);
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status ? "Account is now on hold." : "Account is active again!"))
        );
      }
    } catch (e) {
      // Revert if API fails
      setState(() => isPaused = !status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update status.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Pause Account",
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                Icon(
                  isPaused ? Icons.pause_circle_filled : Icons.play_circle_fill, 
                  size: 64, 
                  color: isPaused ? Colors.red : const Color(0xFFCD9D8F)
                ),
                const SizedBox(height: 20),
                Text(
                  isPaused ? "Your account is paused" : "Your account is active", 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 12),
                const Text(
                  "Pausing your account means you won't be shown to new people, but you can still chat with existing matches.", 
                  textAlign: TextAlign.center, 
                  style: TextStyle(color: Colors.grey)
                ),
                const SizedBox(height: 30),
                SwitchListTile(
                  title: const Text("Pause my account", style: TextStyle(fontWeight: FontWeight.bold)),
                  value: isPaused,
                  activeColor: const Color(0xFFCD9D8F),
                  onChanged: _togglePauseStatus,
                ),
              ],
            ),
          ),
    );
  }
}

// ================= LOCATION PAGES =================

class CurrentLocationPage extends StatefulWidget {
  const CurrentLocationPage({super.key});

  @override
  State<CurrentLocationPage> createState() => _CurrentLocationPageState();
}

class _CurrentLocationPageState extends State<CurrentLocationPage> {
  final TextEditingController _locationController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final data = await Supabase.instance.client
          .from('profiles')
          .select('location')
          .eq('id', userId)
          .maybeSingle();

      if (mounted && data != null) {
        setState(() {
          _locationController.text = data['location'] ?? '';
        });
      }
    } catch (e) {
      print("Error fetching location: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLocation() async {
    setState(() => _isSaving = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'location': _locationController.text})
            .eq('id', userId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location updated successfully!"))
          );
          Navigator.pop(context); // Return to settings page
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving location: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Location",
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCD9D8F)))
          : Column(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
                  child: const Center(child: Icon(Icons.map, size: 50, color: Colors.grey)),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: "My Current Location",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.my_location, color: Color(0xFFCD9D8F)),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCD9D8F), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                  onPressed: _isSaving ? null : _saveLocation,
                  child: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Save Location"),
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
class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  // Logic Variables
  String? _profileImageUrl;
  File? _videoFile;
  bool _isLoading = false;
  bool _isFetchingProfile = true;
  bool _isVerified = false; // New state to track verification
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus(); 
  }

  Future<void> _checkVerificationStatus() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final data = await Supabase.instance.client
          .from('profiles')
          .select('photo_urls, is_verified')
          .eq('id', userId)
          .single();

      final List photos = data['photo_urls'] ?? [];
      final bool verified = data['is_verified'] ?? false;

      setState(() {
        _isVerified = verified; 
        if (photos.isNotEmpty) _profileImageUrl = photos[0];
        _isFetchingProfile = false;
      });
    } catch (e) {
      print("Error fetching profile: $e");
      setState(() => _isFetchingProfile = false);
    }
  }

  Future<void> _recordVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxDuration: const Duration(seconds: 5),
    );
    if (video != null) {
      setState(() => _videoFile = File(video.path));
    }
  }

  Future<void> _submitVerification() async {
    if (_profileImageUrl == null || _videoFile == null) return;

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
      
      final imageResponse = await http.get(Uri.parse(_profileImageUrl!));
      if (imageResponse.statusCode != 200) throw Exception("Failed to download profile photo");

      var uri = Uri.parse('https://nina-unpumped-linus.ngrok-free.dev/verify'); 
      var request = http.MultipartRequest('POST', uri);

      request.fields['user_id'] = userId;
      request.files.add(http.MultipartFile.fromBytes(
        'profile', 
        imageResponse.bodyBytes, 
        filename: 'profile_supa.jpg'
      ));
      request.files.add(await http.MultipartFile.fromPath('video', _videoFile!.path));

      var response = await request.send();
      final respStr = await response.stream.bytesToString();
      final data = jsonDecode(respStr); 

      print("📩 Server Response: $data");

      bool isMatch = data['match'] == true;
      double score = (data['score'] is num) ? (data['score'] as num).toDouble() : 0.0;

      if (isMatch) {
        await Supabase.instance.client
            .from('profiles')
            .update({'is_verified': true}) 
            .eq('id', userId);

        setState(() {
          _isVerified = true; 
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("✅ Verification Complete! You now have a blue tick.")),
          );
        }
      } else {
        if (mounted) {
          _showFailDialog(score); 
        }
      }

    } catch (e) {
      print("Error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFailDialog(double score) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Verification Failed ❌"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Your video did not match your profile picture."),
            const SizedBox(height: 10),
            Text("Match Score: ${score.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Please upload a clearer profile picture where your face is visible, or try recording again in better lighting.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Try Again"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerified) {
      return BaseSettingsPage(
        title: "Identity Verification",
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              const Icon(Icons.verified, size: 100, color: Colors.blue),
              const SizedBox(height: 20),
              const Text("You are Verified!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("You have the blue tick on your profile.", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return BaseSettingsPage(
      title: "Identity Verification",
      body: Column(
        children: [
          const Icon(Icons.verified_user_rounded, size: 80, color: Color(0xFFCD9D8F)),
          const SizedBox(height: 20),
          const Text("Get the Blue Tick", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
                  child: _profileImageUrl == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 16),
                const Expanded(child: Text("Step 1: Profile Photo (Using Main)", style: TextStyle(fontWeight: FontWeight.bold))),
                const Icon(Icons.check_circle, color: Color(0xFFCD9D8F)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          GestureDetector(
            onTap: _recordVideo,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(16),
                border: _videoFile != null ? Border.all(color: const Color(0xFFCD9D8F), width: 2) : null
              ),
              child: Row(
                children: [
                  Icon(_videoFile != null ? Icons.check : Icons.videocam, color: const Color(0xFFCD9D8F)),
                  const SizedBox(width: 16),
                  Text(_videoFile == null ? "Step 2: Record Video (5s)" : "Video Recorded", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black, 
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60)
            ),
            onPressed: (_isLoading || _profileImageUrl == null || _videoFile == null) ? null : _submitVerification,
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Verify Me"),
          ),
        ],
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