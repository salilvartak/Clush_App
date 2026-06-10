import 'package:flutter/material.dart';

/// Draws the like/dislike feedback as a self-drawing outline: the outer
/// circle traces itself first, then the heart (like) or cross (dislike)
/// strokes itself in — instead of the previous pop/bounce/ripple animation.
class AnimatedSwipeIcon extends StatefulWidget {
  final bool isLike;

  const AnimatedSwipeIcon({super.key, required this.isLike});

  @override
  State<AnimatedSwipeIcon> createState() => _AnimatedSwipeIconState();
}

class _AnimatedSwipeIconState extends State<AnimatedSwipeIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Phase 1: outer circle draws itself.
  static const Interval _circlePhase = Interval(0.0, 0.55, curve: Curves.easeInOut);
  // Phase 2: heart/cross draws itself, slightly overlapping the circle finish.
  static const Interval _iconPhase = Interval(0.40, 1.0, curve: Curves.easeInOut);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const wineColor = Color(0xFF722F37);

    return SizedBox(
      width: 220,
      height: 220,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final circleT = _circlePhase.transform(_controller.value);
          final iconT = _iconPhase.transform(_controller.value);

          return CustomPaint(
            size: const Size(220, 220),
            painter: _SwipeIconPainter(
              isLike: widget.isLike,
              color: wineColor,
              circleProgress: circleT,
              iconProgress: iconT,
            ),
          );
        },
      ),
    );
  }
}

class _SwipeIconPainter extends CustomPainter {
  final bool isLike;
  final Color color;
  final double circleProgress;
  final double iconProgress;

  _SwipeIconPainter({
    required this.isLike,
    required this.color,
    required this.circleProgress,
    required this.iconProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const circleRadius = 72.0;

    // ── Outer circle, drawn as a sweeping arc ──
    if (circleProgress > 0) {
      final circlePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: circleRadius);
      const startAngle = -3.14159265358979 / 2; // start at top
      final sweepAngle = 2 * 3.14159265358979 * circleProgress;
      canvas.drawArc(rect, startAngle, sweepAngle, false, circlePaint);
    }

    // ── Inner icon (heart or cross), drawn progressively ──
    if (iconProgress > 0) {
      final iconPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = isLike ? 5 : 7.5;

      final fullPath = isLike ? _heartPath(center) : _crossPath(center);
      final partialPath = _extractProgress(fullPath, iconProgress);
      canvas.drawPath(partialPath, iconPaint);
    }
  }

  /// Heart path centered on [center]. Source SVG: d="M110 144 C93 128 75 116
  /// 75 99 C75 87 84 79 95 79 C102 79 107 83 110 89 C113 83 118 79 125 79
  /// C136 79 145 87 145 99 C145 116 127 128 110 144Z" (220x220 viewBox).
  /// Bounding box: x [75,145], y [79,144] → center (110, 111.5).
  Path _heartPath(Offset center) {
    const double srcCx = 110;
    const double srcCy = 111.5;
    final double dx = center.dx - srcCx;
    final double dy = center.dy - srcCy;

    final path = Path();
    path.moveTo(110 + dx, 144 + dy);
    path.cubicTo(93 + dx, 128 + dy, 75 + dx, 116 + dy, 75 + dx, 99 + dy);
    path.cubicTo(75 + dx, 87 + dy, 84 + dx, 79 + dy, 95 + dx, 79 + dy);
    path.cubicTo(102 + dx, 79 + dy, 107 + dx, 83 + dy, 110 + dx, 89 + dy);
    path.cubicTo(113 + dx, 83 + dy, 118 + dx, 79 + dy, 125 + dx, 79 + dy);
    path.cubicTo(136 + dx, 79 + dy, 145 + dx, 87 + dy, 145 + dx, 99 + dy);
    path.cubicTo(145 + dx, 116 + dy, 127 + dx, 128 + dy, 110 + dx, 144 + dy);
    path.close();
    return path;
  }

  /// Cross (X) path centered on [center]. Source SVG lines: (80,80)-(140,140)
  /// and (140,80)-(80,140) → bounding box center (110, 110).
  Path _crossPath(Offset center) {
    const double srcCx = 110;
    const double srcCy = 110;
    final double dx = center.dx - srcCx;
    final double dy = center.dy - srcCy;

    final path = Path();
    path.moveTo(80 + dx, 80 + dy);
    path.lineTo(140 + dx, 140 + dy);
    path.moveTo(140 + dx, 80 + dy);
    path.lineTo(80 + dx, 140 + dy);
    return path;
  }

  /// Returns the sub-path of [source] covering [progress] (0-1) of its total length.
  Path _extractProgress(Path source, double progress) {
    if (progress >= 1) return source;
    final result = Path();
    for (final metric in source.computeMetrics()) {
      final length = metric.length * progress;
      result.addPath(metric.extractPath(0, length), Offset.zero);
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _SwipeIconPainter oldDelegate) {
    return oldDelegate.circleProgress != circleProgress ||
        oldDelegate.iconProgress != iconProgress ||
        oldDelegate.isLike != isLike;
  }
}
