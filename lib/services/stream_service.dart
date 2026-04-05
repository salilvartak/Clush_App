import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:stream_chat_flutter_core/stream_chat_flutter_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class StreamService {
  StreamService._();
  static final StreamService instance = StreamService._();

  // ─── REPLACE WITH YOUR STREAM API KEY ───────────────────────────────────
  static const _apiKey = 'kqxgf6aywea2';
  // ────────────────────────────────────────────────────────────────────────

  late final StreamChatClient client;
  bool _connected = false;

  Future<void> init() async {
    client = StreamChatClient(_apiKey, logLevel: Level.WARNING);
    
    // Listen to Firebase auth changes to automatically connect/disconnect
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        print('StreamService: Auth detected. Connecting...');
        connectCurrentUser().catchError((e) => print('StreamService: Connection failed: $e'));
      } else {
        print('StreamService: No auth. Disconnecting...');
        disconnect().catchError((e) => print('StreamService: Disconnect failed: $e'));
      }
    });

    // Also try immediate connection if user is already logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      connectCurrentUser().catchError((e) => print('StreamService: Initial connection failed: $e'));
    }
  }

  Future<void> connectCurrentUser() async {
    if (_connected) {
       print('StreamService: Already connected.');
       return;
    }
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
       print('StreamService: Connect aborted - No Firebase user found.');
       return;
    }

    try {
      print('StreamService: Fetching token for ${fbUser.uid}...');
      final token = await _fetchToken(fbUser.uid);
      print('StreamService: Token received. Connecting to Stream...');
      
      await client.connectUser(
        User(
          id: fbUser.uid,
          extraData: {
            'name': fbUser.displayName ?? '',
            'image': fbUser.photoURL ?? '',
          },
        ),
        token,
      );
      _connected = true;
      print('StreamService: SUCCESS! Connected as ${fbUser.uid}');
    } catch (e, st) {
      print('StreamService: ERROR connecting: $e');
      print('Stack trace: $st');
      rethrow;
    }
  }

  Future<String> _fetchToken(String userId) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'stream-token',
        body: {'user_id': userId},
      );
      
      if (res.status != 200) {
        throw Exception('Edge function returned status ${res.status}: ${res.data}');
      }
      
      final token = res.data['token'] as String?;
      if (token == null) {
        throw Exception('Token is null in response: ${res.data}');
      }
      return token;
    } catch (e) {
      print('StreamService: Failed to fetch token: $e');
      rethrow;
    }
  }

  /// Returns the Stream channel for a 1-to-1 chat (auto-creates if missing).
  Channel channel(String myId, String matchId) {
    final ids = [myId, matchId]..sort();
    final channelId = '${ids[0]}_${ids[1]}';
    return client.channel(
      'messaging',
      id: channelId,
      extraData: {
        'members': [myId, matchId],
      },
    );
  }

  Future<void> disconnect() async {
    if (!_connected) return;
    await client.disconnectUser();
    _connected = false;
  }
}
