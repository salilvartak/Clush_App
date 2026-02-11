import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// --- Theme Constants (Matches ProfileViewPage) ---
const Color kRose = Color(0xFFCD9D8F);
const Color kTan = Color(0xFFE9E6E1);
const Color kBlack = Color(0xFF2D2D2D);

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> currentData;

  const EditProfilePage({super.key, required this.currentData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // --- 1. State Variables ---
  late TextEditingController _nameController;
  late TextEditingController _jobController;
  late TextEditingController _schoolController;
  
  // Photos: Can be String (URL) or File (New Upload)
  List<dynamic> _photos = List.filled(6, null); 
  
  // Basic Stats
  String? _gender;
  String? _orientation;
  String? _pronouns;
  String? _ethnicity;
  String? _height;
  String? _religion;
  String? _politics;
  String? _starSign;
  String? _educationLevel;
  String? _location;
  
  // Lifestyle
  String? _drink;
  String? _smoke;
  String? _weed;
  String? _exercise;
  String? _kids;
  String? _pets;

  // Lists
  List<String> _languages = [];
  List<String> _interests = [];
  List<String> _foods = [];
  List<String> _places = [];
  
  // Prompts
  List<Map<String, dynamic>?> _prompts = [null, null, null];
  String? _intent;

  // --- 2. Options Lists (Mirrors BasicsPage) ---
  final List<String> genderOptions = ["Woman", "Man", "Non-binary"];
  final List<String> orientationOptions = ["Straight", "Gay", "Lesbian", "Bisexual", "Asexual", "Demisexual", "Pansexual", "Queer", "Questioning"];
  final List<String> pronounOptions = ["She/Her", "He/Him", "They/Them", "She/They", "He/They", "Prefer not to say"];
  final List<String> ethnicityOptions = ["Black/African Descent", "East Asian", "Hispanic/Latino", "Middle Eastern", "Native American", "Pacific Islander", "South Asian", "White/Caucasian", "Other"];
  final List<String> religionOptions = ["Hindu", "Muslim", "Christian", "Sikh", "Atheist", "Jewish", "Agnostic", "Buddhist", "Spiritual", "Catholic", "Other"];
  final List<String> politicalOptions = ["Liberal", "Moderate", "Conservative", "Not political", "Other"];
  final List<String> educationOptions = ["High School", "Undergraduate", "Postgraduate", "Trade School", "Other"];
  final List<String> kidsOptions = ["Want someday", "Don't want", "Have & want more", "Have & don't want more", "Not sure"];
  final List<String> petsOptions = ["Dog", "Cat", "Reptile", "Amphibian", "Bird", "Fish", "None", "Want one", "Allergic"];
  final List<String> exerciseOptions = ["Active", "Sometimes", "Almost never"];
  final List<String> habitOptions = ["Yes", "Sometimes", "No"];
  final List<String> starSigns = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"];
  final List<String> intentOptionsStrings = ["Life Partner", "Long-term relationship", "Long-term, open to short", "Open to options"];

  final List<String> interestOptions = ["Travel", "Photography", "Hiking", "Yoga", "Art", "Reading", "Fitness", "Music", "Movies", "Cooking", "Gaming", "Writing", "Meditation", "Tech", "Startups", "Dancing", "Cycling", "Swimming", "Pets", "Volunteering", "Astronomy", "Blogging", "DIY", "Podcasting"];
  final List<String> foodOptions = ["Coffee", "Tea", "Pizza", "Sushi", "Burgers", "Street Food", "Desserts", "Vegan", "BBQ", "Pasta", "Indian", "Thai", "Mexican", "Chinese", "Wine", "Cocktails", "Mocktails", "Smoothies", "Ice Cream", "Biryani"];
  final List<String> placeOptions = ["Beach", "Mountains", "Cafes", "Museums", "Art Galleries", "Hidden Bars", "Nature Trails", "Bookstores", "Rooftops", "Parks", "Gyms", "Libraries", "Music Venues", "Temples", "Historic Sites", "Street Markets"];
  final List<String> languageOptions = ["English", "Spanish", "French", "German", "Chinese", "Japanese", "Korean", "Arabic", "Hindi", "Portuguese", "Russian", "Other"];

  // Height Logic
  bool _isFeet = true;
  final List<String> heightFeet = List.generate(37, (i) => "${(i ~/ 12) + 4}' ${i % 12}\""); // 4'0 to 7'0
  final List<String> heightCm = List.generate(121, (i) => "${i + 120} cm"); // 120 to 240

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final data = widget.currentData;
    
    _nameController = TextEditingController(text: data['full_name']);
    _jobController = TextEditingController(text: data['job_title']);
    
    // Parse Education (Level - School)
    String fullEdu = data['education'] ?? '';
    if (fullEdu.contains(' - ')) {
      var parts = fullEdu.split(' - ');
      _educationLevel = parts[0];
      _schoolController = TextEditingController(text: parts.length > 1 ? parts[1] : '');
    } else {
      _educationLevel = fullEdu.isNotEmpty ? fullEdu : null;
      _schoolController = TextEditingController();
    }

    // Load simple fields
    _gender = data['gender'];
    _orientation = data['sexual_orientation'];
    _pronouns = data['pronouns'];
    _ethnicity = data['ethnicity'];
    _height = data['height'];
    _religion = data['religion'];
    _politics = data['political_views'];
    _starSign = data['star_sign'];
    _location = data['location'];
    _drink = data['drink'];
    _smoke = data['smoke'];
    _weed = data['weed'];
    _exercise = data['exercise'];
    _kids = data['kids'];
    _pets = data['pets'];
    _intent = data['intent'];

    // Load Lists
    _languages = List<String>.from((data['languages'] as String?)?.split(', ') ?? []);
    _interests = List<String>.from(data['interests'] ?? []);
    _foods = List<String>.from(data['foods'] ?? []);
    _places = List<String>.from(data['places'] ?? []);

    // Load Photos
    List<dynamic> loadedPhotos = data['photo_urls'] ?? [];
    for (int i = 0; i < loadedPhotos.length && i < 6; i++) {
      _photos[i] = loadedPhotos[i];
    }

    // Load Prompts
    List<dynamic> loadedPrompts = data['prompts'] ?? [];
    for (int i = 0; i < 3; i++) {
      if (i < loadedPrompts.length && loadedPrompts[i] != null) {
        _prompts[i] = Map<String, dynamic>.from(loadedPrompts[i]);
      }
    }
  }

  // --- 3. Save Logic ---
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final supabase = Supabase.instance.client;
      List<String> finalPhotoUrls = [];
      
      // 1. Upload/Keep Photos
      for (var item in _photos) {
        if (item == null) continue;
        
        if (item is File) {
          final fileExt = item.path.split('.').last;
          final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}_${finalPhotoUrls.length}.$fileExt';
          await supabase.storage.from('user_photos').upload(fileName, item);
          final url = supabase.storage.from('user_photos').getPublicUrl(fileName);
          finalPhotoUrls.add(url);
        } else if (item is String) {
          finalPhotoUrls.add(item);
        }
      }

      // 2. Prepare Data
      String finalEdu = _educationLevel ?? '';
      if (_schoolController.text.isNotEmpty) {
        finalEdu = "$finalEdu - ${_schoolController.text.trim()}";
      }

      final updates = {
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
      };

      await supabase.from('profiles').update(updates).eq('id', userId);

      if (mounted) Navigator.pop(context, true); // Return true to trigger refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 4. Main UI Build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTan,
      appBar: AppBar(
        backgroundColor: kTan,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: kBlack),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Edit Profile", style: TextStyle(color: kBlack, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kRose))
              : const Text("Save", style: TextStyle(color: kRose, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. PHOTOS
            _buildSectionHeader("My Photos"),
            _buildPhotoGrid(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text("Tap to replace. Dragging not supported yet.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),

            // B. THE ESSENTIALS
            const SizedBox(height: 20),
            _buildSectionHeader("The Essentials"),
            _buildContainer([
               _buildTextFieldRow("Name", _nameController),
               _buildDivider(),
               _buildTextFieldRow("Job Title", _jobController),
               _buildDivider(),
               _buildLocationRow(),
            ]),

            // C. ABOUT ME
            const SizedBox(height: 20),
            _buildSectionHeader("About Me"),
            _buildContainer([
              _buildSelectorRow("Height", _height, () => _showHeightPicker()),
              _buildDivider(),
              _buildEducationSelector(),
              _buildDivider(),
              _buildSelectorRow("Gender", _gender, () => _showChipModal("Gender", genderOptions, _gender, (v) => setState(() => _gender = v))),
              _buildDivider(),
              _buildSelectorRow("Pronouns", _pronouns, () => _showChipModal("Pronouns", pronounOptions, _pronouns, (v) => setState(() => _pronouns = v))),
              _buildDivider(),
              _buildSelectorRow("Orientation", _orientation, () => _showChipModal("Sexual Orientation", orientationOptions, _orientation, (v) => setState(() => _orientation = v))),
              _buildDivider(),
              _buildSelectorRow("Ethnicity", _ethnicity, () => _showChipModal("Ethnicity", ethnicityOptions, _ethnicity, (v) => setState(() => _ethnicity = v))),
              _buildDivider(),
              _buildSelectorRow("Religion", _religion, () => _showChipModal("Religion", religionOptions, _religion, (v) => setState(() => _religion = v))),
              _buildDivider(),
              _buildSelectorRow("Politics", _politics, () => _showChipModal("Politics", politicalOptions, _politics, (v) => setState(() => _politics = v))),
              _buildDivider(),
              _buildSelectorRow("Star Sign", _starSign, () => _showChipModal("Star Sign", starSigns, _starSign, (v) => setState(() => _starSign = v))),
               _buildDivider(),
              _buildMultiSelectRow("Languages", _languages, () => _showMultiSelectModal("Languages", languageOptions, _languages)),
            ]),

            // D. LIFESTYLE
            const SizedBox(height: 20),
            _buildSectionHeader("Lifestyle"),
            _buildContainer([
              _buildSelectorRow("Looking For", _intent, () => _showChipModal("Intent", intentOptionsStrings, _intent, (v) => setState(() => _intent = v))),
              _buildDivider(),
              _buildSelectorRow("Kids", _kids, () => _showChipModal("Kids", kidsOptions, _kids, (v) => setState(() => _kids = v))),
              _buildDivider(),
              _buildSelectorRow("Pets", _pets, () => _showChipModal("Pets", petsOptions, _pets, (v) => setState(() => _pets = v))),
              _buildDivider(),
              _buildSelectorRow("Exercise", _exercise, () => _showChipModal("Exercise", exerciseOptions, _exercise, (v) => setState(() => _exercise = v))),
              _buildDivider(),
              _buildSelectorRow("Drink", _drink, () => _showChipModal("Drink", habitOptions, _drink, (v) => setState(() => _drink = v))),
              _buildDivider(),
              _buildSelectorRow("Smoke", _smoke, () => _showChipModal("Smoke", habitOptions, _smoke, (v) => setState(() => _smoke = v))),
              _buildDivider(),
              _buildSelectorRow("Weed", _weed, () => _showChipModal("Weed", habitOptions, _weed, (v) => setState(() => _weed = v))),
            ]),

            // E. PASSIONS
            const SizedBox(height: 20),
            _buildSectionHeader("Passions & Discovery"),
            _buildContainer([
              _buildMultiSelectRow("Interests", _interests, () => _showMultiSelectModal("Interests", interestOptions, _interests)),
              _buildDivider(),
              _buildMultiSelectRow("Favorite Foods", _foods, () => _showMultiSelectModal("Foods", foodOptions, _foods)),
              _buildDivider(),
              _buildMultiSelectRow("Favorite Places", _places, () => _showMultiSelectModal("Places", placeOptions, _places)),
            ]),

            // F. PROMPTS
            const SizedBox(height: 20),
            _buildSectionHeader("My Prompts"),
            _buildPromptsList(),
          ],
        ),
      ),
    );
  }

  // --- 5. Helper Widgets ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(title.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
    );
  }

  Widget _buildContainer(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() => const Divider(height: 1, indent: 20, endIndent: 20);

  // --- Photos Grid ---
  Widget _buildPhotoGrid() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 10, mainAxisSpacing: 10
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          final item = _photos[index];
          return GestureDetector(
            onTap: () => _showPhotoOptions(index),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: item != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          item is File ? Image.file(item, fit: BoxFit.cover) : Image.network(item, fit: BoxFit.cover),
                          Positioned(
                            bottom: 5, right: 5,
                            child: CircleAvatar(backgroundColor: Colors.white, radius: 12, child: Icon(Icons.edit, size: 14, color: kRose)),
                          )
                        ],
                      ),
                    )
                  : Icon(Icons.add, color: Colors.grey[300], size: 30),
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
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.photo_library), title: const Text("Gallery"), onTap: () { Navigator.pop(ctx); _pickImage(index, ImageSource.gallery); }),
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text("Camera"), onTap: () { Navigator.pop(ctx); _pickImage(index, ImageSource.camera); }),
            if (_photos[index] != null)
              ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("Remove", style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(ctx); setState(() => _photos[index] = null); }),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(int index, ImageSource source) async {
    final XFile? img = await _picker.pickImage(source: source, imageQuality: 80);
    if (img != null) setState(() => _photos[index] = File(img.path));
  }

  // --- Form Rows ---

  Widget _buildTextFieldRow(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey))),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
              style: const TextStyle(fontWeight: FontWeight.w600, color: kBlack),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorRow(String label, String? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const Spacer(),
            Text(value ?? "Add", style: TextStyle(fontWeight: FontWeight.w600, color: value == null ? kRose : kBlack)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectRow(String label, List<String> values, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const Spacer(),
            Text("${values.length} selected", style: const TextStyle(fontWeight: FontWeight.w600, color: kBlack)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // --- Specialized Rows ---
  Widget _buildLocationRow() {
    return InkWell(
      onTap: _fetchCurrentLocation, // Tap to fetch GPS location
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            const Text("Location", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const Spacer(),
            Icon(Icons.location_on, size: 16, color: kRose),
            const SizedBox(width: 4),
            Expanded(
                child: Text(_location ?? "Tap to update", 
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, color: kBlack)
              ),
            ),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Location error: $e")));
    }
  }

  Widget _buildEducationSelector() {
    return InkWell(
      onTap: () {
         _showChipModal("Education Level", educationOptions, _educationLevel, (v) => setState(() => _educationLevel = v));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: Row(
          children: [
            const SizedBox(width: 80, child: Text("Education", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey))),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_educationLevel ?? "Select Level", style: TextStyle(fontWeight: FontWeight.w600, color: _educationLevel == null ? kRose : kBlack)),
                  TextField(
                    controller: _schoolController,
                    textAlign: TextAlign.end,
                    decoration: const InputDecoration(hintText: "School Name (Optional)", border: InputBorder.none, isDense: true, hintStyle: TextStyle(color: Colors.grey, fontSize: 13)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- Modals (The Magic that makes it functional yet clean) ---

  void _showChipModal(String title, List<String> options, String? current, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: options.map((opt) {
                      final isSelected = current == opt;
                      return ChoiceChip(
                        label: Text(opt),
                        selected: isSelected,
                        selectedColor: kRose,
                        backgroundColor: Colors.grey[100],
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                        onSelected: (_) {
                          onSelect(opt);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                ),
              )
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done", style: TextStyle(color: kRose)))
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: options.map((opt) {
                          final isSelected = current.contains(opt);
                          return FilterChip(
                            label: Text(opt),
                            selected: isSelected,
                            selectedColor: kRose,
                            backgroundColor: Colors.grey[100],
                            labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                            onSelected: (_) {
                              setModalState(() {
                                setState(() { // Update parent state
                                  isSelected ? current.remove(opt) : current.add(opt);
                                });
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  )
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          final list = _isFeet ? heightFeet : heightCm;
          return Container(
            padding: const EdgeInsets.all(20),
            height: 350,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildToggleBtn("Feet", _isFeet, () => setModalState(() => _isFeet = true)),
                    const SizedBox(width: 10),
                    _buildToggleBtn("CM", !_isFeet, () => setModalState(() => _isFeet = false)),
                  ],
                ),
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    itemExtent: 50,
                    perspective: 0.003,
                    onSelectedItemChanged: (i) => setState(() => _height = list[i]),
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (c, i) => Center(child: Text(list[i], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                      childCount: list.length,
                    ),
                  ),
                )
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(color: active ? kRose : Colors.grey[200], borderRadius: BorderRadius.circular(20)),
        child: Text(txt, style: TextStyle(color: active ? Colors.white : Colors.black)),
      ),
    );
  }

  // --- Prompts List ---
  Widget _buildPromptsList() {
    return Column(
      children: List.generate(3, (index) {
        final p = _prompts[index];
        return GestureDetector(
          onTap: () => _editPrompt(index),
          child: Container(
             margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
             child: p == null 
               ? Row(children: const [Icon(Icons.add, color: kRose), SizedBox(width: 8), Text("Add a Prompt", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))])
               : Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text((p['question'] ?? '').toUpperCase(), style: const TextStyle(color: kRose, fontSize: 10, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 4),
                     Text(p['answer'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                   ],
                 ),
          ),
        );
      }),
    );
  }

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
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Choose a Question", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: questions.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(questions[i]),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAnswerDialog(index, questions[i]);
                  },
                ),
              ),
            )
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
        title: Text(question, style: const TextStyle(fontSize: 14)),
        content: TextField(controller: ctrl, maxLines: 3, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () {
            if(ctrl.text.isNotEmpty) setState(() => _prompts[index] = {'question': question, 'answer': ctrl.text});
            Navigator.pop(ctx);
          }, child: const Text("Save", style: TextStyle(color: kRose)))
        ],
      ),
    );
  }
}