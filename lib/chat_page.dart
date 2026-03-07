import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Typography
import 'package:flutter_animate/flutter_animate.dart'; // Animations
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'services/matching_service.dart';

// Global color references
const Color kRose = Color(0xFFCD9D8F);
const Color kBlack = Color(0xFF2D2D2D);
const Color kTan = Color(0xFFF8F9FA); // Sleek off-white for background

class ChatScreen extends StatefulWidget {
  final String myId;       // My Supabase UUID
  final String matchId;    // Their Supabase UUID
  final String myName;     // My Name (e.g. "Salil")
  final String matchName;  // Their Name (e.g. "Rahul")
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
  final ScrollController _scrollController = ScrollController(); // Auto-scroll
  final MatchingService _matchingService = MatchingService();
  List<Map<String, dynamic>> messages = [];
  String? privateRoom; // The secure "UUID_UUID" room ID

  // 🔴 IMPORTANT: Check if this URL is still active in Terminal 2!
  final String serverUrl = 'https://nina-unpumped-linus.ngrok-free.dev';

  @override
  void initState() {
    super.initState();
    connectToServer();
  }

  // --- 1. SECURE ROOM GENERATOR ---
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
      print('✅ Connected to Server');
      privateRoom = getRoomId(widget.myId, widget.matchId);
      print("🔐 Joining Secure Room: $privateRoom");

      socket.emit('join_room', {
        'room': privateRoom,
        'username': widget.myName, 
      });
    });

    // --- 2. LOAD PREVIOUS CHATS (WITH TIME) ---
    socket.on('load_history', (data) {
      if (mounted) {
        setState(() {
          messages = List<Map<String, dynamic>>.from(data.map((msg) => {
            'sender': msg['sender'],
            'message': msg['message'],
            'timestamp': msg['timestamp'] ?? '', // <--- NEW: Get Time
            'isMe': msg['sender'] == widget.myName,
          }));
        });
        _scrollToBottom();
      }
    });

    // --- 3. RECEIVE NEW MESSAGES (WITH TIME) ---
    socket.on('receive_message', (data) {
      if (mounted) {
        setState(() {
          messages.add({
            'sender': data['sender'],
            'message': data['message'],
            'timestamp': data['timestamp'] ?? 'Now', // <--- NEW: Get Time
            'isMe': data['sender'] == widget.myName,
          });
        });
        _scrollToBottom();
      }
    });
    
    socket.onConnectError((data) => print("❌ Connection Error: $data"));
    socket.onDisconnect((_) => print("⚠️ Disconnected"));
  }

  void sendMessage() {
    String text = _controller.text.trim();
    if (text.isEmpty || privateRoom == null) return;

    socket.emit('send_message', {
      'room': privateRoom,
      'sender': widget.myName, 
      'message': text,
    });

    _controller.clear();
  }
  
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    socket.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTan, 
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              backgroundImage: widget.matchPhotoUrl != null ? NetworkImage(widget.matchPhotoUrl!) : null,
              radius: 20,
              child: widget.matchPhotoUrl == null ? const Icon(Icons.person, size: 24, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Text(
              widget.matchName, 
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: kBlack,
                letterSpacing: -0.3,
              )
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: kBlack,
        elevation: 0,
        scrolledUnderElevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black54),
            onSelected: (value) {
              if (value == 'block') {
                _showBlockConfirmation();
              } else if (value == 'report') {
                _showReportDialog();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'report',
                  child: Text('Report User'),
                ),
                const PopupMenuItem<String>(
                  value: 'block',
                  child: Text('Block User', style: TextStyle(color: Colors.red)),
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty 
              ? Center(
                  child: Text(
                    "Say Hello! 👋", 
                    style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 20, fontWeight: FontWeight.w600)
                  ).animate().fade(duration: 800.ms, delay: 200.ms)
                ) 
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    bool isMe = msg['isMe'];
                    String time = msg['timestamp'] ?? "";

                    // Calculate border radius logic for consecutive messages
                    bool isNextSame = false;
                    bool isPrevSame = false;
                    
                    if (index < messages.length - 1) {
                      isNextSame = messages[index + 1]['isMe'] == isMe;
                    }
                    if (index > 0) {
                      isPrevSame = messages[index - 1]['isMe'] == isMe;
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.only(
                          top: isPrevSame ? 2 : 12, // Tighter grouping for consecutive messages
                          bottom: isNextSame ? 2 : 8,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          // the outgoing message gets a subtle gradient
                          gradient: isMe ? const LinearGradient(
                            colors: [Color(0xFFE5B5A5), kRose],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ) : null,
                          color: isMe ? null : Colors.white,
                          boxShadow: [
                            if (!isMe)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                          ],
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular((isMe || !isPrevSame) ? 20 : 6),
                            topRight: Radius.circular((!isMe || !isPrevSame) ? 20 : 6),
                            bottomLeft: Radius.circular((isMe || !isNextSame) ? 20 : 6),
                            bottomRight: Radius.circular((!isMe || !isNextSame) ? 20 : 6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg['message'],
                              style: GoogleFonts.outfit(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // ⏰ TIMESTAMP TEXT
                            Text(
                              time,
                              style: GoogleFonts.outfit(
                                color: isMe ? Colors.white.withOpacity(0.8) : Colors.black45,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fade(duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                    );
                  },
                ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: kTan, // Using the app background color for the input field to make it seamlessly recess
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.outfit(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "Type a message...",
                    hintStyle: GoogleFonts.outfit(color: Colors.black38),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: sendMessage,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kRose, Color(0xFFFFC3A0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kRose.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ACTIONS ---

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block User?'),
        content: Text('Are you sure you want to block ${widget.matchName}? This action cannot be undone and will unmatch you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx); // close dialog
              final success = await _matchingService.blockUser(widget.matchId);
              if (success && mounted) {
                _showThemedToast('${widget.matchName} blocked', isError: false);
                Navigator.pop(context); // close chat screen completely
              } else if (mounted) {
                _showThemedToast('Failed to block. Try again.', isError: true);
              }
            },
            child: const Text('Block', style: TextStyle(color: Colors.white)),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Report User",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...reasons.map((reason) => ListTile(
                      title: Text(reason),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        Navigator.pop(ctx); // close bottom sheet
                        final success = await _matchingService.reportUser(
                            widget.matchId, reason);
                        if (success && mounted) {
                          _showThemedToast('Report submitted. User has been blocked.', isError: false);
                          Navigator.pop(context); // Close chat completely
                        } else if (mounted) {
                          _showThemedToast('Failed to report.', isError: true);
                        }
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- REUSABLE THEMED TOAST ---
  void _showThemedToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFFCD9D8F), // kRose
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        elevation: 10,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}