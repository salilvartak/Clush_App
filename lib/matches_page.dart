// lib/matches_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_page.dart'; // Import the chat screen

class MatchesPage extends StatefulWidget {
  final String myUsername; // Your name
  const MatchesPage({Key? key, required this.myUsername}) : super(key: key);

  @override
  _MatchesPageState createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  List<String> matches = [];
  bool isLoading = true;
  
  // 🔴 REPLACE THIS WITH YOUR NGROK URL
  final String serverUrl = 'https://nina-unpumped-linus.ngrok-free.dev'; 

  @override
  void initState() {
    super.initState();
    fetchMatches();
  }

  Future<void> fetchMatches() async {
    try {
      // Call the Python Server: GET /get_matches/Salil
      final url = Uri.parse('$serverUrl/get_matches/${widget.myUsername}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          // Convert the JSON list ["Rahul", "Anjali"] to a Dart List<String>
          matches = List<String>.from(data['matches']);
          isLoading = false;
        });
      } else {
        print("❌ Server Error: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Connection Error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Matches")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : matches.isEmpty
              ? const Center(child: Text("No matches yet! Go swipe some people! ❤️"))
              : ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final personName = matches[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Text(personName[0].toUpperCase()), // First letter of name
                        ),
                        title: Text(personName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text("Tap to chat"),
                        trailing: const Icon(Icons.chat_bubble_outline),
                        onTap: () {
                          // 🚀 GO TO CHAT SCREEN
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                username: widget.myUsername,
                                matchName: personName, // Pass the clicked name!
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}