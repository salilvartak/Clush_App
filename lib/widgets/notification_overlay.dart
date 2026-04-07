import 'package:flutter/material.dart';
import 'package:clush/theme/colors.dart';

class NotificationOverlay extends StatefulWidget {
  final String title;
  final String body;
  final String? type;
  final VoidCallback onTap;

  const NotificationOverlay({
    Key? key,
    required this.title,
    required this.body,
    this.type,
    required this.onTap,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required String title,
    required String body,
    String? type,
    required VoidCallback onTap,
  }) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 10,
        right: 10,
        child: Material(
          color: Colors.transparent,
          child: NotificationOverlay(
            title: title,
            body: body,
            type: type,
            onTap: () {
              overlayEntry.remove();
              onTap();
            },
          ),
        ),
      ),
    );

    overlayState.insert(overlayEntry);

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kTan,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: kRose.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              _buildIcon(),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.body,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        color: kInkMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: kInkMuted.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;
    Color color;

    switch (widget.type) {
      case 'new_match':
        iconData = Icons.favorite_rounded;
        color = kRose;
        break;
      case 'new_like':
        iconData = Icons.favorite_border_rounded;
        color = kGold;
        break;
      case 'message':
        iconData = Icons.chat_bubble_rounded;
        color = Colors.blue;
        break;
      default:
        iconData = Icons.notifications_rounded;
        color = kRose;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }
}
