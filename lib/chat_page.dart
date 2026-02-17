// lib/chat_page.dart
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatScreen extends StatefulWidget {
  final String username;  // Your Name (e.g., Salil)
  final String matchName; // Their Name (e.g., Rahul)

  const ChatScreen({
    Key? key, 
    required this.username, 
    required this.matchName
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late IO.Socket socket;
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  String? privateRoom; 
  
  // 🔴 REPLACE THIS WITH YOUR CURRENT NGROK URL
  final String serverUrl = 'https://nina-unpumped-linus.ngrok-free.dev'; 

  @override
  void initState() {
    super.initState();
    connectToServer();
  }

  String getRoomId(String user1, String user2) {
    List<String> users = [user1, user2];
    users.sort(); // Sorting ensures 'Rahul_Salil' is always the same for both people
    return "${users[0]}_${users[1]}";
  }

  void connectToServer() {
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('✅ Connected to Server');
      
      // Use the real names passed from the previous screen
      privateRoom = getRoomId(widget.username, widget.matchName);
      
      print("🔐 Joining Private Room: $privateRoom");
      
      socket.emit('join_room', {
        'room': privateRoom, 
        'username': widget.username
      });
      
      // Optional: Ask server for previous messages
      // socket.emit('get_history', {'room': privateRoom}); 
    });

    socket.on('load_history', (data) {
      print("📜 HISTORY RECEIVED: $data"); // Debug print
      if (mounted) {
        setState(() {
          // Convert the incoming List to our Message format
          messages = List<Map<String, dynamic>>.from(data.map((msg) => {
            'sender': msg['sender'],
            'message': msg['message'],
            'isMe': msg['sender'] == widget.username, // Check if I sent it
          }));
        });
      }
    });

    socket.on('receive_message', (data) {
      print("📩 MSG RECEIVED FROM SERVER: $data");
      if (mounted) {
        setState(() {
          messages.add({
            'sender': data['sender'],
            'message': data['message'],
            'isMe': data['sender'] == widget.username,
          });
        });
      }
    });
  }

  void sendMessage() {
    if (_controller.text.isEmpty || privateRoom == null) return;

    socket.emit('send_message', {
      'room': privateRoom, 
      'sender': widget.username,
      'message': _controller.text,
    });

    _controller.clear();
  }

  @override
  void dispose() {
    socket.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chat with ${widget.matchName}"), // Shows who you are talking to
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                bool isMe = msg['isMe'];
                
                return ListTile(
                  title: Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFFCD9D8F) : Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        msg['message'],
                        style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFFCD9D8F),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}