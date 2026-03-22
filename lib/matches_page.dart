import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart'; // Typography
import 'package:flutter_animate/flutter_animate.dart'; // Animations
import 'dart:convert';
import 'chat_page.dart';
import 'heart_loader.dart';
import 'services/crypto_service.dart';
import 'services/matching_service.dart';

import 'theme/colors.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  final _supabase = Supabase.instance.client;
  final MatchingService _matchingService = MatchingService();
  
  List<Map<String, dynamic>> matches = [];
  String? _myDisplayName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final sw = Stopwatch()..start();
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
          final otherId = otherProfile['id'];
          final roomId = _getRoomId(myId, otherId);
          
          String lastMessage = "Tap to chat";
          DateTime? lastMessageTime;

          try {
            final lastMsgData = await _supabase
                .from('messages')
                .select('message, created_at')
                .eq('room_id', roomId)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

            if (lastMsgData != null) {
              final crypto = CryptoService(roomId);
              final decryptedJson = crypto.decryptPayload(lastMsgData['message']);
              try {
                final payload = jsonDecode(decryptedJson);
                if (payload['type'] == 'text') {
                  lastMessage = payload['data'];
                } else if (payload['type'] == 'image') {
                  lastMessage = "Sent an image";
                }
              } catch (e) {
                lastMessage = decryptedJson;
              }
              lastMessageTime = DateTime.tryParse(lastMsgData['created_at']);
            }
          } catch (e) {
            print("Error fetching last message for $roomId: $e");
          }

          int unreadCount = await _matchingService.getUnreadCountForRoom(roomId, _myDisplayName ?? "Me", myId);

          loadedMatches.add({
            'match_uuid': otherId,
            'display_name': otherProfile['full_name'],
            'last_message': lastMessage,
            'last_message_time': lastMessageTime,
            'unread_count': unreadCount,
            'photo_url': otherProfile['photo_urls'] != null && (otherProfile['photo_urls'] as List).isNotEmpty ? otherProfile['photo_urls'][0] : null,
          });
        }
      }

      // Sort matches by last message time (most recent first)
      loadedMatches.sort((a, b) {
        final timeA = a['last_message_time'] as DateTime? ?? DateTime(1970);
        final timeB = b['last_message_time'] as DateTime? ?? DateTime(1970);
        return timeB.compareTo(timeA);
      });

      if (mounted) {
        final elapsed = sw.elapsedMilliseconds;
        if (elapsed < 2200) await Future.delayed(Duration(milliseconds: 2200 - elapsed));
        setState(() {
          matches = loadedMatches;
          isLoading = false;
        });
      }

    } catch (e) {
      print('❌ Error fetching matches: $e');
      if (mounted) {
        final elapsed = sw.elapsedMilliseconds;
        if (elapsed < 2200) await Future.delayed(Duration(milliseconds: 2200 - elapsed));
        setState(() => isLoading = false);
      }
    }
  }

  String _getRoomId(String id1, String id2) {
    List<String> ids = [id1, id2];
    ids.sort();
    return "${ids[0]}_${ids[1]}";
  }

  String _formatMessageTime(DateTime? time) {
    if (time == null) return "";
    final now = DateTime.now();
    final localTime = time.toLocal();
    final diff = now.difference(localTime);

    if (diff.inDays == 0 && now.day == localTime.day) {
      String tStr = "${localTime.hour > 12 ? localTime.hour - 12 : (localTime.hour == 0 ? 12 : localTime.hour)}:${localTime.minute.toString().padLeft(2, '0')} ${localTime.hour >= 12 ? 'PM' : 'AM'}";
      return tStr;
    } else if (diff.inDays == 1 || (diff.inDays == 0 && now.day != localTime.day)) {
      return "Yesterday";
    } else if (diff.inDays < 7) {
      List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[localTime.weekday - 1];
    } else {
      return "${localTime.day}/${localTime.month}/${localTime.year.toString().substring(2)}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTan,
      appBar: AppBar(
        title: Text(
          "Matches",
          style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 26, color: kBlack, letterSpacing: -0.5),
        ),
        backgroundColor: kTan,
        elevation: 0,
        centerTitle: false,
      ),
      body: isLoading
          ? const Center(child: HeartLoader())
          : matches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: kParchment,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: kInk.withOpacity(0.08), blurRadius: 28, offset: const Offset(0, 12))
                          ]
                        ),
                        child: Icon(Icons.favorite_border_rounded, size: 60, color: kRose.withOpacity(0.5)),
                      ),
                      const SizedBox(height: 24),
                      Text("No matches yet.", style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 20, color: kBlack)),
                      const SizedBox(height: 8),
                      Text("Keep swiping to find new people!", style: GoogleFonts.figtree(color: kInkMuted)),
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
                      decoration: BoxDecoration(color: kParchment,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: kInk.withOpacity(0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
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
                                  ? Text(match['display_name'][0].toUpperCase(), style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, color: kRose, fontSize: 20, ))
                                  : null,
                            ),
                            title: Text(match['display_name'], style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 18, color: kBlack)),
                            subtitle: Text(
                              match['last_message'], 
                              style: GoogleFonts.figtree(
                                color: match['unread_count'] > 0 
                                      ? kBlack 
                                      : match['last_message'] == "Tap to chat" ? kInkMuted : kInk,
                                fontWeight: match['unread_count'] > 0
                                      ? FontWeight.bold
                                      : match['last_message'] == "Tap to chat" ? FontWeight.normal : FontWeight.w500,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (match['last_message_time'] != null)
                              Text(
                                _formatMessageTime(match['last_message_time']),
                                style: GoogleFonts.figtree(
                                  fontSize: 12,
                                  color: match['unread_count'] > 0 ? kRose : kInkMuted,
                                  fontWeight: match['unread_count'] > 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            if (match['unread_count'] > 0) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: const BoxDecoration(
                                  color: kRose,
                                  shape: BoxShape.rectangle,
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                child: Text(
                                  match['unread_count'].toString(),
                                  style: GoogleFonts.figtree(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
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
                          // Refresh unread counts after coming back from chat page
                          _fetchData();
                        },
                      ),
                    ).animate().fade(duration: 400.ms, delay: (50 * index).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
                  },
                ),
    );
  }
}
