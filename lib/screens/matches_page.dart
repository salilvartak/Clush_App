import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stream_chat_flutter_core/stream_chat_flutter_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'package:clush/screens/chat_page.dart';
import 'package:clush/services/stream_service.dart';
import 'package:clush/theme/colors.dart';
import 'package:clush/screens/chat_settings_page.dart';
import 'package:clush/services/cache_service.dart';
import 'package:clush/widgets/activity_badge.dart';
import 'package:clush/widgets/heart_loader.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
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
    _loadFromCacheThenFetch();
    _setupRealtime();
  }

  Future<void> _loadFromCacheThenFetch() async {
    final cached = await CacheService.instance.getCachedMatches();
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        matches = cached;
        isLoading = false;
      });
    }
    _fetchData();
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
      final messageText = event.message?.text;
      final createdAt = event.message?.createdAt;

      if (channelId == null || sender == null) return;

      final idx = matches.indexWhere((m) {
        final otherId = m['match_uuid'] as String;
        return _getRoomId(myId, otherId) == channelId;
      });

      if (idx >= 0 && mounted) {
        setState(() {
          if (sender != myId) {
            matches[idx]['unread_count'] = (matches[idx]['unread_count'] as int) + 1;
          }
          matches[idx]['last_message'] = messageText;
          matches[idx]['last_message_at'] = createdAt;
          
          // Re-sort matches to put latest message on top
          matches.sort((a, b) {
            final dateA = a['last_message_at'] as DateTime?;
            final dateB = b['last_message_at'] as DateTime?;
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateB.compareTo(dateA);
          });
        });
      }
    });
  }

  /// Fetch unread counts and last message info for all matches via a single Stream queryChannels call.
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
        final lastMsg = ch.state?.lastMessage;
        
        final idx = matches.indexWhere((m) {
          final otherId = m['match_uuid'] as String;
          return _getRoomId(myId, otherId) == channelId;
        });

        if (idx >= 0) {
          matches[idx]['unread_count'] = unread;
          if (lastMsg != null) {
            matches[idx]['last_message'] = lastMsg.text;
            matches[idx]['last_message_at'] = lastMsg.createdAt;
          }
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Stream unread counts: $e');
    }
  }

  Future<void> _fetchData() async {
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
            profile_a:profiles!user_a(id, full_name, photo_urls, last_seen_at, is_verified),
            profile_b:profiles!user_b(id, full_name, photo_urls, last_seen_at, is_verified)
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
          'is_verified': otherProfile['is_verified'] ?? false,
          'last_message': null,
          'last_message_at': null,
        });
      }

      if (mounted) {
        setState(() {
          matches = loadedMatches;
          isLoading = false;
        });
        CacheService.instance.cacheMatches(loadedMatches);
        _loadStreamUnreadCounts();
        _subscribeStreamEvents();
      }
    } catch (e) {
      debugPrint('❌ Error fetching matches: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _getRoomId(String id1, String id2) {
    final ids = [id1, id2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(
          'Chats',
          style: GoogleFonts.gabarito(
              fontWeight: FontWeight.bold, fontSize: 26, color: kBlack, letterSpacing: -0.5),
        ),
        backgroundColor: kBackground,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: kBlack),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatSettingsPage()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: kAccent,
        backgroundColor: kCard,
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
                              Text(
                                "No chats yet",
                                style: GoogleFonts.gabarito(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: kBlack),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 48),
                                child: Text(
                                  "The best things happen when you least expect them. Keep swiping!",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.figtree(
                                      fontSize: 16, color: kInkMuted, height: 1.5),
                                ),
                              ),
                            ],
                          )
                              .animate()
                              .fade(duration: 600.ms)
                              .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                        ),
                      ],
                    )
                  : ListView.separated(
                      key: const ValueKey('list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: matches.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        indent: 86,
                        endIndent: 16,
                        color: kBorderLight,
                      ),
                      itemBuilder: (context, index) {
                        final match = matches[index];
                        final unread = (match['unread_count'] as int? ?? 0);
                        final hasUnread = unread > 0;
                        final isVerified = match['is_verified'] as bool? ?? false;
                        final lastMsg = match['last_message'] as String?;
                        final lastMsgAt = match['last_message_at'] as DateTime?;

                        return InkWell(
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
                            _loadStreamUnreadCounts();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Avatar with Status Badge
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: kBorderLight, width: 0.5),
                                      ),
                                      child: CircleAvatar(
                                        radius: 30,
                                        backgroundColor: kTagBg,
                                        backgroundImage: match['photo_url'] != null
                                            ? NetworkImage(match['photo_url'] as String)
                                            : null,
                                        child: match['photo_url'] == null
                                            ? Text(
                                                (match['display_name'] as String)[0].toUpperCase(),
                                                style: GoogleFonts.gabarito(
                                                    fontWeight: FontWeight.bold,
                                                    color: kAccent,
                                                    fontSize: 22),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      right: 2,
                                      bottom: 2,
                                      child: ActivityBadge(
                                        lastSeenAt: match['last_seen_at'] as String?,
                                        compact: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                // ── Middle Column (Name & Last Message) ──
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              match['display_name'] as String,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.gabarito(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: kBlack,
                                              ),
                                            ),
                                          ),
                                          if (isVerified) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.verified,
                                                size: 16, color: kGold),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lastMsg ?? "Tap to start chatting",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.figtree(
                                          fontSize: 14,
                                          color: hasUnread ? kBlack : kInkMuted,
                                          fontWeight: hasUnread
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // ── Right Column (Time & Unread Badge) ──
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatTime(lastMsgAt),
                                      style: GoogleFonts.figtree(
                                        fontSize: 11,
                                        color: kInkMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (hasUnread) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: kRose,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          unread > 99 ? '99+' : '$unread',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ).animate().fade(duration: 400.ms, delay: (40 * index).ms);
                      },
                    ),
        ),
      ),
    );
  }
}
