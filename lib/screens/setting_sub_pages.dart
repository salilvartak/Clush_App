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
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'package:clush/theme/colors.dart';
import 'package:clush/widgets/heart_loader.dart';
import 'package:clush/screens/permission_request_page.dart';

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
  hintStyle: GoogleFonts.montserrat(color: _kInkMuted, fontSize: 14),
  filled: true,
  fillColor: _kParchment,
  prefixIcon: icon != null ? Icon(icon, color: _kRose, size: 20) : null,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _kBone)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _kBone)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _kRose, width: 1.5)),
);

Widget _saveButton(String label, bool isLoading, VoidCallback? onTap) {
  final bool isDisabled = isLoading || onTap == null;
  return GestureDetector(
    onTap: isDisabled ? null : onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDisabled ? _kRose.withOpacity(0.4) : _kRose,
        borderRadius: BorderRadius.circular(14),
      ),
      child: isLoading
          ? const SizedBox(width: 20, height: 20,
              child: HeartLoader(size: 22, color: Colors.white))
          : Text(label, style: GoogleFonts.montserrat(
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
                  Expanded(child: Text(title, style: GoogleFonts.montserrat(
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
          style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w400, color: _kInk)),
      const SizedBox(height: 6),
      Text("Your number is kept private and only used for security.",
          style: GoogleFonts.montserrat(fontSize: 13, color: _kInkMuted, height: 1.4)),
      const SizedBox(height: 24),
      TextField(controller: _ctrl, keyboardType: TextInputType.phone,
          style: GoogleFonts.montserrat(color: _kInk, fontSize: 15),
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
          style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w400, color: _kInk)),
      const SizedBox(height: 6),
      Text("A verification link will be sent to your new address.",
          style: GoogleFonts.montserrat(fontSize: 13, color: _kInkMuted, height: 1.4)),
      const SizedBox(height: 24),
      TextField(controller: _ctrl, keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.montserrat(color: _kInk, fontSize: 15),
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
          .from('profiles').select('is_paused').eq('id', userId).maybeSingle();
      if (mounted) setState(() { isPaused = data?['is_paused'] ?? false; isLoading = false; });
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
          ? const Center(child: HeartLoader())
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
                    style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w400, color: _kInk)),
                const SizedBox(height: 10),
                Text(
                  "Pausing hides you from Discover, but you can still chat with existing matches.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(color: _kInkMuted, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 32),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("Pause my account",
                      style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: _kInk)),
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
        if (permission == LocationPermission.denied) {
          final bool? gateGranted = await PermissionRequestPage.show(context, PermissionType.location);
          if (gateGranted != true) return;
        }
        
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
        ? const Center(child: HeartLoader())
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Search Bar
            TextField(
              controller: _searchCtrl,
              style: GoogleFonts.montserrat(color: _kInk, fontSize: 15),
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
                        userAgentPackageName: 'com.clush.app',
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _isMapLoading ? null : _confirmMapLocation,
                child: _isMapLoading 
                  ? const HeartLoader(size: 18)
                  : Text("Confirm Pin Location", style: GoogleFonts.montserrat(color: _kRose, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
            Text("Your Location", style: GoogleFonts.montserrat(fontSize: 20, color: _kInk)),
            const SizedBox(height: 6),
            Text("This helps us show you people nearby. Tap map or type above.",
                style: GoogleFonts.montserrat(fontSize: 13, color: _kInkMuted)),
            const SizedBox(height: 20),
            TextField(controller: _ctrl, readOnly: true,
                style: GoogleFonts.montserrat(color: _kInk, fontSize: 15),
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
          Text("Going somewhere?", style: GoogleFonts.montserrat(
              fontSize: 24, fontWeight: FontWeight.w400, color: _kInk)),
          const SizedBox(height: 10),
          Text("Change your location to swipe in other cities before you arrive.",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 14, color: _kInkMuted, height: 1.5)),
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
  File? _videoFrame;
  bool _isLoading = false, _isFetchingProfile = true, _isVerified = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() { super.initState(); _checkVerificationStatus(); }

  Future<void> _checkVerificationStatus() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('profiles').select('photo_urls, is_verified').eq('id', userId).maybeSingle();
      final List photos = data?['photo_urls'] ?? [];
      setState(() {
        _isVerified = data?['is_verified'] ?? false;
        if (photos.isNotEmpty) _profileImageUrl = photos[0];
        _isFetchingProfile = false;
      });
    } catch (_) { setState(() => _isFetchingProfile = false); }
  }

  Future<void> _recordVideo() async {
    final ph.PermissionStatus currentStatus = await ph.Permission.camera.status;
    if (!currentStatus.isGranted) {
      final bool? gateGranted = await PermissionRequestPage.show(context, PermissionType.camera);
      if (gateGranted != true) return;
    }

    final List? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VerificationCameraPage()),
    );
    if (result != null) {
      setState(() {
        _videoFile = File((result[0] as XFile).path);
        _videoFrame = result[1] != null ? File((result[1] as XFile).path) : null;
      });
    }
  }

  void _showInstructionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          bool agreed = false;

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                backgroundColor: _kCream,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: _kBone)),
                titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                title: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _kRosePale, shape: BoxShape.circle),
                    child: const Icon(Icons.face_retouching_natural_rounded, color: _kRose, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text("Face Verification", style: GoogleFonts.montserrat(fontSize: 20, color: _kInk, fontWeight: FontWeight.bold))),
                ]),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text("How it works", style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: _kInk, letterSpacing: 0.3)),
                      const SizedBox(height: 12),
                      ...[
                        (Icons.wb_sunny_outlined,            "Find good lighting",      "Face a window or bright light so your face is clearly visible."),
                        (Icons.do_not_disturb_on_outlined,   "No accessories",          "Remove sunglasses, hats, or anything covering your face."),
                        (Icons.screen_rotation_outlined,     "Turn your head slowly",   "Start facing forward, then slowly turn your head left, then right, then back to centre."),
                        (Icons.timer_outlined,               "Takes about 5 seconds",   "Keep moving smoothly — a frame is captured automatically during the recording."),
                      ].map((step) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(color: _kRosePale, borderRadius: BorderRadius.circular(10)),
                            child: Icon(step.$1, color: _kRose, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(step.$2, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _kInk)),
                            Text(step.$3, style: GoogleFonts.montserrat(fontSize: 12, color: _kInkMuted, height: 1.4)),
                          ])),
                        ]),
                      )),
                      const SizedBox(height: 8),
                      Divider(color: _kBone, thickness: 1),
                      const SizedBox(height: 10),
                      // Legal disclaimer + checkbox
                      GestureDetector(
                        onTap: () => setDialogState(() => agreed = !agreed),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(
                            width: 20, height: 20,
                            child: Checkbox(
                              value: agreed,
                              onChanged: (v) => setDialogState(() => agreed = v ?? false),
                              activeColor: _kRose,
                              side: BorderSide(color: _kInkMuted),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.montserrat(fontSize: 12, color: _kInkMuted, height: 1.5),
                                children: [
                                  const TextSpan(text: "I consent to Clush processing my facial data solely for identity verification. This data is not stored or shared. By proceeding I agree to the "),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.baseline,
                                    baseline: TextBaseline.alphabetic,
                                    child: GestureDetector(
                                      onTap: () => launchUrl(Uri.parse('https://clush.app/privacy'), mode: LaunchMode.externalApplication),
                                      child: Text("Privacy Policy", style: GoogleFonts.montserrat(fontSize: 12, color: _kRose, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                                    ),
                                  ),
                                  const TextSpan(text: "."),
                                ],
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text("Cancel", style: GoogleFonts.montserrat(color: _kInkMuted, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: agreed ? () { Navigator.pop(ctx); _recordVideo(); } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kRose,
                            disabledBackgroundColor: _kRose.withValues(alpha: 0.35),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text("Start Recording", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]),
                  ),
                ],
                actionsPadding: EdgeInsets.zero,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _submitVerification() async {
    if (_profileImageUrl == null || _videoFile == null) return;
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final imageResponse = await http.get(Uri.parse(_profileImageUrl!));
      if (imageResponse.statusCode != 200) throw Exception("Failed to download profile photo");
      var request = http.MultipartRequest('POST',
          Uri.parse('https://nonterminable-ideologically-meagan.ngrok-free.dev/verify'));
      request.fields['user_id'] = userId;
      request.files.add(http.MultipartFile.fromBytes('profile_image', imageResponse.bodyBytes, filename: 'profile.jpg'));
      request.files.add(await http.MultipartFile.fromPath('video', _videoFile!.path));
      if (_videoFrame != null) {
        request.files.add(await http.MultipartFile.fromPath('video_frame', _videoFrame!.path, filename: 'frame.jpg'));
        debugPrint('📤 Sending video_frame: ${_videoFrame!.path}');
      }
      var res = await request.send();
      final body = await res.stream.bytesToString();
      debugPrint("📥 Verification response: $body");
      final data = jsonDecode(body);
      bool isMatch = data['match'] == true;
      double score = (data['score'] is num) ? (data['score'] as num).toDouble() : 0.0;
      debugPrint("🔍 Verification — match: $isMatch  |  confidence: ${score.toStringAsFixed(4)}");
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
      title: Text("Verification Failed", style: GoogleFonts.montserrat(fontSize: 22, color: _kInk)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("Your video did not match your profile picture.",
            style: GoogleFonts.montserrat(color: _kInkMuted, height: 1.4)),
        const SizedBox(height: 10),
        Text("Match Score: ${score.toStringAsFixed(2)}",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: _kInk)),
        const SizedBox(height: 10),
        Text("Try again with a clearer face photo or better lighting.",
            style: GoogleFonts.montserrat(fontSize: 12, color: _kInkMuted)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text("Try Again", style: GoogleFonts.montserrat(color: _kRose, fontWeight: FontWeight.w600)))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingProfile) {
      return BaseSettingsPage(title: "Verification",
          body: const Center(child: HeartLoader()));
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
            Text("You're Verified!", style: GoogleFonts.montserrat(fontSize: 26, color: _kInk)),
            const SizedBox(height: 10),
            Text("Your verified badge is now visible on your profile.",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(color: _kInkMuted, fontSize: 14, height: 1.5)),
          ]),
        ),
      );
    }

    return BaseSettingsPage(
      title: "Verification",
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Get the Verified Badge", style: GoogleFonts.montserrat(fontSize: 22, color: _kInk)),
        const SizedBox(height: 6),
        Text("Complete these two steps to verify your identity.",
            style: GoogleFonts.montserrat(color: _kInkMuted, fontSize: 13, height: 1.4)),
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
              Text("Step 1", style: GoogleFonts.montserrat(fontSize: 11, color: _kInkMuted, letterSpacing: 1)),
              Text("Profile Photo", style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600, color: _kInk)),
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showInstructionDialog,
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _videoFile != null ? _kRose.withOpacity(0.08) : _kParchment,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _videoFile != null ? _kRose : _kBone, width: _videoFile != null ? 1.5 : 1),
                boxShadow: _videoFile == null ? [
                  BoxShadow(color: _kInk.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                ] : null,
              ),
              child: Row(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _videoFile != null ? _kRosePale : _kCream,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kBone),
                  ),
                  child: Icon(_videoFile != null ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                      color: _videoFile != null ? _kRose : _kInkMuted, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Step 2", style: GoogleFonts.montserrat(fontSize: 11, color: _kInkMuted, letterSpacing: 1)),
                  Text(_videoFile == null ? "Record short video (5s)" : "Video Recorded ✓",
                      style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold,
                          color: _videoFile != null ? _kRose : _kInk)),
                ])),
                Icon(_videoFile != null ? Icons.check_circle_rounded : Icons.chevron_right_rounded, 
                     color: _videoFile != null ? _kRose : _kBone, size: 24),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _saveButton("Verify Me", _isLoading,
            (_isLoading || _profileImageUrl == null || _videoFile == null) ? null : _submitVerification),
      ]),
    );
  }
}

// ─── CUSTOM CAMERA PAGE ──────────────────────────────────────────────────────
class VerificationCameraPage extends StatefulWidget {
  const VerificationCameraPage({super.key});
  @override
  State<VerificationCameraPage> createState() => _VerificationCameraPageState();
}

class _VerificationCameraPageState extends State<VerificationCameraPage> {
  CameraController? _controller;
  bool _isRecording = false;
  int _secondsLeft = 5;
  XFile? _capturedFrame;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _controller = CameraController(front, ResolutionPreset.high, enableAudio: false);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.startVideoRecording();
    setState(() => _isRecording = true);

    // Capture a still frame 2s in (camera is fully warmed up by then)
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted || !_isRecording || _controller == null) return;
      try {
        _capturedFrame = await _controller!.takePicture();
        debugPrint('📸 Captured verification frame: ${_capturedFrame!.path}');
      } catch (e) {
        debugPrint('⚠️ Frame capture failed: $e');
      }
    });

    // Timer for visual feedback + auto-stop
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_isRecording) return false;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _stopRecording();
        return false;
      }
      return true;
    });
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_isRecording) return;
    final videoFile = await _controller!.stopVideoRecording();
    if (mounted) {
      setState(() => _isRecording = false);
      // Return [video, frame] — frame may be null if capture failed
      Navigator.pop(context, [videoFile, _capturedFrame]);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: HeartLoader(color: Colors.white, size: 40)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),
          // Gradient Overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0, 0.2, 0.8, 1],
                ),
              ),
            ),
          ),
          // UI
          Positioned(
            top: 60, left: 24,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: 70, left: 0, right: 0,
            child: Center(
              child: Text(
                "VERIFICATION",
                style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 2),
              ),
            ),
          ),
          Positioned(
            bottom: 80, left: 0, right: 0,
            child: Column(
              children: [
                if (_isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      "00:0$_secondsLeft",
                      style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Text(
                    "Center your face in the camera",
                    style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: _isRecording ? null : _startRecording,
                  child: Container(
                    height: 84, width: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: _isRecording 
                        ? null 
                        : const Icon(Icons.videocam_rounded, color: Colors.black, size: 32),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
  List<String> _blockedPhones = [];
  int _selectedTab = 0;
  final TextEditingController _phoneController = TextEditingController();

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
          
      final profileResp = await Supabase.instance.client
          .from('profiles')
          .select('blocked_phones')
          .eq('id', myId)
          .maybeSingle();

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
      
      final List<String> loadedPhones = [];
      if (profileResp != null && profileResp['blocked_phones'] != null) {
        loadedPhones.addAll(List<String>.from(profileResp['blocked_phones']));
      }

      if (mounted) setState(() { _blockedUsers = loaded; _blockedPhones = loadedPhones; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _unblockUser(String blockedId, String name) async {
    bool? confirm = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _kBone)),
        title: Text('Unblock $name?', style: GoogleFonts.montserrat(fontSize: 22, color: _kInk)),
        content: Text('You will be able to see each other in Discover again.',
            style: GoogleFonts.montserrat(color: _kInkMuted, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.montserrat(color: _kInkMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('Unblock', style: GoogleFonts.montserrat(color: _kRose, fontWeight: FontWeight.w600))),
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
          content: Text('$name unblocked', style: GoogleFonts.montserrat(color: Colors.white)),
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

  Future<void> _unblockPhone(String phone) async {
    bool? confirm = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _kBone)),
        title: Text('Unblock $phone?', style: GoogleFonts.montserrat(fontSize: 22, color: _kInk)),
        content: Text('This number will no longer be pre-blocked.',
            style: GoogleFonts.montserrat(color: _kInkMuted, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.montserrat(color: _kInkMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('Unblock', style: GoogleFonts.montserrat(color: _kRose, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final myId = FirebaseAuth.instance.currentUser?.uid;
      if (myId == null) return;
      _blockedPhones.remove(phone);
      await Supabase.instance.client
          .from('profiles')
          .update({'blocked_phones': _blockedPhones})
          .eq('id', myId);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$phone unblocked', style: GoogleFonts.montserrat(color: Colors.white)),
          backgroundColor: _kRose, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unblock phone'), backgroundColor: Colors.red));
    }
  }

  Future<void> _blockMultiplePhones(List<String> phonesInput) async {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    if (myId == null) return;
    
    setState(() => _isLoading = true);
    try {
      bool addedAny = false;
      for (final p in phonesInput) {
        final phone = p.trim();
        final formattedPhone = phone.replaceAll(RegExp(r'\s+'), '');
        final finalPhone = formattedPhone.startsWith('+') ? formattedPhone : '+91$formattedPhone';
        
        if (!_blockedPhones.contains(finalPhone)) {
           _blockedPhones.add(finalPhone);
           addedAny = true;
        }
      }
      
      if (addedAny) {
        await Supabase.instance.client
            .from('profiles')
            .update({'blocked_phones': _blockedPhones})
            .eq('id', myId);
        
        _phoneController.clear();
        await _fetchBlockedUsers();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${phonesInput.length} contacts blocked', style: GoogleFonts.montserrat(color: Colors.white)),
            backgroundColor: _kRose, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
          ));
        }
      }
    } catch (e) {
      debugPrint('Block multiple phones error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _blockByPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    final myId = FirebaseAuth.instance.currentUser?.uid;
    if (myId == null) return;

    setState(() => _isLoading = true);
    try {
      // Look up the profile with this phone number
      final result = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name')
          .eq('phone', phone)
          .maybeSingle();

      if (result == null) {
        final fallbackPhone = phone.startsWith('+') ? phone : '+91$phone';
        if (!_blockedPhones.contains(fallbackPhone)) {
          _blockedPhones.add(fallbackPhone);
          await Supabase.instance.client.from('profiles').update({'blocked_phones': _blockedPhones}).eq('id', myId);
        }
        
        _phoneController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text('Number $fallbackPhone pre-blocked', style: GoogleFonts.montserrat(color: Colors.white)),
             backgroundColor: _kRose, behavior: SnackBarBehavior.floating,
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
             margin: const EdgeInsets.all(16),
          ));
        }
        return;
      }

      final fallbackPhone = phone.startsWith('+') ? phone : '+91$phone';
      if (!_blockedPhones.contains(fallbackPhone)) {
        _blockedPhones.add(fallbackPhone);
        await Supabase.instance.client.from('profiles').update({'blocked_phones': _blockedPhones}).eq('id', myId);
      }

      final blockedId = result['id'] as String;
      if (blockedId == myId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("You can't block yourself", style: GoogleFonts.montserrat(color: Colors.white)),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }

      await Supabase.instance.client.from('blocks').upsert({
        'blocker_id': myId,
        'blocked_id': blockedId,
      }, onConflict: 'blocker_id,blocked_id');

      _phoneController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${result['full_name']} blocked', style: GoogleFonts.montserrat(color: Colors.white)),
          backgroundColor: _kRose, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      debugPrint('Block by phone error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e', style: GoogleFonts.montserrat(color: Colors.white)),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importContacts() async {
    final ph.PermissionStatus currentStatus = await ph.Permission.contacts.status;
    if (!currentStatus.isGranted) {
      final bool? gateGranted = await PermissionRequestPage.show(context, PermissionType.contacts);
      if (gateGranted != true) return;
    }

    final ph.PermissionStatus beforeStatus = await ph.Permission.contacts.status;
    debugPrint('📋 Contacts permission before request: $beforeStatus');
    ph.PermissionStatus status = await ph.Permission.contacts.request();
    debugPrint('📋 Contacts permission after request: $status');
    if (status.isPermanentlyDenied) {
      debugPrint('📋 Permanently denied — opening app settings');
      await ph.openAppSettings();
      status = await ph.Permission.contacts.status;
      debugPrint('📋 Contacts permission after settings: $status');
    }
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contacts permission denied ($status)', style: GoogleFonts.montserrat(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: HeartLoader()),
    );

    final List<fc.Contact> contacts = await fc.FlutterContacts.getAll(
      properties: {fc.ContactProperty.phone, fc.ContactProperty.name},
    );
    if (mounted) Navigator.pop(context);

    if (!mounted) return;
    final selectedPhones = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: _kCream,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => _buildContactsList(contacts, controller),
      ),
    );

    if (selectedPhones != null && selectedPhones.isNotEmpty) {
      await _blockMultiplePhones(selectedPhones);
    }
  }

  Widget _buildContactsList(List<fc.Contact> contacts, ScrollController controller) {
    if (contacts.isEmpty) {
      return Center(child: Text("No contacts found", style: GoogleFonts.montserrat(color: _kInkMuted)));
    }
    final Set<String> localSelected = {};
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Mass Select Contacts", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: _kInk)),
                  if (localSelected.isNotEmpty)
                    GestureDetector(
                      onTap: () => Navigator.pop(context, localSelected.toList()),
                      child: Text("Block (${localSelected.length})", 
                        style: GoogleFonts.montserrat(color: _kRose, fontWeight: FontWeight.bold, fontSize: 16)),
                    )
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final c = contacts[index];
                  final phone = c.phones.isNotEmpty ? c.phones.first.number : null;
                  final displayName = c.displayName ?? 'Unknown';
                  
                  if (phone == null) return const SizedBox.shrink();
                  final isSelected = localSelected.contains(phone);
                  return CheckboxListTile(
                    activeColor: _kRose,
                    value: isSelected,
                    onChanged: (val) {
                      setModalState(() {
                        if (val == true) localSelected.add(phone);
                        else localSelected.remove(phone);
                      });
                    },
                    secondary: CircleAvatar(
                      backgroundColor: _kBone,
                      child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', style: GoogleFonts.montserrat(color: _kInk)),
                    ),
                    title: Text(displayName, style: GoogleFonts.montserrat(color: _kInk, fontWeight: FontWeight.w500)),
                    subtitle: Text(phone, style: GoogleFonts.montserrat(color: _kInkMuted)),
                  );
                },
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildBlockedUsers() {
    if (_isLoading) {
      return const Center(child: HeartLoader());
    }
    if (_blockedUsers.isEmpty) {
      return Column(children: [
        const SizedBox(height: 60),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: _kParchment, shape: BoxShape.circle, border: Border.all(color: _kBone)),
          child: const Icon(Icons.block_rounded, color: _kBone, size: 32),
        ),
        const SizedBox(height: 20),
        Text("No blocked users", style: GoogleFonts.montserrat(fontSize: 22, color: _kInk)),
        const SizedBox(height: 8),
        Text("Users you block will appear here.",
            style: GoogleFonts.montserrat(color: _kInkMuted, fontSize: 13), textAlign: TextAlign.center),
      ]);
    }

    return Container(
      decoration: _cardDecor(),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _blockedUsers.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: _kBone, indent: 72),
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
                  style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: _kInk))),
              GestureDetector(
                onTap: () => _unblockUser(user['blocked_id'], user['full_name']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border.all(color: _kRose, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text("Unblock", style: GoogleFonts.montserrat(
                      color: _kRose, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildBlockedContacts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Pre-block Contacts", style: GoogleFonts.montserrat(fontSize: 20, color: _kInk)),
        const SizedBox(height: 6),
        Text("Block relatives or friends using their phone number.",
            style: GoogleFonts.montserrat(color: _kInkMuted, fontSize: 13, height: 1.4)),
        const SizedBox(height: 24),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: GoogleFonts.montserrat(color: _kInk, fontSize: 15),
          decoration: _inputDecor("Enter phone number", icon: Icons.phone_outlined),
        ),
        const SizedBox(height: 16),
        _saveButton("Block Contact", false, _blockByPhone),
        const SizedBox(height: 32),
        Center(child: Text("OR", style: GoogleFonts.montserrat(color: _kInkMuted, fontWeight: FontWeight.bold))),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: _importContacts,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kRose, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.contacts_outlined, color: _kRose),
                const SizedBox(width: 8),
                Text("Mass Import Contacts", style: GoogleFonts.montserrat(
                  color: _kRose, fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
          ),
        ),
        if (_blockedPhones.isNotEmpty) ...[
         const SizedBox(height: 32),
         const Divider(height: 1),
         const SizedBox(height: 16),
         Text("Pre-blocked Numbers", style: GoogleFonts.montserrat(fontSize: 18, color: _kInk)),
         const SizedBox(height: 12),
         Container(
           decoration: _cardDecor(),
           child: ListView.separated(
             shrinkWrap: true,
             physics: const NeverScrollableScrollPhysics(),
             itemCount: _blockedPhones.length,
             separatorBuilder: (_, __) => const Divider(height: 1, color: _kBone, indent: 16),
             itemBuilder: (ctx, i) {
                final phone = _blockedPhones[i];
                return Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                   child: Row(
                      children: [
                         const Icon(Icons.phone_locked_rounded, color: _kInkMuted),
                         const SizedBox(width: 14),
                         Expanded(child: Text(phone, style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: _kInk))),
                         GestureDetector(
                            onTap: () => _unblockPhone(phone),
                            child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                               decoration: BoxDecoration(border: Border.all(color: _kRose, width: 1.5), borderRadius: BorderRadius.circular(10)),
                               child: Text("Unblock", style: GoogleFonts.montserrat(color: _kRose, fontWeight: FontWeight.w600, fontSize: 13)),
                            )
                         )
                      ]
                   )
                );
             }
           )
         )
        ]
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Blocked Users",
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _kParchment,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBone),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? _kRose : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text("Blocked Users", style: GoogleFonts.montserrat(
                          color: _selectedTab == 0 ? Colors.white : _kInk,
                          fontWeight: _selectedTab == 0 ? FontWeight.w600 : FontWeight.w500,
                        )),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? _kRose : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text("Blocked Contacts", style: GoogleFonts.montserrat(
                          color: _selectedTab == 1 ? Colors.white : _kInk,
                          fontWeight: _selectedTab == 1 ? FontWeight.w600 : FontWeight.w500,
                        )),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _selectedTab == 0 ? _buildBlockedUsers() : _buildBlockedContacts(),
        ],
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
      child: Text(content, style: GoogleFonts.montserrat(
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
        Expanded(child: Text(label, style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: _kInk))),
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
        Text("Clush Gold", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w400)),
        const SizedBox(height: 10),
        Text("You are on the Free plan.", style: GoogleFonts.montserrat(color: Colors.white70)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(color: kParchment, borderRadius: BorderRadius.circular(20)),
            child: Text("Upgrade Now", style: GoogleFonts.montserrat(
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
              Expanded(child: Text(langs[i], style: GoogleFonts.montserrat(
                  fontSize: 15, fontWeight: FontWeight.w400, color: _kInk))),
              if (i == 0) Icon(Icons.check_rounded, color: _kRose, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── SUBSCRIPTIONS ────────────────────────────────────────────────────────────
class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});
  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  int _selectedPeriod = 1; // index into _periods

  static const _periods = [
    _Period('1 month',  '₹165',  null,   null),
    _Period('3 months', '₹449',  '₹495', '~9% off'),
    _Period('6 months', '₹699',  '₹990', '~30% off'),
    _Period('12 months','₹1,199','₹1,980','~40% off'),
  ];

  static const _features = [
    (Icons.all_inclusive_rounded,  "Unlimited Likes",         "Never run out of swipes"),
    (Icons.back_hand_rounded,      "5 High Fives / week",     "Stand out and get noticed"),
    (Icons.replay_rounded,         "Rewind Last Swipe",        "Change your mind? No problem"),
    (Icons.tune_rounded,           "Advanced Filters",         "Find exactly who you're looking for"),
    (Icons.message_outlined,       "Message Before Matching",  "Start the conversation first"),
  ];

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Subscriptions coming soon!", style: GoogleFonts.montserrat(color: Colors.white)),
      backgroundColor: _kRose, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final period = _periods[_selectedPeriod];
    return BaseSettingsPage(
      title: "Clush+",
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Hero header ────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A0010), Color(0xFF5C0030), _kRose],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: _kRose.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text("Clush", style: GoogleFonts.gabarito(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Text("+", style: GoogleFonts.gabarito(color: _kGold, fontSize: 24, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            Text("Match faster. Connect deeper.", style: GoogleFonts.figtree(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
          ]),
        ),

        const SizedBox(height: 24),

        // ── Period selector ────────────────────────────────────────────────
        Text("Choose your plan", style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: _kInkMuted, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Row(
          children: List.generate(_periods.length, (i) {
            final p = _periods[i];
            final selected = _selectedPeriod == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedPeriod = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(right: i < _periods.length - 1 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? _kRose : _kParchment,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? _kRose : _kBone, width: 1.5),
                    boxShadow: selected ? [BoxShadow(color: _kRose.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))] : [],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (p.discount != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: selected ? Colors.white.withValues(alpha: 0.25) : _kGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(p.discount!, style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w700, color: selected ? Colors.white : _kGold, letterSpacing: 0.3)),
                      )
                    else
                      const SizedBox(height: 18),
                    Text(p.duration.split(' ')[0], style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: selected ? Colors.white : _kInk)),
                    Text(p.duration.split(' ')[1], style: GoogleFonts.montserrat(fontSize: 10, color: selected ? Colors.white.withValues(alpha: 0.8) : _kInkMuted)),
                  ]),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 16),

        // ── Price summary ──────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: _kParchment,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBone),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(period.price, style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.bold, color: _kInk)),
              Text("for ${period.duration} · incl. taxes", style: GoogleFonts.montserrat(fontSize: 12, color: _kInkMuted)),
            ]),
            const Spacer(),
            if (period.strikePrice != null)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(period.strikePrice!, style: GoogleFonts.montserrat(fontSize: 14, color: _kInkMuted, decoration: TextDecoration.lineThrough, decorationColor: _kInkMuted)),
                Text("You save ${period.discount!}", style: GoogleFonts.montserrat(fontSize: 12, color: _kGold, fontWeight: FontWeight.w600)),
              ]),
          ]),
        ),

        const SizedBox(height: 20),

        // ── Features ──────────────────────────────────────────────────────
        Text("Everything included", style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: _kInkMuted, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Container(
          decoration: _cardDecor(),
          child: Column(
            children: _features.asMap().entries.map((entry) {
              final i = entry.key;
              final f = entry.value;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: _kRosePale, shape: BoxShape.circle),
                      child: Icon(f.$1, color: _kRose, size: 18)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.$2, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _kInk)),
                      Text(f.$3, style: GoogleFonts.montserrat(fontSize: 11, color: _kInkMuted)),
                    ])),
                    Icon(Icons.check_circle_rounded, color: _kRose, size: 18),
                  ]),
                ),
                if (i < _features.length - 1) Divider(height: 1, color: _kBone, indent: 66),
              ]);
            }).toList(),
          ),
        ),

        const SizedBox(height: 24),

        // ── Subscribe button ──────────────────────────────────────────────
        _saveButton("Subscribe · ${period.price}", false, _showComingSoon),

        const SizedBox(height: 12),
        Center(child: Text("Renews automatically · Cancel anytime", style: GoogleFonts.montserrat(fontSize: 11, color: _kInkMuted))),

        // ── High Fives section ────────────────────────────────────────────
        const SizedBox(height: 36),
        Row(children: [
          Container(width: 3, height: 14, color: _kGold, margin: const EdgeInsets.only(right: 9)),
          Text("HIGH FIVES", style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: _kInkMuted, letterSpacing: 1.8)),
        ]),
        const SizedBox(height: 8),
        Text("Send a High Five to someone you really like — they'll get notified and you'll stand out.", style: GoogleFonts.montserrat(fontSize: 13, color: _kInkMuted, height: 1.4)),
        const SizedBox(height: 16),
        ...[
          _HighFivePack(count: 5,  price: '₹99',  tag: null),
          _HighFivePack(count: 10, price: '₹179', tag: 'Popular'),
          _HighFivePack(count: 20, price: '₹299', tag: 'Best Value'),
        ].map((pack) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildHighFiveTile(pack),
        )),

        const SizedBox(height: 8),
        Center(child: Text("High Fives never expire.", style: GoogleFonts.montserrat(fontSize: 11, color: _kInkMuted))),
      ]),
    );
  }

  Widget _buildHighFiveTile(_HighFivePack pack) {
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _kParchment,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pack.tag == 'Best Value' ? _kRose : _kBone, width: pack.tag == 'Best Value' ? 1.5 : 1),
        ),
        child: Row(children: [
          Stack(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: _kRosePale, shape: BoxShape.circle),
              child: const Icon(Icons.back_hand_rounded, color: _kRose, size: 24)),
            Positioned(top: -2, right: -2,
              child: Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(color: _kRose, shape: BoxShape.circle),
                child: Center(child: Text('${pack.count}', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              )),
          ]),
          const SizedBox(width: 16),
          Expanded(child: Text("${pack.count} High Fives", style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600, color: _kInk))),
          Text(pack.price, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: _kRose)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showComingSoon,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: _kRose, borderRadius: BorderRadius.circular(20)),
              child: Text("Buy", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ]),
      ),
      if (pack.tag != null)
        Positioned(top: -10, left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: pack.tag == 'Best Value' ? _kRose : _kGold, borderRadius: BorderRadius.circular(20)),
            child: Text(pack.tag!.toUpperCase(), style: GoogleFonts.montserrat(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          )),
    ]);
  }
}

class _Period {
  final String duration;
  final String price;
  final String? strikePrice;
  final String? discount;
  const _Period(this.duration, this.price, this.strikePrice, this.discount);
}

class _HighFivePack {
  final int count;
  final String price;
  final String? tag;
  const _HighFivePack({required this.count, required this.price, required this.tag});
}

// ─── DOWNLOAD MY DATA ─────────────────────────────────────────────────────────
class DownloadMyDataPage extends StatefulWidget {
  const DownloadMyDataPage({super.key});
  @override
  State<DownloadMyDataPage> createState() => _DownloadMyDataPageState();
}

class _DownloadMyDataPageState extends State<DownloadMyDataPage> {
  bool _requested = false;

  static const _dataItems = [
    (Icons.person_outline_rounded,       "Profile Information",  "Name, age, bio, photos, and profile details"),
    (Icons.favorite_border_rounded,      "Likes & Matches",      "Your likes, dislikes, and all matches"),
    (Icons.chat_bubble_outline_rounded,  "Messages",             "Full history of your conversations"),
    (Icons.location_on_outlined,         "Location History",     "Locations used for discovery"),
    (Icons.settings_outlined,            "App Settings",         "Preferences, notifications, and filters"),
  ];

  @override
  Widget build(BuildContext context) {
    return BaseSettingsPage(
      title: "Download My Data",
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Your data, your right", style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w600, color: _kInk)),
        const SizedBox(height: 6),
        Text("Request a copy of all data Clush holds about you. We'll send it to your registered email within 48 hours.",
            style: GoogleFonts.montserrat(fontSize: 13, color: _kInkMuted, height: 1.5)),
        const SizedBox(height: 24),

        Text("What's included", style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: _kInkMuted, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Container(
          decoration: _cardDecor(),
          child: Column(
            children: _dataItems.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _kRosePale, shape: BoxShape.circle),
                      child: Icon(item.$1, color: _kRose, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.$2, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: _kInk)),
                      Text(item.$3, style: GoogleFonts.montserrat(fontSize: 12, color: _kInkMuted)),
                    ])),
                  ]),
                ),
                if (i < _dataItems.length - 1)
                  Divider(height: 1, thickness: 1, color: _kBone, indent: 66),
              ]);
            }).toList(),
          ),
        ),

        const SizedBox(height: 28),
        if (_requested)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 24),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Request submitted", style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                Text("You'll receive your data export by email within 48 hours.", style: GoogleFonts.montserrat(fontSize: 12, color: Colors.green.shade600, height: 1.4)),
              ])),
            ]),
          )
        else
          _saveButton("Request Data Export", false, () => setState(() => _requested = true)),

        const SizedBox(height: 16),
        Center(child: Text("Data exports are available once every 30 days.",
            style: GoogleFonts.montserrat(fontSize: 11, color: _kInkMuted))),
      ]),
    );
  }
}
