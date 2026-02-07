import 'package:flutter/material.dart';
import 'success_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User; // Hide User to avoid conflicts
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'main.dart'; 
import 'profile_store.dart'; 
 // Ensure this file exists

const Color kTan = Color(0xFFE9E6E1);
const Color kRose = Color(0xFFCD9D8F);

class PromptsPage extends StatefulWidget {
  final int currentStep;
  final int totalSteps;

  const PromptsPage({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  State<PromptsPage> createState() => _PromptsPageState();
}

class _PromptsPageState extends State<PromptsPage> {
  final List<Map<String, String>?> _slots = [null, null, null];
  bool _isUploading = false; // Controls the loading spinner

  final List<String> _questions = [
    "What I'd order for the table",
    "One thing to know about me",
    "My ideal Sunday",
    "I'm overly competitive about",
    "The way to win my heart",
    "My biggest pet peeve",
    "I geek out on",
    "A random fact I love",
    "My simple pleasures",
    "I'm looking for",
    "Unpopular opinion",
    "Two truths and a lie",
  ];

  bool get _isComplete => _slots.every((slot) => slot != null);

  // --- SUBMIT PROFILE LOGIC ---
  Future<void> _submitProfile() async {
    setState(() => _isUploading = true);

    try {
      final supabase = Supabase.instance.client;
      final store = ProfileStore.instance;
      
      // 1. Get the current User ID from Firebase
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) throw Exception("User not logged in");

      // 2. Upload Photos to Supabase Storage
      List<String> photoUrls = [];
      
      for (var file in store.photos) {
        // Extract file extension safely
        final fileExt = file.path.split('.').last; 
        final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        // Upload to 'user_photos' bucket
        await supabase.storage.from('user_photos').upload(fileName, file);
        
        // Get Public URL
        final imageUrl = supabase.storage.from('user_photos').getPublicUrl(fileName);
        photoUrls.add(imageUrl);
      }

      // 3. Prepare the Data Object
      final profileData = {
        'id': userId, // Link to the Firebase Auth ID
        'full_name': store.name,
        'birthday': store.birthday?.toIso8601String(),
        'gender': store.gender,
        'intent': store.intent,
        'interests': store.interests,
        'foods': store.foods,
        'places': store.places,
        'photo_urls': photoUrls,
        'prompts': _slots, // The answers from this page
        'created_at': DateTime.now().toIso8601String(),
      };

      // 4. Insert into 'profiles' table
      await supabase.from('profiles').upsert(profileData);

      // 5. Success Handling
      if (mounted) {
        store.clear(); // Clear local state backpack
        
        // NAVIGATE TO SUCCESS SCREEN
        // FIX: Removed 'const' keyword here to prevent the error
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => SuccessScreen()), 
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showQuestionSelector(int slotIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "Pick a Prompt",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: _questions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final question = _questions[index];
                      final isAlreadySelected = _slots.any((s) => s != null && s['question'] == question);

                      return ListTile(
                        title: Text(
                          question, 
                          style: TextStyle(
                            color: isAlreadySelected ? Colors.grey : Colors.black87
                          )
                        ),
                        enabled: !isAlreadySelected,
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () {
                          Navigator.pop(context);
                          _showAnswerDialog(slotIndex, question);
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

  void _showAnswerDialog(int slotIndex, String question) {
    final TextEditingController controller = TextEditingController(
      text: _slots[slotIndex]?['answer'] ?? ''
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(question, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Type your answer...",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: kRose),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kRose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _slots[slotIndex] = {
                      'question': question,
                      'answer': controller.text.trim(),
                    };
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _removePrompt(int index) {
    setState(() {
      _slots[index] = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.currentStep / widget.totalSteps;

    return Scaffold(
      backgroundColor: kTan,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text("Step ${widget.currentStep} of ${widget.totalSteps}"),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Hero(
                    tag: 'progress_bar',
                    child: LinearProgressIndicator(
                      value: progress, 
                      color: kRose, 
                      backgroundColor: Colors.white24
                    ),
                  ),
                ],
              ),
            ),

            // --- CONTENT ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      "Write your profile answers",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Pick 3 prompts to help others get to know you better.",
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 32),

                    // --- PROMPT SLOTS ---
                    ...List.generate(3, (index) {
                      final slot = _slots[index];
                      final isFilled = slot != null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: isFilled
                            ? Dismissible(
                                key: ValueKey("slot_$index"),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) => _removePrompt(index),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.delete, color: Colors.red),
                                ),
                                child: GestureDetector(
                                  onTap: () => _showAnswerDialog(index, slot['question']!),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: kRose.withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          slot['question']!.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 12, 
                                            fontWeight: FontWeight.bold,
                                            color: kRose,
                                            letterSpacing: 0.5
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          slot['answer']!,
                                          style: const TextStyle(fontSize: 16, height: 1.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: () => _showQuestionSelector(index),
                                child: Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                                    borderRadius: BorderRadius.circular(20),
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.add, color: kRose),
                                        SizedBox(width: 8),
                                        Text("Select a Prompt", style: TextStyle(color: kRose, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // --- FOOTER (Finish Profile Button) ---
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRose,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                // LOGIC: Enable only if prompts are filled AND not currently uploading
                onPressed: (_isComplete && !_isUploading) ? _submitProfile : null,
                child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Finish profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}