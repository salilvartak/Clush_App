import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'services/matching_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'services/crypto_service.dart';
import 'heart_loader.dart';

import 'theme/colors.dart';

class ChatScreen extends StatefulWidget {
  final String myId;
  final String matchId;
  final String myName;
  final String matchName;
  final String? matchPhotoUrl;

  const ChatScreen({
    Key? key,
    required this.myId,
    required this.matchId,
    required this.myName,
    required this.matchName,
    this.matchPhotoUrl,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late IO.Socket socket;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MatchingService _matchingService = MatchingService();
  List<Map<String, dynamic>> messages = [];
  String? privateRoom;
  late CryptoService _crypto;
  bool _isUploadingMedia = false;

  // Unread message badge
  int _unreadCount = 0;
  bool _isAtBottom = true;

  final String serverUrl = 'https://nina-unpumped-linus.ngrok-free.dev';

  @override
  void initState() {
    super.initState();
    connectToServer();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final atBottom = _scrollController.hasClients &&
        _scrollController.offset >= _scrollController.position.maxScrollExtent - 60;
    if (atBottom && _unreadCount > 0) {
      setState(() {
        _unreadCount = 0;
        _isAtBottom = true;
      });
      if (privateRoom != null) _matchingService.updateLastRead(privateRoom!);
    } else if (!atBottom && _isAtBottom) {
      setState(() => _isAtBottom = false);
    }
  }

  String getRoomId(String id1, String id2) {
    List<String> ids = [id1, id2];
    ids.sort();
    return "${ids[0]}_${ids[1]}";
  }

  void connectToServer() {
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      privateRoom = getRoomId(widget.myId, widget.matchId);
      _crypto = CryptoService(privateRoom!);
      socket.emit('join_room', {
        'room': privateRoom,
        'username': widget.myName,
      });
      _matchingService.updateLastRead(privateRoom!);
    });

    // 🛑 THE FIX: Changed 'load_history' to 'chat_history' to match Python perfectly
    socket.on('chat_history', (data) {
      if (mounted) {
        try {
          List<dynamic> rawData = data as List<dynamic>;
          setState(() {
            messages = rawData.map((msg) {
              String decryptedString = "[Error decrypting]";
              Map<String, dynamic> parsed = {"type": "text", "data": decryptedString};
              
              try {
                // Safeguard against null messages
                String rawMsg = msg['message'] ?? "";
                if (rawMsg.isNotEmpty) {
                  decryptedString = _crypto.decryptPayload(rawMsg);
                  parsed = jsonDecode(decryptedString);
                }
              } catch (e) {
                // If it's old unencrypted text, fallback to it
                parsed = {"type": "text", "data": decryptedString};
              }

              return {
                'sender': msg['sender'],
                'type': parsed['type'] ?? 'text',
                'data': parsed['data'] ?? '[Corrupted Message]',
                'timestamp': msg['timestamp'] ?? '',
                'isMe': msg['sender'] == widget.myName,
              };
            }).toList();
          });
          _scrollToBottom();
        } catch (e) {
          debugPrint("❌ Flutter History Parsing Error: $e");
        }
      }
    });

    socket.on('receive_message', (data) {
      if (mounted) {
        try {
          String decryptedString = "[Error decrypting]";
          Map<String, dynamic> parsed = {"type": "text", "data": decryptedString};

          try {
            String rawMsg = data['message'] ?? "";
            if (rawMsg.isNotEmpty) {
              decryptedString = _crypto.decryptPayload(rawMsg);
              parsed = jsonDecode(decryptedString);
            }
          } catch (e) {
            parsed = {"type": "text", "data": decryptedString};
          }

          setState(() {
            messages.add({
              'sender': data['sender'],
              'type': parsed['type'] ?? 'text',
              'data': parsed['data'] ?? '[Corrupted]',
              'timestamp': data['timestamp'] ?? 'Now',
              'isMe': data['sender'] == widget.myName,
            });

            final isFromOther = data['sender'] != widget.myName;
            if (isFromOther && !_isAtBottom) {
              _unreadCount++;
            }
          });

          if (_isAtBottom) {
            _scrollToBottom();
            if (privateRoom != null) _matchingService.updateLastRead(privateRoom!);
          }
        } catch (e) {
          debugPrint("❌ Flutter Receive Message Error: $e");
        }
      }
    });

    socket.onConnectError((data) => debugPrint("Connection Error: $data"));
    socket.onDisconnect((_) => debugPrint("Disconnected"));
  }

  void sendMessage() {
    String text = _controller.text.trim();
    if (text.isEmpty || privateRoom == null) return;

    String jsonPayload = jsonEncode({"type": "text", "data": text});
    String gibberish = _crypto.encryptPayload(jsonPayload);

    socket.emit('send_message', {
      'room': privateRoom,
      'sender': widget.myName,
      'message': gibberish,
      'timestamp': DateTime.now().toIso8601String(),
    });

    _controller.clear();
  }

  Future<void> sendEncryptedImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploadingMedia = true);
    try {
      Uint8List rawBytes = await image.readAsBytes();
      Uint8List encryptedBytes = _crypto.encryptBytes(rawBytes);
      String fileName = 'secure_media/${DateTime.now().millisecondsSinceEpoch}.enc';
      await Supabase.instance.client.storage
          .from('chat_bucket')
          .uploadBinary(fileName, encryptedBytes);
      String publicUrl = Supabase.instance.client.storage.from('chat_bucket').getPublicUrl(fileName);
      String jsonPayload = jsonEncode({"type": "image", "data": publicUrl});
      String gibberish = _crypto.encryptPayload(jsonPayload);
      socket.emit('send_message', {
        'room': privateRoom,
        'sender': widget.myName,
        'message': gibberish,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<Uint8List> fetchAndDecryptMedia(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return _crypto.decryptBytes(response.bodyBytes);
    throw Exception('Failed to load media');
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
    socket.dispose();
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: kRosePale,
                                shape: BoxShape.circle,
                                border: Border.all(color: kBone, width: 2),
                              ),
                              child: const Icon(Icons.waving_hand_rounded, color: kRose, size: 34),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Say Hello!",
                              style: GoogleFonts.figtree(
                                color: kInk,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Your messages are end-to-end encrypted",
                              style: GoogleFonts.figtree(color: kInkMuted, fontSize: 13),
                            ),
                          ],
                        ).animate().fade(duration: 600.ms).scale(begin: const Offset(0.92, 0.92)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: messages.length,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          bool isMe = msg['isMe'];
                          String time = msg['timestamp'] ?? "";
                          bool showHeader = _shouldShowTimeHeader(index);

                          bool isNextSame = false;
                          bool isPrevSame = false;
                          if (index < messages.length - 1) {
                            bool nextShowsHeader = _shouldShowTimeHeader(index + 1);
                            isNextSame = !nextShowsHeader && (messages[index + 1]['isMe'] == isMe);
                          }
                          if (index > 0) {
                            isPrevSame = !showHeader && (messages[index - 1]['isMe'] == isMe);
                          }

                          return Column(
                            children: [
                              if (showHeader)
                                Padding(
                                  padding: const EdgeInsets.only(top: 20, bottom: 10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: kBone,
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Text(
                                      _formatDateGroup(time),
                                      style: GoogleFonts.figtree(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: kInkMuted,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ).animate().fade(duration: 300.ms),
                                ),
                              Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: isPrevSame ? 2 : 10,
                                    bottom: isNextSame ? 2 : 8,
                                    left: isMe ? 48 : 0,
                                    right: isMe ? 0 : 48,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      gradient: isMe
                                          ? const LinearGradient(
                                              colors: [kRoseLight, kRose],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      color: isMe ? null : Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isMe ? kRose : kInk).withOpacity(isMe ? 0.18 : 0.04),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular((isMe || !isPrevSame) ? 20 : 6),
                                        topRight: Radius.circular((!isMe || !isPrevSame) ? 20 : 6),
                                        bottomLeft: Radius.circular((isMe || !isNextSame) ? 20 : 6),
                                        bottomRight: Radius.circular((!isMe || !isNextSame) ? 20 : 6),
                                      ),
                                    ),
                                    child: _buildMessageContent(msg, isMe),
                                  ).animate().fade(duration: 300.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutQuad),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                // ── Scroll‑to‑bottom + unread badge ────────────────────────
                if (!_isAtBottom)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _scrollToBottom,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(color: kParchment,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: kInk.withOpacity(0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: kBone),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_unreadCount > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: kRose,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    "$_unreadCount new",
                                    style: GoogleFonts.figtree(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Icon(Icons.keyboard_arrow_down_rounded, color: kInkMuted, size: 20),
                            ],
                          ),
                        ).animate().fade(duration: 250.ms).slideY(begin: 0.3, end: 0),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

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
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kBone, width: 2),
              boxShadow: [BoxShadow(color: kRose.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: CircleAvatar(
              backgroundColor: kRosePale,
              backgroundImage: widget.matchPhotoUrl != null ? NetworkImage(widget.matchPhotoUrl!) : null,
              radius: 20,
              child: widget.matchPhotoUrl == null
                  ? const Icon(Icons.person_rounded, size: 22, color: kRose)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.matchName,
                style: GoogleFonts.gabarito(fontWeight: FontWeight.bold, fontSize: 18,
                  color: kInk,
                  height: 1.1,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "End-to-End Encrypted",
                    style: GoogleFonts.figtree(fontSize: 11, color: Colors.green.shade600, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: kInkMuted),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onSelected: (value) {
            if (value == 'block') _showBlockConfirmation();
            else if (value == 'report') _showReportDialog();
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<String>(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, color: kInkMuted, size: 18),
                  const SizedBox(width: 10),
                  Text('Report User', style: GoogleFonts.figtree(color: kInk)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'block',
              child: Row(
                children: [
                  const Icon(Icons.block_rounded, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Text('Block User', style: GoogleFonts.figtree(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Container(
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
              onPressed: _isUploadingMedia ? null : sendEncryptedImage,
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
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: kCream,
        title: Text('Block ${widget.matchName}?',
            style: GoogleFonts.figtree(fontWeight: FontWeight.bold, color: kInk)),
        content: Text(
          'This action cannot be undone and will unmatch you.',
          style: GoogleFonts.figtree(color: kInkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.figtree(color: kInkMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _matchingService.blockUser(widget.matchId);
              if (success && mounted) {
                _showThemedToast('${widget.matchName} blocked', isError: false);
                Navigator.pop(context);
              } else if (mounted) {
                _showThemedToast('Failed to block. Try again.', isError: true);
              }
            },
            child: Text('Block', style: GoogleFonts.figtree(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final List<String> reasons = [
      "Inappropriate messages",
      "Fake profile / Spam",
      "Harassment",
      "Other"
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: kCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: kBone, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 20),
              Text("Report User",
                  style: GoogleFonts.figtree(fontSize: 20, fontWeight: FontWeight.bold, color: kInk)),
              const SizedBox(height: 4),
              Text("Select a reason", style: GoogleFonts.figtree(color: kInkMuted, fontSize: 14)),
              const SizedBox(height: 16),
              ...reasons.map((reason) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text(reason, style: GoogleFonts.figtree(color: kInk, fontSize: 15)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kInkMuted),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final success = await _matchingService.reportUser(widget.matchId, reason);
                      if (success && mounted) {
                        _showThemedToast('Report submitted. User has been blocked.', isError: false);
                        Navigator.pop(context);
                      } else if (mounted) {
                        _showThemedToast('Failed to report.', isError: true);
                      }
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemedToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : kRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        elevation: 10,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> msg, bool isMe) {
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
  }
}
