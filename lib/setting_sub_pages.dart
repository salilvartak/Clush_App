import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme/colors.dart';
import 'heart_loader.dart';

// ─── PALETTE (mapped to theme/colors.dart) ───────────────────────────────────
const Color _kRose      = kRose;
const Color _kRosePale  = kRosePale;
const Color _kCream     = kCream;
const Color _kParchment = kTan; 
const Color _kBone      = kBone;
const Color _kInk       = kInk;
const Color _kInkMuted  = kInkMuted;
const Color _kGold      = kGold;

// ─── Helpers ─────────────────────────────────────────────────────────────────

BoxDecoration _cardDecor() => BoxDecoration(
  color: _kParchment,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: _kBone, width: 1),
  boxShadow: [BoxShadow(color: _kInk.withOpacity(0.09), blurRadius: 28, offset: const Offset(0, 8))],
);

InputDecoration _inputDecor(String hint, {IconData? icon}) => InputDecoration(
  hintText: hint,
  hintStyle: GoogleFonts.dmSans(color: _kInkMuted, fontSize: 14),
  filled: true,
  fillColor: _kParchment,
  prefixIcon: icon != null ? Icon(icon, color: _kRose, size: 20) : null,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _kBone)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _kBone)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _kRose, width: 1.5)),
);

Widget _saveButton(String label, bool isLoading, VoidCallback? onTap) {
  return GestureDetector(
    onTap: isLoading ? null : onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isLoading ? _kRose.withOpacity(0.5) : _kRose,
        borderRadius: BorderRadius.circular(14),
      ),
      child: isLoading
          ? const SizedBox(width: 20, height: 20,
              child: const HeartLoader(size: 22, color: Colors.white))
          : Text(label, style: GoogleFonts.dmSans(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
    ),
  );
}

// ─── BASE TEMPLATE ────────────────────────────────────────────────────────────
class BaseSettingsPage extends StatelessWidget {
  final String title;
  final Widget body;
  const BaseSettingsPage({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCream,
      body: Stack(children: [
        SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 110, 20, 40),
            child: body,
          ),
        ),
        // Frosted header
        Positioned(
          top: 0, left: 0, right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: _kCream.withOpacity(0.88),
                  border: Border(bottom: BorderSide(color: _kBone, width: 0.5)),
                ),
                padding: const EdgeInsets.fromLTRB(4, 44, 16, 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _kInk),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 2),
                  Expanded(child: Text(title, style: GoogleFonts.domine(
                      color: _kInk, fontSize: 24, fontWeight: FontWeight.w400, letterSpacing: -0.3))),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── PHONE NUMBER ─────────────────────────────────────────────────────────────
class PhoneNumberPage extends StatefulWidget {
  const PhoneNumberPage({super.key});
  @override
  State<PhoneNumberPage> createState() => _PhoneNumberPageState();
}

class _PhoneNumberPageState extends State<PhoneNumberPage> {
  final _ctrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() { super.initState(); _fetchPhoneNumber(); }

  Future<void> _fetchPhoneNumber() async {
    final user = FirebaseAuth.instance.currentUser;
    String? phone = user?.phoneNumber;
    if (user != null && (phone == null || phone.isEmpty)) {
      try {
        final data = await Supabase.instance.client
            .from('profiles').select('phone').eq('id', user.uid).maybeSingle();
        phone = data?['phone'];
      } catch (_) {}
    }
    if (mounted && phone != null) setState(() => _ctrl.text = phone!);
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await Supabase.instance.client.from('profiles').update({'phone': _ctrl.text}).eq('id', userId);
        if (mounted) { Navigator.pop(context); }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) => BaseSettingsPage(
    title: "Phone Number",
    body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Update your phone number",
          style: GoogleFonts.domine(fontSize: 20, fontWeight: FontWeight.w400, color: _kInk)),
      const SizedBox(height: 6),
      Text("Your number is kept private and only used for security.",
          style: GoogleFonts.dmSans(fontSize: 13, color: _kInkMuted, height: 1.4)),
      const SizedBox(height: 24),
      TextField(controller: _ctrl, keyboardType: TextInputType.phone,
          style: GoogleFonts.dmSans(color: _kInk, fontSize: 15),
          decoration: _inputDecor("Phone number", icon: Icons.phone_outlined)),
      const SizedBox(height: 20),
      _saveButton("Save Number", _isLoading, _save),
    ]),
  );
}

// ─── EMAIL ADDRESS ────────────────────────────────────────────────────────────
class EmailAddressPage extends StatefulWidget {
  const EmailAddressPage({super.key});
  @override
  State<EmailAddressPage> createState() => _EmailAddressPageState();
}

class _EmailAddressPageState extends State<EmailAddressPage> {
  final _ctrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ctrl.text = FirebaseAuth.instance.currentUser?.email ?? '';
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _ctrl.text.isNotEmpty) {
        await user.verifyBeforeUpdateEmail(_ctrl.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Verification email sent! Check your inbox.")));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) => BaseSettingsPage(
    title: "Email Address",
    body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Update your email",
          style: GoogleFonts.domine(fontSize: 20, fontWeight: FontWeight.w400, color: _kInk)),
      const SizedBox(height: 6),
      Text("A verification link will be sent to your new address.",
          style: GoogleFonts.dmSans(fontSize: 13, color: _kInkMuted, height: 1.4)),
      const SizedBox(height: 24),
      TextField(controller: _ctrl, keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.dmSans(color: _kInk, fontSize: 15),
          decoration: _inputDecor("Email address", icon: Icons.email_outlined)),
      const SizedBox(height: 20),
      _saveButton("Save Email", _isLoading, _save),
    ]),
  );
}

// ─── PAUSE ACCOUNT ────────────────────────────────────────────────────────────
class PauseAccountPage extends StatefulWidget {
  const PauseAccountPage({super.key});
  @override
  State<PauseAccountPage> createState() => _PauseAccountPageState();
}

class _PauseAccountPageState extends State<PauseAccountPage> {
  bool isPaused = false, isLoading = true;

  @override
  void initState() { super.initState(); _fetchPauseStatus(); }

  Future<void> _fetchPauseStatus() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('profiles').select('is_paused').eq('id', userId).single();
      if (mounted) setState(() { isPaused = data['is_paused'] ?? false; isLoading = false; });
    } catch (_) { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> _toggle(bool val) async {
    setState(() => isPaused = val);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      await Supabase.instance.client.from('profiles')
          .update({'is_paused': val}).eq('id', userId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(val ? "Account is now on hold." : "Account is active again!")));
    } catch (_) {
      setState(() => isPaused = !val);
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Failed to update status.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Pause Account",
      body: isLoading
          ? const Center(child: HeartLoader(size: 40))
          : Container(
              padding: const EdgeInsets.all(28),
              decoration: _cardDecor(),
              child: Column(children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: isPaused ? Colors.red.shade50 : _kRosePale,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPaused ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                    size: 40, color: isPaused ? Colors.red.shade400 : _kRose,
                  ),
                ),
                const SizedBox(height: 20),
                Text(isPaused ? "Account Paused" : "Account is Active",
                    style: GoogleFonts.domine(fontSize: 24, fontWeight: FontWeight.w400, color: _kInk)),
                const SizedBox(height: 10),
                Text(
                  "Pausing hides you from Discover, but you can still chat with existing matches.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(color: _kInkMuted, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 32),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("Pause my account",
                      style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500, color: _kInk)),
                  Switch.adaptive(value: isPaused, activeColor: _kRose, onChanged: _toggle),
                ]),
              ]),
            ),
    );
  }
}

// ─── LOCATION ─────────────────────────────────────────────────────────────────
class CurrentLocationPage extends StatefulWidget {
  const CurrentLocationPage({super.key});
  @override
  State<CurrentLocationPage> createState() => _CurrentLocationPageState();
}

class _CurrentLocationPageState extends State<CurrentLocationPage> {
  final _ctrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _mapController = MapController();
  LatLng _currentMapCenter = const LatLng(40.7128, -74.0060); // Default NY
  bool _isLoading = true, _isSaving = false, _isMapLoading = false;

  @override
  void initState() { super.initState(); _fetchLocation(); }

  Future<void> _fetchLocation() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('profiles').select('location').eq('id', userId).maybeSingle();
      if (mounted && data != null) {
        final locStr = data['location'] ?? '';
        setState(() => _ctrl.text = locStr);
        // If it contains coordinates, move map there
        if (locStr.contains('(') && locStr.contains(',')) {
          try {
            final coords = locStr.split('(')[1].split(')')[0].split(',');
            final lat = double.parse(coords[0]);
            final lng = double.parse(coords[1]);
            _currentMapCenter = LatLng(lat, lng);
            _mapController.move(_currentMapCenter, 13.0);
          } catch (_) {}
        }
      }
    } catch (_) {} finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      setState(() => _currentMapCenter = LatLng(position.latitude, position.longitude));
      _mapController.move(_currentMapCenter, 13.0);
    } catch (e) {
      debugPrint("Location Error: $e");
    }
  }

  Future<void> _confirmMapLocation() async {
    setState(() => _isMapLoading = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(_currentMapCenter.latitude, _currentMapCenter.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String area = place.subLocality ?? place.thoroughfare ?? "";
        String city = place.locality ?? place.subAdministrativeArea ?? "";
        String state = place.administrativeArea ?? "";
        
        List<String> displayParts = [];
        if (area.isNotEmpty) displayParts.add(area);
        if (city.isNotEmpty && city != area) displayParts.add(city);
        if (displayParts.isEmpty && state.isNotEmpty) displayParts.add(state);
        
        String displayString = displayParts.join(", ");
        if (displayString.isEmpty) displayString = "Selected Location";
        
        String exactLocation = "$displayString, $state(${_currentMapCenter.latitude},${_currentMapCenter.longitude})";
        setState(() {
          _ctrl.text = exactLocation;
          _isMapLoading = false;
        });
        FocusManager.instance.primaryFocus?.unfocus();
      } else {
        setState(() => _isMapLoading = false);
      }
    } catch (e) {
      setState(() => _isMapLoading = false);
    }
  }

  Future<void> _searchMapLocation(String query) async {
    if (query.trim().isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        setState(() => _currentMapCenter = LatLng(loc.latitude, loc.longitude));
        _mapController.move(_currentMapCenter, 13.0);
      }
    } catch (_) {}
  }

  String _getDisplayLocation(String loc) {
    if (loc.contains("(")) return loc.split("(")[0].trim();
    return loc;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await Supabase.instance.client.from('profiles')
            .update({'location': _ctrl.text}).eq('id', userId);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  Widget build(BuildContext context) => BaseSettingsPage(
    title: "Location",
    body: _isLoading
        ? const Center(child: HeartLoader(size: 40))
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Search Bar
            TextField(
              controller: _searchCtrl,
              style: GoogleFonts.dmSans(color: _kInk, fontSize: 15),
              onSubmitted: _searchMapLocation,
              decoration: _inputDecor("Search a city...", icon: Icons.search).copyWith(
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: _kRose, size: 20),
                  onPressed: () => _searchMapLocation(_searchCtrl.text),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Map
            Container(
              height: 240, width: double.infinity,
              decoration: BoxDecoration(
                color: _kParchment, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBone)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Stack(alignment: Alignment.center, children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentMapCenter,
                      initialZoom: 13.0,
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture && position.center != null) {
                          _currentMapCenter = position.center!;
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.clush',
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                            onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.only(bottom: 30),
                    child: Icon(Icons.location_on_rounded, color: _kRose, size: 40)),
                  Positioned(bottom: 12, right: 12, child: FloatingActionButton(
                    mini: true, backgroundColor: _kCream, elevation: 2,
                    onPressed: _fetchCurrentLocation,
                    child: const Icon(Icons.my_location, color: _kInk, size: 18),
                  )),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kRose, width: 1),
                  backgroundColor: _kCream,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isMapLoading ? null : _confirmMapLocation,
                child: _isMapLoading 
                  ? const HeartLoader(size: 18)
                  : Text("Confirm Pin Location", style: GoogleFonts.dmSans(color: _kRose, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
            Text("Your Location", style: GoogleFonts.domine(fontSize: 20, color: _kInk)),
            const SizedBox(height: 6),
            Text("This helps us show you people nearby. Tap map or type above.",
                style: GoogleFonts.dmSans(fontSize: 13, color: _kInkMuted)),
            const SizedBox(height: 20),
            TextField(controller: _ctrl, readOnly: true,
                style: GoogleFonts.dmSans(color: _kInk, fontSize: 15),
                decoration: _inputDecor("Confirm location above", icon: Icons.location_on_outlined)),
            const SizedBox(height: 20),
            _saveButton("Save Location", _isSaving, _save),
          ]),
  );
}

// ─── TRAVEL MODE ──────────────────────────────────────────────────────────────
class TravelModePage extends StatelessWidget {
  const TravelModePage({super.key});
  @override
  Widget build(BuildContext context) => BaseSettingsPage(
    title: "Travel Mode",
    body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity, padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _kParchment, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBone),
        ),
        child: Column(children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: _kRosePale, shape: BoxShape.circle),
            child: const Icon(Icons.flight_takeoff_rounded, color: _kRose, size: 28),
          ),
          const SizedBox(height: 20),
          Text("Going somewhere?", style: GoogleFonts.domine(
              fontSize: 24, fontWeight: FontWeight.w400, color: _kInk)),
          const SizedBox(height: 10),
          Text("Change your location to swipe in other cities before you arrive.",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 14, color: _kInkMuted, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 24),
      _saveButton("Add a New Spot", false, () {}),
    ]),
  );
}

// ─── VERIFICATION ─────────────────────────────────────────────────────────────
class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});
  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  String? _profileImageUrl;
  File? _videoFile;
  bool _isLoading = false, _isFetchingProfile = true, _isVerified = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() { super.initState(); _checkVerificationStatus(); }

  Future<void> _checkVerificationStatus() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('profiles').select('photo_urls, is_verified').eq('id', userId).single();
      final List photos = data['photo_urls'] ?? [];
      setState(() {
        _isVerified = data['is_verified'] ?? false;
        if (photos.isNotEmpty) _profileImageUrl = photos[0];
        _isFetchingProfile = false;
      });
    } catch (_) { setState(() => _isFetchingProfile = false); }
  }

  Future<void> _recordVideo() async {
    final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxDuration: const Duration(seconds: 5));
    if (video != null) setState(() => _videoFile = File(video.path));
  }

  Future<void> _submitVerification() async {
    if (_profileImageUrl == null || _videoFile == null) return;
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final imageResponse = await http.get(Uri.parse(_profileImageUrl!));
      if (imageResponse.statusCode != 200) throw Exception("Failed to download profile photo");
      var request = http.MultipartRequest('POST',
          Uri.parse('https://nina-unpumped-linus.ngrok-free.dev/verify'));
      request.fields['user_id'] = userId;
      request.files.add(http.MultipartFile.fromBytes('profile', imageResponse.bodyBytes, filename: 'profile.jpg'));
      request.files.add(await http.MultipartFile.fromPath('video', _videoFile!.path));
      var res = await request.send();
      final data = jsonDecode(await res.stream.bytesToString());
      bool isMatch = data['match'] == true;
      double score = (data['score'] is num) ? (data['score'] as num).toDouble() : 0.0;
      if (isMatch) {
        await Supabase.instance.client.from('profiles').update({'is_verified': true}).eq('id', userId);
        setState(() => _isVerified = true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Verified! You now have a verified badge.")));
      } else {
        if (mounted) _showFailDialog(score);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  void _showFailDialog(double score) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _kCream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _kBone)),
      title: Text("Verification Failed", style: GoogleFonts.domine(fontSize: 22, color: _kInk)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("Your video did not match your profile picture.",
            style: GoogleFonts.dmSans(color: _kInkMuted, height: 1.4)),
        const SizedBox(height: 10),
        Text("Match Score: ${score.toStringAsFixed(2)}",
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: _kInk)),
        const SizedBox(height: 10),
        Text("Try again with a clearer face photo or better lighting.",
            style: GoogleFonts.dmSans(fontSize: 12, color: _kInkMuted)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text("Try Again", style: GoogleFonts.dmSans(color: _kRose, fontWeight: FontWeight.w600)))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingProfile) {
      return BaseSettingsPage(title: "Verification",
          body: const Center(child: HeartLoader(size: 40)));
    }
    if (_isVerified) {
      return BaseSettingsPage(
        title: "Verification",
        body: Container(
          padding: const EdgeInsets.all(28),
          decoration: _cardDecor(),
          child: Column(children: [
            const SizedBox(height: 20),
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(color: Color(0xFFE8F4FF), shape: BoxShape.circle),
              child: const Icon(Icons.verified_rounded, color: Colors.blue, size: 40),
            ),
            const SizedBox(height: 20),
            Text("You're Verified!", style: GoogleFonts.domine(fontSize: 26, color: _kInk)),
            const SizedBox(height: 10),
            Text("Your verified badge is now visible on your profile.",
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(color: _kInkMuted, fontSize: 14, height: 1.5)),
          ]),
        ),
      );
    }

    return BaseSettingsPage(
      title: "Verification",
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Get the Verified Badge", style: GoogleFonts.domine(fontSize: 22, color: _kInk)),
        const SizedBox(height: 6),
        Text("Complete these two steps to verify your identity.",
            style: GoogleFonts.dmSans(color: _kInkMuted, fontSize: 13, height: 1.4)),
        const SizedBox(height: 24),

        // Step 1
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecor(),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _kBone,
              backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
              child: _profileImageUrl == null
                  ? const Icon(Icons.person_outline_rounded, color: _kInkMuted) : null,
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Step 1", style: GoogleFonts.dmSans(fontSize: 11, color: _kInkMuted, letterSpacing: 1)),
              Text("Profile Photo", style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: _kInk)),
            ])),
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: _kRosePale, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: _kRose, size: 16),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // Step 2
        GestureDetector(
          onTap: _recordVideo,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kParchment,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _videoFile != null ? _kRose : _kBone, width: _videoFile != null ? 1.5 : 1),
            ),
            child: Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: _videoFile != null ? _kRosePale : _kCream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBone),
                ),
                child: Icon(_videoFile != null ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    color: _videoFile != null ? _kRose : _kInkMuted, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Step 2", style: GoogleFonts.dmSans(fontSize: 11, color: _kInkMuted, letterSpacing: 1)),
                Text(_videoFile == null ? "Record short video (5s)" : "Video Recorded ✓",
                    style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600,
                        color: _videoFile != null ? _kRose : _kInk)),
              ])),
              Icon(Icons.chevron_right_rounded, color: _kBone, size: 20),
            ]),
          ),
        ),
        const SizedBox(height: 32),
        _saveButton("Verify Me", _isLoading,
            (_isLoading || _profileImageUrl == null || _videoFile == null) ? null : _submitVerification),
      ]),
    );
  }
}

// ─── BLOCK LIST ───────────────────────────────────────────────────────────────
class BlockListPage extends StatefulWidget {
  const BlockListPage({super.key});
  @override
  State<BlockListPage> createState() => _BlockListPageState();
}

class _BlockListPageState extends State<BlockListPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _blockedUsers = [];

  @override
  void initState() { super.initState(); _fetchBlockedUsers(); }

  Future<void> _fetchBlockedUsers() async {
    try {
      final myId = FirebaseAuth.instance.currentUser?.uid;
      if (myId == null) return;
      final response = await Supabase.instance.client
          .from('blocks')
          .select('blocked_id, profiles!blocks_blocked_id_fkey(full_name, photo_urls)')
          .eq('blocker_id', myId);
      final List<Map<String, dynamic>> loaded = [];
      for (var row in (response as List)) {
        final profile = row['profiles'];
        if (profile != null) {
          loaded.add({
            'blocked_id': row['blocked_id'],
            'full_name': profile['full_name'] ?? 'Unknown',
            'photo_url': (profile['photo_urls'] as List?)?.isNotEmpty == true
                ? profile['photo_urls'][0] : null,
          });
        }
      }
      if (mounted) setState(() { _blockedUsers = loaded; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _unblockUser(String blockedId, String name) async {
    bool? confirm = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _kBone)),
        title: Text('Unblock $name?', style: GoogleFonts.domine(fontSize: 22, color: _kInk)),
        content: Text('You will be able to see each other in Discover again.',
            style: GoogleFonts.dmSans(color: _kInkMuted, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.dmSans(color: _kInkMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('Unblock', style: GoogleFonts.dmSans(color: _kRose, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final myId = FirebaseAuth.instance.currentUser?.uid;
      if (myId == null) return;
      await Supabase.instance.client.from('blocks')
          .delete().match({'blocker_id': myId, 'blocked_id': blockedId});
      if (mounted) {
        setState(() => _blockedUsers.removeWhere((u) => u['blocked_id'] == blockedId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name unblocked', style: GoogleFonts.dmSans(color: Colors.white)),
          backgroundColor: _kRose, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unblock'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return BaseSettingsPage(title: "Blocked Users",
          body: const Center(child: HeartLoader(size: 40)));
    }
    if (_blockedUsers.isEmpty) {
      return BaseSettingsPage(
        title: "Blocked Users",
        body: Column(children: [
          const SizedBox(height: 60),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: _kParchment, shape: BoxShape.circle, border: Border.all(color: _kBone)),
            child: Icon(Icons.block_rounded, color: _kBone, size: 32),
          ),
          const SizedBox(height: 20),
          Text("No blocked users", style: GoogleFonts.domine(fontSize: 22, color: _kInk)),
          const SizedBox(height: 8),
          Text("Users you block will appear here.",
              style: GoogleFonts.dmSans(color: _kInkMuted, fontSize: 13), textAlign: TextAlign.center),
        ]),
      );
    }

    return BaseSettingsPage(
      title: "Blocked Users",
      body: Container(
        decoration: _cardDecor(),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _blockedUsers.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: _kBone, indent: 72),
          itemBuilder: (context, index) {
            final user = _blockedUsers[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                CircleAvatar(
                  radius: 24, backgroundColor: _kBone,
                  backgroundImage: user['photo_url'] != null ? NetworkImage(user['photo_url']) : null,
                  child: user['photo_url'] == null
                      ? const Icon(Icons.person_outline_rounded, color: _kInkMuted) : null,
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(user['full_name'],
                    style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500, color: _kInk))),
                GestureDetector(
                  onTap: () => _unblockUser(user['blocked_id'], user['full_name']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kRose, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text("Unblock", style: GoogleFonts.dmSans(
                        color: _kRose, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

// ─── LEGAL PAGE ───────────────────────────────────────────────────────────────
class LegalPage extends StatelessWidget {
  final String title, content;
  const LegalPage({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) => BaseSettingsPage(
    title: title,
    body: Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecor(),
      child: Text(content, style: GoogleFonts.dmSans(
          fontSize: 15, color: _kInkMuted, height: 1.7)),
    ),
  );
}

// ─── REMAINING STUBS ─────────────────────────────────────────────────────────
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool newMatches = true, messages = true, promotions = false;

  Widget _switchTile(String label, bool val, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Expanded(child: Text(label, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500, color: _kInk))),
        Switch.adaptive(value: val, activeColor: _kRose, onChanged: onChanged),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => BaseSettingsPage(
    title: "Notifications",
    body: Container(
      decoration: _cardDecor(),
      child: Column(children: [
        _switchTile("New Matches", newMatches, (v) => setState(() => newMatches = v)),
        Divider(height: 1, color: _kBone, indent: 16, endIndent: 16),
        _switchTile("Messages", messages, (v) => setState(() => messages = v)),
        Divider(height: 1, color: _kBone, indent: 16, endIndent: 16),
        _switchTile("Promotions", promotions, (v) => setState(() => promotions = v)),
      ]),
    ),
  );
}

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});
  @override
  Widget build(BuildContext context) => BaseSettingsPage(
    title: "Subscription",
    body: Container(
      width: double.infinity, padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_kRose, _kGold], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        Text("Clush Gold", style: GoogleFonts.domine(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w400)),
        const SizedBox(height: 10),
        Text("You are on the Free plan.", style: GoogleFonts.dmSans(color: Colors.white70)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Text("Upgrade Now", style: GoogleFonts.dmSans(
                color: _kRose, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ]),
    ),
  );
}

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});
  @override
  Widget build(BuildContext context) {
    final langs = ["English", "Hindi", "Spanish", "French"];
    return BaseSettingsPage(
      title: "Language",
      body: Container(
        decoration: _cardDecor(),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: langs.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: _kBone, indent: 16, endIndent: 16),
          itemBuilder: (ctx, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Expanded(child: Text(langs[i], style: GoogleFonts.dmSans(
                  fontSize: 15, fontWeight: FontWeight.w400, color: _kInk))),
              if (i == 0) Icon(Icons.check_rounded, color: _kRose, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}