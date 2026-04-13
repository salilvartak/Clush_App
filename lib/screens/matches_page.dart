import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stream_chat_flutter_core/stream_chat_flutter_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'package:clush/screens/chat_page.dart';
import 'package:clush/services/stream_service.dart';
import 'package:clush/theme/colors.dart';
import 'package:clush/widgets/activity_badge.dart';
import 'package:clush/widgets/heart_loader.dart';

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

  // Stream Chat live-event subscription for new messages
  StreamSubscription<Event>? _streamEventSub;

  @override
  void initState() {
    super.initState();
    _myId = FirebaseAuth.instance.currentUser?.uid;
    _fetchData();
    _setupRealtime();
  }

  RealtimeChannel? _matchesChannel;

  void _setupRealtime() {
    _matchesChannel = _supabase
        .channel('matches_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_a',
            value: _myId,
          ),
          callback: (payload) => _fetchData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_b',
            value: _myId,
          ),
          callback: (payload) => _fetchData(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _streamEventSub?.cancel();
    _matchesChannel?.unsubscribe();
    super.dispose();
  }

  /// Subscribe to new-message events so unread badges update in real time.
  void _subscribeStreamEvents() {
    final myId = _myId;
    if (myId == null) return;
    _streamEventSub = StreamService.instance.client
        .on(EventType.messageNew)
        .listen((event) {
      // cid format: "messaging:<channelId>"
      final channelId = event.cid?.split(':').lastOrNull;
      final sender = event.message?.user?.id;
      if (channelId == null || sender == null || sender == myId) return;

      final idx = matches.indexWhere((m) {
        final otherId = m['match_uuid'] as String;
        return _getRoomId(myId, otherId) == channelId;
      });
      if (idx >= 0 && mounted) {
        setState(
            () => matches[idx]['unread_count'] = (matches[idx]['unread_count'] as int) + 1);
      }
    });
  }

  /// Fetch unread counts for all matches via a single Stream queryChannels call.
  Future<void> _loadStreamUnreadCounts() async {
    final myId = _myId;
    if (myId == null) return;
    try {
      final channelList = await StreamService.instance.client
          .queryChannels(
            filter: Filter.in_('members', [myId]),
            state: true,
            watch: false,
          )
          .first;

      for (final ch in channelList) {
        final channelId = ch.id;
        if (channelId == null) continue;
        final unread = ch.state?.unreadCount ?? 0;
        if (unread == 0) continue;
        final idx = matches.indexWhere((m) {
          final otherId = m['match_uuid'] as String;
          return _getRoomId(myId, otherId) == channelId;
        });
        if (idx >= 0) matches[idx]['unread_count'] = unread;
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Stream unread counts: $e');
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

      // 3. Fetch matches with joined profiles
      final data = await _supabase.from('matches').select('''
            *,
            profile_a:profiles!user_a(id, full_name, photo_urls, last_seen_at),
            profile_b:profiles!user_b(id, full_name, photo_urls, last_seen_at)
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

        loadedMatches.add({
          'match_uuid': otherId,
          'display_name': otherProfile['full_name'],
          'photo_url': photoUrl,
          'unread_count': 0, // populated below via Stream
          'last_seen_at': otherProfile['last_seen_at'],
        });
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

        // Load unread counts from Stream + start live listener
        _loadStreamUnreadCounts();
        _subscribeStreamEvents();
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
          'Matches',
          style: GoogleFonts.gabarito(
              fontWeight: FontWeight.bold, fontSize: 26, color: kBlack, letterSpacing: -0.5),
        ),
        backgroundColor: kTan,
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: kRose,
        backgroundColor: kParchment,
        child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutQuad,
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
        child: isLoading
            ? const Center(key: ValueKey('loading'), child: HeartLoader())
            : matches.isEmpty
                ? ListView(
                    key: const ValueKey('empty'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset('assets/images/2.svg', width: 180, height: 180),
                            const SizedBox(height: 28),
                            Text(
                              "You're reaching far, but the right connection hasn't locked in yet.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.gabarito(
                                  fontWeight: FontWeight.bold, fontSize: 20, color: kBlack),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: 120,
                              height: 120,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: kRosePale,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: kRose.withOpacity(0.1),
                                      blurRadius: 30,
                                      spreadRadius: 5)
                                ],
                              ),
                              child: SvgPicture.asset(
                                'assets/clush_logo_alt.svg',
                                colorFilter: const ColorFilter.mode(
                                    kRose, BlendMode.srcIn),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              "No matches yet",
                              style: GoogleFonts.gabarito(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: kBlack),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 48),
                              child: Text(
                                "The best things happen when you least expect them. Keep swiping!",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.figtree(
                                    fontSize: 16, color: kInkMuted, height: 1.5),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        )
                            .animate()
                            .fade(duration: 600.ms)
                            .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                      ),
                    ],
                  )
                : ListView.builder(
                    key: const ValueKey('list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final match = matches[index];
                      final unread = (match['unread_count'] as int? ?? 0);
                      final hasUnread = unread > 0;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
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
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
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
                                        (match['display_name'] as String)[0]
                                            .toUpperCase(),
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
                                )
                              else
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: ActivityBadge(
                                    lastSeenAt:
                                        match['last_seen_at'] as String?,
                                    compact: true,
                                  ),
                                ),
                            ],
                          ),
                          title: Text(match['display_name'] as String,
                              style: GoogleFonts.gabarito(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: kBlack)),
                          subtitle: hasUnread
                              ? Text(
                                  '$unread ${unread == 1 ? 'new message' : 'new messages'}',
                                  style: GoogleFonts.figtree(
                                      color: kRose, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : ActivityBadge(
                                  lastSeenAt: match['last_seen_at'] as String?),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              color: kInkMuted),
                          onTap: () async {
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
                            final myId = _myId;
                            if (myId == null || !mounted) return;
                            final channelId = _getRoomId(
                                myId, match['match_uuid'] as String);
                            final ch = StreamService
                                .instance.client.state.channels[channelId];
                            final count = ch?.state?.unreadCount ?? 0;
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
      ),
    );
  }
}
