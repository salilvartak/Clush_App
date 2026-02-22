import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

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

  // ==========================================
  // UI CODE BELOW (Updated to match App Theme)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E6E1), // App's standard background
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFCD9D8F).withOpacity(0.2),
              radius: 20,
              child: const Icon(Icons.person, size: 22, color: Color(0xFFCD9D8F)),
            ),
            const SizedBox(width: 12),
            Text(
              widget.matchName, 
              style: const TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2D2D), // Dark premium text
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey.withOpacity(0.15),
            height: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty 
              ? _buildEmptyState() 
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    bool isMe = msg['isMe'];
                    String time = msg['timestamp'] ?? "";

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFCD9D8F) : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            // Create the "chat tail" effect
                            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg['message'],
                              style: TextStyle(
                                color: isMe ? Colors.white : const Color(0xFF2D2D2D),
                                fontSize: 16,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              time,
                              style: TextStyle(
                                color: isMe ? Colors.white.withOpacity(0.7) : Colors.black38,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFCD9D8F).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Text("👋", style: TextStyle(fontSize: 40)),
          ),
          const SizedBox(height: 16),
          Text(
            "Say Hello to ${widget.matchName}!",
            style: const TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.w600, 
              color: Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Be polite and start the conversation.",
            style: TextStyle(color: Colors.black45, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, 
        right: 16, 
        top: 12, 
        // Adds extra padding at the bottom for iOS home bar / safe area
        bottom: MediaQuery.of(context).padding.bottom > 0 
            ? MediaQuery.of(context).padding.bottom 
            : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5), // Soft grey background for text field
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5, // Allows the text field to grow if they type a long message
                style: const TextStyle(fontSize: 16, color: Color(0xFF2D2D2D)),
                decoration: const InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: TextStyle(color: Colors.black38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            margin: const EdgeInsets.only(bottom: 2), // Align visually with the growing text field
            child: CircleAvatar(
              backgroundColor: const Color(0xFFCD9D8F),
              radius: 24,
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                onPressed: sendMessage,
              ),
            ),
          ),
        ],
      ),
    );
  }
}