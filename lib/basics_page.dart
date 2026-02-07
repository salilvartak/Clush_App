import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'intent_page.dart';
 // Import to access kTan and kRose constants

const Color kTan = Color(0xFFE9E6E1);
const Color kRose = Color(0xFFCD9D8F);

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
  final TextEditingController nameController = TextEditingController();
  DateTime? selectedDate;
  String? selectedGender;

  bool get isValid =>
      nameController.text.trim().length >= 2 &&
      selectedDate != null &&
      selectedGender != null;

  void pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(DateTime.now().year - 18),
      initialDate: DateTime(DateTime.now().year - 18),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Widget genderTile(String gender) {
    final selected = selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => selectedGender = gender),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? kRose : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: kRose),
        ),
        child: Center(
          child: Text(
            gender,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.currentStep / widget.totalSteps;

    return Scaffold(
      backgroundColor: kTan,
      body: SafeArea(
        child: SingleChildScrollView( // Fixes RenderFlex overflow
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () => FirebaseAuth.instance.signOut(),
                    ),
                    Text("Step ${widget.currentStep} of ${widget.totalSteps}"),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress,
                  color: kRose,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 32),
                const Text(
                  "The Basics",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                const Text("First Name"),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: "Your name as it should appear",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Birthday"),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedDate == null
                              ? "MM / DD / YYYY"
                              : "${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}",
                        ),
                        const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Gender"),
                const SizedBox(height: 12),
                genderTile("Woman"),
                genderTile("Man"),
                genderTile("Non-binary"),
                const SizedBox(height: 40), 
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRose,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () {
                    if (!isValid) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Complete all fields")),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IntentPage(currentStep: 2, totalSteps: 6),
                      ),
                    );
                  },
                  child: const Text("Continue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}