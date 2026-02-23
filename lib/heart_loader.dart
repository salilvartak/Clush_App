import 'package:flutter/material.dart';

class HeartLoader extends StatefulWidget {
  final double size;
  final Color color;

  const HeartLoader({
    super.key,
    this.size = 50.0, // Default size for full screens
    this.color = const Color(0xFFCD9D8F), // Your brand peach color
  });

  @override
  State<HeartLoader> createState() => _HeartLoaderState();
}

class _HeartLoaderState extends State<HeartLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // 600ms gives a nice, natural heartbeat rhythm
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true); // Reverses automatically to "beat" back down
    
    // Scales the heart from 85% to 115% size
    _animation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: child,
        );
      },
      // Passing child here is an optimization so Flutter doesn't rebuild the Icon
      child: Icon(
        Icons.favorite, // You can change this to Icons.favorite_border for an outlined heart
        color: widget.color,
        size: widget.size,
      ),
    );
  }
}