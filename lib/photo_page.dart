import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'prompts_page.dart';
import 'dart:io';

const Color kTan = Color(0xFFE9E6E1);
const Color kRose = Color(0xFFCD9D8F);

class PhotoPage extends StatefulWidget {
  final int currentStep;
  final int totalSteps;

  const PhotoPage({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> {
  final List<File?> _photos = List<File?>.generate(6, (_) => null);
  final ImagePicker _picker = ImagePicker();

  bool get _hasMinimumPhotos => _photos.where((p) => p != null).length >= 2;

  void _showPickerOptions(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: kRose),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(index, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: kRose),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(index, ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(int index, ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _photos[index] = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _removeImage(int index) {
    setState(() {
      _photos[index] = null;
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
                  LinearProgressIndicator(
                    value: progress, 
                    color: kRose, 
                    backgroundColor: Colors.white24
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text("Add your photos", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text("At least 2 photos required (Max 6).", style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 32),
                    
                    // The Grid Section
                    Expanded(
                      child: GridView.builder(
                        itemCount: 6,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.7,
                        ),
                        itemBuilder: (context, index) {
                          final photoFile = _photos[index];
                          final isSlotOccupied = photoFile != null;

                          return GestureDetector(
                            onTap: () => isSlotOccupied ? null : _showPickerOptions(index),
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: index < 2 && !isSlotOccupied ? kRose.withOpacity(0.5) : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: isSlotOccupied
                                        ? Image.file(photoFile, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                                        : Center(child: Icon(Icons.add_a_photo_outlined, color: index < 2 ? kRose : Colors.grey)),
                                  ),
                                ),
                                if (isSlotOccupied)
                                  Positioned(
                                    right: 4,
                                    bottom: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: const CircleAvatar(
                                        radius: 12,
                                        backgroundColor: kRose,
                                        child: Icon(Icons.close, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // --- NEW: PRO TIP TAG AT THE BOTTOM OF SECTION ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.auto_awesome, color: kRose, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                                children: [
                                  const TextSpan(text: "Pro Tip: ", style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(
                                    text: "Clear, high-quality photos that show your face and hobbies tend to perform 40% better.",
                                    style: TextStyle(color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
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
                onPressed: _hasMinimumPhotos ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PromptsPage(currentStep: 5, totalSteps: 6),
                    ),
                  );
                } : null,
                child: const Text("Continue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}