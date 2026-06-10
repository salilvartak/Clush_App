import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_chat_flutter_core/stream_chat_flutter_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:clush/services/cache_service.dart';
import 'package:clush/services/stream_service.dart';

// ─── Matches notifier ────────────────────────────────────────────────────────

class MatchesNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final cached = await CacheService.instance.getCachedMatches();
    if (cached != null && cached.isNotEmpty) {
      Future.microtask(_fetchAndUpdate);
      return cached;
    }
    return _fetchAndUpdate();
  }

  Future<List<Map<String, dynamic>>> _fetchAndUpdate() async {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    if (myId == null) return [];

    final supabase = Supabase.instance.client;
    final blockedIds = <String>{};

    try {
      final rows = await supabase
          .from('blocks')
          .select('blocker_id, blocked_id')
          .or('blocker_id.eq.$myId,blocked_id.eq.$myId');
      for (final b in rows as List) {
        final a = b['blocker_id'].toString();
        final bId = b['blocked_id'].toString();
        blockedIds.add(a == myId ? bId : a);
      }
    } catch (_) {}

    final data = await supabase.from('matches').select('''
      *,
      profile_a:profiles!user_a(id, full_name, photo_urls, last_seen_at, verification_status),
      profile_b:profiles!user_b(id, full_name, photo_urls, last_seen_at, verification_status)
    ''').or('user_a.eq.$myId,user_b.eq.$myId');

    final loaded = <Map<String, dynamic>>[];
    for (final match in data as List) {
      final isUserA = match['user_a'] == myId;
      final other = isUserA ? match['profile_b'] : match['profile_a'];
      if (other == null) continue;

      final otherId = other['id'] as String;
      if (blockedIds.contains(otherId)) continue;

      final photos = other['photo_urls'];
      final photoUrl =
          (photos is List && photos.isNotEmpty) ? photos[0] as String? : null;

      loaded.add({
        'match_uuid': otherId,
        'display_name': other['full_name'],
        'photo_url': photoUrl,
        'unread_count': 0,
        'last_seen_at': other['last_seen_at'],
        'is_verified': other['verification_status'] == 'approved',
        'last_message': null,
        'last_message_at': null,
      });
    }

    await CacheService.instance.cacheMatches(loaded);
    state = AsyncData(loaded);

    // Enrich with Stream Chat data without blocking the UI.
    Future.microtask(() => _enrichWithStreamData(myId, loaded));
    return loaded;
  }

  Future<void> _enrichWithStreamData(
    String myId,
    List<Map<String, dynamic>> matches,
  ) async {
    try {
      final channels = await StreamService.instance.client
          .queryChannels(
            filter: Filter.in_('members', [myId]),
            state: true,
            watch: false,
          )
          .first;

      bool changed = false;
      for (final ch in channels) {
        final channelId = ch.id;
        if (channelId == null) continue;

        final unread = ch.state?.unreadCount ?? 0;
        final lastMsg = ch.state?.lastMessage;

        final idx = matches.indexWhere(
          (m) => _roomId(myId, m['match_uuid'] as String) == channelId,
        );
        if (idx < 0) continue;

        matches[idx]['unread_count'] = unread;
        if (lastMsg != null) {
          matches[idx]['last_message'] = _previewText(lastMsg);
          matches[idx]['last_message_at'] = lastMsg.createdAt;
        }
        changed = true;
      }
      if (changed) state = AsyncData(List.from(matches));
    } catch (_) {}
  }

  /// Called from the widget layer when a new Stream Chat message arrives.
  void applyMessageEvent({
    required String channelId,
    required String myId,
    required String senderId,
    required String? text,
    required DateTime? createdAt,
  }) {
    state.whenData((matches) {
      final idx = matches.indexWhere(
        (m) => _roomId(myId, m['match_uuid'] as String) == channelId,
      );
      if (idx < 0) return;

      final updated = List<Map<String, dynamic>>.from(matches);
      updated[idx] = {
        ...updated[idx],
        if (senderId != myId)
          'unread_count': (updated[idx]['unread_count'] as int) + 1,
        'last_message': text,
        'last_message_at': createdAt,
      };

      updated.sort((a, b) {
        final da = a['last_message_at'] as DateTime?;
        final db = b['last_message_at'] as DateTime?;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

      state = AsyncData(updated);
    });
  }

  Future<void> refresh() async => state = AsyncData(await _fetchAndUpdate());

  /// Returns a human-readable preview string for a Stream Chat message.
  static String? _previewText(Message msg) {
    final mt = msg.extraData['mt'] as String?;
    if (mt == 'image') {
      final vt = (msg.extraData['vt'] as num?)?.toInt() ?? 0;
      if (vt == 1) return '📷 View once';
      if (vt == 2) return '📷 View twice';
      return '📷 Photo';
    }
    if (mt == 'audio') return '🎤 Voice message';
    return msg.text;
  }

  static String _roomId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}

final matchesProvider =
    AsyncNotifierProvider<MatchesNotifier, List<Map<String, dynamic>>>(
  MatchesNotifier.new,
);

// ─── Total unread count ──────────────────────────────────────────────────────

/// Streams the running total unread count from Stream Chat.
final unreadCountProvider = StreamProvider<int>((ref) {
  return StreamService.instance.client
      .on()
      .map((event) => event.totalUnreadCount ?? 0)
      .distinct();
});
