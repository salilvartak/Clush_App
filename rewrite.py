import re

file_path = "lib/chat_page.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Imports
imports_replacement = """import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cometchat_sdk/cometchat_sdk.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'services/matching_service.dart';
import 'heart_loader.dart';
import 'theme/colors.dart';
"""
content = re.sub(r"import 'package:flutter/material\.dart';.*?import 'theme/colors\.dart';", imports_replacement, content, flags=re.DOTALL)

# 2. State variables and old socket code
state_vars_start_index = content.find("class _ChatScreenState extends State<ChatScreen> {")
build_method_index = content.find("  @override\n  Widget build(BuildContext context) {")
if state_vars_start_index != -1 and build_method_index != -1:
    old_state_block = content[state_vars_start_index:build_method_index]
    new_state_block = """class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MatchingService _matchingService = MatchingService();
  List<Map<String, dynamic>> messages = [];
  bool _isUploadingMedia = false;

  // Voice Notes
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  String? _currentlyPlayingAudio;

  // Unread message badge
  int _unreadCount = 0;
  bool _isAtBottom = true;
  late String listenerId;

  @override
  void initState() {
    super.initState();
    listenerId = "chat_listener_${widget.matchId}";
    _scrollController.addListener(_onScroll);
    initializeCometChat();
  }

  void _onScroll() {
    final atBottom = _scrollController.hasClients &&
        _scrollController.offset >= _scrollController.position.maxScrollExtent - 60;
    if (atBottom && _unreadCount > 0) {
      setState(() {
        _unreadCount = 0;
        _isAtBottom = true;
      });
      _markAllAsRead();
    } else if (!atBottom && _isAtBottom) {
      setState(() => _isAtBottom = false);
    }
  }

  void initializeCometChat() {
    CometChat.addMessageListener(listenerId, MessageListener(
      onTextMessageReceived: (TextMessage textMessage) {
        _handleIncomingMessage(textMessage);
      },
      onMediaMessageReceived: (MediaMessage mediaMessage) {
        _handleIncomingMessage(mediaMessage);
      },
    ));
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final ccMatchId = widget.matchId.replaceAll('-', '_');
    MessagesRequest messageRequest = (MessagesRequestBuilder()
          ..uid = ccMatchId
          ..limit = 50)
        .build();

    try {
      final List<BaseMessage> list = await messageRequest.fetchPrevious(
        onSuccess: (List<BaseMessage> messages) { return messages; },
        onError: (CometChatException excep) { return []; }
      );
      if (mounted) {
        setState(() {
          messages = list.map((msg) => _parseCometChatMessage(msg)).toList();
        });
        _scrollToBottom();
        _markAllAsRead();
      }
    } catch(e) { /* ignore */ }
  }

  void _markAllAsRead() {
    final ccMatchId = widget.matchId.replaceAll('-', '_');
    CometChat.markAsRead(ccMatchId, ConversationType.user, onSuccess: (s) {}, onError: (e) {});
  }

  Map<String, dynamic> _parseCometChatMessage(BaseMessage msg) {
      String type = 'text';
      String data = '';

      if (msg is TextMessage) {
          type = 'text';
          data = msg.text;
      } else if (msg is MediaMessage) {
          if (msg.type == MessageTypeConstants.image) {
              type = 'image';
              data = msg.attachment?.fileUrl ?? '';
          } else if (msg.type == MessageTypeConstants.audio) {
              type = 'audio';
              data = msg.attachment?.fileUrl ?? '';
          } else {
              type = 'text';
              data = '[Unsupported Media]';
          }
      }

      return {
          'sender': msg.sender?.name ?? 'Unknown',
          'type': type,
          'data': data,
          'timestamp': msg.sentAt != null 
              ? DateTime.fromMillisecondsSinceEpoch(msg.sentAt! * 1000).toIso8601String() 
              : DateTime.now().toIso8601String(),
          'isMe': msg.sender?.uid == widget.myId.replaceAll('-', '_'),
      };
  }

  void _handleIncomingMessage(BaseMessage msg) {
      if (!mounted) return;
      if (msg.sender?.uid != widget.matchId.replaceAll('-', '_')) return; // ignore other chats
      
      setState(() {
          messages.add(_parseCometChatMessage(msg));
          if (!_isAtBottom) _unreadCount++;
      });
      if (_isAtBottom) {
          _scrollToBottom();
          _markAllAsRead();
      }
  }

  void sendMessage() async {
    String text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final ccMatchId = widget.matchId.replaceAll('-', '_');
    TextMessage textMessage = TextMessage(
        receiverUid: ccMatchId,
        text: text,
        receiverType: ConversationType.user,
        type: MessageTypeConstants.text
    );

    setState(() {
        messages.add({
            'sender': widget.myName,
            'type': 'text',
            'data': text,
            'timestamp': DateTime.now().toIso8601String(),
            'isMe': true,
        });
    });
    _scrollToBottom();

    await CometChat.sendMessage(textMessage, onSuccess: (TextMessage msg) {
    }, onError: (CometChatException e) {
        debugPrint("Send Error: ${e.message}");
    });
  }

  Future<void> sendImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploadingMedia = true);
    
    final ccMatchId = widget.matchId.replaceAll('-', '_');
    MediaMessage mediaMessage = MediaMessage(
        receiverUid: ccMatchId,
        file: image.path,
        receiverType: ConversationType.user,
        type: MessageTypeConstants.image
    );

    await CometChat.sendMediaMessage(mediaMessage, onSuccess: (MediaMessage msg) {
        if (mounted) {
            setState(() {
                _isUploadingMedia = false;
                messages.add(_parseCometChatMessage(msg));
            });
            _scrollToBottom();
        }
    }, onError: (CometChatException e) {
        if (mounted) {
            setState(() => _isUploadingMedia = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${e.message}')));
        }
    });
  }

  Future<void> _toggleRecording() async {
      if (_isRecording) {
          final path = await _audioRecorder.stop();
          setState(() => _isRecording = false);
          if (path != null) {
              _sendAudioMessage(path);
          }
      } else {
          if (await _audioRecorder.hasPermission()) {
              final directory = await getTemporaryDirectory();
              _recordingPath = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
              await _audioRecorder.start(const RecordConfig(), path: _recordingPath!);
              setState(() => _isRecording = true);
          }
      }
  }

  Future<void> _sendAudioMessage(String path) async {
    setState(() => _isUploadingMedia = true);
    final ccMatchId = widget.matchId.replaceAll('-', '_');
    MediaMessage mediaMessage = MediaMessage(
        receiverUid: ccMatchId,
        file: path,
        receiverType: ConversationType.user,
        type: MessageTypeConstants.audio
    );

    await CometChat.sendMediaMessage(mediaMessage, onSuccess: (MediaMessage msg) {
        if (mounted) {
            setState(() {
                _isUploadingMedia = false;
                messages.add(_parseCometChatMessage(msg));
            });
            _scrollToBottom();
        }
    }, onError: (CometChatException e) {
        if (mounted) setState(() => _isUploadingMedia = false);
    });
  }

  Future<void> _playAudio(String url) async {
    if (_currentlyPlayingAudio == url) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingAudio = null);
    } else {
      await _audioPlayer.play(UrlSource(url));
      setState(() => _currentlyPlayingAudio = url);
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _currentlyPlayingAudio = null);
      });
    }
  }

  bool _shouldShowTimeHeader(int index) {
    if (index == 0) return true;
    String? currentStr = messages[index]['timestamp'];
    String? prevStr = messages[index - 1]['timestamp'];
    if (currentStr == null || prevStr == null || currentStr == 'Now' || prevStr == 'Now') return true;
    DateTime? current = DateTime.tryParse(currentStr);
    DateTime? prev = DateTime.tryParse(prevStr);
    if (current == null || prev == null) return currentStr != prevStr;
    return current.difference(prev).inMinutes.abs() >= 5;
  }

  String _formatDateGroup(String? timestampStr) {
    if (timestampStr == null || timestampStr.isEmpty || timestampStr == 'Now') {
      DateTime now = DateTime.now();
      String timeStr = "${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
      return "Today, $timeStr";
    }
    DateTime? msgTime = DateTime.tryParse(timestampStr);
    if (msgTime == null) return timestampStr;
    msgTime = msgTime.toLocal();
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime msgDate = DateTime(msgTime.year, msgTime.month, msgTime.day);
    Duration diff = today.difference(msgDate);
    String timeStr = "${msgTime.hour > 12 ? msgTime.hour - 12 : (msgTime.hour == 0 ? 12 : msgTime.hour)}:${msgTime.minute.toString().padLeft(2, '0')} ${msgTime.hour >= 12 ? 'PM' : 'AM'}";
    if (diff.inDays == 0) return "Today, $timeStr";
    else if (diff.inDays == 1) return "Yesterday, $timeStr";
    else if (diff.inDays < 7) {
      List<String> days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return "${days[msgTime.weekday - 1]}, $timeStr";
    } else {
      List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${msgTime.day} ${months[msgTime.month - 1]}, $timeStr";
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
        setState(() {
          _unreadCount = 0;
          _isAtBottom = true;
        });
      }
    });
  }

  @override
  void dispose() {
    CometChat.removeMessageListener(listenerId);
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }
"""
    content = content[:state_vars_start_index] + new_state_block + content[build_method_index:]

content = content.replace("sendEncryptedImage", "sendImage")

# Replace voice note / text input in _buildMessageInput
old_input_method = """    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(color: kParchment,
        border: Border(top: BorderSide(color: kBone, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Image button
            IconButton(
              icon: _isUploadingMedia
                  ? const HeartLoader(size: 22)
                  : const Icon(Icons.add_photo_alternate_outlined, color: kInkMuted),
              onPressed: _isUploadingMedia ? null : sendImage,
            ),
            // Text field
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
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  style: GoogleFonts.figtree(fontSize: 15, color: kInk),
                  decoration: InputDecoration(
                    hintText: "Write a message…",
                    hintStyle: GoogleFonts.figtree(color: kInkMuted, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            GestureDetector(
              onTap: sendMessage,
              child: Container(
                width: 46,
                height: 46,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kRoseLight, kRose],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kRose.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );"""

new_input_method = """    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(color: kParchment,
        border: Border(top: BorderSide(color: kBone, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Image button
            IconButton(
              icon: _isUploadingMedia
                  ? const SizedBox(width: 22, height: 22, child: HeartLoader())
                  : const Icon(Icons.add_photo_alternate_outlined, color: kInkMuted),
              onPressed: _isUploadingMedia ? null : sendImage,
            ),
            // Text field
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
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  style: GoogleFonts.figtree(fontSize: 15, color: kInk),
                  decoration: InputDecoration(
                    hintText: _isRecording ? "Recording audio..." : "Write a message…",
                    hintStyle: GoogleFonts.figtree(color: _isRecording ? Colors.redAccent : kInkMuted, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onChanged: (v) => setState((){}),
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            // Record Audio Button
            if (_controller.text.isEmpty)
              GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 46,
                  height: 46,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.redAccent : kBone,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded, 
                    color: _isRecording ? Colors.white : kInkMuted, 
                    size: 20
                  ),
                ),
              ),
              
            // Send button
            if (_controller.text.isNotEmpty)
              GestureDetector(
                onTap: sendMessage,
                child: Container(
                  width: 46,
                  height: 46,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kRoseLight, kRose],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kRose.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
          ],
        ),
      ),
    );"""

content = content.replace(old_input_method, new_input_method)

# Handle message rendering
old_message_rendering = """  Widget _buildMessageContent(Map<String, dynamic> msg, bool isMe) {
    if (msg['type'] == 'text') {
      return Text(
        msg['data'],
        style: GoogleFonts.figtree(
          color: isMe ? Colors.white : kInk,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      );
    } else if (msg['type'] == 'image') {
      return FutureBuilder<Uint8List>(
        future: fetchAndDecryptMedia(msg['data']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
                height: 150,
                width: 150,
                child: const Center(child: HeartLoader()));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const SizedBox(
                height: 150,
                width: 150,
                child: Icon(Icons.broken_image_rounded, color: kRosePale, size: 50));
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(snapshot.data!, height: 220, width: 220, fit: BoxFit.cover),
          );
        },
      );
    }
    return const SizedBox();
  }"""

new_message_rendering = """  Widget _buildMessageContent(Map<String, dynamic> msg, bool isMe) {
    if (msg['type'] == 'text') {
      return Text(
        msg['data'],
        style: GoogleFonts.figtree(
          color: isMe ? Colors.white : kInk,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      );
    } else if (msg['type'] == 'image') {
      if (msg['data'] == null || msg['data'].isEmpty) {
         return const SizedBox(height: 150, width: 150, child: Center(child: HeartLoader()));
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(msg['data'], height: 220, width: 220, fit: BoxFit.cover),
      );
    } else if (msg['type'] == 'audio') {
      final isPlaying = _currentlyPlayingAudio == msg['data'];
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _playAudio(msg['data']),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withOpacity(0.2) : kBone,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: isMe ? Colors.white : kInk,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // A minimalist mock wave
          for (var i = 0; i < 6; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3,
              height: isPlaying ? (10.0 + (i % 3) * 5.0) : 8.0,
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withOpacity(0.7) : kInkMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      );
    }
    return const SizedBox();
  }"""
content = content.replace(old_message_rendering, new_message_rendering)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
