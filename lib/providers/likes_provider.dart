import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clush/services/cache_service.dart';
import 'package:clush/services/matching_service.dart';

// ─── Likes (who liked me) ────────────────────────────────────────────────────

class LikesNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final cached = await CacheService.instance.getCachedLikes();
    if (cached != null) {
      Future.microtask(_fetchAndUpdate);
      return cached;
    }
    return _fetchAndUpdate();
  }

  Future<List<Map<String, dynamic>>> _fetchAndUpdate() async {
    final users = await MatchingService().fetchWhoLikedMe();
    users.sort((a, b) {
      if (a['like_type'] == 'pulse' && b['like_type'] != 'pulse') return -1;
      if (a['like_type'] != 'pulse' && b['like_type'] == 'pulse') return 1;
      return 0;
    });
    await CacheService.instance.cacheLikes(users);
    state = AsyncData(users);
    return users;
  }

  void remove(String userId) {
    state.whenData((likes) {
      final updated = likes.where((u) => u['id'] != userId).toList();
      state = AsyncData(updated);
      CacheService.instance.cacheLikes(updated);
    });
  }

  Future<void> refresh() async => state = AsyncData(await _fetchAndUpdate());
}

final likesProvider =
    AsyncNotifierProvider<LikesNotifier, List<Map<String, dynamic>>>(
  LikesNotifier.new,
);

// ─── Saved profiles ──────────────────────────────────────────────────────────

class SavedProfilesNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final cached = await CacheService.instance.getCachedSaved();
    if (cached != null) {
      Future.microtask(_fetchAndUpdate);
      return cached;
    }
    return _fetchAndUpdate();
  }

  Future<List<Map<String, dynamic>>> _fetchAndUpdate() async {
    final users = await MatchingService().fetchSavedProfiles();
    await CacheService.instance.cacheSaved(users);
    state = AsyncData(users);
    return users;
  }

  void remove(String userId) {
    state.whenData((saved) {
      final updated = saved.where((u) => u['id'] != userId).toList();
      state = AsyncData(updated);
      CacheService.instance.cacheSaved(updated);
    });
  }

  Future<void> refresh() async => state = AsyncData(await _fetchAndUpdate());
}

final savedProfilesProvider =
    AsyncNotifierProvider<SavedProfilesNotifier, List<Map<String, dynamic>>>(
  SavedProfilesNotifier.new,
);
