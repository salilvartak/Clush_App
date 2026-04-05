import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  Timer? _timer;

  void start() {
    _ping();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _ping());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _ping() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', uid);
    } catch (_) {}
  }
}
