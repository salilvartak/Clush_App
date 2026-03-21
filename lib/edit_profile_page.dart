import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clush/services/image_validation_service.dart';
import 'package:clush/services/content_moderator.dart';

import 'theme/colors.dart';
import 'heart_loader.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> currentData;
  const EditProfilePage({super.key, required this.currentData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final ImageValidationService _imageValidationService = ImageValidationService();
  int? _validatingIndex;
  bool _photo0Changed = false;

  // ─── State ──────────────────────────────────────────────────────────────────
  late TextEditingController _nameController;
  late TextEditingController _jobController;
  late TextEditingController _schoolController;

  List<dynamic> _photos = List.filled(6, null);

  String? _gender, _orientation, _pronouns, _ethnicity;
  String? _height, _religion, _politics, _starSign;
  String? _educationLevel, _location;
  String? _drink, _smoke, _weed, _exercise, _kids, _pets, _intent;

  List<String> _languages = [], _interests = [], _foods = [], _places = [];
  List<Map<String, dynamic>?> _prompts = [null, null, null];

  bool _isFeet = true;

  // ─── Options ─────────────────────────────────────────────────────────────────
  final List<String> genderOptions        = ["Woman","Man","Non-binary"];
  final List<String> orientationOptions   = ["Straight","Gay","Lesbian","Bisexual","Asexual","Demisexual","Pansexual","Queer","Questioning"];
  final List<String> pronounOptions       = ["She/Her","He/Him","They/Them","She/They","He/They","Prefer not to say"];
  final List<String> ethnicityOptions     = ["Black/African Descent","East Asian","Hispanic/Latino","Middle Eastern","Native American","Pacific Islander","South Asian","White/Caucasian","Other"];
  final List<String> religionOptions      = ["Hindu","Muslim","Christian","Sikh","Atheist","Jewish","Agnostic","Buddhist","Spiritual","Catholic","Other"];
  final List<String> politicalOptions     = ["Liberal","Moderate","Conservative","Not political","Other"];
  final List<String> educationOptions     = ["High School","Undergraduate","Postgraduate","Trade School","Other"];
  final List<String> kidsOptions          = ["Want someday","Don't want","Have & want more","Have & don't want more","Not sure"];
  final List<String> petsOptions          = ["Dog","Cat","Reptile","Amphibian","Bird","Fish","None","Want one","Allergic"];
  final List<String> exerciseOptions      = ["Active","Sometimes","Almost never"];
  final List<String> habitOptions         = ["Yes","Sometimes","No"];
  final List<String> starSigns            = ["Aries","Taurus","Gemini","Cancer","Leo","Virgo","Libra","Scorpio","Sagittarius","Capricorn","Aquarius","Pisces"];
  final List<String> intentOptionsStrings = ["Life Partner","Long-term relationship","Long-term, open to short","Open to options"];
  final List<String> interestOptions      = ["Travel","Photography","Hiking","Yoga","Art","Reading","Fitness","Music","Movies","Cooking","Gaming","Writing","Meditation","Tech","Startups","Dancing","Cycling","Swimming","Pets","Volunteering","Astronomy","Blogging","DIY","Podcasting"];
  final List<String> foodOptions          = ["Coffee","Tea","Pizza","Sushi","Burgers","Street Food","Desserts","Vegan","BBQ","Pasta","Indian","Thai","Mexican","Chinese","Wine","Cocktails","Mocktails","Smoothies","Ice Cream","Biryani"];
  final List<String> placeOptions         = ["Beach","Mountains","Cafes","Museums","Art Galleries","Hidden Bars","Nature Trails","Bookstores","Rooftops","Parks","Gyms","Libraries","Music Venues","Temples","Historic Sites","Street Markets"];
  final List<String> languageOptions      = ["English","Spanish","French","German","Chinese","Japanese","Korean","Arabic","Hindi","Portuguese","Russian","Other"];

  final List<String> heightFeet = List.generate(37, (i) => "${(i ~/ 12) + 4}' ${i % 12}\"");
  final List<String> heightCm   = List.generate(121, (i) => "${i + 120} cm");

  @override
  void initState() {
    super.initState();
    _imageValidationService.initialize();
    _initializeData();
  }

  @override
  void dispose() {
    _imageValidationService.dispose();
    _nameController.dispose();
    _jobController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  void _initializeData() {
    final data = widget.currentData;
    _nameController = TextEditingController(text: data['full_name']);
    _jobController  = TextEditingController(text: data['job_title']);

    String fullEdu = data['education'] ?? '';
    if (fullEdu.contains(' - ')) {
      var parts = fullEdu.split(' - ');
      _educationLevel  = parts[0];
      _schoolController = TextEditingController(text: parts.length > 1 ? parts[1] : '');
    } else {
      _educationLevel   = fullEdu.isNotEmpty ? fullEdu : null;
      _schoolController = TextEditingController();
    }

    _gender      = data['gender'];
    _orientation = data['sexual_orientation'];
    _pronouns    = data['pronouns'];
    _ethnicity   = data['ethnicity'];
    _height      = data['height'];
    _religion    = data['religion'];
    _politics    = data['political_views'];
    _starSign    = data['star_sign'];
    _location    = data['location'];
    _drink       = data['drink'];
    _smoke       = data['smoke'];
    _weed        = data['weed'];
    _exercise    = data['exercise'];
    _kids        = data['kids'];
    _pets        = data['pets'];
    _intent      = data['intent'];

    _languages = List<String>.from((data['languages'] as String?)?.split(', ') ?? []);
    _interests = List<String>.from(data['interests'] ?? []);
    _foods     = List<String>.from(data['foods'] ?? []);
    _places    = List<String>.from(data['places'] ?? []);

    List<dynamic> loadedPhotos = data['photo_urls'] ?? [];
    for (int i = 0; i < loadedPhotos.length && i < 6; i++) {
      _photos[i] = loadedPhotos[i];
    }

    List<dynamic> loadedPrompts = data['prompts'] ?? [];
    for (int i = 0; i < 3; i++) {
      if (i < loadedPrompts.length && loadedPrompts[i] != null) {
        _prompts[i] = Map<String, dynamic>.from(loadedPrompts[i]);
      }
    }
  }

  // ─── Save ────────────────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // ─── Text Moderation ────────────────────────────────────────────────────────
    String? nameError = ContentModerator.validatePromptText(_nameController.text);
    if (nameError != null) { _showNotification(nameError); return; }
    String? jobError = ContentModerator.validatePromptText(_jobController.text);
    if (jobError != null) { _showNotification(jobError); return; }

    String? schoolError = ContentModerator.validatePromptText(_schoolController.text);
    if (schoolError != null) { _showNotification(schoolError); return; }

    for (var prompt in _prompts) {
      if (prompt != null) {
        String? promptError = ContentModerator.validatePromptText(prompt['answer']);
        if (promptError != null) { _showNotification(promptError); return; }
      }
    }

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      List<String> finalPhotoUrls = [];
      for (var item in _photos) {
        if (item == null) continue;
        if (item is File) {
          final fileExt = item.path.split('.').last;
          final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}_${finalPhotoUrls.length}.$fileExt';
          await supabase.storage.from('user_photos').upload(fileName, item);
          finalPhotoUrls.add(supabase.storage.from('user_photos').getPublicUrl(fileName));
        } else if (item is String) {
          finalPhotoUrls.add(item);
        }
      }

      String finalEdu = _educationLevel ?? '';
      if (_schoolController.text.isNotEmpty) {
        finalEdu = "$finalEdu - ${_schoolController.text.trim()}";
      }

      await supabase.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'job_title': _jobController.text.trim(),
        'education': finalEdu,
        'location': _location,
        'gender': _gender,
        'sexual_orientation': _orientation,
        'pronouns': _pronouns,
        'ethnicity': _ethnicity,
        'height': _height,
        'religion': _religion,
        'political_views': _politics,
        'star_sign': _starSign,
        'drink': _drink,
        'smoke': _smoke,
        'weed': _weed,
        'exercise': _exercise,
        'kids': _kids,
        'pets': _pets,
        'intent': _intent,
        'languages': _languages.join(', '),
        'interests': _interests,
        'foods': _foods,
        'places': _places,
        'photo_urls': finalPhotoUrls,
        'prompts': _prompts.where((p) => p != null).toList(),
        if (_photo0Changed) 'is_verified': false,
      }).eq('id', userId);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showNotification("Error saving: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNotification(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              color: isError ? const Color(0xFFE57373) : kRose,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: kInk,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 4),
        elevation: 4,
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 104), // header spacer

                // ── PHOTOS ──────────────────────────────────────────────────
                _buildSectionLabel("My Photos"),
                const SizedBox(height: 12),
                _buildPhotoGrid(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                  child: Text(
                    "Tap a photo to replace it.",
                    style: GoogleFonts.dmSans(color: kInkMuted, fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                ),

                // ── THE ESSENTIALS ───────────────────────────────────────────
                const SizedBox(height: 28),
                _buildSectionLabel("The Essentials"),
                const SizedBox(height: 10),
                _buildCard([
                  _buildTextRow("Name", _nameController),
                  _buildBoneDivider(),
                  _buildTextRow("Job Title", _jobController),
                  _buildBoneDivider(),
                  _buildLocationRow(),
                ]),

                // ── ABOUT ME ─────────────────────────────────────────────────
                const SizedBox(height: 28),
                _buildSectionLabel("About Me"),
                const SizedBox(height: 10),
                _buildCard([
                  _buildSelectorRow("Height",      _height,      Icons.straighten_outlined,         () => _showHeightPicker()),
                  _buildBoneDivider(),
                  _buildEducationSelector(),
                  _buildBoneDivider(),
                  _buildSelectorRow("Gender",      _gender,      Icons.person_outline_rounded,       () => _showChipModal("Gender", genderOptions, _gender, (v) => setState(() => _gender = v))),
                  _buildBoneDivider(),
                  _buildSelectorRow("Pronouns",    _pronouns,    Icons.record_voice_over_outlined,   () => _showChipModal("Pronouns", pronounOptions, _pronouns, (v) => setState(() => _pronouns = v))),
                  _buildBoneDivider(),
                  _buildSelectorRow("Orientation", _orientation, Icons.favorite_border_rounded,      () => _showChipModal("Sexual Orientation", orientationOptions, _orientation, (v) => setState(() => _orientation = v))),
                  _buildBoneDivider(),
                  _buildSelectorRow("Ethnicity",   _ethnicity,   Icons.public_outlined,              () => _showChipModal("Ethnicity", ethnicityOptions, _ethnicity, (v) => setState(() => _ethnicity = v))),
                  _buildBoneDivider(),
                  _buildSelectorRow("Religion",    _religion,    Icons.auto_stories_outlined,        () => _showChipModal("Religion", religionOptions, _religion, (v) => setState(() => _religion = v))),
                  _buildBoneDivider(),
                  _buildSelectorRow("Politics",    _politics,    Icons.gavel_outlined,               () => _showChipModal("Politics", politicalOptions, _politics, (v) => setState(() => _politics = v))),
                  _buildBoneDivider(),
                  _buildSelectorRow("Star Sign",   _starSign,    Icons.auto_awesome_outlined,        () => _showChipModal("Star Sign", starSigns, _starSign, (v) => setState(() => _starSign = v))),
                  _buildBoneDivider(),
                  _buildMultiRow("Languages",      _languages,   Icons.translate_outlined,           () => _showMultiSelectModal("Languages", languageOptions, _languages)),
                ]),

                // ── LIFESTYLE ────────────────────────────────────────────────
                const SizedBox(height: 28),
                _buildSectionLabel("Lifestyle"),
                const SizedBox(height: 10),
                _buildCard([
                  _buildSelectorRow("Looking For", _intent,   Icons.search_rounded,          () => _showChipModal("Intent", intentOptionsStrings, _intent, (v) => setState(() => _intent = v))),
                  _buildBoneDivider(),
                  _buildSelectorRow("Kids",        _kids,     Icons.child_care_outlined,     () => _showChipModal("Kids", kidsOptions, _kids, (v) => setState(() => _kids = v))),
                  _buildBoneDivider(),
                  _buildSelectorRow("Pets",        _pets,     Icons.pets_outlined,           () => _showChipModal("Pets", petsOptions, _pets, (v) => setState(() => _pets = v))),
                  _buildBoneDivider(),
                  _buildSelectorRow("Exercise",    _exercise, Icons.fitness_center_outlined, () => _showChipModal("Exercise", exerciseOptions, _exercise, (v) => setState(() => _exercise = v))),
                  _buildBoneDivider(),
                  _buildSelectorRow("Drink",       _drink,    Icons.local_bar_outlined,      () => _showChipModal("Drink", habitOptions, _drink, (v) => setState(() => _drink = v))),
                  _buildBoneDivider(),
                  _buildSelectorRow("Smoke",       _smoke,    Icons.smoking_rooms_outlined,  () => _showChipModal("Smoke", habitOptions, _smoke, (v) => setState(() => _smoke = v))),
                  _buildBoneDivider(),
                  _buildSelectorRow("Weed",        _weed,     Icons.grass_outlined,          () => _showChipModal("Weed", habitOptions, _weed, (v) => setState(() => _weed = v))),
                ]),

                // ── PASSIONS ─────────────────────────────────────────────────
                const SizedBox(height: 28),
                _buildSectionLabel("Passions & Discovery"),
                const SizedBox(height: 10),
                _buildCard([
                  _buildMultiRow("Interests",      _interests, Icons.favorite_border_rounded, () => _showMultiSelectModal("Interests", interestOptions, _interests)),
                  _buildBoneDivider(),
                  _buildMultiRow("Favorite Foods", _foods,     Icons.restaurant_outlined,     () => _showMultiSelectModal("Foods", foodOptions, _foods)),
                  _buildBoneDivider(),
                  _buildMultiRow("Favorite Places",_places,    Icons.location_on_outlined,    () => _showMultiSelectModal("Places", placeOptions, _places)),
                ]),

                // ── PROMPTS ──────────────────────────────────────────────────
                const SizedBox(height: 28),
                _buildSectionLabel("My Prompts"),
                const SizedBox(height: 10),
                _buildPromptsList(),
              ],
            ),
          ),

          // ── FROSTED HEADER ───────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildHeader(),
          ),
        ],
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: kCream.withOpacity(0.88),
            border: Border(bottom: BorderSide(color: kBone, width: 0.5)),
          ),
          padding: const EdgeInsets.fromLTRB(6, 44, 16, 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: kInk),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  "Edit Profile",
                  style: GoogleFonts.domine(
                    color: kInk,
                    fontSize: 26,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              _isLoading
                  ? const HeartLoader(size: 22)
                  : GestureDetector(
                      onTap: _saveProfile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: kRose,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "Save",
                          style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section Label ────────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: kGold, margin: const EdgeInsets.only(right: 10)),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: kInkMuted, letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Card Shell ───────────────────────────────────────────────────────────────
  Widget _buildCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: kParchment,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBone, width: 1),
        boxShadow: [BoxShadow(color: kInk.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildBoneDivider() => Divider(height: 1, thickness: 1, color: kBone, indent: 20, endIndent: 20);

  // ─── Photo Grid ───────────────────────────────────────────────────────────────
  Widget _buildPhotoGrid() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 0.72,
          crossAxisSpacing: 10, mainAxisSpacing: 10,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          final item = _photos[index];
          return GestureDetector(
            onTap: () => _showPhotoOptions(index),
              child: Container(
              decoration: BoxDecoration(
                color: kParchment,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBone, width: 1),
                boxShadow: [BoxShadow(color: kInk.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: _validatingIndex == index
                  ? const Center(child: HeartLoader(size: 40))
                  : item != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              item is File
                                  ? Image.file(item, fit: BoxFit.cover)
                                  : Image.network(item, fit: BoxFit.cover),
                              Positioned(
                                bottom: 6, right: 6,
                                child: Container(
                                  width: 26, height: 26,
                                  decoration: BoxDecoration(
                                    color: kCream.withOpacity(0.92),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: kBone, width: 1),
                                  ),
                                  child: const Icon(Icons.edit_rounded, size: 14, color: kRose),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, color: kBone, size: 28),
                            const SizedBox(height: 4),
                            Text("Add", style: GoogleFonts.dmSans(color: kInkMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showPhotoOptions(int index) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: kCream,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: kBone, width: 0.5)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: kBone, borderRadius: BorderRadius.circular(4))),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: kInkMuted, size: 20),
                title: Text("Gallery", style: GoogleFonts.dmSans(fontWeight: FontWeight.w500, color: kInk)),
                onTap: () { Navigator.pop(ctx); _pickImage(index, ImageSource.gallery); },
              ),
              Divider(height: 1, color: kBone, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: kInkMuted, size: 20),
                title: Text("Camera", style: GoogleFonts.dmSans(fontWeight: FontWeight.w500, color: kInk)),
                onTap: () { Navigator.pop(ctx); _pickImage(index, ImageSource.camera); },
              ),
              if (_photos[index] != null) ...[
                Divider(height: 1, color: kBone, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  title: Text("Remove", style: GoogleFonts.dmSans(color: Colors.red, fontWeight: FontWeight.w500)),
                  onTap: () { Navigator.pop(ctx); setState(() => _photos[index] = null); },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _scanImageWithPython(File image) async {
    final result = await _imageValidationService.checkTextModeration(image);
    return result.isValid;
  }

  Future<void> _pickImage(int index, ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile == null) return;

    final File selectedImage = File(pickedFile.path);

    setState(() => _validatingIndex = index);

    // 1. Show scanning indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🔍 Scanning image for text..."),
        duration: Duration(seconds: 2),
      ),
    );

    // 2. Wait for Python to scan it
    bool isClean = await _scanImageWithPython(selectedImage);

    // 3. THE WALL: If Python says it's dirty, we KILL the function right here.
    if (!isClean) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚨 Blocked: Images containing text or numbers are strictly prohibited."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      setState(() => _validatingIndex = null);
      return; // 🛑 THIS IS THE MOST IMPORTANT LINE. It stops the image from uploading.
    }

    // 4. ONLY IF CLEAN: Perform other validations (resolution, face, NSFW)
    try {
      final validationResult = await _imageValidationService.validateImage(selectedImage, index);

      if (mounted) {
        if (!validationResult.isValid) {
          _showNotification(validationResult.errorMessage ?? "Invalid image");
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          setState(() {
            _photos[index] = selectedImage;
            if (index == 0) _photo0Changed = true;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _validatingIndex = null);
    }
  }

  // ─── Row Builders ─────────────────────────────────────────────────────────────

  Widget _buildTextRow(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.w500, color: kInkMuted, fontSize: 14)),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: kInk, fontSize: 15),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorRow(String label, String? value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 18, color: kRose),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.w500, color: kInkMuted, fontSize: 14)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value ?? "Add",
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w500,
                  color: value == null ? kRoseLight : kInk,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: kBone),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiRow(String label, List<String> values, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 18, color: kRose),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.w500, color: kInkMuted, fontSize: 14)),
            const Spacer(),
            Text(
              values.isEmpty ? "Add" : "${values.length} selected",
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w500,
                color: values.isEmpty ? kRoseLight : kInk,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: kBone),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow() {
    return InkWell(
      onTap: _fetchCurrentLocation,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 18, color: kRose),
            const SizedBox(width: 12),
            Text("Location", style: GoogleFonts.dmSans(fontWeight: FontWeight.w500, color: kInkMuted, fontSize: 14)),
            const Spacer(),
            Flexible(
              child: Text(
                _location ?? "Tap to update",
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w500,
                  color: _location == null ? kRoseLight : kInk,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: kBone),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        setState(() => _location = "${placemarks[0].locality}, ${placemarks[0].country}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Location error: $e")));
      }
    }
  }

  Widget _buildEducationSelector() {
    return InkWell(
      onTap: () => _showChipModal("Education Level", educationOptions, _educationLevel, (v) => setState(() => _educationLevel = v)),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Icon(Icons.school_outlined, size: 18, color: kRose),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: Text("Education", style: GoogleFonts.dmSans(fontWeight: FontWeight.w500, color: kInkMuted, fontSize: 14)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _educationLevel ?? "Select Level",
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w500,
                      color: _educationLevel == null ? kRoseLight : kInk,
                      fontSize: 14,
                    ),
                  ),
                  TextField(
                    controller: _schoolController,
                    textAlign: TextAlign.end,
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w400, color: kInk, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "School Name (Optional)",
                      hintStyle: GoogleFonts.dmSans(color: kInkMuted, fontSize: 13),
                      border: InputBorder.none, isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.chevron_right_rounded, size: 18, color: kBone),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Prompts ─────────────────────────────────────────────────────────────────
  Widget _buildPromptsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(3, (index) {
          final p = _prompts[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: kParchment,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBone, width: 1),
              boxShadow: [BoxShadow(color: kInk.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: p == null
                ? InkWell(
                    onTap: () => _editPrompt(index),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      child: Row(
                        children: [
                          Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(color: kRosePale, shape: BoxShape.circle),
                            child: const Icon(Icons.add_rounded, color: kRose, size: 18),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            "Add a Prompt",
                            style: GoogleFonts.dmSans(color: kInkMuted, fontWeight: FontWeight.w500, fontSize: 15),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded, color: kBone, size: 20),
                        ],
                      ),
                    ),
                  )
                : InkWell(
                    onTap: () => _editPrompt(index),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Opening quote
                              Text(
                                "\u201C",
                                style: GoogleFonts.domine(
                                  fontSize: 36, color: kRose.withOpacity(0.3), height: 0.8,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => setState(() => _prompts[index] = null),
                                child: Icon(Icons.close_rounded, color: kInkMuted, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (p['question'] ?? '').toString(),
                            style: GoogleFonts.dmSans(
                              color: kInkMuted, fontSize: 11,
                              fontWeight: FontWeight.w600, letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            p['answer'] ?? '',
                            style: GoogleFonts.domine(
                              fontSize: 22, height: 1.35,
                              fontWeight: FontWeight.w600, color: kInk,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.edit_rounded, color: kRose.withOpacity(0.6), size: 12),
                              const SizedBox(width: 5),
                              Text(
                                "Tap to edit",
                                style: GoogleFonts.dmSans(
                                  color: kRose.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          );
        }),
      ),
    );
  }

  // ─── Modals ───────────────────────────────────────────────────────────────────

  void _showChipModal(String title, List<String> options, String? current, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: kCream,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: kBone, width: 0.5)),
          ),
          padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4, margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: kBone, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Text(title, style: GoogleFonts.domine(fontSize: 24, fontWeight: FontWeight.w400, color: kInk)),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Wrap(
                    spacing: 10, runSpacing: 10,
                    children: options.map((opt) {
                      final isSelected = current == opt;
                      return GestureDetector(
                        onTap: () { onSelect(opt); Navigator.pop(ctx); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? kRose : kCream,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? kRose : kBone, width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            opt,
                            style: GoogleFonts.dmSans(
                              color: isSelected ? Colors.white : kInk,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMultiSelectModal(String title, List<String> options, List<String> current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: kCream,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: kBone, width: 0.5)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              height: MediaQuery.of(ctx).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4, margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: kBone, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: GoogleFonts.domine(fontSize: 24, fontWeight: FontWeight.w400, color: kInk)),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(color: kRose, borderRadius: BorderRadius.circular(8)),
                          child: Text("Done", style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Wrap(
                        spacing: 10, runSpacing: 10,
                        children: options.map((opt) {
                          final isSelected = current.contains(opt);
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                setState(() {
                                  isSelected ? current.remove(opt) : current.add(opt);
                                });
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? kRose : kCream,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? kRose : kBone, width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                opt,
                                style: GoogleFonts.dmSans(
                                  color: isSelected ? Colors.white : kInk,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showHeightPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          final list = _isFeet ? heightFeet : heightCm;
          return Container(
            decoration: BoxDecoration(
              color: kCream,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: kBone, width: 0.5)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            height: 420,
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4, margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: kBone, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Text("Height", style: GoogleFonts.domine(fontSize: 24, fontWeight: FontWeight.w400, color: kInk)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildToggleBtn("Feet", _isFeet, () => setModalState(() => _isFeet = true)),
                    const SizedBox(width: 12),
                    _buildToggleBtn("CM", !_isFeet, () => setModalState(() => _isFeet = false)),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    itemExtent: 50,
                    perspective: 0.003,
                    onSelectedItemChanged: (i) => setState(() => _height = list[i]),
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (c, i) => Center(
                        child: Text(list[i], style: GoogleFonts.domine(fontSize: 22, fontWeight: FontWeight.w600, color: kInk)),
                      ),
                      childCount: list.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildToggleBtn(String txt, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          color: active ? kRose : kCream,
          border: Border.all(color: active ? kRose : kBone, width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          txt,
          style: GoogleFonts.dmSans(
            color: active ? Colors.white : kInkMuted,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ─── Prompt Editor ────────────────────────────────────────────────────────────
  void _editPrompt(int index) {
    final questions = [
      "What I'd order for the table", "One thing to know about me", "My ideal Sunday",
      "I'm overly competitive about", "The way to win my heart", "My biggest pet peeve",
      "I geek out on", "A random fact I love", "My simple pleasures", "I'm looking for",
      "Unpopular opinion", "Two truths and a lie"
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: kCream,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: kBone, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(color: kBone, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text("Choose a Prompt", style: GoogleFonts.domine(fontWeight: FontWeight.w400, fontSize: 24, color: kInk)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: kInkMuted, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: questions.length,
                separatorBuilder: (c, i) => Divider(color: kBone, height: 1),
                itemBuilder: (context, i) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  title: Text(
                    questions[i],
                    style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w400, color: kInk),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: kInkMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAnswerDialog(index, questions[i]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnswerDialog(int index, String question) {
    TextEditingController ctrl = TextEditingController(text: _prompts[index]?['answer']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: kBone, width: 1),
        ),
        title: Text(question, style: GoogleFonts.domine(fontSize: 17, fontWeight: FontWeight.w500, color: kInk, height: 1.3)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          style: GoogleFonts.dmSans(fontSize: 15, color: kInk),
          decoration: InputDecoration(
            hintText: "Your answer…",
            hintStyle: GoogleFonts.dmSans(color: kInkMuted, fontSize: 15),
            filled: true,
            fillColor: kParchment,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kBone)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kBone)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kRose, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.dmSans(color: kInkMuted, fontWeight: FontWeight.w500)),
          ),
          GestureDetector(
            onTap: () {
              if (ctrl.text.isNotEmpty) setState(() => _prompts[index] = {'question': question, 'answer': ctrl.text});
              Navigator.pop(ctx);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(color: kRose, borderRadius: BorderRadius.circular(8)),
              child: Text("Save", style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}