import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:clush/widgets/heart_loader.dart';
import 'package:clush/services/crypto_service.dart';
import 'package:clush/services/matching_service.dart';
import 'package:clush/theme/colors.dart';

// ─── Static row cache — filled by MatchesPage preload ────────────────────────
class ChatCache {
  ChatCache._();
  // roomId → raw rows from Supabase (unprocessed)
  static final Map<String, List<Map<String, dynamic>>> _rows = {};

  static void store(String roomId, List<Map<String, dynamic>> rows) =>
      _rows[roomId] = rows;

  static List<Map<String, dynamic>>? take(String roomId) {
    final rows = _rows[roomId];
    _rows.remove(roomId); // consume once
    return rows;
  }

  /// Preload raw rows for a room in the background (called from MatchesPage).
  static Future<void> preload(String roomId) async {
    if (_rows.containsKey(roomId)) return; // already cached
    try {
      final rows = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('room_id', roomId)
          .order('created_at');
      _rows[roomId] = List<Map<String, dynamic>>.from(rows);
    } catch (_) {}
  }
}

class ChatScreen extends StatefulWidget {
  final String myId;
  final String matchId;
  final String myName;
  final String matchName;
  final String? matchPhotoUrl;

  const ChatScreen({
    super.key,
    required this.myId,
    required this.matchId,
    required this.myName,
    required this.matchName,
    this.matchPhotoUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;
  final _matchingService = MatchingService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _audioPlayer = AudioPlayer();
  final _audioRecorder = AudioRecorder();

  // Messages
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  // UI state
  bool _isAtBottom = true;
  int _unreadCount = 0;
  bool _hasText = false;
  bool _isRecording = false;
  bool _isUploadingMedia = false;
  String? _currentlyPlayingId;
  String? _cryptoError;
  bool _isMatchTyping = false;
  Map<String, dynamic>? _replyTo;

  // Crypto
  SecretKey? _conversationKey;
  bool _cryptoReady = false;

  // Realtime
  RealtimeChannel? _channel;
  late String _roomId;

  // Read receipts — when the match last read this room
  DateTime? _matchLastReadAt;

  // Typing debounce
  bool _wasTyping = false;
  Timer? _typingDebounce;
  Timer? _typingExpiry;

  // Unread divider
  bool _hasUnreadDivider = false;

  // Media caches — keyed by storage path so futures are created only once
  final Map<String, Future<Uint8List?>> _imageFutures = {};
  final Map<String, Future<String?>> _audioPathFutures = {};

  // Track which message IDs are freshly received (so we only animate new ones)
  final Set<String> _freshIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _roomId = _buildRoomId(widget.myId, widget.matchId);
    _scrollController.addListener(_onScroll);
    _initChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel?.unsubscribe();
    _typingDebounce?.cancel();
    _typingExpiry?.cancel();
    _clearTypingStatus();
    _textController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _clearTypingStatus();
  }

  String _buildRoomId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Init
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initChat() async {
    await _setupCrypto();
    await _loadHistory();
    _subscribeAll();
  }

  Future<void> _setupCrypto() async {
    try {
      await CryptoService.ensurePublicKeyUploaded();
      final row = await _supabase
          .from('profiles')
          .select('public_key')
          .eq('id', widget.matchId)
          .maybeSingle();
      final theirKey = row?['public_key'] as String?;
      if (theirKey == null || theirKey.isEmpty) {
        if (mounted) setState(() => _cryptoError = 'Partner has not set up encryption yet.');
        return;
      }
      _conversationKey = await CryptoService.deriveConversationKey(_roomId, theirKey);
      if (mounted) setState(() => _cryptoReady = true);
    } catch (_) {
      if (mounted) setState(() => _cryptoError = 'Encryption setup failed.');
    }
  }

  Future<void> _loadHistory() async {
    try {
      // Use preloaded cache if available for instant display
      final cached = ChatCache.take(_roomId);
      final rawRows = cached != null && cached.isNotEmpty
          ? cached
          : List<Map<String, dynamic>>.from(
              await _supabase
                  .from('messages')
                  .select()
                  .eq('room_id', _roomId)
                  .order('created_at'),
            );

      // Fetch read statuses — optional (table may not exist yet)
      List readRows = [];
      try {
        readRows = await _supabase
            .from('chat_read_status')
            .select('user_id, last_read_at')
            .eq('room_id', _roomId);
      } catch (_) {}

      DateTime? myLastReadAt;
      DateTime? matchLastReadAt;
      for (final r in readRows) {
        final uid = r['user_id'] as String?;
        final ts = DateTime.tryParse(r['last_read_at'] as String? ?? '');
        if (uid == widget.myId) myLastReadAt = ts;
        if (uid == widget.matchId) matchLastReadAt = ts;
      }
      _matchLastReadAt = matchLastReadAt;

      // Decrypt / parse all messages
      final parsed = <Map<String, dynamic>>[];
      for (final row in rawRows) {
        final msg = await _parseRow(row);
        if (msg != null) parsed.add(msg);
      }

      // Find first unread message from the other person
      int firstUnreadIdx = -1;
      if (myLastReadAt != null) {
        for (int i = 0; i < parsed.length; i++) {
          if (parsed[i]['isMe'] as bool) continue;
          final ts = DateTime.tryParse(parsed[i]['timestamp'] as String? ?? '');
          if (ts != null && ts.isAfter(myLastReadAt)) {
            firstUnreadIdx = i;
            break;
          }
        }
      }

      final unreadCount = firstUnreadIdx >= 0
          ? parsed.sublist(firstUnreadIdx).where((m) => !(m['isMe'] as bool)).length
          : 0;

      if (firstUnreadIdx >= 0 && unreadCount > 0) {
        parsed.insert(
            firstUnreadIdx, _dividerItem(unreadCount, parsed[firstUnreadIdx]['timestamp']));
      }

      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(parsed);
        _isLoading = false;
        _hasUnreadDivider = firstUnreadIdx >= 0 && unreadCount > 0;
      });

      if (_hasUnreadDivider) {
        // Small delay so list measures before we scroll
        Future.delayed(const Duration(milliseconds: 80), () {
          if (mounted) _scrollToIndex(firstUnreadIdx);
        });
      } else {
        // Delay to let the ListView finish layout before jumping to bottom
        Future.delayed(const Duration(milliseconds: 80), () {
          if (mounted) _scrollToBottom(animate: false);
        });
        Future.delayed(const Duration(milliseconds: 300), () => _markAsRead());
      }
    } catch (e, st) {
      debugPrint('_loadHistory error: $e\n$st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _dividerItem(int count, String timestamp) => {
        'id': '__divider__',
        'type': '_divider',
        'count': count,
        'isMe': false,
        'timestamp': timestamp,
        'isDeleted': false,
        'reply_to': null,
      };

  // ─────────────────────────────────────────────────────────────────────────
  // Realtime — single channel for all events
  // ─────────────────────────────────────────────────────────────────────────

  void _subscribeAll() {
    _channel = _supabase.channel('room_$_roomId')

        // New / updated messages
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: _roomId),
          callback: _onMessageInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: _roomId),
          callback: _onMessageUpdate,
        )

        // Read receipts
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_read_status',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: _roomId),
          callback: _onReadStatusChange,
        )

        // Typing
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'typing_status',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: _roomId),
          callback: _onTypingChange,
        )

        .subscribe();
  }

  Future<void> _onMessageInsert(PostgresChangePayload payload) async {
    final row = payload.newRecord;
    // Ignore our own optimistic inserts (we already added them)
    if (row['sender'] == widget.myId) return;
    final msg = await _parseRow(row);
    if (msg == null || !mounted) return;
    final id = msg['id']?.toString();
    if (id != null) _freshIds.add(id);
    setState(() {
      _messages.add(msg);
      if (!_isAtBottom) _unreadCount++;
    });
    if (_isAtBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      _markAsRead();
    }
  }

  Future<void> _onMessageUpdate(PostgresChangePayload payload) async {
    final row = payload.newRecord;
    final id = row['id'] as String?;
    if (id == null || !mounted) return;
    final idx = _messages.indexWhere((m) => m['id'] == id);
    if (idx < 0) return;
    final updated = await _parseRow(row);
    if (updated == null || !mounted) return;
    setState(() => _messages[idx] = updated);
  }

  void _onReadStatusChange(PostgresChangePayload payload) {
    final row = payload.newRecord;
    final uid = row['user_id'] as String?;
    // Only care about match's read status for blue ticks
    if (uid != widget.matchId) return;
    final ts = DateTime.tryParse(row['last_read_at'] as String? ?? '');
    if (ts != null && mounted) {
      // Only update if newer than what we have
      if (_matchLastReadAt == null || ts.isAfter(_matchLastReadAt!)) {
        setState(() => _matchLastReadAt = ts);
      }
    }
  }

  void _onTypingChange(PostgresChangePayload payload) {
    final row = payload.newRecord;
    if ((row['user_id'] as String?) != widget.matchId) return;
    final updatedAt = DateTime.tryParse(row['updated_at'] as String? ?? '');
    final isTyping = updatedAt != null && DateTime.now().difference(updatedAt).inSeconds < 6;
    if (mounted && isTyping != _isMatchTyping) {
      setState(() => _isMatchTyping = isTyping);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Message parsing
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _parseRow(Map<String, dynamic> row) async {
    final sender = row['sender'] as String? ?? '';
    final isMe = sender == widget.myId;
    final isDeleted = row['deleted_at'] != null;
    final encPayload = row['encrypted_content'] as String? ?? '';

    String type = 'text';
    String data = '';

    if (isDeleted) {
      type = 'deleted';
    } else if (encPayload.isNotEmpty) {
      String? plain;
      if (_conversationKey != null) {
        plain = await CryptoService.decryptMessage(encPayload, _conversationKey!);
      }
      // If decryption failed or no key, try reading as plain JSON (fallback mode)
      if (plain == null) {
        try {
          final map = jsonDecode(encPayload) as Map<String, dynamic>;
          if (map.containsKey('data') && !map.containsKey('ct')) {
            plain = encPayload; // it's plain JSON, parse below
          }
        } catch (_) {}
      }
      if (plain != null) {
        if (plain.startsWith('{')) {
          try {
            final map = jsonDecode(plain) as Map<String, dynamic>;
            type = (map['type'] as String?) ?? 'text';
            data = (map['data'] as String?) ?? plain;
          } catch (_) {
            data = plain;
          }
        } else {
          data = plain;
        }
      } else {
        data = '🔒 Encrypted message';
      }
    }

    return {
      'id': row['id'],
      'sender': sender,
      'type': type,
      'data': data,
      'timestamp': row['created_at'] as String? ?? DateTime.now().toIso8601String(),
      'isMe': isMe,
      'isDeleted': isDeleted,
      'reply_to': row['reply_to'],
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sending
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final replyId = _replyTo?['id'];
    _textController.clear();
    setState(() {
      _hasText = false;
      _replyTo = null;
      _wasTyping = false;
    });
    _clearTypingStatus();

    // Optimistic
    final optimistic = _buildOptimistic(type: 'text', data: text, replyTo: replyId);
    setState(() => _messages.add(optimistic));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final payload = jsonEncode({'type': 'text', 'data': text});
      final envelope = _conversationKey != null
          ? await CryptoService.encryptMessage(payload, _conversationKey!)
          : payload; // plaintext fallback when E2EE not ready
      await _supabase.from('messages').insert({
        'room_id': _roomId,
        'sender': widget.myId,
        'encrypted_content': envelope,
        'type': 'text',
        if (replyId != null) 'reply_to': replyId,
      });
    } catch (e) {
      if (mounted) {
        setState(() => _messages.remove(optimistic));
        _showToast('Failed to send. Try again.', isError: true);
      }
    }
  }

  Future<void> _sendImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 75);
    if (file == null) return;
    setState(() => _isUploadingMedia = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last.toLowerCase();
      final path = 'chat/$_roomId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final uploadBytes = _conversationKey != null
          ? Uint8List.fromList(utf8.encode(await CryptoService.encryptBytes(bytes, _conversationKey!)))
          : bytes;
      final contentType = _conversationKey != null ? 'application/octet-stream' : 'image/$ext';
      await _supabase.storage.from('chat-media').uploadBinary(
            path,
            uploadBytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      final payload = jsonEncode({'type': 'image', 'data': path});
      final envelope = _conversationKey != null
          ? await CryptoService.encryptMessage(payload, _conversationKey!)
          : payload;
      await _supabase.from('messages').insert({
        'room_id': _roomId,
        'sender': widget.myId,
        'encrypted_content': envelope,
        'type': 'image',
      });
      // Cache the bytes locally so the preview is instant
      _imageFutures[path] = Future.value(bytes);
      if (mounted) {
        setState(() {
          _isUploadingMedia = false;
          _messages.add(_buildOptimistic(type: 'image', data: path));
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
        _showToast('Image upload failed.', isError: true);
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) await _sendAudio(path);
    } else {
      if (!await _audioRecorder.hasPermission()) return;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      if (mounted) setState(() => _isRecording = true);
    }
  }

  Future<void> _sendAudio(String localPath) async {
    setState(() => _isUploadingMedia = true);
    try {
      final bytes = await File(localPath).readAsBytes();
      final storagePath = 'chat/$_roomId/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final uploadBytes = _conversationKey != null
          ? Uint8List.fromList(utf8.encode(await CryptoService.encryptBytes(bytes, _conversationKey!)))
          : bytes;
      await _supabase.storage.from('chat-media').uploadBinary(
            storagePath,
            uploadBytes,
            fileOptions: FileOptions(contentType: _conversationKey != null ? 'application/octet-stream' : 'audio/m4a'),
          );
      final payload = jsonEncode({'type': 'audio', 'data': storagePath});
      final envelope = _conversationKey != null
          ? await CryptoService.encryptMessage(payload, _conversationKey!)
          : payload;
      await _supabase.from('messages').insert({
        'room_id': _roomId,
        'sender': widget.myId,
        'encrypted_content': envelope,
        'type': 'audio',
      });
      // Cache local path so playback is instant
      _audioPathFutures[storagePath] = Future.value(localPath);
      if (mounted) {
        setState(() {
          _isUploadingMedia = false;
          _messages.add(_buildOptimistic(type: 'audio', data: storagePath));
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
        _showToast('Audio upload failed.', isError: true);
      }
    }
  }

  Map<String, dynamic> _buildOptimistic({
    required String type,
    required String data,
    String? replyTo,
  }) =>
      {
        'id': null,
        'sender': widget.myId,
        'type': type,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'isMe': true,
        'isDeleted': false,
        'reply_to': replyTo,
      };

  Future<void> _deleteMessage(Map<String, dynamic> msg) async {
    final id = msg['id'];
    if (id == null) return;
    try {
      await _supabase
          .from('messages')
          .update({'deleted_at': DateTime.now().toIso8601String()}).eq('id', id);
      final idx = _messages.indexWhere((m) => m['id'] == id);
      if (idx >= 0 && mounted) {
        setState(() => _messages[idx] = {
              ..._messages[idx],
              'type': 'deleted',
              'isDeleted': true,
              'data': '',
            });
      }
    } catch (_) {
      _showToast('Could not delete message.', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Audio playback
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> _getAudioPath(String storagePath) async {
    // Check if it's a local file path (just recorded)
    if (storagePath.startsWith('/')) return storagePath;
    // Download + decrypt from storage
    try {
      final url = await _supabase.storage.from('chat-media').createSignedUrl(storagePath, 300);
      final req = await HttpClient().getUrl(Uri.parse(url));
      final res = await req.close();
      final raw = <int>[];
      await for (final chunk in res) {
        raw.addAll(chunk);
      }
      Uint8List? plain;
      if (_conversationKey != null) {
        plain = await CryptoService.decryptBytes(utf8.decode(raw), _conversationKey!);
      }
      // Fallback: raw bytes are the audio directly
      final audioBytes = plain ?? Uint8List.fromList(raw);
      final dir = await getTemporaryDirectory();
      final tmp = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await File(tmp).writeAsBytes(audioBytes);
      return tmp;
    } catch (_) {
      return null;
    }
  }

  Future<void> _playAudio(String id, String storagePath) async {
    if (_currentlyPlayingId == id) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _currentlyPlayingId = null);
      return;
    }
    if (mounted) setState(() => _currentlyPlayingId = id);
    try {
      _audioPathFutures[storagePath] ??= _getAudioPath(storagePath);
      final path = await _audioPathFutures[storagePath];
      if (path == null || !mounted) return;
      await _audioPlayer.play(DeviceFileSource(path));
      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _currentlyPlayingId = null);
      });
    } catch (_) {
      if (mounted) setState(() => _currentlyPlayingId = null);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Images
  // ─────────────────────────────────────────────────────────────────────────

  Future<Uint8List?> _downloadAndDecryptImage(String storagePath) async {
    try {
      final url = await _supabase.storage.from('chat-media').createSignedUrl(storagePath, 300);
      final req = await HttpClient().getUrl(Uri.parse(url));
      final res = await req.close();
      final raw = <int>[];
      await for (final chunk in res) {
        raw.addAll(chunk);
      }
      if (_conversationKey != null) {
        // Try decrypting — if it's an encrypted envelope
        final decrypted = await CryptoService.decryptBytes(utf8.decode(raw), _conversationKey!);
        if (decrypted != null) return decrypted;
      }
      // Fallback: raw bytes are the image directly
      return Uint8List.fromList(raw);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Typing
  // ─────────────────────────────────────────────────────────────────────────

  void _onTextChanged(String value) {
    final has = value.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);

    if (has) {
      if (!_wasTyping) {
        _wasTyping = true;
        _updateTypingStatus(true);
      }
      // Reset expiry — if user stops typing for 4s, clear
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(seconds: 4), () {
        _wasTyping = false;
        _updateTypingStatus(false);
      });
    } else {
      if (_wasTyping) {
        _wasTyping = false;
        _typingDebounce?.cancel();
        _updateTypingStatus(false);
      }
    }
  }

  void _updateTypingStatus(bool isTyping) {
    if (isTyping) {
      _supabase.from('typing_status').upsert({
        'user_id': widget.myId,
        'room_id': _roomId,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, room_id').catchError((_) {});
    } else {
      _clearTypingStatus();
    }
  }

  void _clearTypingStatus() {
    _supabase
        .from('typing_status')
        .delete()
        .eq('user_id', widget.myId)
        .eq('room_id', _roomId)
        .catchError((_) {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Read status
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _markAsRead() async {
    await _matchingService.updateLastRead(_roomId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Scroll
  // ─────────────────────────────────────────────────────────────────────────

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom =
        _scrollController.offset >= _scrollController.position.maxScrollExtent - 80;

    if (atBottom && !_isAtBottom) {
      setState(() {
        _isAtBottom = true;
        _unreadCount = 0;
        if (_hasUnreadDivider) {
          _messages.removeWhere((m) => m['type'] == '_divider');
          _hasUnreadDivider = false;
        }
      });
      _markAsRead();
    } else if (!atBottom && _isAtBottom) {
      setState(() => _isAtBottom = false);
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    // Use double.maxFinite — Flutter clamps to maxScrollExtent automatically,
    // so this works even before the list finishes layout.
    if (animate) {
      _scrollController.animateTo(
        double.maxFinite,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(double.maxFinite);
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const approxItemH = 72.0;
    final offset =
        (index * approxItemH).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(offset);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  bool _shouldShowDateHeader(int index) {
    if (_messages[index]['type'] == '_divider') return false;
    int prev = index - 1;
    while (prev >= 0 && _messages[prev]['type'] == '_divider') prev--;
    if (prev < 0) return true;
    final a = DateTime.tryParse(_messages[index]['timestamp'] as String? ?? '');
    final b = DateTime.tryParse(_messages[prev]['timestamp'] as String? ?? '');
    if (a == null || b == null) return true;
    return a.day != b.day || a.month != b.month || a.year != b.year;
  }

  bool _isMessageRead(Map<String, dynamic> msg) {
    if (_matchLastReadAt == null) return false;
    final ts = DateTime.tryParse(msg['timestamp'] as String? ?? '');
    if (ts == null) return false;
    return !ts.isAfter(_matchLastReadAt!);
  }

  String _formatTime(String? ts) {
    if (ts == null) return '';
    final t = DateTime.tryParse(ts)?.toLocal();
    if (t == null) return '';
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _formatDateHeader(String? ts) {
    if (ts == null) return '';
    final t = DateTime.tryParse(ts)?.toLocal();
    if (t == null) return '';
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(t.year, t.month, t.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[t.weekday - 1];
    }
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${t.day} ${months[t.month - 1]}';
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.figtree(color: Colors.white, fontSize: 13)),
      backgroundColor: isError ? Colors.redAccent : kRose,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_cryptoError != null) _buildCryptoBanner(),
          Expanded(child: _buildBody()),
          if (_replyTo != null) _buildReplyBar(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kCream,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: kBone,
      surfaceTintColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(Icons.arrow_back_ios_new_rounded, color: kInk, size: 20),
        ),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: kRosePale,
            backgroundImage:
                widget.matchPhotoUrl != null ? NetworkImage(widget.matchPhotoUrl!) : null,
            child: widget.matchPhotoUrl == null
                ? const Icon(Icons.person_rounded, size: 22, color: kRose)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.matchName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.gabarito(
                        fontWeight: FontWeight.bold, fontSize: 17, color: kInk, height: 1.1)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isMatchTyping
                      ? Text('typing…',
                          key: const ValueKey('typing'),
                          style: GoogleFonts.figtree(
                              fontSize: 11, color: kRose, fontStyle: FontStyle.italic))
                      : Row(
                          key: const ValueKey('e2ee'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                    color: Color(0xFF4CAF50), shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text('End-to-End Encrypted',
                                style: GoogleFonts.figtree(
                                    fontSize: 10,
                                    color: Color(0xFF388E3C),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: kInkMuted),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (v) {
            if (v == 'block') _confirmBlock();
            if (v == 'report') _showReport();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'report',
              child: Row(children: [
                const Icon(Icons.flag_outlined, color: kInkMuted, size: 18),
                const SizedBox(width: 10),
                Text('Report', style: GoogleFonts.figtree(color: kInk)),
              ]),
            ),
            PopupMenuItem(
              value: 'block',
              child: Row(children: [
                const Icon(Icons.block_rounded, color: Colors.redAccent, size: 18),
                const SizedBox(width: 10),
                Text('Block',
                    style: GoogleFonts.figtree(
                        color: Colors.redAccent, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Crypto banner ────────────────────────────────────────────────────────

  Widget _buildCryptoBanner() {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.lock_open_rounded, size: 15, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_cryptoError!,
                style: GoogleFonts.figtree(fontSize: 12, color: Colors.orange.shade800)),
          ),
        ],
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_isLoading) return const Center(child: HeartLoader());

    if (_messages.isEmpty || (_messages.length == 1 && _messages[0]['type'] == '_divider')) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.waving_hand_rounded, size: 52, color: kRose),
            const SizedBox(height: 14),
            Text('Say hello!',
                style: GoogleFonts.gabarito(
                    fontSize: 22, fontWeight: FontWeight.bold, color: kInk)),
            const SizedBox(height: 6),
            Text('Messages are end-to-end encrypted',
                style: GoogleFonts.figtree(color: kInkMuted, fontSize: 13)),
          ],
        ).animate().fade(duration: 500.ms),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final msg = _messages[index];
            if (msg['type'] == '_divider') {
              return _buildUnreadDivider(msg['count'] as int);
            }
            return _buildMessageRow(msg, index);
          },
        ),
        if (!_isAtBottom) _buildScrollFab(),
      ],
    );
  }

  // ── Message row ──────────────────────────────────────────────────────────

  Widget _buildMessageRow(Map<String, dynamic> msg, int index) {
    final isMe = msg['isMe'] as bool;
    final showDate = _shouldShowDateHeader(index);
    final id = msg['id']?.toString();
    final isFresh = id != null && _freshIds.contains(id);

    Widget row = Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showDate) _buildDateHeader(msg['timestamp'] as String?),
        GestureDetector(
          onLongPress: () => _showMessageMenu(msg),
          onHorizontalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) > 300) setState(() => _replyTo = msg);
          },
          child: Container(
            margin: EdgeInsets.only(
              top: 2,
              bottom: 2,
              left: isMe ? 56 : 0,
              right: isMe ? 0 : 56,
            ),
            child: Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (msg['reply_to'] != null) _buildReplyPreview(msg['reply_to'] as String),
                  _buildBubble(msg, isMe),
                  const SizedBox(height: 2),
                  _buildMeta(msg, isMe),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    // Only animate freshly received messages, not on every rebuild
    if (isFresh) {
      _freshIds.remove(id);
      row = row.animate().fade(duration: 200.ms).slideY(begin: 0.06, end: 0);
    }

    return row;
  }

  Widget _buildDateHeader(String? ts) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(color: kBone, borderRadius: BorderRadius.circular(30)),
        child: Text(_formatDateHeader(ts),
            style: GoogleFonts.figtree(
                fontSize: 11, color: kInkMuted, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Bubble ───────────────────────────────────────────────────────────────

  Widget _buildBubble(Map<String, dynamic> msg, bool isMe) {
    final type = msg['type'] as String;
    final isDeleted = msg['isDeleted'] as bool? ?? false;

    Widget content;
    bool noPadding = false;

    if (isDeleted) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.block_rounded, size: 13, color: kInkMuted),
          const SizedBox(width: 5),
          Text('This message was deleted',
              style: GoogleFonts.figtree(
                  color: kInkMuted, fontSize: 13, fontStyle: FontStyle.italic)),
        ],
      );
    } else if (type == 'image') {
      noPadding = true;
      content = _buildImageBubble(msg['data'] as String);
    } else if (type == 'audio') {
      content = _buildAudioBubble(msg, isMe);
    } else {
      content = Text(msg['data'] as String,
          style: GoogleFonts.figtree(
              fontSize: 15, color: isMe ? Colors.white : kInk, height: 1.45));
    }

    return Container(
      padding: noPadding ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: (isMe && !isDeleted)
            ? const LinearGradient(
                colors: [kRoseLight, kRose],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : null,
        color: (isMe && !isDeleted) ? null : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: (isMe ? kRose : kInk).withOpacity(isMe ? 0.15 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _buildImageBubble(String storagePath) {
    // Use cached future — only created once per path
    _imageFutures[storagePath] ??= _downloadAndDecryptImage(storagePath);
    return FutureBuilder<Uint8List?>(
      future: _imageFutures[storagePath],
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
              width: 220,
              height: 160,
              child: Center(child: HeartLoader(size: 28)));
        }
        if (snap.data == null) {
          return const SizedBox(
              width: 220,
              height: 80,
              child: Center(child: Icon(Icons.broken_image_rounded, color: kInkMuted)));
        }
        return GestureDetector(
          onTap: () => _openFullImage(snap.data!),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(snap.data!, width: 220, height: 220, fit: BoxFit.cover),
          ),
        );
      },
    );
  }

  Widget _buildAudioBubble(Map<String, dynamic> msg, bool isMe) {
    final id = msg['id']?.toString() ?? msg['timestamp'] as String;
    final storagePath = msg['data'] as String;
    final isPlaying = _currentlyPlayingId == id;
    return GestureDetector(
      onTap: () => _playAudio(id, storagePath),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_filled_rounded,
            color: isMe ? Colors.white : kRose,
            size: 34,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Voice message',
                  style: GoogleFonts.figtree(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : kInk)),
              Text(isPlaying ? 'Playing…' : 'Tap to play',
                  style: GoogleFonts.figtree(
                      fontSize: 11, color: isMe ? Colors.white70 : kInkMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(String replyId) {
    final original = _messages.firstWhere(
        (m) => m['id']?.toString() == replyId,
        orElse: () => <String, dynamic>{});
    if (original.isEmpty) return const SizedBox.shrink();
    final type = original['type'] as String? ?? 'text';
    final preview = type == 'audio'
        ? '🎤 Voice message'
        : type == 'image'
            ? '📷 Photo'
            : (original['data'] as String? ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: kRose, width: 3)),
      ),
      child: Text(preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.figtree(fontSize: 12, color: kInkMuted)),
    );
  }

  Widget _buildMeta(Map<String, dynamic> msg, bool isMe) {
    final isRead = isMe ? _isMessageRead(msg) : false;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_formatTime(msg['timestamp'] as String?),
            style: GoogleFonts.figtree(fontSize: 10, color: kInkMuted)),
        if (isMe) ...[
          const SizedBox(width: 3),
          Icon(
            Icons.done_all_rounded,
            size: 14,
            color: isRead ? const Color(0xFF4FC3F7) : kInkMuted,
          ),
        ],
      ],
    );
  }

  // ── Unread divider ───────────────────────────────────────────────────────

  Widget _buildUnreadDivider(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: kRose.withOpacity(0.3), thickness: 1)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: kRose.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: kRose.withOpacity(0.3)),
            ),
            child: Text(
              '$count unread message${count == 1 ? '' : 's'}',
              style: GoogleFonts.figtree(
                  fontSize: 11, color: kRose, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: kRose.withOpacity(0.3), thickness: 1)),
        ],
      ),
    );
  }

  // ── Scroll FAB ───────────────────────────────────────────────────────────

  Widget _buildScrollFab() {
    return Positioned(
      bottom: 12,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () {
            _scrollToBottom();
            _markAsRead();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: kParchment,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: kBone),
              boxShadow: [
                BoxShadow(
                    color: kInk.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 3))
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_unreadCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration:
                        BoxDecoration(color: kRose, borderRadius: BorderRadius.circular(30)),
                    child: Text('$_unreadCount new',
                        style: GoogleFonts.figtree(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(Icons.keyboard_arrow_down_rounded, color: kInkMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Reply bar ────────────────────────────────────────────────────────────

  Widget _buildReplyBar() {
    final r = _replyTo!;
    final type = r['type'] as String? ?? 'text';
    final preview = type == 'audio'
        ? '🎤 Voice message'
        : type == 'image'
            ? '📷 Photo'
            : (r['data'] as String? ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: kBone,
      child: Row(
        children: [
          Container(width: 3, height: 36, color: kRose, margin: const EdgeInsets.only(right: 8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r['isMe'] == true ? 'You' : widget.matchName,
                    style: GoogleFonts.figtree(
                        fontSize: 12, color: kRose, fontWeight: FontWeight.w600)),
                Text(preview,
                    style: GoogleFonts.figtree(fontSize: 12, color: kInkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyTo = null),
            child: const Icon(Icons.close_rounded, size: 18, color: kInkMuted),
          ),
        ],
      ),
    );
  }

  // ── Input bar ────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      decoration:
          BoxDecoration(color: kParchment, border: Border(top: BorderSide(color: kBone))),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: _isUploadingMedia
                  ? const SizedBox(width: 22, height: 22, child: HeartLoader(size: 22))
                  : const Icon(Icons.add_photo_alternate_outlined, color: kInkMuted),
              onPressed: _isUploadingMedia ? null : _showImageSourceSheet,
            ),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: kCream,
                  border: Border.all(color: kBone, width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _textController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  enabled: _cryptoReady && !_isRecording,
                  style: GoogleFonts.figtree(fontSize: 15, color: kInk),
                  decoration: InputDecoration(
                    hintText: _isRecording
                        ? 'Recording…'
                        : _cryptoReady
                            ? 'Write a message…'
                            : 'Encryption not ready…',
                    hintStyle: GoogleFonts.figtree(
                        color: _isRecording ? Colors.redAccent : kInkMuted, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: _onTextChanged,
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (_hasText)
              _sendButton()
            else
              GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.redAccent : kBone,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: _isRecording ? Colors.white : kInkMuted,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sendButton() {
    return GestureDetector(
      onTap: _sendText,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [kRoseLight, kRose],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: kRose.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
      ),
    );
  }

  // ── Sheets / Dialogs ─────────────────────────────────────────────────────

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kParchment,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 36,
                height: 4,
                decoration:
                    BoxDecoration(color: kBone, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: kRose),
              title: Text('Gallery', style: GoogleFonts.figtree(color: kInk, fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
                _sendImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: kRose),
              title: Text('Camera', style: GoogleFonts.figtree(color: kInk, fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
                _sendImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showMessageMenu(Map<String, dynamic> msg) {
    if (msg['isDeleted'] == true || msg['type'] == '_divider') return;
    final isMe = msg['isMe'] as bool;
    showModalBottomSheet(
      context: context,
      backgroundColor: kParchment,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 36,
                height: 4,
                decoration:
                    BoxDecoration(color: kBone, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: kInkMuted),
              title: Text('Reply', style: GoogleFonts.figtree(color: kInk, fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyTo = msg);
              },
            ),
            if (msg['type'] == 'text')
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: kInkMuted),
                title: Text('Copy', style: GoogleFonts.figtree(color: kInk, fontSize: 15)),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: msg['data'] as String? ?? ''));
                  _showToast('Copied');
                },
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: Text('Delete',
                    style: GoogleFonts.figtree(
                        color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 15)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(msg);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openFullImage(Uint8List bytes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0),
          body: Center(child: InteractiveViewer(child: Image.memory(bytes))),
        ),
      ),
    );
  }

  void _confirmBlock() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kParchment,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Block ${widget.matchName}?',
            style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, color: kInk)),
        content: Text("They won't be able to message you.",
            style: GoogleFonts.figtree(color: kInkMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.figtree(color: kInkMuted))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _matchingService.blockUser(widget.matchId);
              if (mounted) Navigator.pop(context);
            },
            child: Text('Block',
                style: GoogleFonts.figtree(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReport() {
    const reasons = [
      'Inappropriate content',
      'Harassment or bullying',
      'Spam',
      'Fake profile',
      'Underage user',
      'Other',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: kParchment,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 36,
                height: 4,
                decoration:
                    BoxDecoration(color: kBone, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text('Report ${widget.matchName}',
                style: GoogleFonts.gabarito(
                    fontSize: 17, fontWeight: FontWeight.bold, color: kInk)),
            const SizedBox(height: 8),
            for (final reason in reasons)
              ListTile(
                title: Text(reason, style: GoogleFonts.figtree(color: kInk, fontSize: 14)),
                onTap: () async {
                  Navigator.pop(context);
                  await _matchingService.reportUser(widget.matchId, reason);
                  if (mounted) {
                    _showToast('Report submitted. Thank you.');
                    Navigator.pop(context);
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
