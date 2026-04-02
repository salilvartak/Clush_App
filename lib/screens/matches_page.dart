import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:clush/screens/chat_page.dart';
import 'package:clush/widgets/heart_loader.dart';

import 'package:clush/l10n/app_localizations.dart';

import 'package:clush/theme/colors.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> matches = [];
  String? _myDisplayName;
  String? _myId;
  bool isLoading = true;
  RealtimeChannel? _unreadChannel;

  @override
  void initState() {
    super.initState();
    _myId = FirebaseAuth.instance.currentUser?.uid;
    _fetchData();
    _subscribeUnread();
  }

  @override
  void dispose() {
    _unreadChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeUnread() {
    final myId = _myId;
    if (myId == null) return;
    _unreadChannel = _supabase.channel('matches_read_$myId');
    _unreadChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_read_status',
          callback: (payload) async {
            final row = payload.newRecord;
            // Only care about the match reading (not me reading)
            if (row['user_id'] == myId) return;
            final roomId = row['room_id'] as String?;
            if (roomId == null) return;
            final idx = matches.indexWhere((m) {
              final otherId = m['match_uuid'] as String;
              return _getRoomId(myId, otherId) == roomId;
            });
            if (idx < 0 || !mounted) return;
            // Recalculate unread for this room
            final count = await _getUnreadCount(roomId, myId);
            if (mounted) setState(() => matches[idx]['unread_count'] = count);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final row = payload.newRecord;
            final roomId = row['room_id'] as String?;
            final sender = row['sender'] as String?;
            if (roomId == null || sender == null || sender == myId) return;
            if (!roomId.contains(myId)) return;
            final idx = matches.indexWhere((m) {
              final otherId = m['match_uuid'] as String;
              return _getRoomId(myId, otherId) == roomId;
            });
            if (idx < 0 || !mounted) return;
            setState(() {
              matches[idx]['unread_count'] =
                  (matches[idx]['unread_count'] as int) + 1;
            });
          },
        )
        .subscribe();
  }

  Future<int> _getUnreadCount(String roomId, String myId) async {
    try {
      final rs = await _supabase
          .from('chat_read_status')
          .select('last_read_at')
          .eq('user_id', myId)
          .eq('room_id', roomId)
          .maybeSingle();
      final lastRead = rs?['last_read_at'] ?? '1970-01-01T00:00:00Z';
      final resp = await _supabase
          .from('messages')
          .select('id')
          .eq('room_id', roomId)
          .neq('sender', myId)
          .gt('created_at', lastRead)
          .count(CountOption.exact);
      return resp.count;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _fetchData() async {
    final sw = Stopwatch()..start();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final myId = user.uid;

      // 1. Fetch my name
      try {
        final myProfile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', myId)
            .maybeSingle();
        _myDisplayName = myProfile?['full_name'];
      } catch (_) {
        _myDisplayName = 'Me';
      }

      // 2. Fetch blocked users
      final List<String> blockedIds = [];
      try {
        final blocksData = await _supabase
            .from('blocks')
            .select('blocker_id, blocked_id')
            .or('blocker_id.eq.$myId,blocked_id.eq.$myId');
        for (final b in blocksData) {
          final b1 = b['blocker_id'].toString();
          final b2 = b['blocked_id'].toString();
          blockedIds.add(b1 == myId ? b2 : b1);
        }
      } catch (_) {}

      // 3. Fetch matches with joined profiles (including photo_urls)
      final data = await _supabase.from('matches').select('''
            *,
            profile_a:profiles!user_a(id, full_name, photo_urls),
            profile_b:profiles!user_b(id, full_name, photo_urls)
          ''').or('user_a.eq.$myId,user_b.eq.$myId');

      final List<Map<String, dynamic>> loadedMatches = [];

      for (final match in data) {
        final isUserAMe = match['user_a'] == myId;
        final otherProfile = isUserAMe ? match['profile_b'] : match['profile_a'];
        if (otherProfile == null) continue;
        final otherId = otherProfile['id'] as String;
        if (blockedIds.contains(otherId)) continue;

        final photoUrls = otherProfile['photo_urls'];
        final photoUrl = (photoUrls is List && photoUrls.isNotEmpty)
            ? photoUrls[0] as String?
            : null;

        final roomId = _getRoomId(myId, otherId);
        int unread = 0;
        try {
          unread = await _getUnreadCount(roomId, myId);
        } catch (_) {}

        loadedMatches.add({
          'match_uuid': otherId,
          'display_name': otherProfile['full_name'],
          'photo_url': photoUrl,
          'unread_count': unread,
        });

        // Preload messages in background so chat opens instantly
        unawaited(ChatCache.preload(roomId));
      }

      if (mounted) {
        final elapsed = sw.elapsedMilliseconds;
        if (elapsed < 2200) {
          await Future.delayed(Duration(milliseconds: 2200 - elapsed));
        }
        setState(() {
          matches = loadedMatches;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching matches: $e');
      if (mounted) {
        final elapsed = sw.elapsedMilliseconds;
        if (elapsed < 2200) {
          await Future.delayed(Duration(milliseconds: 2200 - elapsed));
        }
        setState(() => isLoading = false);
      }
    }
  }

  String _getRoomId(String id1, String id2) {
    final ids = [id1, id2]..sort();
    return '${ids[0]}_${ids[1]}';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTan,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.matches ?? 'Matches',
          style: GoogleFonts.gabarito(
              fontWeight: FontWeight.bold, fontSize: 26, color: kBlack, letterSpacing: -0.5),
        ),
        backgroundColor: kTan,
        elevation: 0,
        centerTitle: false,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutQuad,
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
        child: isLoading
            ? const Center(key: ValueKey('loading'), child: HeartLoader())
            : matches.isEmpty
                ? Center(
                    key: const ValueKey('empty'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset('assets/images/2.svg', width: 180, height: 180),
                          const SizedBox(height: 28),
                          Text(
                            AppLocalizations.of(context)?.signalsReachingOut ?? 'Your signals are reaching out wide, but a clear return frequency is still far off.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.gabarito(
                                fontWeight: FontWeight.bold, fontSize: 20, color: kBlack),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            AppLocalizations.of(context)?.fineTuneTransmission ?? 'We can help you fine-tune your transmission and find your match soon.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.figtree(fontSize: 15, color: kInkMuted, height: 1.5),
                          ),
                        ],
                      )
                          .animate()
                          .fade(duration: 600.ms)
                          .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                    ),
                  )
                : ListView.builder(
                    key: const ValueKey('list'),
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final match = matches[index];
                      final unread = (match['unread_count'] as int? ?? 0);
                      final hasUnread = unread > 0;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: kParchment,
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
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: kRose.withOpacity(0.1),
                                backgroundImage: match['photo_url'] != null
                                    ? NetworkImage(match['photo_url'] as String)
                                    : null,
                                child: match['photo_url'] == null
                                    ? Text(
                                        (match['display_name'] as String)[0].toUpperCase(),
                                        style: GoogleFonts.gabarito(
                                            fontWeight: FontWeight.bold,
                                            color: kRose,
                                            fontSize: 20),
                                      )
                                    : null,
                              ),
                              if (hasUnread)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: kRose,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                        minWidth: 18, minHeight: 18),
                                    child: Text(
                                      unread > 99 ? '99+' : '$unread',
                                      style: GoogleFonts.figtree(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(match['display_name'] as String,
                              style: GoogleFonts.gabarito(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: hasUnread ? kBlack : kBlack)),
                          subtitle: Text(
                            hasUnread
                                ? '$unread ${unread == 1 ? (AppLocalizations.of(context)?.newMessage ?? 'new message') : (AppLocalizations.of(context)?.newMessages ?? 'new messages')}'
                                : (AppLocalizations.of(context)?.tapToChat ?? 'Tap to chat'),
                            style: GoogleFonts.figtree(
                              color: hasUnread ? kRose : kInkMuted,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              color: kInkMuted),
                          onTap: () async {
                            // Optimistically clear badge before navigating
                            setState(() => matches[index]['unread_count'] = 0);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  myId: FirebaseAuth.instance.currentUser!.uid,
                                  matchId: match['match_uuid'] as String,
                                  matchName: match['display_name'] as String,
                                  myName: _myDisplayName ?? 'Me',
                                  matchPhotoUrl: match['photo_url'] as String?,
                                ),
                              ),
                            );
                            // Recheck after returning from chat
                            final myId = _myId;
                            if (myId == null || !mounted) return;
                            final roomId = _getRoomId(
                                myId, match['match_uuid'] as String);
                            final count =
                                await _getUnreadCount(roomId, myId);
                            if (mounted) {
                              setState(
                                  () => matches[index]['unread_count'] = count);
                            }
                          },
                        ),
                      )
                          .animate()
                          .fade(duration: 400.ms, delay: (50 * index).ms)
                          .slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
                    },
                  ),
      ),
    );
  }
}
