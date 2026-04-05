import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:clush/main.dart';
import 'package:clush/services/profile_store.dart';
import 'package:clush/services/image_validation_service.dart';
import 'package:clush/services/matching_service.dart';
import 'package:clush/widgets/heart_loader.dart';
import 'package:clush/services/content_moderator.dart';
import 'package:clush/screens/success_screen.dart'; 
import 'package:clush/screens/permission_request_page.dart';
import 'package:clush/services/notification_service.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:google_fonts/google_fonts.dart';

// --- Premium Theme Constants ---
import 'package:clush/theme/colors.dart';

const double kPadding = 24.0;

class BasicsPage extends StatefulWidget {
  final int currentStep;
  final int totalSteps;

  const BasicsPage({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  State<BasicsPage> createState() => _BasicsPageState();
}

class _BasicsPageState extends State<BasicsPage> {
  final PageController _pageController = PageController();
  int _currentQuestionIndex = 0;
  bool _isUploading = false;
  int? _validatingIndex;
  final ImageValidationService _validationService = ImageValidationService();
  
  // Total steps
  final int _totalQuestionScreens = 26;

  // --- Controllers (Text) ---
  final TextEditingController nameController = TextEditingController();
  final TextEditingController jobController = TextEditingController();
  final TextEditingController schoolNameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  // Whether the user authenticated via phone (true) or email (false)
  bool _loggedInWithPhone = false;

  // --- State Variables (Basics) ---
  int? selectedAge; 
  DateTime? selectedDate;
  
  bool isFeet = true;
  String? selectedHeight; 
  int _selectedHeightIndex = 20; 

  String? selectedGender;
  String? selectedOrientation;
  String? selectedReligion;
  String? selectedPolitics;
  String? selectedStarSign;
  String? selectedPronouns;
  String? selectedEthnicity;
  String? selectedEducationLevel;
  List<String> selectedLanguages = [];
  String? selectedKids;
  String? selectedPets;
  String? selectedExercise;
  String? location;
  String? drinkStatus;
  String? smokeStatus;
  String? weedStatus;

  // --- Map State ---
  final MapController _mapController = MapController();
  LatLng _currentMapCenter = const LatLng(40.7128, -74.0060); // Default to NY
  bool _isMapLoading = false;
  final TextEditingController _mapSearchController = TextEditingController();

  // --- State Variables (New Sections) ---
  String? selectedIntent;
  List<String> selectedInterests = [];
  List<String> selectedFoods = [];
  List<String> selectedPlaces = [];
  
  // Photos
  final List<File?> _photos = List<File?>.generate(6, (_) => null);
  final ImagePicker _picker = ImagePicker();

  // Prompts
  final List<Map<String, String>?> _promptSlots = [null, null, null];

  // --- Options Lists ---
  late List<String> heightOptionsFeet;
  late List<String> heightOptionsCm;

  final List<String> pronounOptions = ["She/Her", "He/Him", "They/Them", "She/They", "He/They", "Prefer not to say"];
  final List<String> genderOptions = ["Woman", "Man", "Non-binary"];
  final List<String> ethnicityOptions = ["Black/African Descent", "East Asian", "Hispanic/Latino", "Middle Eastern", "Native American", "Pacific Islander", "South Asian", "White/Caucasian", "Other"];
  final List<String> religionOptions = ["Hindu", "Muslim", "Christian", "Sikh", "Atheist", "Jewish", "Agnostic", "Buddhist", "Spiritual", "Catholic", "Other"];
  final List<String> politicalOptions = ["Liberal", "Moderate", "Conservative", "Not political", "Other"];
  final List<String> languageOptions = ["English", "Spanish", "French", "German", "Chinese", "Japanese", "Korean", "Arabic", "Hindi", "Portuguese", "Russian", "Other"];
  final List<String> educationLevelOptions = ["High School", "Undergraduate", "Postgraduate", "Trade School", "Other"];
  final List<String> kidsOptions = ["Want someday", "Don't want", "Have & want more", "Have & don't want more", "Not sure"];
  final List<String> petsOptions = ["Dog", "Cat", "Reptile", "Amphibian", "Bird", "Fish", "None", "Want one", "Allergic"];
  final List<String> exerciseOptions = ["Active", "Sometimes", "Almost never"];
  final List<String> starSigns = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"];
  final List<String> orientationOptions = ["Straight", "Gay", "Lesbian", "Bisexual", "Asexual", "Demisexual", "Pansexual", "Queer", "Questioning"];
  final List<String> habitOptions = ["Yes", "Sometimes", "No"];

  // Intent Options
  final List<Map<String, String>> intentOptions = [
    {"title": "Life Partner", "subtitle": "Marriage or lifelong commitment"},
    {"title": "Long-term relationship", "subtitle": "Meaningful connection"},
    {"title": "Long-term, open to short", "subtitle": "Flexible journey"},
    {"title": "Open to options", "subtitle": "See where it goes"},
  ];

  // Discovery Options
  final List<String> interestOptions = ["Travel", "Photography", "Hiking", "Yoga", "Art", "Reading", "Fitness", "Music", "Movies", "Cooking", "Gaming", "Writing", "Meditation", "Tech", "Startups", "Dancing", "Cycling", "Swimming", "Pets", "Volunteering", "Astronomy", "Blogging", "DIY", "Podcasting"];
  final List<String> foodOptions = ["Coffee", "Tea", "Pizza", "Sushi", "Burgers", "Street Food", "Desserts", "Vegan", "BBQ", "Pasta", "Indian", "Thai", "Mexican", "Chinese", "Wine", "Cocktails", "Mocktails", "Smoothies", "Ice Cream", "Biryani"];
  final List<String> placeOptions = ["Beach", "Mountains", "Cafes", "Museums", "Art Galleries", "Hidden Bars", "Nature Trails", "Bookstores", "Rooftops", "Parks", "Gyms", "Libraries", "Music Venues", "Temples", "Historic Sites", "Street Markets"];

  // Prompt Questions
  final List<String> _promptQuestions = [
    "What I'd order for the table", "One thing to know about me", "My ideal Sunday",
    "I'm overly competitive about", "The way to win my heart", "My biggest pet peeve",
    "I geek out on", "A random fact I love", "My simple pleasures", "I'm looking for",
    "Unpopular opinion", "Two truths and a lie",
  ];

  @override
  void initState() {
    super.initState();
    _generateHeightOptions();
    _loadFromStore();
    _validationService.initialize();
    final user = FirebaseAuth.instance.currentUser;
    _loggedInWithPhone = user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty;
  }

  @override
  void dispose() {
    _validationService.dispose();
    super.dispose();
  }

  void _generateHeightOptions() {
    heightOptionsFeet = [];
    for (int feet = 4; feet <= 7; feet++) {
      for (int inches = 0; inches < 12; inches++) {
        heightOptionsFeet.add("$feet' $inches\"");
      }
    }
    heightOptionsCm = [];
    for (int cm = 120; cm <= 240; cm++) {
      heightOptionsCm.add("$cm cm");
    }
  }

  void _loadFromStore() {
    final store = ProfileStore.instance;
    nameController.text = store.name ?? '';
    selectedDate = store.birthday;
    if (selectedDate != null) {
      selectedAge = DateTime.now().year - selectedDate!.year;
    } else {
      selectedAge = 25; 
    }

    if (store.height != null) {
      if (heightOptionsCm.contains(store.height)) {
        isFeet = false;
        selectedHeight = store.height;
        _selectedHeightIndex = heightOptionsCm.indexOf(store.height!);
      } else if (heightOptionsFeet.contains(store.height)) {
        isFeet = true;
        selectedHeight = store.height;
        _selectedHeightIndex = heightOptionsFeet.indexOf(store.height!);
      }
    } else {
      selectedHeight = heightOptionsFeet[20];
    }
    
    selectedGender = store.gender;
    selectedOrientation = store.sexualOrientation;
    selectedPronouns = store.pronouns; 
    selectedEthnicity = store.ethnicity;
    selectedReligion = store.religion;
    
    if (store.education != null && store.education!.contains(" - ")) {
       final parts = store.education!.split(" - ");
       selectedEducationLevel = parts[0];
       if (parts.length > 1) schoolNameController.text = parts[1];
    } else {
       selectedEducationLevel = store.education;
    }

    jobController.text = store.jobTitle ?? '';
    if (store.languages != null && store.languages!.isNotEmpty) {
      selectedLanguages = store.languages!.split(', ');
    }
    
    selectedPolitics = store.politicalViews;
    selectedKids = store.kids;
    selectedStarSign = store.starSign;
    selectedPets = store.pets;
    drinkStatus = store.drink;
    smokeStatus = store.smoke;
    weedStatus = store.weed;
    location = store.location;
    selectedIntent = store.intent;
    selectedInterests = List.from(store.interests);
    selectedFoods = List.from(store.foods);
    selectedPlaces = List.from(store.places);
    
    // Load Photos
    for (int i = 0; i < store.photos.length && i < 6; i++) {
      _photos[i] = store.photos[i];
    }
  }

  // --- Navigation & Validation ---

  Future<void> _handleLogout() async {
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint("Error signing out: $e");
    }
  }

  void _prevPage() {
    FocusManager.instance.primaryFocus?.unfocus(); // Close keyboard on navigation
    if (_currentQuestionIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentQuestionIndex--;
      });
    } else {
      _handleLogout();
    }
  }

  void _nextPage() {
    FocusManager.instance.primaryFocus?.unfocus(); // Close keyboard on navigation

    if (!_validateCurrentStep()) return;

    _saveToStore();

    if (_currentQuestionIndex == _totalQuestionScreens - 1) {
      _showLegalConsentPopup();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  bool _validateCurrentStep() {
    switch (_currentQuestionIndex) {
      case 0:
        final nameError = ContentModerator.validatePromptText(nameController.text);
        if (nameError != null) { _showNotification(nameError); return false; }
        return nameController.text.trim().length >= 2;
      case 1:
        final val = _contactController.text.trim();
        if (val.isEmpty) {
          _showNotification(_loggedInWithPhone ? 'Please enter your email address' : 'Please enter your phone number');
          return false;
        }
        if (_loggedInWithPhone) {
          // asking for email — basic format check
          if (!val.contains('@') || !val.contains('.')) {
            _showNotification('Please enter a valid email address');
            return false;
          }
        } else {
          // asking for phone — must be digits only, 7–15 chars
          if (!RegExp(r'^\+?[\d\s\-]{7,15}$').hasMatch(val)) {
            _showNotification('Please enter a valid phone number');
            return false;
          }
        }
        return true;
      case 2: return selectedAge != null;
      case 3: return selectedGender != null;
      case 4: return selectedOrientation != null;
      case 5: return selectedPronouns != null;
      case 6: return location != null;
      case 7: return selectedEthnicity != null;
      case 8: return selectedHeight != null;
      case 9: return selectedReligion != null;
      case 10:
        final eduError = ContentModerator.validatePromptText(schoolNameController.text);
        if (eduError != null) { _showNotification(eduError); return false; }
        return true;
      case 11:
        final jobError = ContentModerator.validatePromptText(jobController.text);
        if (jobError != null) { _showNotification(jobError); return false; }
        return true;
      case 12: return selectedLanguages.isNotEmpty;
      case 13: return true;
      case 14: return true;
      case 15: return selectedStarSign != null;
      case 16: return true;
      case 17: return true;
      case 18: return true;
      case 19: return selectedIntent != null;
      case 20: return selectedInterests.isNotEmpty;
      case 21: return selectedFoods.isNotEmpty;
      case 22: return selectedPlaces.isNotEmpty;
      case 23: return _photos.where((p) => p != null).length >= 2;
      case 24:
        for (var slot in _promptSlots) {
          if (slot != null) {
            final promptError = ContentModerator.validatePromptText(slot['answer']);
            if (promptError != null) { _showNotification(promptError); return false; }
          }
        }
        return _promptSlots.every((slot) => slot != null);
      case 25: return true; // Permissions step
    }
    return true;
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
                style: GoogleFonts.figtree(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: kBlack,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 4),
        elevation: 4,
      ),
    );
  }

  void _saveToStore() {
    final store = ProfileStore.instance;
    store.name = nameController.text.trim();
    if (selectedAge != null) {
      final birthYear = DateTime.now().year - selectedAge!;
      store.birthday = DateTime(birthYear, 1, 1);
    }
    store.height = selectedHeight;
    store.gender = selectedGender;
    store.sexualOrientation = selectedOrientation;
    store.pronouns = selectedPronouns;
    store.ethnicity = selectedEthnicity;
    store.religion = selectedReligion;
    if (selectedEducationLevel != null) {
       String edu = selectedEducationLevel!;
       if (schoolNameController.text.isNotEmpty) {
         edu += " - ${schoolNameController.text.trim()}";
       }
       store.education = edu;
    }
    store.jobTitle = jobController.text.trim();
    store.languages = selectedLanguages.join(', ');
    store.politicalViews = selectedPolitics;
    store.kids = selectedKids;
    store.starSign = selectedStarSign;
    store.pets = selectedPets;
    store.drink = drinkStatus;
    store.smoke = smokeStatus;
    store.weed = weedStatus;
    store.location = location;
    
    // New Fields
    store.intent = selectedIntent;
    store.interests = selectedInterests;
    store.foods = selectedFoods;
    store.places = selectedPlaces;
    store.photos = _photos.whereType<File>().toList();
  }

  Future<void> _submitProfile() async {
    setState(() => _isUploading = true);
    try {
      final supabase = Supabase.instance.client;
      final store = ProfileStore.instance;
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception("User not logged in");

      List<String> photoUrls = [];
      for (var file in store.photos) {
        final fileExt = file.path.split('.').last; 
        final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        await supabase.storage.from('user_photos').upload(fileName, file);
        final imageUrl = supabase.storage.from('user_photos').getPublicUrl(fileName);
        photoUrls.add(imageUrl);
      }

      final profileData = {
        'id': userId,
        'full_name': store.name,
        'birthday': store.birthday?.toIso8601String(),
        'gender': store.gender,
        'sexual_orientation': store.sexualOrientation,
        'pronouns': store.pronouns,
        'ethnicity': store.ethnicity,
        'height': store.height,
        'religion': store.religion,
        'education': store.education,
        'job_title': store.jobTitle,
        'languages': store.languages,
        'political_views': store.politicalViews,
        'kids': store.kids,
        'star_sign': store.starSign,
        'pets': store.pets,
        'drink': store.drink,
        'smoke': store.smoke,
        'weed': store.weed,
        'location': store.location,
        'intent': store.intent,
        'interests': store.interests,
        'foods': store.foods,
        'places': store.places,
        'photo_urls': photoUrls,
        'prompts': _promptSlots,
        'is_verified': false,
        'created_at': DateTime.now().toIso8601String(),
        if (_contactController.text.trim().isNotEmpty)
          (_loggedInWithPhone ? 'email' : 'phone'): _contactController.text.trim(),
      };

      await supabase.from('profiles').upsert(profileData);

      if (mounted) {
        store.clear();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SuccessScreen()), 
        );
      }
    } catch (e) {
      if (mounted) _showNotification("Error uploading: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showLegalConsentPopup() {
    bool isAgeTruthChecked = false;
    bool isLegalAgreementsChecked = false;
    bool isBiometricConsentChecked = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool allChecked = isAgeTruthChecked && isLegalAgreementsChecked && isBiometricConsentChecked;

            return AlertDialog(
              backgroundColor: kTan,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              title: Text(
                "Legal Confirmation",
                style: GoogleFonts.gabarito(
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                  color: kBlack,
                ),
              ),
              content: Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildConsentTile(
                        "Legal Age & Truthfulness: I declare under penalty of perjury that I am at least 18 years of age. I affirm that all information and photographs I provide are entirely truthful, accurate, and represent my actual identity.",
                        isAgeTruthChecked,
                        (val) => setState(() => isAgeTruthChecked = val ?? false),
                      ),
                      const SizedBox(height: 16),
                      _buildConsentTile(
                        "Master Legal Agreements: I have read, understood, and agree to be bound by the Clush Terms of Service, Privacy Policy, and Community Guidelines.",
                        isLegalAgreementsChecked,
                        (val) => setState(() => isLegalAgreementsChecked = val ?? false),
                      ),
                      const SizedBox(height: 16),
                      _buildConsentTile(
                        "Explicit Biometric Consent: I explicitly consent to the temporary processing of my facial biometric data strictly for the purpose of identity verification. I understand this video will not be permanently stored, shared, or sold to third parties.",
                        isBiometricConsentChecked,
                        (val) => setState(() => isBiometricConsentChecked = val ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancel", style: GoogleFonts.figtree(color: kInkMuted, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: allChecked
                            ? () {
                                Navigator.pop(context);
                                _submitProfile();
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kRose,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: kRose.withOpacity(0.3),
                          disabledForegroundColor: Colors.white70,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Text("Continue", style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildConsentTile(String text, bool value, ValueChanged<bool?> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: kRose,
                checkColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                side: BorderSide(color: kInkMuted.withOpacity(0.4), width: 1.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.figtree(
                  color: kBlack,
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Location Logic ---
  Future<void> _fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showNotification("Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showNotification("Location permissions are denied.");
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showNotification("Location permissions are permanently denied.");
        return;
      }

      // Show loading indicator logic could be added here
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      _currentMapCenter = LatLng(position.latitude, position.longitude);
      _mapController.move(_currentMapCenter, 13.0);
    } catch (e) {
      debugPrint("Location Error: $e");
      _showNotification("Could not fetch location.");
    }
  }

  Future<void> _confirmMapLocation() async {
    setState(() => _isMapLoading = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(_currentMapCenter.latitude, _currentMapCenter.longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Format: "Locality, City, State(Lat,Lng)"
        String area = place.subLocality ?? place.thoroughfare ?? "";
        String city = place.locality ?? place.subAdministrativeArea ?? "";
        String state = place.administrativeArea ?? "";
        
        // Construct visual portion (Area, City)
        List<String> displayParts = [];
        if (area.isNotEmpty) displayParts.add(area);
        if (city.isNotEmpty && city != area) displayParts.add(city);
        if (displayParts.isEmpty && state.isNotEmpty) displayParts.add(state);
        
        String displayString = displayParts.join(", ");
        if (displayString.isEmpty) displayString = "Selected Location";
        
        // Exact location format representing "displayString, state(lat,lng)"
        String exactLocation = "$displayString, $state(${_currentMapCenter.latitude},${_currentMapCenter.longitude})";
        
        setState(() {
          location = exactLocation;
          _isMapLoading = false;
        });
        
        // Just unfocus keyboard, user must press continue
        FocusManager.instance.primaryFocus?.unfocus();
      } else {
        setState(() => _isMapLoading = false);
        _showNotification("Could not identify location name.");
      }
    } catch (e) {
      setState(() => _isMapLoading = false);
      debugPrint("Confirm Location Error: $e");
      _showNotification("Failed to lock location.");
    }
  }

  Future<void> _searchMapLocation(String query) async {
    if (query.trim().isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        setState(() {
          _currentMapCenter = LatLng(loc.latitude, loc.longitude);
        });
        _mapController.move(_currentMapCenter, 13.0);
      } else {
        _showNotification("Location not found.");
      }
    } catch (e) {
      _showNotification("Could not find address: $query");
    }
  }

  String _getDisplayLocation(String loc) {
    if (loc.contains("(")) {
      return loc.split("(")[0].trim();
    }
    return loc;
  }

  // --- Discovery Tracking & Custom Data ---
  int _getTotalDiscoverySelections() {
    return selectedInterests.length + selectedFoods.length + selectedPlaces.length;
  }

  void _showAddCustomOptionDialog(String title, List<String> currentSelections, Function(String) onAdded) {
    TextEditingController customCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Add Custom $title", style: GoogleFonts.figtree(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: customCtrl,
          autofocus: true,
          style: GoogleFonts.figtree(color: kBlack),
          decoration: const InputDecoration(hintText: "Type here...", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: GoogleFonts.figtree(color: kInkMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRose, foregroundColor: Colors.white),
            onPressed: () {
              final val = customCtrl.text.trim();
              if (val.isNotEmpty) {
                onAdded(val);
              }
              Navigator.pop(context);
            },
            child: Text("Add", style: GoogleFonts.figtree(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    final progress = (_currentQuestionIndex + 1) / _totalQuestionScreens;

    return Scaffold(
      backgroundColor: kTan,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: _prevPage,
                    color: kBlack,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          color: kRose,
                          backgroundColor: kBone,
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 20),
                    onPressed: _handleLogout,
                    color: kBlack,
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildSimpleInputStep("What's your first name?", nameController, "Your Name", TextInputType.name),
                  _buildContactStep(),
                  _buildAgeLadderStep(),
                  _buildChipStep("How do you identify?", genderOptions, selectedGender, (val) => setState(() => selectedGender = val)),
                  _buildChipStep("Sexual Orientation", orientationOptions, selectedOrientation, (val) => setState(() => selectedOrientation = val)),
                  _buildChipStep("What are your pronouns?", pronounOptions, selectedPronouns, (val) => setState(() => selectedPronouns = val)),
                  _buildLocationStep(),
                  _buildChipStep("What is your ethnicity?", ethnicityOptions, selectedEthnicity, (val) => setState(() => selectedEthnicity = val)),
                  _buildHeightLadderStep(),
                  _buildChipStep("What is your religion?", religionOptions, selectedReligion, (val) => setState(() => selectedReligion = val)),
                  _buildEducationStep(),
                  _buildSimpleInputStep("What do you do for work?", jobController, "Job Title", TextInputType.text),
                  _buildMultiSelectStep("Languages you speak?", languageOptions, selectedLanguages, (val) {
                     setState(() => selectedLanguages.contains(val) ? selectedLanguages.remove(val) : selectedLanguages.add(val));
                  }),
                  _buildChipStep("Political Views", politicalOptions, selectedPolitics, (val) => setState(() => selectedPolitics = val)),
                  _buildChipStep("Do you have/want kids?", kidsOptions, selectedKids, (val) => setState(() => selectedKids = val)),
                  _buildChipStep("What's your Star Sign?", starSigns, selectedStarSign, (val) => setState(() => selectedStarSign = val)),
                  _buildChipStep("Do you have pets?", petsOptions, selectedPets, (val) => setState(() => selectedPets = val)),
                  _buildChipStep("Do you exercise?", exerciseOptions, selectedExercise, (val) => setState(() => selectedExercise = val)),
                  _buildSocialHabitsStep(),
                  _buildIntentStep(),
                  _buildDiscoveryStep("Interests & Hobbies", interestOptions, selectedInterests),
                  _buildDiscoveryStep("Favorite Foods", foodOptions, selectedFoods),
                  _buildDiscoveryStep("Favorite Places", placeOptions, selectedPlaces),
                  _buildPhotoStep(),
                  _buildPromptsStep(),
                  _buildPermissionsStep(),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(kPadding),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRose,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: (_currentQuestionIndex == _totalQuestionScreens - 1 && _isUploading) ? null : _nextPage,
                      child: _isUploading 
                        ? const HeartLoader(size: 24, color: Colors.white)
                        : Text(_currentQuestionIndex == _totalQuestionScreens - 1 ? "Finish Profile" : "Continue", style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  // Optional Skip Button for specific screens
                  if ([9, 10, 12, 13, 15, 16, 17].contains(_currentQuestionIndex)) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        // Clear the selection for that specific optional step if they explicitly hit skip
                        setState(() {
                             if (_currentQuestionIndex == 9) { selectedEducationLevel = null; schoolNameController.clear(); }
                        else if (_currentQuestionIndex == 10) jobController.clear();
                        else if (_currentQuestionIndex == 12) selectedPolitics = null;
                        else if (_currentQuestionIndex == 13) selectedKids = null;
                        else if (_currentQuestionIndex == 15) selectedPets = null;
                        else if (_currentQuestionIndex == 16) selectedExercise = null;
                        else if (_currentQuestionIndex == 17) { drinkStatus = null; smokeStatus = null; weedStatus = null; }
                        });
                        // Skip validation and force next page
                        if (_currentQuestionIndex < _totalQuestionScreens - 1) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          _saveToStore();
                          _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOutCubic);
                          setState(() => _currentQuestionIndex++);
                        }
                      },
                      child: Text("Skip for now", style: GoogleFonts.figtree(color: kInkMuted, fontWeight: FontWeight.w500)),
                    )
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildStepContainer({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start, 
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30), 
          Text(title, style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 30, height: 1.1, color: kBlack)),
          const SizedBox(height: 24),
          Expanded(child: child), 
        ],
      ),
    );
  }

  Widget _buildContactStep() {
    final isPhone = _loggedInWithPhone;
    return _buildStepContainer(
      title: isPhone ? "What's your email?" : "What's your phone number?",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPhone
                ? "Add an email so you can recover your account if you lose access to your number."
                : "Add a phone number for account security and recovery.",
            style: GoogleFonts.figtree(fontSize: 15, color: kInkMuted, height: 1.5),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _contactController,
            keyboardType: isPhone ? TextInputType.emailAddress : TextInputType.phone,
            style: GoogleFonts.figtree(fontSize: 20, color: kBlack),
            decoration: InputDecoration(
              hintText: isPhone ? "your@email.com" : "+1 234 567 8900",
              prefixIcon: Icon(
                isPhone ? Icons.email_outlined : Icons.phone_outlined,
                color: kRose,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleInputStep(String title, TextEditingController controller, String hint, TextInputType type) {
    return _buildStepContainer(
      title: title,
      child: Column(
        children: [
          TextField(
            controller: controller,
            keyboardType: type,
            style: GoogleFonts.figtree(fontSize: 20, color: kBlack),
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationStep() {
    return _buildStepContainer(
      title: "Education",
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: educationLevelOptions.map((level) {
                final isSelected = selectedEducationLevel == level;
                // Matches style of _buildChipStep exactly
                return ChoiceChip(
                  label: Text(level),
                  selected: isSelected,
                  selectedColor: kRose,
                  backgroundColor: kCream,
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  labelStyle: GoogleFonts.figtree(
                    color: isSelected ? Colors.white : kBlack, 
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: isSelected ? kRose : Colors.transparent)),
                  onSelected: (val) => setState(() => selectedEducationLevel = level),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text("School / College Name (Optional)", style: GoogleFonts.figtree(fontWeight: FontWeight.bold, color: kBlack)),
            const SizedBox(height: 8),
            TextField(
              controller: schoolNameController,
              style: GoogleFonts.figtree(fontSize: 18, color: kBlack),
              decoration: InputDecoration(
                hintText: "e.g. Harvard University",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Age & Height --- (No Changes to logic, kept for completeness)
  Widget _buildAgeLadderStep() {
    return _buildStepContainer(
      title: "How old are you?",
      child: Center(
        child: SizedBox(
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 60,
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: kRose, width: 2), bottom: BorderSide(color: kRose, width: 2))),
              ),
              ListWheelScrollView.useDelegate(
                itemExtent: 60,
                perspective: 0.003,
                physics: const FixedExtentScrollPhysics(),
                controller: FixedExtentScrollController(initialItem: (selectedAge ?? 25) - 18),
                onSelectedItemChanged: (index) => setState(() => selectedAge = index + 18),
                childDelegate: ListWheelChildBuilderDelegate(
                  builder: (context, index) {
                    final age = index + 18;
                    final isSelected = age == selectedAge;
                    return Center(child: Text("$age", style: GoogleFonts.figtree(fontSize: isSelected ? 34 : 24, color: isSelected ? kBlack : kInkMuted.withOpacity(0.7), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)));
                  },
                  childCount: 82, 
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeightLadderStep() {
    final currentList = isFeet ? heightOptionsFeet : heightOptionsCm;
    return _buildStepContainer(
      title: "How tall are you?",
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(color: kParchment, borderRadius: BorderRadius.circular(30)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [_buildToggleBtn("Feet", isFeet), _buildToggleBtn("CM", !isFeet)]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 60,
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: kRose, width: 2), bottom: BorderSide(color: kRose, width: 2))),
                ),
                ListWheelScrollView.useDelegate(
                  key: ValueKey(isFeet),
                  itemExtent: 60,
                  perspective: 0.003,
                  physics: const FixedExtentScrollPhysics(),
                  controller: FixedExtentScrollController(initialItem: _selectedHeightIndex),
                  onSelectedItemChanged: (index) {
                     setState(() {
                       _selectedHeightIndex = index;
                       if (index >= 0 && index < currentList.length) selectedHeight = currentList[index];
                     });
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, index) {
                      if (index < 0 || index >= currentList.length) return null;
                      final isSelected = index == _selectedHeightIndex;
                      return Center(child: Text(currentList[index], style: GoogleFonts.figtree(fontSize: isSelected ? 26 : 20, color: isSelected ? kBlack : kInkMuted.withOpacity(0.7), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)));
                    },
                    childCount: currentList.length,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          setState(() {
            isFeet = !isFeet;
            _selectedHeightIndex = 20; 
            selectedHeight = isFeet ? heightOptionsFeet[20] : heightOptionsCm[20];
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(color: isActive ? kRose : Colors.transparent, borderRadius: BorderRadius.circular(30)),
        child: Text(label, style: GoogleFonts.figtree(color: isActive ? Colors.white : kBlack, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- Chips (Standardized) ---

  Widget _buildChipStep(String title, List<String> options, String? selectedValue, Function(String) onSelect) {
    return _buildStepContainer(
      title: title,
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              selectedColor: kRose,
              backgroundColor: kCream,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              labelStyle: GoogleFonts.figtree(color: isSelected ? Colors.white : kBlack, fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: isSelected ? kRose : Colors.transparent)),
              onSelected: (selected) { if (selected) onSelect(option); },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMultiSelectStep(String title, List<String> options, List<String> currentSelections, Function(String) onToggle) {
    return _buildStepContainer(
      title: title,
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...options.map((option) {
              final isSelected = currentSelections.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                selectedColor: kRose,
                backgroundColor: kCream,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                labelStyle: GoogleFonts.figtree(color: isSelected ? Colors.white : kBlack, fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: isSelected ? kRose : Colors.transparent)),
                onSelected: (_) => onToggle(option),
              );
            }),
            // Add Custom Option Button
            ActionChip(
              label: Text("+ Add your own"),
              backgroundColor: kBone,
              labelStyle: GoogleFonts.figtree(color: kInkMuted, fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: kBone)),
              onPressed: () {
                _showAddCustomOptionDialog(title, currentSelections, (newVal) {
                  setState(() {
                    if (!options.contains(newVal)) options.add(newVal);
                    if (!currentSelections.contains(newVal)) currentSelections.add(newVal);
                  });
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Location with Detection ---
  Widget _buildLocationStep() {
    return _buildStepContainer(
      title: "Where are you located?",
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _mapSearchController,
            style: GoogleFonts.figtree(color: kBlack),
            onSubmitted: _searchMapLocation,
            decoration: InputDecoration(
              hintText: "Search a city...",
              hintStyle: GoogleFonts.figtree(color: kInkMuted),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: kRose),
                onPressed: () => _searchMapLocation(_mapSearchController.text),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Interactive Map Area
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentMapCenter,
                      initialZoom: 13.0,
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture) {
                          _currentMapCenter = position.center;
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
                  // Center Pin Overlay (Doesn't move with the map)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 40), // Offset slightly to point correctly
                    child: Icon(Icons.location_on, color: kRose, size: 48),
                  ),
                  // Current GPS Location Button
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: kCream,
                      onPressed: _fetchCurrentLocation,
                      child: const Icon(Icons.my_location, color: kBlack),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Confirm Pin Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kRose, width: 2),
                backgroundColor: kCream,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: _isMapLoading ? null : _confirmMapLocation,
              child: _isMapLoading 
                ? const HeartLoader(size: 24)
                : Text("Confirm Pin Location", style: GoogleFonts.figtree(color: kRose, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          if (location != null) ...[
             const SizedBox(height: 16),
             Text("Currently: ${_getDisplayLocation(location!)}", style: GoogleFonts.figtree(color: kInkMuted, fontSize: 14)),
          ]
        ],
      ),
    );
  }

  // --- Social Habits (Updated to match Chip style) ---
  Widget _buildSocialHabitsStep() {
    return _buildStepContainer(
      title: "Social Habits",
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHabitRow("Do you drink?", drinkStatus, (val) => setState(() => drinkStatus = val)),
            const SizedBox(height: 24),
            _buildHabitRow("Do you smoke?", smokeStatus, (val) => setState(() => smokeStatus = val)),
            const SizedBox(height: 24),
            _buildHabitRow("Weed?", weedStatus, (val) => setState(() => weedStatus = val)),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitRow(String label, String? current, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.bold, color: kBlack)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, children: habitOptions.map((opt) {
          final isSelected = current == opt;
          return ChoiceChip(
            label: Text(opt),
            selected: isSelected,
            selectedColor: kRose,
            backgroundColor: kCream,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            labelStyle: GoogleFonts.figtree(color: isSelected ? Colors.white : kBlack, fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: isSelected ? kRose : Colors.transparent)),
            onSelected: (val) => onSelect(opt),
          );
        }).toList()),
      ],
    );
  }

  // --- Intent & Discovery (Kept Same) ---
  Widget _buildIntentStep() {
    return _buildStepContainer(
      title: "What are you looking for?",
      child: ListView.separated(
        itemCount: intentOptions.length,
        separatorBuilder: (c, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = intentOptions[index];
          final title = item['title']!;
          final isSelected = selectedIntent == title;
          return GestureDetector(
            onTap: () => setState(() => selectedIntent = title),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isSelected ? kRose : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? kRose : Colors.transparent),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: GoogleFonts.figtree(color: isSelected ? Colors.white : kBlack, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(item['subtitle']!, style: GoogleFonts.figtree(color: isSelected ? Colors.white70 : kInkMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiscoveryStep(String title, List<String> options, List<String> selectionList) {
    return _buildStepContainer(
      title: title,
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            ...options.map((option) {
              final isSelected = selectionList.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                selectedColor: kRose,
                backgroundColor: kCream,
                showCheckmark: false,
                labelStyle: GoogleFonts.figtree(color: isSelected ? Colors.white : kBlack, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: isSelected ? kRose : Colors.transparent)),
                onSelected: (_) {
                  setState(() {
                    if (isSelected) {
                      selectionList.remove(option);
                    } else {
                      if (_getTotalDiscoverySelections() >= 15) {
                        _showNotification("You can choose up to 15 combined discovery traits.");
                      } else {
                        selectionList.add(option);
                      }
                    }
                  });
                },
              );
            }),
            ActionChip(
              label: Text("+ Add your own"),
              backgroundColor: kBone,
              labelStyle: GoogleFonts.figtree(color: kInkMuted, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: kBone)),
              onPressed: () {
                if (_getTotalDiscoverySelections() >= 15) {
                   _showNotification("You can choose up to 15 combined discovery traits.");
                   return;
                }
                _showAddCustomOptionDialog(title, selectionList, (newVal) {
                  setState(() {
                    if (!options.contains(newVal)) options.add(newVal);
                    if (!selectionList.contains(newVal)) selectionList.add(newVal);
                  });
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Photos (Redesigned) ---
  Widget _buildPhotoStep() {
    return _buildStepContainer(
      title: "Add your photos",
      child: Column(
        children: [
          Text("Add at least 2 photos. Tap a slot to add.", style: GoogleFonts.figtree(color: kInkMuted, fontSize: 16)),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, 
                crossAxisSpacing: 10, 
                mainAxisSpacing: 10, 
                childAspectRatio: 0.7
              ),
              itemBuilder: (context, index) {
                final photoFile = _photos[index];
                final isValidating = _validatingIndex == index;

                return GestureDetector(
                  onTap: () => (photoFile == null && !isValidating) ? _showPhotoOptions(index) : (photoFile != null ? _removeImage(index) : null),
                  child: Container(
                    decoration: BoxDecoration(color: kParchment,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: photoFile == null && index < 2 ? kRose : Colors.transparent, width: 2), // Highlight required slots
                      boxShadow: [BoxShadow(color: kInk.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: isValidating
                        ? const Center(child: HeartLoader())
                        : photoFile != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.file(photoFile, fit: BoxFit.cover)),
                                  const Positioned(bottom: 4, right: 4, child: CircleAvatar(radius: 10, backgroundColor: kCream, child: Icon(Icons.close, size: 14, color: kRose))),
                                ],
                              )
                            : Icon(Icons.add_a_photo, color: index < 2 ? kRose : kInkMuted.withOpacity(0.5)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoOptions(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.photo_library), title: const Text("Gallery"), onTap: () { Navigator.pop(ctx); _pickImage(index, ImageSource.gallery); }),
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text("Camera"), onTap: () { Navigator.pop(ctx); _pickImage(index, ImageSource.camera); }),
          ],
        ),
      ),
    );
  }

  Future<bool> _scanImageWithPython(File image) async {
    final result = await _validationService.checkTextModeration(image);
    return result.isValid;
  }

  Future<void> _pickImage(int index, ImageSource source) async {
    final XFile? img = await _picker.pickImage(source: source, imageQuality: 80);
    if (img == null) return;

    final File selectedImage = File(img.path);
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
      final result = await _validationService.validateImage(selectedImage, index);

      if (mounted) {
        if (result.isValid) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          setState(() => _photos[index] = selectedImage);
        } else {
          _showNotification(result.errorMessage ?? "Invalid image");
        }
      }
    } catch (e) {
      if (mounted) _showNotification("Validation error: $e");
    } finally {
      if (mounted) setState(() => _validatingIndex = null);
    }
  }

  void _removeImage(int index) => setState(() => _photos[index] = null);

  // --- Prompts (Restored UI Logic) ---
  Widget _buildPromptsStep() {
    return _buildStepContainer(
      title: "Write your profile answers",
      child: Column(
        children: [
          Text("Pick 3 prompts to help others get to know you better.", style: GoogleFonts.figtree(color: kInkMuted, fontSize: 16)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final slot = _promptSlots[index];
                return GestureDetector(
                  onTap: () => slot != null ? _showAnswerDialog(index, slot['question']!) : _showPromptSelector(index),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(color: kParchment,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kRose.withOpacity(0.5)),
                    ),
                    child: slot == null
                        ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add, color: kRose), const SizedBox(width: 8), Text("Select a Prompt", style: GoogleFonts.figtree(color: kRose, fontWeight: FontWeight.bold))])
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(slot['question']!.toUpperCase(), style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: kRose, letterSpacing: 0.5))),
                                  GestureDetector(onTap: () => setState(() => _promptSlots[index] = null), child: const Icon(Icons.close, size: 16, color: kInkMuted)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(slot['answer']!, style: GoogleFonts.figtree(fontSize: 16, color: kBlack, fontWeight: FontWeight.w500)),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPromptSelector(int index) {
    // Filter out already selected questions
    final usedQuestions = _promptSlots.where((s) => s != null).map((s) => s!['question']).toSet();
    final availableQuestions = _promptQuestions.where((q) => !usedQuestions.contains(q)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          expand: false,
          builder: (context, controller) {
            return Column(
              children: [
                const SizedBox(height: 16),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: kInkMuted.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text("Pick a Prompt", style: GoogleFonts.figtree(fontWeight: FontWeight.bold, fontSize: 18, color: kBlack)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    itemCount: availableQuestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      return ListTile(
                        title: Text(availableQuestions[idx], style: GoogleFonts.figtree(color: kBlack, fontWeight: FontWeight.w500)),
                        trailing: const Icon(Icons.chevron_right, size: 16, color: kInkMuted),
                        onTap: () {
                          Navigator.pop(context);
                          _showAnswerDialog(index, availableQuestions[idx]);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAnswerDialog(int index, String question) {
    final textCtrl = TextEditingController(text: _promptSlots[index]?['answer'] ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(question, style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.bold, color: kBlack)),
        content: TextField(controller: textCtrl, autofocus: true, maxLines: 3, style: GoogleFonts.figtree(color: kBlack), decoration: const InputDecoration(hintText: "Type your answer...", border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: GoogleFonts.figtree(color: kInkMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRose, foregroundColor: Colors.white),
            onPressed: () {
              if (textCtrl.text.trim().isNotEmpty) {
                setState(() => _promptSlots[index] = {'question': question, 'answer': textCtrl.text.trim()});
                Navigator.pop(context);
              }
            },
            child: Text("Save", style: GoogleFonts.figtree(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildPermissionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: kPadding, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kRosePale,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security_rounded, color: kRose, size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            "Final Permissions",
            style: GoogleFonts.gabarito(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: kBlack,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Grant these permissions to get the full Clush experience. We prioritize your privacy.",
            style: GoogleFonts.figtree(
              fontSize: 16,
              color: kInkMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 48),
          
          _buildPermissionTile(
            "Location",
            "To find amazing people near you.",
            Icons.location_on_outlined,
            () async {
              final granted = await PermissionRequestPage.show(context, PermissionType.location);
              if (granted == true) {
                await _fetchCurrentLocation();
              }
            }
          ),
          
          const SizedBox(height: 16),
          
          _buildPermissionTile(
            "Notifications",
            "To never miss a match or message.",
            Icons.notifications_none_outlined,
            () async {
              final granted = await PermissionRequestPage.show(context, PermissionType.notifications);
              if (granted == true) {
                await NotificationService().initNotifications(context: context, force: true);
              }
            }
          ),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: kParchment,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBone),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kCream,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: kRose, size: 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.figtree(fontWeight: FontWeight.bold, color: kBlack, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.figtree(fontSize: 13, color: kInkMuted),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kInkMuted),
        onTap: onTap,
      ),
    );
  }
}

// End of file
