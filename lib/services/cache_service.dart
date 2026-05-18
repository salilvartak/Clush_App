import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clush/services/matching_service.dart';

class CacheService {
  static final CacheService instance = CacheService._internal();
  CacheService._internal();

  static const String _kDiscoveryFeed = 'cache_discovery_feed';
  static const String _kMatches       = 'cache_matches';
  static const String _kLikes         = 'cache_likes';
  static const String _kSaved         = 'cache_saved';
  static const String _kWallet        = 'cache_wallet';
  static const String _kMyProfile     = 'cache_my_profile';
  static const String _kIsVerified    = 'cache_is_verified';

  final MatchingService _matchingService = MatchingService();

  // Cached prefs instance so subsequent reads are synchronous.
  SharedPreferences? _prefs;
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ─── Generic read / write ────────────────────────────────────────────────

  Future<void> _write(String key, dynamic data) async {
    final prefs = await _getPrefs();
    await prefs.setString(key, jsonEncode(data));
  }

  dynamic _readSync(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  Future<dynamic> _read(String key) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  // ─── Discovery feed ──────────────────────────────────────────────────────

  Future<void> cacheDiscoveryFeed(List<Map<String, dynamic>> data) =>
      _write(_kDiscoveryFeed, data);

  Future<List<Map<String, dynamic>>?> getCachedDiscoveryFeed() async {
    final raw = await _read(_kDiscoveryFeed);
    if (raw is! List) return null;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ─── Matches ─────────────────────────────────────────────────────────────

  Future<void> cacheMatches(List<Map<String, dynamic>> data) =>
      _write(_kMatches, data);

  /// Returns cached matches synchronously if prefs are already loaded.
  List<Map<String, dynamic>>? getCachedMatchesSync() {
    final raw = _readSync(_kMatches);
    if (raw is! List) return null;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>?> getCachedMatches() async {
    final raw = await _read(_kMatches);
    if (raw is! List) return null;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ─── Likes ───────────────────────────────────────────────────────────────

  Future<void> cacheLikes(List<Map<String, dynamic>> data) =>
      _write(_kLikes, data);

  List<Map<String, dynamic>>? getCachedLikesSync() {
    final raw = _readSync(_kLikes);
    if (raw is! List) return null;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>?> getCachedLikes() async {
    final raw = await _read(_kLikes);
    if (raw is! List) return null;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ─── Saved profiles ──────────────────────────────────────────────────────

  Future<void> cacheSaved(List<Map<String, dynamic>> data) =>
      _write(_kSaved, data);

  Future<List<Map<String, dynamic>>?> getCachedSaved() async {
    final raw = await _read(_kSaved);
    if (raw is! List) return null;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ─── My profile ──────────────────────────────────────────────────────────

  Future<void> cacheMyProfile(Map<String, dynamic> data) =>
      _write(_kMyProfile, data);

  Future<Map<String, dynamic>?> getCachedMyProfile() async {
    final raw = await _read(_kMyProfile);
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  // ─── Wallet ──────────────────────────────────────────────────────────────

  Future<void> cacheWallet(Map<String, dynamic> data) =>
      _write(_kWallet, data);

  Future<Map<String, dynamic>?> getCachedWallet() async {
    final raw = await _read(_kWallet);
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  // ─── Verification status ─────────────────────────────────────────────────

  Future<void> cacheIsVerified(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_kIsVerified, value);
  }

  /// Returns the cached verification status instantly (null if never cached).
  bool? getCachedIsVerifiedSync() {
    return _prefs?.getBool(_kIsVerified);
  }

  Future<bool?> getCachedIsVerified() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_kIsVerified);
  }

  // ─── Prefetch on login ───────────────────────────────────────────────────

  Future<void> prefetchAndCache() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _getPrefs(); // warm the prefs instance

      final wallet = await _matchingService.getWallet();
      await cacheWallet(wallet);

      final myProfile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.uid)
          .maybeSingle();
      if (myProfile != null) await cacheMyProfile(myProfile);

      final feed = await _matchingService.fetchDiscoveryFeed(
          genderPref: 'Everyone', limit: 20);
      await cacheDiscoveryFeed(feed);
    } catch (e) {
      // Prefetch is best-effort; failures are silent.
    }
  }

  // ─── Warm the prefs instance early ──────────────────────────────────────

  Future<void> init() async => _getPrefs();
}
