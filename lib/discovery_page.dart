import 'package:flutter/material.dart';
import 'photo_page.dart';
import 'main.dart'; // Import for createPremiumRoute

const Color kTan = Color(0xFFE9E6E1);
const Color kRose = Color(0xFFCD9D8F);

class DiscoveryPage extends StatefulWidget {
  final int currentStep;
  final int totalSteps;

  const DiscoveryPage({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final Set<String> interests = {};
  final Set<String> foods = {};
  final Set<String> places = {};

  int get totalSelected => interests.length + foods.length + places.length;
  List<String> get allSelected => [...interests, ...foods, ...places];

  void toggleChip(String label, Set<String> group) {
    setState(() {
      if (group.contains(label)) {
        group.remove(label);
      } else {
        if (totalSelected < 15) {
          group.add(label);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Maximum 15 selections allowed")),
          );
        }
      }
    });
  }

  Widget chip(String label, Set<String> group) {
    final selected = group.contains(label);
    return GestureDetector(
      onTap: () => toggleChip(label, group),
      child: Container(
        margin: const EdgeInsets.only(right: 10, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? kRose : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: selected ? kRose : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
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
                  
                  // HERO WIDGET ADDED HERE
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

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      "What makes you, you?",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    
                    if (allSelected.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text("Selected ($totalSelected/15)", style: const TextStyle(color: kRose, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        children: allSelected.map((item) => Container(
                          margin: const EdgeInsets.only(right: 8, bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: kRose.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: kRose),
                          ),
                          child: Text(item, style: const TextStyle(color: kRose, fontSize: 12, fontWeight: FontWeight.bold)),
                        )).toList(),
                      ),
                    ],

                    const SizedBox(height: 24),
                    const Text("Interests & Hobbies", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      children: [
                        "Travel", "Photography", "Hiking", "Yoga", "Art", "Reading",
                        "Fitness", "Music", "Movies", "Cooking", "Gaming", "Writing",
                        "Meditation", "Tech", "Startups", "Dancing", "Cycling",
                        "Swimming", "Pets", "Volunteering", "Astronomy", "Blogging",
                        "DIY", "Podcasting"
                      ].map((e) => chip(e, interests)).toList(),
                    ),

                    const SizedBox(height: 24),
                    const Text("Food & Drinks", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      children: [
                        "Coffee", "Tea", "Pizza", "Sushi", "Burgers", "Street Food",
                        "Desserts", "Vegan", "BBQ", "Pasta", "Indian", "Thai",
                        "Mexican", "Chinese", "Wine", "Cocktails", "Mocktails",
                        "Smoothies", "Ice Cream", "Biryani"
                      ].map((e) => chip(e, foods)).toList(),
                    ),

                    const SizedBox(height: 24),
                    const Text("Favorite Places", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      children: [
                        "Beach", "Mountains", "Cafes", "Museums", "Art Galleries",
                        "Hidden Bars", "Nature Trails", "Bookstores", "Rooftops",
                        "Parks", "Gyms", "Libraries", "Music Venues", "Temples",
                        "Historic Sites", "Street Markets"
                      ].map((e) => chip(e, places)).toList(),
                    ),
                    const SizedBox(height: 40),
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
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: totalSelected > 0 ? () {
                  // PREMIUM ROUTE USED HERE
                  Navigator.push(
                    context,
                    createPremiumRoute(const PhotoPage(currentStep: 4, totalSteps: 6)),
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