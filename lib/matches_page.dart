import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart'; // Typography
import 'package:flutter_animate/flutter_animate.dart'; // Animations
import 'chat_page.dart';
import 'main.dart'; // For HeartLoader

const Color kRose = Color(0xFFCD9D8F);
const Color kBlack = Color(0xFF2D2D2D);
const Color kTan = Color(0xFFF8F9FA);

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

      // 2. Fetch Blocked Users
      final List<String> blockedIds = [];
      try {
        final blocksData = await _supabase
            .from('blocks')
            .select('blocker_id, blocked_id')
            .or('blocker_id.eq.$myId,blocked_id.eq.$myId');

        for (var b in blocksData) {
          final b1 = b['blocker_id'].toString();
          final b2 = b['blocked_id'].toString();
          blockedIds.add(b1 == myId ? b2 : b1);
        }
      } catch (e) {
        print("Error fetching blocks for matches view: $e");
      }

      // 3. Fetch Matches (Using user_a and user_b)
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

        if (otherProfile != null && !blockedIds.contains(otherProfile['id'])) {
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
      backgroundColor: kTan,
      appBar: AppBar(
        title: Text(
          "Matches",
          style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: kBlack, letterSpacing: -0.5),
        ),
        backgroundColor: kTan,
        elevation: 0,
        centerTitle: false,
      ),
      body: isLoading
          ? const Center(child: HeartLoader(size: 60))
          : matches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))
                          ]
                        ),
                        child: Icon(Icons.favorite_border_rounded, size: 60, color: kRose.withOpacity(0.5)),
                      ),
                      const SizedBox(height: 24),
                      Text("No matches yet.", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: kBlack)),
                      const SizedBox(height: 8),
                      Text("Keep swiping to find new people!", style: GoogleFonts.outfit(color: Colors.black54)),
                    ],
                  ).animate().fade(duration: 600.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final match = matches[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: kRose.withOpacity(0.1),
                          backgroundImage: match['photo_url'] != null ? NetworkImage(match['photo_url']) : null, // Assuming backend could return photo_url
                          child: match['photo_url'] == null 
                              ? Text(match['display_name'][0].toUpperCase(), style: GoogleFonts.outfit(color: kRose, fontSize: 20, fontWeight: FontWeight.bold))
                              : null,
                        ),
                        title: Text(match['display_name'], style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: kBlack)),
                        subtitle: Text("Tap to chat", style: GoogleFonts.outfit(color: Colors.black45)),
                        trailing: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: kTan, shape: BoxShape.circle),
                          child: const Icon(Icons.send_rounded, color: kRose, size: 20),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                myId: FirebaseAuth.instance.currentUser!.uid,
                                matchId: match['match_uuid'],
                                matchName: match['display_name'],
                                myName: _myDisplayName ?? "Me",
                                matchPhotoUrl: match['photo_url'], 
                              ),
                            ),
                          );
                        },
                      ),
                    ).animate().fade(duration: 400.ms, delay: (50 * index).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
                  },
                ),
    );
  }
}