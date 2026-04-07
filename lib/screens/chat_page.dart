import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:stream_chat_flutter_core/stream_chat_flutter_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:clush/widgets/heart_loader.dart';
import 'package:clush/services/crypto_service.dart';
import 'package:clush/services/matching_service.dart';
import 'package:clush/services/stream_service.dart';
import 'package:clush/theme/colors.dart';

// ─── ChatCache — no-op stub kept for MatchesPage compatibility ────────────────
class ChatCache {
  ChatCache._();
  static Future<void> preload(String roomId) async {}
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
  // Supabase kept only for Storage (media upload/download) and MatchingService
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
  bool _hasText = false;
  bool _isRecording = false;
  bool _isUploadingMedia = false;
  // Media caches — keyed by storage path so futures are created only once
  final Map<String, Future<Uint8List?>> _imageFutures = {};
  final Map<String, Future<String?>> _audioPathFutures = {};

  // Track which message IDs are freshly received (so we only animate new ones)
  final Set<String> _freshIds = {};

  // Twice-view feature
  bool _isEphemeralMode = false;

  String? _currentlyPlayingId;
  String? _cryptoError;
  bool _isMatchTyping = false;
  Map<String, dynamic>? _replyTo;

  // Crypto
  SecretKey? _conversationKey;
  bool _cryptoReady = false;

  // Stream Chat
  Channel? _streamChannel;
  StreamSubscription<List<Message>>? _msgSub;
  StreamSubscription<Event>? _typingStartSub;
  StreamSubscription<Event>? _typingStopSub;
  StreamSubscription<Event>? _readSub;
  StreamSubscription<ConnectionStatus>? _connSub;
  bool _initialLoadDone = false;
  int _prevMsgCount = 0;
  ConnectionStatus _connectionStatus = ConnectionStatus.connected;
  late String _roomId;

  // Read receipts — when the match last read this channel
  DateTime? _matchLastReadAt;

  // Typing debounce
  bool _wasTyping = false;
  Timer? _typingDebounce;

  // Unread divider
  bool _hasUnreadDivider = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _roomId = _buildRoomId(widget.myId, widget.matchId);
    _initChat();
    _enableScreenProtection();
  }

  Future<void> _enableScreenProtection() async {
    try {
      await ScreenProtector.preventScreenshotOn();
    } catch (_) {}
  }

  Future<void> _disableScreenProtection() async {
    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disableScreenProtection();
    WidgetsBinding.instance.removeObserver(this);
    _msgSub?.cancel();
    _typingStartSub?.cancel();
    _typingStopSub?.cancel();
    _readSub?.cancel();
    _connSub?.cancel();
    _streamChannel?.stopTyping().catchError((_) {});
    _typingDebounce?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _streamChannel?.stopTyping().catchError((_) {});
    }
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
    await _setupChannel();
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

  Future<void> _setupChannel() async {
    try {
      _streamChannel = StreamService.instance.channel(widget.myId, widget.matchId);
      await _streamChannel!.watch();
    } catch (e, st) {
      debugPrint('_setupChannel error: $e\n$st');
      
      final errStr = e.toString();
      if (errStr.contains('don\'t exist') || errStr.contains('code: 4')) {
        print('ChatPage: Match seems missing from Stream. Syncing...');
        try {
          await StreamService.instance.syncUser(
            widget.matchId, 
            name: widget.matchName, 
            image: widget.matchPhotoUrl
          );
          
          _streamChannel = StreamService.instance.channel(widget.myId, widget.matchId);
          await _streamChannel!.watch();
        } catch (e2) {
          debugPrint('_setupChannel retry error: $e2');
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    // --- SHARED SETUP (Runs on success OR after successful retry) ---
    try {
      final streamMessages = _streamChannel!.state!.messages;
      final unreadCount = _streamChannel!.state!.unreadCount;

      // Parse all messages from Stream history
      final parsed = <Map<String, dynamic>>[];
      for (final msg in streamMessages) {
        final m = await _parseStreamMessage(msg);
        if (m != null) parsed.add(m);
      }

      // Insert unread divider before first unread message from the other user
      int firstUnreadIdx = -1;
      if (unreadCount > 0) {
        final candidateStart = parsed.length - unreadCount;
        for (int i = max(0, candidateStart); i < parsed.length; i++) {
          if (parsed[i]['isMe'] != true) {
            firstUnreadIdx = i;
            break;
          }
        }
      }

      if (firstUnreadIdx >= 0) {
        parsed.insert(
            firstUnreadIdx, _dividerItem(unreadCount, parsed[firstUnreadIdx]['timestamp']));
      }

      _prevMsgCount = streamMessages.length;
      _initialLoadDone = true;

      // Subscribe to live message updates
      _msgSub = _streamChannel!.state!.messagesStream.listen(_onMessagesChanged);

      // Typing indicators
      _typingStartSub = _streamChannel!.on(EventType.typingStart).listen((event) {
        if (event.user?.id == widget.matchId && mounted) {
          setState(() => _isMatchTyping = true);
        }
      });
      _typingStopSub = _streamChannel!.on(EventType.typingStop).listen((event) {
        if (event.user?.id == widget.matchId && mounted) {
          setState(() => _isMatchTyping = false);
        }
      });

      _readSub = _streamChannel!.on(EventType.messageRead).listen((event) {
        if (event.user?.id == widget.matchId) _refreshMatchReadAt();
      });

      _connSub = StreamService.instance.client.wsConnectionStatusStream.listen((status) {
        if (mounted) setState(() => _connectionStatus = status);
      });

      _refreshMatchReadAt();

      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(parsed.reversed); // Newest at index 0 for reverse:true
        _isLoading = false;
        _hasUnreadDivider = firstUnreadIdx >= 0;
      });

      if (_hasUnreadDivider) {
        Future.delayed(const Duration(milliseconds: 80), () {
          if (mounted) _scrollToIndex(parsed.length - 1 - firstUnreadIdx);
        });
      }
      Future.delayed(const Duration(milliseconds: 300), () => _markAsRead());
    } catch (e) {
      debugPrint('_setupChannel listener setup error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stream live updates
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onMessagesChanged(List<Message> streamMessages) async {
    if (!_initialLoadDone || !mounted) return;

    // Stream returns messages oldest-to-newest. We UI-sort newest-at-index-0 if reverse:true.
    final parsed = <Map<String, dynamic>>[];
    for (final sm in streamMessages) {
       final m = await _parseStreamMessage(sm);
       if (m != null) parsed.insert(0, m);
    }

    // Preserve the unread divider if it exists
    if (_hasUnreadDivider) {
       final dividerIdx = _messages.indexWhere((m) => m['id'] == '__divider__');
       if (dividerIdx >= 0) {
          final divider = _messages[dividerIdx];
          // Find original timestamp position
          int insertAt = parsed.indexWhere((m) => m['timestamp'] == divider['timestamp']);
          if (insertAt >= 0) parsed.insert(insertAt, divider);
       }
    }

    if (mounted) {
      setState(() {
        _messages.clear();
        _messages.addAll(parsed);
      });
      _markAsRead();
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
  // Message parsing
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _parseStreamMessage(Message message) async {
    final sender = message.user?.id ?? '';
    final isMe = sender == widget.myId;
    final isDeleted = message.type == 'deleted';

    // message.extraData['mt'] carries the type: 'text' | 'image' | 'audio'
    String type = (message.extraData['mt'] as String?) ?? 'text';
    String data = '';

    if (isDeleted) {
      type = 'deleted';
    } else {
      final encPayload = message.text ?? '';
      if (encPayload.isNotEmpty) {
        if (_conversationKey != null) {
          final plain = await CryptoService.decryptMessage(encPayload, _conversationKey!);
          data = plain ?? '🔒 Encrypted message';
        } else {
          data = encPayload;
        }
      }
    }

    return {
      'id': message.id,
      'sender': sender,
      'type': type,
      'data': data,
      'timestamp': message.createdAt.toIso8601String(),
      'isMe': isMe,
      'isDeleted': isDeleted,
      'reply_to': message.quotedMessageId,
      'vt': message.extraData['vt'] as int? ?? 0,
      'view_count': message.ownReactions?.where((r) => r.type == 'viewed').length ?? 0,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sending
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _streamChannel == null) return;

    final replyId = _replyTo?['id'] as String?;
    _textController.clear();
    setState(() {
      _hasText = false;
      _replyTo = null;
      _wasTyping = false;
    });
    _streamChannel!.stopTyping().catchError((_) {});

    try {
      final envelope = _conversationKey != null
          ? await CryptoService.encryptMessage(text, _conversationKey!)
          : text;
      await _streamChannel!.sendMessage(Message(
        text: envelope,
        extraData: const {'mt': 'text'},
        quotedMessageId: replyId,
      ));
    } catch (e) {
      if (mounted) _showToast('Failed to send. Try again.', isError: true);
    }
  }

  Future<void> _sendImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 75);
    if (file == null || _streamChannel == null) return;
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
      // path → encrypt → send via Stream (E2EE: receiver decrypts path, then downloads+decrypts image)
      final envelope = _conversationKey != null
          ? await CryptoService.encryptMessage(path, _conversationKey!)
          : path;
      await _streamChannel!.sendMessage(Message(
        text: envelope,
        extraData: {
          'mt': 'image',
          if (_isEphemeralMode) 'vt': 2,
        },
      ));
      // Cache bytes locally for instant preview
      _imageFutures[path] = Future.value(bytes);
      if (mounted) setState(() => _isUploadingMedia = false);
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
    if (_streamChannel == null) return;
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
            fileOptions: FileOptions(
                contentType: _conversationKey != null ? 'application/octet-stream' : 'audio/m4a'),
          );
      final envelope = _conversationKey != null
          ? await CryptoService.encryptMessage(storagePath, _conversationKey!)
          : storagePath;
      await _streamChannel!.sendMessage(Message(
        text: envelope,
        extraData: const {'mt': 'audio'},
      ));
      // Cache local path for instant playback
      _audioPathFutures[storagePath] = Future.value(localPath);
      if (mounted) setState(() => _isUploadingMedia = false);
    } catch (_) {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
        _showToast('Audio upload failed.', isError: true);
      }
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> msg) async {
    final id = msg['id'] as String?;
    if (id == null || _streamChannel == null) return;
    try {
      // Find the Stream Message object by ID
      final streamMsg = _streamChannel!.state!.messages.firstWhere(
        (m) => m.id == id,
        orElse: () => Message(id: id),
      );
      await _streamChannel!.deleteMessage(streamMsg);
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
    if (storagePath.startsWith('/')) return storagePath;
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
        final decrypted = await CryptoService.decryptBytes(utf8.decode(raw), _conversationKey!);
        if (decrypted != null) return decrypted;
      }
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
        _streamChannel?.keyStroke().catchError((_) {});
      }
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(seconds: 4), () {
        _wasTyping = false;
        _streamChannel?.stopTyping().catchError((_) {});
      });
    } else {
      if (_wasTyping) {
        _wasTyping = false;
        _typingDebounce?.cancel();
        _streamChannel?.stopTyping().catchError((_) {});
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Read status
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _markAsRead() async {
    try {
      await _streamChannel?.markRead();
    } catch (_) {}
  }

  void _refreshMatchReadAt() {
    final readList = _streamChannel?.state?.read ?? [];
    for (final r in readList) {
      if (r.user.id == widget.matchId) {
        if (mounted) setState(() => _matchLastReadAt = r.lastRead);
        return;
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Scroll
  // ─────────────────────────────────────────────────────────────────────────

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const approxItemH = 80.0;
    final offset =
        (index * approxItemH).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(offset);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  bool _shouldShowDateHeader(int index) {
    if (_messages[index]['type'] == '_divider') return false;
    // For reverse:true, index + 1 is the OLDER message
    int older = index + 1;
    while (older < _messages.length && _messages[older]['type'] == '_divider') { older++; }
    if (older >= _messages.length) return true; // First (oldest) message always shows date
    
    final a = DateTime.tryParse(_messages[index]['timestamp'] as String? ?? '');
    final b = DateTime.tryParse(_messages[older]['timestamp'] as String? ?? '');
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
      resizeToAvoidBottomInset: true, // Crucial for chat
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_connectionStatus == ConnectionStatus.connecting || _connectionStatus == ConnectionStatus.disconnected)
            _buildConnectionBanner(),
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

  Widget _buildConnectionBanner() {
    return Container(
      width: double.infinity,
      color: kRose.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: kRose)),
            const SizedBox(width: 10),
            Text(
              _connectionStatus == ConnectionStatus.disconnected ? 'Disconnected. Retrying…' : 'Connecting…',
              style: GoogleFonts.figtree(fontSize: 10, color: kRose, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(key: ValueKey('loading'), child: HeartLoader());
    }

    if (_messages.isEmpty || (_messages.length == 1 && _messages[0]['type'] == '_divider')) {
      return Center(
        key: const ValueKey('empty'),
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
        ).animate().fade(duration: 500.ms).scale(begin: const Offset(0.9, 0.9)),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      child: ListView.builder(
        key: const ValueKey('list'),
        controller: _scrollController,
        reverse: true, // Standard for premium chat
        physics: const AlwaysScrollableScrollPhysics(), // Robust scrolling
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        cacheExtent: 1500, // Pre-cache items
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 40), // More bottom padding
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          if (msg['type'] == '_divider') {
            return _buildUnreadDivider(msg['count'] as int);
          }
          return _buildMessageRow(msg, index);
        },
      ),
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

    if (isFresh) {
      _freshIds.remove(id);
      row = row.animate().fade(duration: 200.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDate) _buildDateHeader(msg['timestamp'] as String?),
        row,
      ],
    );
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
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMe ? 20 : 6),
          bottomRight: Radius.circular(isMe ? 6 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: (isMe ? kRose : kInk).withOpacity(isMe ? 0.2 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _buildImageBubble(String storagePath) {
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

        final msgId = _messages.firstWhere((m) => m['data'] == storagePath, orElse: () => {})['id'] as String?;
        final vt = _messages.firstWhere((m) => m['id'] == msgId, orElse: () => {})['vt'] as int? ?? 0;
        final views = _messages.firstWhere((m) => m['id'] == msgId, orElse: () => {})['view_count'] as int? ?? 0;
        final isExpired = vt > 0 && views >= vt;

        if (isExpired) {
          return Container(
            width: 220,
            height: 160,
            decoration: BoxDecoration(
              color: kBone,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.visibility_off_rounded, color: kInkMuted, size: 32),
                const SizedBox(height: 8),
                Text('Image expired', style: GoogleFonts.figtree(color: kInkMuted, fontSize: 13)),
              ],
            ),
          );
        }

        return GestureDetector(
          onTap: () => _openFullImage(snap.data!, msgId as String?, vt),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(snap.data!, width: 220, height: 220, fit: BoxFit.cover),
              ),
              if (vt > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text('${vt - views} left',
                            style: GoogleFonts.figtree(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
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
                  border: Border.all(color: kBone.withOpacity(0.8), width: 1.5),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: kInk.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))
                  ],
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
            const Divider(height: 1),
            SwitchListTile(
              secondary: Icon(Icons.timer_outlined, color: _isEphemeralMode ? kRose : kInkMuted),
              title: Text('View Twice Mode', style: GoogleFonts.figtree(color: kInk, fontSize: 15)),
              subtitle: Text('Images disappear after 2 views', style: GoogleFonts.figtree(fontSize: 12)),
              value: _isEphemeralMode,
              activeColor: kRose,
              onChanged: (v) {
                setState(() => _isEphemeralMode = v);
                Navigator.pop(context);
                _showImageSourceSheet(); // Reopen to show updated state
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

  void _openFullImage(Uint8List bytes, String? msgId, int vt) async {
    if (msgId != null && vt > 0 && _streamChannel != null) {
      try {
        final messages = _streamChannel!.state?.messages ?? [];
        final mObj = messages.cast<Message?>().firstWhere((m) => m?.id == msgId, orElse: () => null);
        if (mObj != null) {
           await _streamChannel!.sendReaction(mObj, 'viewed');
        }
      } catch (_) {}
    }

    if (!mounted) return;
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
