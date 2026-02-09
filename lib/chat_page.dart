import 'package:flutter/material.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E6E1), // kTan
      appBar: AppBar(
        title: const Text("Messages", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        separatorBuilder: (context, index) => const Divider(height: 32),
        itemBuilder: (context, index) => _buildChatSkeleton(),
      ),
    );
  }

  Widget _buildChatSkeleton() {
    return Row(
      children: [
        Stack(
          children: [
            CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade200),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 100, height: 14, color: Colors.grey.shade200),
                  Container(width: 30, height: 10, color: Colors.grey.shade200),
                ],
              ),
              const SizedBox(height: 8),
              Container(width: double.infinity, height: 12, color: Colors.grey.shade100),
            ],
          ),
        ),
      ],
    );
  }
}