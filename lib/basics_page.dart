import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'main.dart';
import 'profile_store.dart';
import 'success_screen.dart'; 

// --- Theme Constants ---
const Color kTan = Color(0xFFE9E6E1);
const Color kRose = Color(0xFFCD9D8F);
const Color kBlack = Color(0xFF2D2D2D);
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
  
  // Total steps
  final int _totalQuestionScreens = 24; 

  // --- Controllers (Text) ---
  final TextEditingController nameController = TextEditingController();
  final TextEditingController jobController = TextEditingController();
  final TextEditingController schoolNameController = TextEditingController();

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
      _submitProfile();
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
      case 0: return nameController.text.trim().length >= 2;
      case 1: return selectedAge != null;
      case 2: return selectedGender != null;
      case 3: return selectedOrientation != null;
      case 4: return selectedPronouns != null;
      case 5: return location != null;
      case 6: return selectedEthnicity != null;
      case 7: return selectedHeight != null;
      case 8: return selectedReligion != null;
      case 9: return selectedEducationLevel != null;
      case 10: return jobController.text.trim().isNotEmpty;
      case 11: return selectedLanguages.isNotEmpty;
      case 12: return selectedPolitics != null;
      case 13: return selectedKids != null;
      case 14: return selectedStarSign != null;
      case 15: return selectedPets != null;
      case 16: return selectedExercise != null;
      case 17: return drinkStatus != null && smokeStatus != null && weedStatus != null;
      case 18: return selectedIntent != null;
      case 19: return selectedInterests.isNotEmpty; 
      case 20: return selectedFoods.isNotEmpty; 
      case 21: return selectedPlaces.isNotEmpty; 
      case 22: return _photos.where((p) => p != null).length >= 2; 
      case 23: return _promptSlots.every((slot) => slot != null); 
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
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
        'created_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('profiles').upsert(profileData);

      if (mounted) {
        store.clear();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SuccessScreen()), 
        );
      }
    } catch (e) {
      if (mounted) _showError("Error uploading: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- Location Logic ---
  Future<void> _fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError("Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError("Location permissions are denied.");
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showError("Location permissions are permanently denied.");
        return;
      }

      // Show loading indicator logic could be added here
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Format: "City, Country" or "City, State"
        String city = place.locality ?? place.subAdministrativeArea ?? "";
        String country = place.country ?? "";
        
        setState(() {
          location = "$city, $country";
        });
      }
    } catch (e) {
      debugPrint("Location Error: $e");
      _showError("Could not fetch location.");
    }
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
                          backgroundColor: Colors.black12,
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
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(kPadding),
              child: SizedBox(
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
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_currentQuestionIndex == _totalQuestionScreens - 1 ? "Finish Profile" : "Continue", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
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
          Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, height: 1.1, color: kBlack)),
          const SizedBox(height: 24),
          Expanded(child: child), 
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
            style: const TextStyle(fontSize: 20),
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
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black, 
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: isSelected ? kRose : Colors.transparent)),
                  onSelected: (val) => setState(() => selectedEducationLevel = level),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text("School / College Name (Optional)", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: schoolNameController,
              style: const TextStyle(fontSize: 18),
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
                    return Center(child: Text("$age", style: TextStyle(fontSize: isSelected ? 34 : 24, color: isSelected ? kBlack : Colors.grey[400], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)));
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
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
                      return Center(child: Text(currentList[index], style: TextStyle(fontSize: isSelected ? 26 : 20, color: isSelected ? kBlack : Colors.grey[400], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)));
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
        child: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
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
              backgroundColor: Colors.white,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
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
          children: options.map((option) {
            final isSelected = currentSelections.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              selectedColor: kRose,
              backgroundColor: Colors.white,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: isSelected ? kRose : Colors.transparent)),
              onSelected: (_) => onToggle(option),
            );
          }).toList(),
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
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const LocationSearchPage()));
              if (result != null) setState(() => location = result);
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Icon(Icons.location_city, color: kRose, size: 28),
                const SizedBox(width: 16),
                Expanded(child: Text(location ?? "Search City", style: TextStyle(fontSize: 18, color: location == null ? Colors.grey : kBlack, fontWeight: FontWeight.w500))),
                const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _fetchCurrentLocation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: kRose),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.my_location, color: kRose),
                  SizedBox(width: 8),
                  Text("Use Current Location", style: TextStyle(color: kRose, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
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
        Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, children: habitOptions.map((opt) {
          final isSelected = current == opt;
          return ChoiceChip(
            label: Text(opt),
            selected: isSelected,
            selectedColor: kRose,
            backgroundColor: Colors.white,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
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
                        Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(item['subtitle']!, style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey.shade600)),
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
          children: options.map((option) {
            final isSelected = selectionList.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              selectedColor: kRose,
              backgroundColor: Colors.white,
              showCheckmark: false,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: isSelected ? kRose : Colors.transparent)),
              onSelected: (_) {
                setState(() {
                  isSelected ? selectionList.remove(option) : selectionList.add(option);
                });
              },
            );
          }).toList(),
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
          const Text("Add at least 2 photos. Tap a slot to add.", style: TextStyle(color: Colors.grey, fontSize: 16)),
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
                return GestureDetector(
                  onTap: () => photoFile == null ? _showPhotoOptions(index) : _removeImage(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: photoFile == null && index < 2 ? kRose : Colors.transparent, width: 2), // Highlight required slots
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: photoFile != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.file(photoFile, fit: BoxFit.cover)),
                              const Positioned(bottom: 4, right: 4, child: CircleAvatar(radius: 10, backgroundColor: Colors.white, child: Icon(Icons.close, size: 14, color: kRose))),
                            ],
                          )
                        : Icon(Icons.add_a_photo, color: index < 2 ? kRose : Colors.grey[300]),
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

  Future<void> _pickImage(int index, ImageSource source) async {
    final XFile? img = await _picker.pickImage(source: source, imageQuality: 80);
    if (img != null) setState(() => _photos[index] = File(img.path));
  }

  void _removeImage(int index) => setState(() => _photos[index] = null);

  // --- Prompts (Restored UI Logic) ---
  Widget _buildPromptsStep() {
    return _buildStepContainer(
      title: "Write your profile answers",
      child: Column(
        children: [
          const Text("Pick 3 prompts to help others get to know you better.", style: TextStyle(color: Colors.grey, fontSize: 16)),
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
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kRose.withOpacity(0.5)),
                    ),
                    child: slot == null
                        ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.add, color: kRose), SizedBox(width: 8), Text("Select a Prompt", style: TextStyle(color: kRose, fontWeight: FontWeight.bold))])
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(slot['question']!.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kRose, letterSpacing: 0.5))),
                                  GestureDetector(onTap: () => setState(() => _promptSlots[index] = null), child: const Icon(Icons.close, size: 16, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(slot['answer']!, style: const TextStyle(fontSize: 16)),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          expand: false,
          builder: (context, controller) {
            return Column(
              children: [
                const SizedBox(height: 16),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text("Pick a Prompt", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    itemCount: availableQuestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      return ListTile(
                        title: Text(availableQuestions[idx]),
                        trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
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
        title: Text(question, style: const TextStyle(fontSize: 16)),
        content: TextField(controller: textCtrl, autofocus: true, maxLines: 3, decoration: const InputDecoration(hintText: "Type your answer...", border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRose, foregroundColor: Colors.white),
            onPressed: () {
              if (textCtrl.text.trim().isNotEmpty) {
                setState(() => _promptSlots[index] = {'question': question, 'answer': textCtrl.text.trim()});
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }
}

// --- Sub Page: Location Search ---
class LocationSearchPage extends StatefulWidget {
  const LocationSearchPage({super.key});
  @override
  State<LocationSearchPage> createState() => _LocationSearchPageState();
}

class _LocationSearchPageState extends State<LocationSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> allCities = ["New York, USA", "Los Angeles, USA", "Chicago, USA", "London, UK", "Paris, France", "Tokyo, Japan", "Mumbai, India", "Pune, India", "Delhi, India", "Toronto, Canada", "Berlin, Germany", "Sydney, Australia", "Dubai, UAE", "Singapore", "San Francisco, USA", "Seattle, USA", "Austin, USA"];
  List<String> filteredCities = [];

  @override
  void initState() {
    super.initState();
    filteredCities = allCities;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Set Location", style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context))),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (val) => setState(() => filteredCities = allCities.where((c) => c.toLowerCase().contains(val.toLowerCase())).toList()),
              decoration: InputDecoration(hintText: "Search city...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: kTan.withOpacity(0.5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 20),
            Expanded(child: ListView.separated(itemCount: filteredCities.length, separatorBuilder: (ctx, i) => const Divider(height: 1), itemBuilder: (context, index) => ListTile(title: Text(filteredCities[index]), leading: const Icon(Icons.location_city, color: Colors.grey), onTap: () => Navigator.pop(context, filteredCities[index])))),
          ],
        ),
      ),
    );
  }
}