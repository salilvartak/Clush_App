// chat_screen.dart
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatScreen extends StatefulWidget {
  final String username;
  const ChatScreen({Key? key, required this.username}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late IO.Socket socket;
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  
  // Variable to store the specific room ID for this conversation
  String? privateRoom; 
  
  // 🔴 IMPORTANT: REPLACE THIS WITH YOUR NEW NGROK URL!
  final String serverUrl = 'https://nina-unpumped-linus.ngrok-free.dev'; 

  @override
  void initState() {
    super.initState();
    connectToServer();
  }

  // --- 1. THE NEW HELPER FUNCTION ---
  String getRoomId(String user1, String user2) {
    List<String> users = [user1, user2];
    users.sort(); // Ensures 'Rahul_Salil' is always generated, regardless of who logs in
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
      
      // --- 2. UPDATED CONNECTION LOGIC ---
      String matchName = "Rahul"; // Hardcoded for now (in real app, pass this in constructor)
      String myName = widget.username;
      
      // Generate and store the private room ID
      privateRoom = getRoomId(myName, matchName);
      
      print("Joining Room: $privateRoom"); // Debug print
      
      socket.emit('join_room', {'room': privateRoom, 'username': myName});
    });

    socket.on('receive_message', (data) {
      if (mounted) {
        setState(() {
          messages.add({
            'sender': data['sender'],
            'message': data['message'],
            'isMe': data['sender'] == widget.username, // Helper to check if I sent it
          });
        });
      }
    });
  }

  void sendMessage() {
    if (_controller.text.isEmpty) return;
    // Ensure we have a room to send to
    if (privateRoom == null) {
      print("❌ Error: Not connected to a room yet");
      return;
    }

    // --- 3. UPDATED SEND LOGIC ---
    // Send message to the privateRoom, not 'global'
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
      appBar: AppBar(title: const Text("Clush Chat")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                // Using a safe access for 'isMe' in case data structure changes
                bool isMe = msg['isMe'] ?? (msg['sender'] == widget.username);
                
                return ListTile(
                  title: Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        msg['message'],
                        style: TextStyle(color: isMe ? Colors.white : Colors.black),
                      ),
                    ),
                  ),
                  subtitle: Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(msg['sender'], style: const TextStyle(fontSize: 10)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _controller,
                        decoration:
                            const InputDecoration(hintText: "Type a message..."))),
                IconButton(icon: const Icon(Icons.send), onPressed: sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}