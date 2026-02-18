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

  // 🔴 IMPORTANT: REPLACE THIS WITH YOUR CURRENT NGROK URL!
  final String serverUrl = 'https://nina-unpumped-linus.ngrok-free.dev';

  @override
  void initState() {
    super.initState();
    connectToServer();
  }

  // --- 1. SECURE ROOM GENERATOR ---
  // Sorts UUIDs alphabetically so "UserA_UserB" is ALWAYS the same string
  String getRoomId(String id1, String id2) {
    List<String> ids = [id1, id2];
    ids.sort(); 
    return "${ids[0]}_${ids[1]}";
  }

  void connectToServer() {
    // Initialize Socket
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('✅ Connected to Server');

      // Generate the Secure Room ID using UUIDs
      privateRoom = getRoomId(widget.myId, widget.matchId);
      print("🔐 Joining Secure Room: $privateRoom");

      // Join the room
      // We send 'username' so the server can print "Salil joined..."
      socket.emit('join_room', {
        'room': privateRoom,
        'username': widget.myName, 
      });
    });

    // --- 2. LOAD PREVIOUS CHATS ---
    socket.on('load_history', (data) {
      if (mounted) {
        setState(() {
          messages = List<Map<String, dynamic>>.from(data.map((msg) => {
            'sender': msg['sender'],
            'message': msg['message'],
            'isMe': msg['sender'] == widget.myName, // Check if I sent it
          }));
        });
        _scrollToBottom();
      }
    });

    // --- 3. RECEIVE NEW MESSAGES ---
    socket.on('receive_message', (data) {
      if (mounted) {
        setState(() {
          messages.add({
            'sender': data['sender'],
            'message': data['message'],
            'isMe': data['sender'] == widget.myName,
          });
        });
        _scrollToBottom();
      }
    });
    
    // Handle connection errors
    socket.onConnectError((data) => print("❌ Connection Error: $data"));
    socket.onDisconnect((_) => print("⚠️ Disconnected"));
  }

  void sendMessage() {
    String text = _controller.text.trim();
    if (text.isEmpty || privateRoom == null) return;

    // Send the message
    // Note: We use UUID for the room, but Name for the 'sender' display
    socket.emit('send_message', {
      'room': privateRoom,
      'sender': widget.myName, 
      'message': text,
    });

    _controller.clear();
  }
  
  void _scrollToBottom() {
    // Scroll to bottom after a slight delay to let the list render
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
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.grey,
              radius: 16,
              child: Icon(Icons.person, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(widget.matchName, style: const TextStyle(fontSize: 18)), // "Chat with Rahul"
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty 
              ? const Center(child: Text("Say Hello! 👋", style: TextStyle(color: Colors.grey))) 
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    bool isMe = msg['isMe'];

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFCD9D8F) : Colors.grey[200],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          msg['message'],
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 16
                          ),
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
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: "Type a message...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFFCD9D8F),
            radius: 24,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}