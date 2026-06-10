import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clush/services/cache_service.dart';
import 'package:clush/services/matching_service.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

final class WalletState {
  const WalletState({
    this.likesRemaining = 6,
    this.superLikesRemaining = 1,
    this.rewindsRemaining = 2,
    this.savesRemaining = 2,
    this.isPremium = false,
  });

  factory WalletState.fromMap(Map<String, dynamic> map) => WalletState(
        likesRemaining: (map['likes_remaining'] as num?)?.toInt() ?? 6,
        superLikesRemaining:
            (map['super_likes_remaining'] as num?)?.toInt() ?? 1,
        rewindsRemaining: (map['rewinds_remaining'] as num?)?.toInt() ?? 2,
        savesRemaining:
            (map['profile_saves_remaining'] as num?)?.toInt() ?? 2,
        isPremium: map['is_premium'] as bool? ?? false,
      );

  final int likesRemaining;
  final int superLikesRemaining;
  final int rewindsRemaining;
  final int savesRemaining;
  final bool isPremium;

  WalletState copyWith({
    int? likesRemaining,
    int? superLikesRemaining,
    int? rewindsRemaining,
    int? savesRemaining,
    bool? isPremium,
  }) =>
      WalletState(
        likesRemaining: likesRemaining ?? this.likesRemaining,
        superLikesRemaining: superLikesRemaining ?? this.superLikesRemaining,
        rewindsRemaining: rewindsRemaining ?? this.rewindsRemaining,
        savesRemaining: savesRemaining ?? this.savesRemaining,
        isPremium: isPremium ?? this.isPremium,
      );

  Map<String, dynamic> toMap() => {
        'likes_remaining': likesRemaining,
        'super_likes_remaining': superLikesRemaining,
        'rewinds_remaining': rewindsRemaining,
        'profile_saves_remaining': savesRemaining,
        'is_premium': isPremium,
      };
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class WalletNotifier extends AsyncNotifier<WalletState> {
  @override
  Future<WalletState> build() async {
    final cached = await CacheService.instance.getCachedWallet();
    if (cached != null) {
      // Serve cache immediately; refresh in background.
      Future.microtask(_fetchAndUpdate);
      return WalletState.fromMap(cached);
    }
    return _fetchAndUpdate();
  }

  Future<WalletState> _fetchAndUpdate() async {
    final map = await MatchingService().getWallet();
    if (map.isEmpty) return state.value ?? const WalletState();
    final wallet = WalletState.fromMap(map);
    await CacheService.instance.cacheWallet(wallet.toMap());
    state = AsyncData(wallet);
    return wallet;
  }

  /// Decrement like count optimistically; persists to cache.
  void decrementLikes() => _mutate(
        (w) => w.copyWith(likesRemaining: (w.likesRemaining - 1).clamp(0, 999)),
      );

  /// Decrement super-like count optimistically; persists to cache.
  void decrementSuperLikes() => _mutate(
        (w) => w.copyWith(
          superLikesRemaining: (w.superLikesRemaining - 1).clamp(0, 999),
        ),
      );

  /// Force a full re-fetch from the server.
  Future<void> refresh() async => state = AsyncData(await _fetchAndUpdate());

  void _mutate(WalletState Function(WalletState) updater) {
    state.whenData((current) {
      final next = updater(current);
      state = AsyncData(next);
      CacheService.instance.cacheWallet(next.toMap());
    });
  }
}

final walletProvider = AsyncNotifierProvider<WalletNotifier, WalletState>(
  WalletNotifier.new,
);
