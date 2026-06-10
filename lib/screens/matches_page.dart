import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stream_chat_flutter_core/stream_chat_flutter_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'package:clush/providers/matches_provider.dart';
import 'package:clush/providers/profile_provider.dart';
import 'package:clush/screens/chat_page.dart';
import 'package:clush/screens/chat_settings_page.dart';
import 'package:clush/screens/setting_sub_pages.dart';
import 'package:clush/services/stream_service.dart';
import 'package:clush/theme/colors.dart';
import 'package:clush/widgets/activity_badge.dart';
import 'package:clush/widgets/heart_loader.dart';

class MatchesPage extends ConsumerStatefulWidget {
  const MatchesPage({super.key});

  @override
  ConsumerState<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends ConsumerState<MatchesPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final String? _myId = FirebaseAuth.instance.currentUser?.uid;
  StreamSubscription<Event>? _streamEventSub;
  RealtimeChannel? _matchesChannel;

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _streamEventSub?.cancel();
    _matchesChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscriptions() {
    final myId = _myId;
    if (myId == null) return;

    // Supabase real-time: refresh provider when matches table changes.
    _matchesChannel = Supabase.instance.client
        .channel('matches_updates_$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_a',
            value: myId,
          ),
          callback: (_) => ref.read(matchesProvider.notifier).refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_b',
            value: myId,
          ),
          callback: (_) => ref.read(matchesProvider.notifier).refresh(),
        )
        .subscribe();

    // Stream Chat: apply new-message events directly to provider state.
    _streamEventSub = StreamService.instance.client
        .on(EventType.messageNew)
        .listen((event) {
      final channelId = event.cid?.split(':').lastOrNull;
      final sender = event.message?.user?.id;
      if (channelId == null || sender == null) return;

      // Format the preview text so image/audio messages show correctly.
      final msg = event.message;
      final String? preview;
      if (msg != null) {
        final mt = msg.extraData['mt'] as String?;
        if (mt == 'image') {
          final vt = (msg.extraData['vt'] as num?)?.toInt() ?? 0;
          preview = vt == 1 ? '📷 View once' : vt == 2 ? '📷 View twice' : '📷 Photo';
        } else if (mt == 'audio') {
          preview = '🎤 Voice message';
        } else {
          preview = msg.text;
        }
      } else {
        preview = null;
      }

      ref.read(matchesProvider.notifier).applyMessageEvent(
            channelId: channelId,
            myId: myId,
            senderId: sender,
            text: preview,
            createdAt: event.message?.createdAt,
          );
    });
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

    final matchesAsync = ref.watch(matchesProvider);
    final myName = ref.watch(myProfileProvider).value?['full_name'] as String? ?? 'Me';
    final matches = matchesAsync.value ?? [];
    final isLoading = matchesAsync.isLoading && matches.isEmpty;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(
          'Chats',
          style: GoogleFonts.gabarito(
            fontWeight: FontWeight.bold,
            fontSize: 26,
            color: kBlack,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: kBackground,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: kBlack),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const ChatSettingsPage()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(matchesProvider.notifier).refresh(),
        color: kAccent,
        backgroundColor: kCard,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutQuad,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: isLoading
              ? const Center(key: ValueKey('loading'), child: HeartLoader())
              : matches.isEmpty
                  ? ListView(
                      key: const ValueKey('empty'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.04),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 36),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'No chats yet',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSerifDisplay(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: kAccent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Keep swiping to start\na conversation',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.figtree(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 14,
                                  color: kAccent,
                                ),
                              ),
                              Image.asset(
                                'assets/images/no_chat.jpeg',
                                width: 300,
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const SubscriptionsPage())),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 28, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: kAccent,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text('Get Clush',
                                          style: GoogleFonts.gabarito(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      Text('+',
                                          style: GoogleFonts.gabarito(
                                              color: kGold,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                              .animate()
                              .slideY(
                                  begin: 0.1,
                                  end: 0,
                                  curve: Curves.easeOutQuad),
                        ),
                      ],
                    )
                  : ListView.separated(
                      key: const ValueKey('list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 86,
                        endIndent: 16,
                        color: kBorderLight,
                      ),
                      itemBuilder: (context, index) {
                        final match = matches[index];
                        final unread = match['unread_count'] as int? ?? 0;
                        final hasUnread = unread > 0;
                        final isVerified =
                            match['is_verified'] as bool? ?? false;
                        final lastMsg = match['last_message'] as String?;
                        final lastMsgAt =
                            match['last_message_at'] as DateTime?;

                        return InkWell(
                          onTap: () async {
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ChatScreen(
                                  myId: _myId!,
                                  matchId: match['match_uuid'] as String,
                                  matchName: match['display_name'] as String,
                                  myName: myName,
                                  matchPhotoUrl:
                                      match['photo_url'] as String?,
                                ),
                              ),
                            );
                            if (mounted) {
                              ref.read(matchesProvider.notifier).refresh();
                            }
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
