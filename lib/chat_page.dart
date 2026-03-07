import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'services/matching_service.dart';

class ChatScreen extends StatefulWidget {
  final String myId;       // My Supabase UUID
  final String matchId;    // Their Supabase UUID
  final String myName;     // My Name (e.g. "Salil")
  final String matchName;  // Their Name (e.g. "Rahul")

  const ChatScreen({
    Key? key,
    required this.myId,
    required this.matchId,
    required this.myName,
    required this.matchName,
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
      backgroundColor: const Color(0xFFE5E5E5), // Light grey background like WhatsApp
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.grey,
              radius: 18,
              child: Icon(Icons.person, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(widget.matchName, style: const TextStyle(fontSize: 18)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
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
              ? const Center(child: Text("Say Hello! 👋", style: TextStyle(color: Colors.grey))) 
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    bool isMe = msg['isMe'];
                    String time = msg['timestamp'] ?? "";

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 8),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFCD9D8F) : Colors.white, // Colors
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            )
                          ],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end, // Align time to right
                          mainAxisSize: MainAxisSize.min, // Wrap content
                          children: [
                            Text(
                              msg['message'],
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // ⏰ TIMESTAMP TEXT
                            Text(
                              time,
                              style: TextStyle(
                                color: isMe ? Colors.white.withOpacity(0.7) : Colors.black38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: "Type a message...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFFCD9D8F),
            radius: 24,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 22),
              onPressed: sendMessage,
            ),
          ),
        ],
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