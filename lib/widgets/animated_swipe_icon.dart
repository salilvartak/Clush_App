import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedSwipeIcon extends StatelessWidget {
  final bool isLike;

  const AnimatedSwipeIcon({super.key, required this.isLike});

  @override
  Widget build(BuildContext context) {
    const wineColor = Color(0xFF722F37);

    // The base circle and ripples share the same radius/stroke
    Widget buildBaseCircle({double strokeWidth = 5}) {
      return Container(
        width: 144,
        height: 144,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: wineColor, width: strokeWidth),
        ),
      );
    }

    Widget heartIcon = CustomPaint(
      size: const Size(144, 144),
      painter: HeartPainter(color: wineColor, strokeWidth: 5),
    );

    Widget crossIcon = CustomPaint(
      size: const Size(144, 144),
      painter: CrossPainter(color: wineColor, strokeWidth: 7.5),
    );

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base Circle
          buildBaseCircle(strokeWidth: 5)
              .animate(delay: 50.ms)
              .fadeIn(duration: 150.ms, curve: Curves.easeOut)
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                duration: 400.ms,
                curve: Curves.easeOutBack,
              ),

          // Inner Icon (Heart or Cross)
          (isLike ? heartIcon : crossIcon)
              .animate(delay: 150.ms)
              .fadeIn(duration: 150.ms, curve: Curves.easeOut)
              .scale(
                begin: const Offset(0.4, 0.4),
                end: const Offset(1, 1),
                duration: 400.ms,
                curve: Curves.easeOutBack,
              ),

          // Ripple 1
          buildBaseCircle(strokeWidth: 3)
              .animate(delay: 200.ms)
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.6, 1.6),
                duration: 700.ms,
                curve: Curves.easeOutCubic,
              )
              .fadeOut(
                begin: 0.4,
                duration: 700.ms,
                curve: Curves.easeOutCubic,
              ),

          // Ripple 2
          buildBaseCircle(strokeWidth: 2)
              .animate(delay: 300.ms)
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1.9, 1.9),
                duration: 900.ms,
                curve: Curves.easeOutCubic,
              )
              .fadeOut(
                begin: 0.2,
                duration: 900.ms,
                curve: Curves.easeOutCubic,
              ),
        ],
      ),
    );
  }
}

class HeartPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  HeartPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // HTML SVG d="M110 144 C93 128 75 116 75 99 C75 87 84 79 95 79 C102 79 107 83 110 89 C113 83 118 79 125 79 C136 79 145 87 145 99 C145 116 127 128 110 144Z"
    // The original SVG was 220x220, centered at 110. Since this canvas is 144x144, 
    // the offset needs to be shifted so 110 becomes 72. (Offset by -38)
    const double dx = -38;
    const double dy = -38 + 8; // Added 8px down shift for centering since original transform-origin was 110 118

    path.moveTo(110 + dx, 144 + dy);
    path.cubicTo(93 + dx, 128 + dy, 75 + dx, 116 + dy, 75 + dx, 99 + dy);
    path.cubicTo(75 + dx, 87 + dy, 84 + dx, 79 + dy, 95 + dx, 79 + dy);
    path.cubicTo(102 + dx, 79 + dy, 107 + dx, 83 + dy, 110 + dx, 89 + dy);
    path.cubicTo(113 + dx, 83 + dy, 118 + dx, 79 + dy, 125 + dx, 79 + dy);
    path.cubicTo(136 + dx, 79 + dy, 145 + dx, 87 + dy, 145 + dx, 99 + dy);
    path.cubicTo(145 + dx, 116 + dy, 127 + dx, 128 + dy, 110 + dx, 144 + dy);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CrossPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  CrossPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // HTML SVG x1="80" y1="80" x2="140" y2="140"
    // Center at 110 offset to 72 (-38)
    const double dx = -38;
    const double dy = -38;

    canvas.drawLine(const Offset(80 + dx, 80 + dy), const Offset(140 + dx, 140 + dy), paint);
    canvas.drawLine(const Offset(140 + dx, 80 + dy), const Offset(80 + dx, 140 + dy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
