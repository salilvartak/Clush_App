import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User; // Hide Supabase User to avoid conflict
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase to get the real User ID
import 'chat_page.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> matches = [];
  String? _myDisplayName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final myId = user.uid;

      // 1. Fetch My Name
      try {
        final myProfile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', myId)
            .single();
        _myDisplayName = myProfile['full_name'];
      } catch (e) {
        _myDisplayName = "Me";
      }

      // 2. Fetch Matches (Using user_a and user_b)
      final data = await _supabase
          .from('matches')
          .select('''
            *,
            profile_a:profiles!user_a(id, full_name), 
            profile_b:profiles!user_b(id, full_name)
          ''')
          .or('user_a.eq.$myId, user_b.eq.$myId');

      final List<Map<String, dynamic>> loadedMatches = [];

      for (var match in data) {
        final isUserA_Me = match['user_a'] == myId;
        
        // If I am 'user_a', then the match is 'profile_b'
        // If I am 'user_b', then the match is 'profile_a'
        final otherProfile = isUserA_Me ? match['profile_b'] : match['profile_a'];

        if (otherProfile != null) {
          loadedMatches.add({
            'match_uuid': otherProfile['id'],
            'display_name': otherProfile['full_name'],
          });
        }
      }

      if (mounted) {
        setState(() {
          matches = loadedMatches;
          isLoading = false;
        });
      }

    } catch (e) {
      print('❌ Error fetching matches: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Matches"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCD9D8F)))
          : matches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.heart_broken, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      const Text("No matches yet.", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final match = matches[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFCD9D8F),
                        child: Text(match['display_name'][0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(match['display_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text("Tap to chat"),
                      trailing: const Icon(Icons.chat_bubble_outline, color: Color(0xFFCD9D8F)),
                      onTap: () {
                        // Pass the Firebase ID as "myId"
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              myId: FirebaseAuth.instance.currentUser!.uid,
                              matchId: match['match_uuid'],
                              matchName: match['display_name'],
                              myName: _myDisplayName ?? "Me", 
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}