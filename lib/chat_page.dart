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
  
  // 🔴 IMPORTANT: REPLACE THIS WITH THE NEW NGROK URL!
  final String serverUrl = 'https://nina-unpumped-linus.ngrok-free.dev'; 

  @override
  void initState() {
    super.initState();
    connectToServer();
  }

  void connectToServer() {
    // Connect to the server
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('✅ Connected to Server');
      // Join the 'global' chat room
      socket.emit('join_room', {'room': 'global', 'username': widget.username});
    });

    // Listen for new messages
    socket.on('receive_message', (data) {
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
    if (_controller.text.isEmpty) return;

    // Send the message to the backend
    socket.emit('send_message', {
      'room': 'global',
      'sender': widget.username,
      'message': _controller.text,
    });

    _controller.clear();
  }

  @override
  void dispose() {
    socket.dispose();
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
                return ListTile(
                  title: Align(
                    alignment: msg['isMe'] ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: msg['isMe'] ? Colors.blue : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        msg['message'],
                        style: TextStyle(color: msg['isMe'] ? Colors.white : Colors.black),
                      ),
                    ),
                  ),
                  subtitle: Align(
                    alignment: msg['isMe'] ? Alignment.centerRight : Alignment.centerLeft,
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
                Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: "Type a message..."))),
                IconButton(icon: const Icon(Icons.send), onPressed: sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}