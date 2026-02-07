import 'package:flutter/material.dart';
import 'discovery_page.dart';
import 'main.dart';
import 'profile_store.dart'; // Import Store

const Color kTan = Color(0xFFE9E6E1);
const Color kRose = Color(0xFFCD9D8F);

class IntentPage extends StatefulWidget {
  final int currentStep;
  final int totalSteps;

  const IntentPage({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  State<IntentPage> createState() => _IntentPageState();
}

class _IntentPageState extends State<IntentPage> {
  String? intent;

  @override
  void initState() {
    super.initState();
    intent = ProfileStore.instance.intent;
  }

  Widget option(String title, String subtitle) {
    final selected = intent == title;
    return GestureDetector(
      onTap: () => setState(() => intent = title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? kRose : Colors.grey.shade300),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
              ]
            ),
          ),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? kRose : Colors.grey,
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.currentStep / widget.totalSteps;

    return Scaffold(
      backgroundColor: kTan,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back)
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
            const SizedBox(height: 32),
            const Text(
              "What are you looking for?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            option("Life Partner", "Marriage or lifelong commitment"),
            option("Long-term relationship", "Meaningful connection"),
            option("Long-term, open to short", "Flexible journey"),
            option("Open to options", "See where it goes"),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kRose,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () {
                  if (intent == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Select an option")),
                    );
                    return;
                  }
                  
                  // SAVE TO STORE
                  ProfileStore.instance.intent = intent;

                  Navigator.push(
                    context,
                    createPremiumRoute(const DiscoveryPage(currentStep: 3, totalSteps: 6)),
                  );
                },
              child: const Text("Continue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ),
    );
  }
}