import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:stream_chat_flutter_core/stream_chat_flutter_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:clush/widgets/heart_loader.dart';
import 'package:clush/services/matching_service.dart';
import 'package:clush/services/stream_service.dart';
import 'package:clush/theme/colors.dart';
import 'package:clush/screens/profile_view_page.dart';

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

  String? _currentlyPlayingId;
  bool _isMatchTyping = false;
  Map<String, dynamic>? _replyTo;

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

  // Premium status
  bool _myIsPremium = false;

  // Draft messages — persisted across navigation (static so it survives dispose)
  static final Map<String, String> _drafts = {};

  // Voice preview — recorded path waiting to be sent or cancelled
  String? _pendingAudioPath;
  bool _isPreviewPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _roomId = _buildRoomId(widget.myId, widget.matchId);
    // Restore any saved draft
    final saved = _drafts[_roomId];
    if (saved != null && saved.isNotEmpty) {
      _textController.text = saved;
      _hasText = true;
    }
    _initChat();

  }



  @override
  void dispose() {
    // Save draft so it's restored when the user returns
    final draft = _textController.text;
    if (draft.trim().isNotEmpty) {
      _drafts[_roomId] = draft;
    } else {
      _drafts.remove(_roomId);
    }

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
    _fetchPremiumStatus();
    await _setupChannel();
  }

  Future<void> _fetchPremiumStatus() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('is_premium')
          .eq('id', widget.myId)
          .single();
      final val = data['is_premium'];
      bool premium = false;
      if (val is bool) {
        premium = val;
      } else if (val is String) {
        premium = val.toLowerCase() == 'true';
      }
      if (mounted) setState(() => _myIsPremium = premium);
    } catch (_) {}
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

    String caption = '';
    if (isDeleted) {
      type = 'deleted';
    } else if (type == 'image') {
      // Path is always in text; optional caption in extraData['caption']
      data = message.text ?? '';
      caption = (message.extraData['caption'] as String?) ?? '';
    } else {
      final text = message.text ?? '';
      if (text.isNotEmpty) data = text;
    }

    return {
      'id': message.id,
      'sender': sender,
      'type': type,
      'data': data,
      'caption': caption,
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
    _drafts.remove(_roomId);
    setState(() {
      _hasText = false;
      _replyTo = null;
      _wasTyping = false;
    });
    _streamChannel!.stopTyping().catchError((_) {});

    try {
      final envelope = text;
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

    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageSendPreviewScreen(
          bytes: bytes,
          ext: ext,
          onSend: _uploadAndSendImage,
        ),
      ),
    );
  }

  Future<void> _uploadAndSendImage(
      Uint8List bytes, String ext, int vt, String caption) async {
    if (_streamChannel == null) return;
    setState(() => _isUploadingMedia = true);
    try {
      // Normalize extension for storage consistency
      final normalizedExt = ext.toLowerCase() == 'jpg' ? 'jpeg' : ext.toLowerCase();
      final path = 'chat/$_roomId/${DateTime.now().millisecondsSinceEpoch}.$normalizedExt';
      
      final mimeType = _getMimeType(normalizedExt);

      await _supabase.storage.from('chat-media').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      await _streamChannel!.sendMessage(Message(
        text: path,
        extraData: {
          'mt': 'image',
          if (caption.isNotEmpty) 'caption': caption,
          if (vt > 0) 'vt': vt,
        },
      ));
      
      _imageFutures[path] = Future.value(bytes);
      if (mounted) setState(() => _isUploadingMedia = false);
    } catch (e) {
      debugPrint('Image upload error: $e');
      if (mounted) {
        setState(() => _isUploadingMedia = false);
        _showToast('Image upload failed.', isError: true);
      }
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    if (!await _audioRecorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(const RecordConfig(), path: path);
    if (mounted) setState(() => _isRecording = true);
  }

  Future<void> _stopRecordingForPreview() async {
    if (!_isRecording) return;
    final path = await _audioRecorder.stop();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _pendingAudioPath = path;
      });
    }
  }

  Future<void> _cancelAudioPreview() async {
    await _audioPlayer.stop();
    final path = _pendingAudioPath;
    if (path != null) {
      try { await File(path).delete(); } catch (_) {}
    }
    if (mounted) setState(() { _pendingAudioPath = null; _isPreviewPlaying = false; });
  }

  Future<void> _sendAudioPreview() async {
    final path = _pendingAudioPath;
    if (path == null) return;
    await _audioPlayer.stop();
    setState(() { _pendingAudioPath = null; _isPreviewPlaying = false; });
    await _sendAudio(path);
  }

  Future<void> _togglePreviewPlayback() async {
    final path = _pendingAudioPath;
    if (path == null) return;
    if (_isPreviewPlaying) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _isPreviewPlaying = false);
    } else {
      if (mounted) setState(() => _isPreviewPlaying = true);
      try {
        await _audioPlayer.play(DeviceFileSource(path));
        _audioPlayer.onPlayerComplete.first.then((_) {
          if (mounted) setState(() => _isPreviewPlaying = false);
        });
      } catch (_) {
        if (mounted) setState(() => _isPreviewPlaying = false);
      }
    }
  }

  Future<void> _openMatchProfile() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', widget.matchId)
          .single();
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ProfileViewPage(profile: data),
      ));
    } catch (_) {
      _showToast('Could not load profile.');
    }
  }

  Future<void> _sendAudio(String localPath) async {
    if (_streamChannel == null) return;
    setState(() => _isUploadingMedia = true);
    try {
      final bytes = await File(localPath).readAsBytes();
      final storagePath = 'chat/$_roomId/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final uploadBytes = bytes;
      final mimeType = _getMimeType('m4a');
      await _supabase.storage.from('chat-media').uploadBinary(
            storagePath,
            uploadBytes,
            fileOptions: FileOptions(
                contentType: mimeType,
                upsert: true),
          );
      final envelope = storagePath;
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
      final audioBytes = await _supabase.storage.from('chat-media').download(storagePath);
      final dir = await getTemporaryDirectory();
      final tmp = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await File(tmp).writeAsBytes(audioBytes);
      return tmp;
    } catch (e) {
      debugPrint('Error downloading audio: $e');
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
      // Use direct download which is safer and handles authentication/headers correctly
      return await _supabase.storage.from('chat-media').download(storagePath);
    } catch (e) {
      debugPrint('Error downloading image ($storagePath): $e');
      return null;
    }
  }

  String _getMimeType(String ext) {
    final e = ext.toLowerCase();
    switch (e) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'm4a':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
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
          Expanded(child: _buildBody()),
          if (_replyTo != null) _buildReplyBar(),
          if (_isRecording || _pendingAudioPath != null) _buildVoicePreviewBar(),
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
          GestureDetector(
            onTap: _openMatchProfile,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: kRosePale,
              backgroundImage:
                  widget.matchPhotoUrl != null ? NetworkImage(widget.matchPhotoUrl!) : null,
              child: widget.matchPhotoUrl == null
                  ? const Icon(Icons.person_rounded, size: 22, color: kRose)
                  : null,
            ),
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
                      : const SizedBox.shrink(),
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
            if (v == 'unmatch') _confirmUnmatch();
            if (v == 'block') _confirmBlock();
            if (v == 'report') _showReport();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'unmatch',
              child: Row(children: [
                const Icon(Icons.heart_broken_rounded, color: kInkMuted, size: 18),
                const SizedBox(width: 10),
                Text('Unmatch', style: GoogleFonts.figtree(color: kInk)),
              ]),
            ),
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



  Widget _buildConnectionBanner() {
    return Container(
      width: double.infinity,
      color: kRose.withValues(alpha: 0.1),
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
      return Center(key: const ValueKey('loading'), child: HeartLoader());
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
            Text('Send a heart to start the spark!',
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
      final caption = (msg['caption'] as String?) ?? '';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildImageBubble(msg['data'] as String),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Text(caption,
                  style: GoogleFonts.figtree(
                      fontSize: 14,
                      color: isMe ? Colors.white : kInk,
                      height: 1.4)),
            ),
        ],
      );
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
            color: (isMe ? kRose : kInk).withValues(alpha: isMe ? 0.2 : 0.06),
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
          return SizedBox(
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

        // View-once / view-twice: show compact "Photo" row instead of the image
        if (vt > 0) {
          return GestureDetector(
            onTap: () => _openFullImage(snap.data!, msgId, vt),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Circular timer badge
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 2.5,
                            color: kInkMuted,
                          ),
                        ),
                        Text(
                          vt == 1 ? '1' : '${vt - views}',
                          style: GoogleFonts.figtree(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Photo',
                    style: GoogleFonts.figtree(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () => _openFullImage(snap.data!, msgId, vt),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              snap.data!,
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 220,
                height: 220,
                color: kBone,
                child: const Icon(Icons.broken_image_rounded, color: kInkMuted),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioBubble(Map<String, dynamic> msg, bool isMe) {
    final id = msg['id']?.toString() ?? msg['timestamp'].toString();
    final storagePath = msg['data'] as String;
    final isPlaying = _currentlyPlayingId == id;

    // Deterministic waveform heights from message ID
    final seed = id.codeUnits.fold(0, (a, b) => a + b);
    final rng = Random(seed);
    final bars = List.generate(26, (_) => 0.25 + rng.nextDouble() * 0.75);

    final barColor = isMe ? Colors.white : kRose;

    return GestureDetector(
      onTap: () => _playAudio(id, storagePath),
      child: SizedBox(
        width: 190,
        child: Row(
          children: [
            Icon(
              isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
              color: barColor,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 36,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: bars.asMap().entries.map((e) {
                    final animated = isPlaying && (e.key % 3 == 0);
                    Widget bar = Container(
                      width: 3,
                      height: 36 * e.value,
                      decoration: BoxDecoration(
                        color: barColor.withValues(alpha: isPlaying ? 1.0 : 0.65),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                    if (animated) {
                      bar = bar
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleY(begin: 0.5, end: 1.0, duration: 400.ms, curve: Curves.easeInOut);
                    }
                    return bar;
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
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
        color: Colors.black.withValues(alpha: 0.07),
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
    // Only premium users see read receipts; free users see nothing
    if (!isMe || !_myIsPremium) return const SizedBox.shrink();
    final isRead = _isMessageRead(msg);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Icon(
        Icons.done_all_rounded,
        size: 13,
        color: isRead ? const Color(0xFF4FC3F7) : kInkMuted,
      ),
    );
  }

  // ── Unread divider ───────────────────────────────────────────────────────

  Widget _buildUnreadDivider(int count) => const SizedBox.shrink();



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

  // ── Voice preview bar (shown above input while recording / after recording) ─

  Widget _buildVoicePreviewBar() {
    // Deterministic bars: seeded from path when previewing, random-ish when recording
    final seed = _pendingAudioPath != null
        ? _pendingAudioPath!.codeUnits.fold(0, (a, b) => a + b)
        : 42;
    final rng = Random(seed);
    final bars = List.generate(28, (_) => 0.25 + rng.nextDouble() * 0.75);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(
        color: kParchment,
        border: Border(top: BorderSide(color: kBone)),
      ),
      child: Row(
        children: [
          // Cancel
          GestureDetector(
            onTap: _isRecording ? null : _cancelAudioPreview,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kInkMuted.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Icon(Icons.close_rounded,
                  size: 18, color: _isRecording ? kInkMuted.withValues(alpha: 0.3) : kInkMuted),
            ),
          ),
          const SizedBox(width: 10),

          // Recording dot (only while recording)
          if (_isRecording) ...[
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(begin: 1.0, end: 0.2, duration: 600.ms),
          ],

          // Play button (only in preview mode)
          if (_pendingAudioPath != null) ...[
            GestureDetector(
              onTap: _togglePreviewPlayback,
              child: Icon(
                _isPreviewPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                color: kRose,
                size: 34,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Waveform
          Expanded(
            child: SizedBox(
              height: 40,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: bars.asMap().entries.map((e) {
                  final barH = 40 * e.value;
                  Widget bar = Container(
                    width: 3,
                    height: barH,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? Colors.redAccent.withValues(alpha: 0.75)
                          : kRose.withValues(alpha: _isPreviewPlaying ? 1.0 : 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                  if (_isRecording) {
                    bar = bar
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleY(
                          begin: 0.25,
                          end: 1.0,
                          duration: Duration(milliseconds: 250 + (e.key * 37) % 350),
                          curve: Curves.easeInOut,
                        );
                  } else if (_isPreviewPlaying && e.key % 3 == 0) {
                    bar = bar
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleY(begin: 0.4, end: 1.0, duration: 400.ms, curve: Curves.easeInOut);
                  }
                  return bar;
                }).toList(),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Label / send button
          if (_isRecording)
            Text('Release to send',
                style: GoogleFonts.figtree(fontSize: 11, color: kInkMuted))
          else
            GestureDetector(
              onTap: _sendAudioPreview,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [kRoseLight, kRose],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: kRose.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  // ── Input bar ────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: kParchment,
        border: Border(top: BorderSide(color: kBone)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: _buildNormalInputRow(),
        ),
      ),
    );
  }

  Widget _buildNormalInputRow() {
    // All three elements share the same intrinsic height with crossAxisAlignment.end.
    // No bottom margins — the vertical padding on the container handles spacing.
    // Buttons are 44 px; text field min height is also ~44 px via contentPadding.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ── Image attach button ───────────────────────────────────────
        GestureDetector(
          onTap: _isUploadingMedia ? null : _showImageSourceSheet,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kBone,
              border: Border.all(color: kBone, width: 1.5),
            ),
            child: Center(
              child: _isUploadingMedia
                  ? SizedBox(width: 22, height: 22, child: HeartLoader(size: 22))
                  : const Icon(Icons.add_photo_alternate_outlined,
                      color: kInkMuted, size: 22),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // ── Text field ───────────────────────────────────────────────
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120, minHeight: 44),
            decoration: BoxDecoration(
              color: kCream,
              border: Border.all(color: kBone.withValues(alpha: 0.8), width: 1.5),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: kInk.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: TextField(
              controller: _textController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              style: GoogleFonts.figtree(fontSize: 15, color: kInk),
              decoration: InputDecoration(
                hintText: 'Write a message…',
                hintStyle: GoogleFonts.figtree(color: kInkMuted, fontSize: 15),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: _onTextChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // ── Send / Mic button ────────────────────────────────────────
        if (_hasText)
          _sendButton()
        else
          // Listener fires on raw pointer events — no gesture disambiguation delay,
          // so press-and-hold works reliably as push-to-talk.
          Listener(
            onPointerDown: (_) => _startRecording(),
            onPointerUp: (_) => _stopRecordingForPreview(),
            onPointerCancel: (_) => _cancelAudioPreview(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.redAccent : kBone,
                border: Border.all(
                  color: _isRecording ? Colors.redAccent : kBone,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.mic_rounded,
                color: _isRecording ? Colors.white : kInkMuted,
                size: 20,
              ),
            ),
          ),
      ],
    );
  }

  Widget _sendButton() {
    return GestureDetector(
      onTap: _sendText,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [kRoseLight, kRose],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: kRose.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))
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
              // Also delete stream channel if blocking
              await StreamService.instance.deleteChannel(widget.myId, widget.matchId);
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

  void _confirmUnmatch() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kParchment,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Unmatch with ${widget.matchName}?',
            style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, color: kInk)),
        content: Text("This will permanently end your connection and delete your chat history.",
            style: GoogleFonts.figtree(color: kInkMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.figtree(color: kInkMuted))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              final success = await _matchingService.unmatchUser(widget.matchId);
              if (success) {
                await StreamService.instance.deleteChannel(widget.myId, widget.matchId);
                if (mounted) Navigator.pop(context); // Return to matches list
              }
            },
            child: Text('Unmatch',
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

// ─────────────────────────────────────────────────────────────────────────────
// Image send preview screen
// ─────────────────────────────────────────────────────────────────────────────

class _ImageSendPreviewScreen extends StatefulWidget {
  final Uint8List bytes;
  final String ext;
  final Future<void> Function(Uint8List bytes, String ext, int vt, String caption) onSend;

  const _ImageSendPreviewScreen({
    required this.bytes,
    required this.ext,
    required this.onSend,
  });

  @override
  State<_ImageSendPreviewScreen> createState() => _ImageSendPreviewScreenState();
}

class _ImageSendPreviewScreenState extends State<_ImageSendPreviewScreen> {
  // 0 = normal, 1 = view once, 2 = view twice
  int _viewType = 0;
  final _captionCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _doSend() async {
    setState(() => _sending = true);
    try {
      await widget.onSend(
          widget.bytes, widget.ext, _viewType, _captionCtrl.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blur = _viewType > 0;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen image (blurred when view-once / view-twice) ──────
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(widget.bytes, fit: BoxFit.contain),
                if (blur)
                  BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: Container(color: Colors.black.withValues(alpha: 0.18)),
                  ),
              ],
            ),
          ),

          // ── Back button ──────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),

          // ── Blur label (when active) ─────────────────────────────────────
          if (blur)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility_off_rounded,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _viewType == 1 ? 'View Once' : 'View Twice',
                      style: GoogleFonts.figtree(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom controls ──────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // View mode chips
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _viewChip('Normal', 0, Icons.image_rounded),
                      const SizedBox(width: 8),
                      _viewChip('View Once', 1, Icons.looks_one_rounded),
                      const SizedBox(width: 8),
                      _viewChip('View Twice', 2, Icons.looks_two_rounded),
                    ],
                  ),
                ),

                // Caption field
                Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          color: Colors.white60, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _captionCtrl,
                          style: GoogleFonts.figtree(
                              color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Add a caption…',
                            hintStyle: GoogleFonts.figtree(
                                color: Colors.white54, fontSize: 15),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Send row
                Container(
                  color: Colors.black87,
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 12,
                    top: 10,
                    bottom: MediaQuery.of(context).padding.bottom + 10,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _viewType == 0
                            ? 'Send photo'
                            : _viewType == 1
                                ? 'View once • blurred'
                                : 'View twice • blurred',
                        style: GoogleFonts.figtree(
                            color: Colors.white60, fontSize: 13),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _sending ? null : _doSend,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                              color: kRose, shape: BoxShape.circle),
                          child: _sending
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewChip(String label, int value, IconData icon) {
    final selected = _viewType == value;
    return GestureDetector(
      onTap: () => setState(() => _viewType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.black45,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: selected ? Colors.white : Colors.white30,
              width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: selected ? Colors.black87 : Colors.white70),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.figtree(
                color: selected ? Colors.black87 : Colors.white70,
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
