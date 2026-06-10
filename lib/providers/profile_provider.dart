import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:clush/services/cache_service.dart';
import 'package:clush/services/matching_service.dart';

// ─── Current user ID ─────────────────────────────────────────────────────────

final currentUserIdProvider = Provider<String?>(
  (_) => FirebaseAuth.instance.currentUser?.uid,
);

// ─── My profile ──────────────────────────────────────────────────────────────

class MyProfileNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async {
    final cached = await CacheService.instance.getCachedMyProfile();
    if (cached != null) {
      Future.microtask(_fetchAndUpdate);
      return cached;
    }
    return _fetchAndUpdate();
  }

  Future<Map<String, dynamic>?> _fetchAndUpdate() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;

    final data = await Supabase.instance.client
        .from('profile_discovery')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;

    final result = Map<String, dynamic>.from(data);

    try {
      final wallet = await MatchingService().getWallet();
      if (wallet.isNotEmpty) {
        result['super_likes_remaining'] =
            (wallet['super_likes_remaining'] as num?)?.toInt() ?? 0;
        result['rewinds_remaining'] =
            (wallet['rewinds_remaining'] as num?)?.toInt() ?? 0;
        result['profile_saves_remaining'] =
            (wallet['profile_saves_remaining'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}

    await CacheService.instance.cacheMyProfile(result);
    state = AsyncData(result);
    return result;
  }

  Future<void> refresh() async => state = AsyncData(await _fetchAndUpdate());
}

final myProfileProvider =
    AsyncNotifierProvider<MyProfileNotifier, Map<String, dynamic>?>(
  MyProfileNotifier.new,
);

// ─── Verification status ─────────────────────────────────────────────────────

class VerificationNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final cached = await CacheService.instance.getCachedIsVerified();
    if (cached != null) {
      Future.microtask(_fetchAndUpdate);
      return cached;
    }
    return _fetchAndUpdate();
  }

  Future<bool> _fetchAndUpdate() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    final data = await Supabase.instance.client
        .from('profile_discovery')
        .select('is_verified')
        .eq('id', userId)
        .maybeSingle();

    final verified = data?['is_verified'] as bool? ?? false;
    await CacheService.instance.cacheIsVerified(verified);
    state = AsyncData(verified);
    return verified;
  }

  Future<void> refresh() async => state = AsyncData(await _fetchAndUpdate());
}

final verificationProvider =
    AsyncNotifierProvider<VerificationNotifier, bool>(
  VerificationNotifier.new,
);
