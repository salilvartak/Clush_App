import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:clush/theme/colors.dart';

class HeartLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const HeartLoader({
    super.key,
    this.size = 50.0,
    this.color,
  });

  @override
  State<HeartLoader> createState() => _HeartLoaderState();
}

class _HeartLoaderState extends State<HeartLoader> with SingleTickerProviderStateMixin {
  late AnimationController _drawController;

  @override
  void initState() {
    super.initState();
    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _drawController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _drawController,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: QPainter(
              drawProgress: _drawController.value,
              color: widget.color ?? kRose,
            ),
          ),
        );
      },
    );
  }
}

class QPainter extends CustomPainter {
  final double drawProgress;
  final Color color;

  QPainter({
    required this.drawProgress,
    required this.color,
  });

  static const String qPathData = "M 589.59375 23.34375 C 517.207031 23.34375 449.488281 8.363281 386.4375 -21.59375 C 323.394531 -51.5625 268.132812 -93.984375 220.65625 -148.859375 C 173.175781 -203.734375 136.203125 -268.140625 109.734375 -342.078125 C 83.273438 -416.015625 70.046875 -496.570312 70.046875 -583.75 C 70.046875 -671.695312 83.273438 -752.445312 109.734375 -826 C 136.203125 -899.550781 173.175781 -963.765625 220.65625 -1018.640625 C 268.132812 -1073.515625 323.394531 -1115.929688 386.4375 -1145.890625 C 449.488281 -1175.859375 517.207031 -1190.84375 589.59375 -1190.84375 C 656.53125 -1190.84375 712.957031 -1183.253906 758.875 -1168.078125 C 804.789062 -1152.898438 841.566406 -1133.050781 869.203125 -1108.53125 C 896.835938 -1084.019531 916.878906 -1057.363281 929.328125 -1028.5625 C 941.785156 -999.769531 948.015625 -972.140625 948.015625 -945.671875 C 948.015625 -905.203125 940.035156 -868.617188 924.078125 -835.921875 C 908.117188 -803.234375 887.6875 -773.65625 862.78125 -747.1875 C 837.875 -720.726562 811.210938 -696.019531 782.796875 -673.0625 C 754.390625 -650.101562 727.734375 -628.113281 702.828125 -607.09375 C 677.921875 -586.082031 657.488281 -565.066406 641.53125 -544.046875 C 625.582031 -523.035156 617.609375 -500.851562 617.609375 -477.5 C 617.609375 -459.601562 620.523438 -445.007812 626.359375 -433.71875 C 632.203125 -422.4375 640.957031 -411.738281 652.625 -401.625 C 631.613281 -396.945312 613.519531 -400.054688 598.34375 -410.953125 C 583.164062 -421.859375 571.488281 -436.648438 563.3125 -455.328125 C 555.144531 -474.003906 551.0625 -492.296875 551.0625 -510.203125 C 551.0625 -544.441406 559.035156 -575.375 574.984375 -603 C 590.941406 -630.632812 611.375 -656.128906 636.28125 -679.484375 C 661.1875 -702.835938 687.457031 -725.019531 715.09375 -746.03125 C 742.726562 -767.050781 769 -788.257812 793.90625 -809.65625 C 818.8125 -831.0625 839.238281 -853.632812 855.1875 -877.375 C 871.144531 -901.113281 879.125 -926.992188 879.125 -955.015625 C 879.125 -1024.285156 855.191406 -1078.570312 807.328125 -1117.875 C 759.460938 -1157.1875 686.882812 -1176.84375 589.59375 -1176.84375 C 528.875 -1176.84375 473.21875 -1162.050781 422.625 -1132.46875 C 372.039062 -1102.894531 328.257812 -1061.445312 291.28125 -1008.125 C 254.3125 -954.8125 225.707031 -892.15625 205.46875 -820.15625 C 185.238281 -748.164062 175.125 -669.363281 175.125 -583.75 C 175.125 -498.914062 186.019531 -420.304688 207.8125 -347.921875 C 229.601562 -275.535156 259.566406 -212.679688 297.703125 -159.359375 C 335.847656 -106.046875 380.019531 -64.597656 430.21875 -35.015625 C 480.425781 -5.441406 533.550781 9.34375 589.59375 9.34375 C 641.738281 9.34375 686.488281 2.726562 723.84375 -10.5 C 761.207031 -23.738281 792.726562 -40.085938 818.40625 -59.546875 C 844.09375 -79.003906 864.523438 -98.460938 879.703125 -117.921875 C 894.890625 -137.378906 905.789062 -153.722656 912.40625 -166.953125 C 919.019531 -180.179688 922.328125 -186.796875 922.328125 -186.796875 L 935.171875 -186.796875 L 935.171875 -30.359375 C 888.472656 -15.566406 837.878906 -2.921875 783.390625 7.578125 C 728.910156 18.085938 664.3125 23.34375 589.59375 23.34375 Z";

  @override
  void paint(Canvas canvas, Size size) {
    // Background Glow pulse removed to match latest HTML simplified design

    // 2. Adjust Canvas to fit path
    double vbWidth = 880;
    double vbHeight = 1235;
    double vbX = 70;
    double vbY = -1210;
    
    canvas.save();
    
    double svgSize = size.width * (180 / 220);
    double margin = (size.width - svgSize) / 2;
    canvas.translate(margin, margin);
    
    double svgScale = svgSize / math.max(vbWidth, vbHeight);
    canvas.scale(svgScale, svgScale);
    canvas.translate(-vbX, -vbY);
    
    // 3. Path Drawing logic
    Path qPath = parseSvgPathData(qPathData);
    
    double strokeStepProgress = math.min(drawProgress / 0.70, 1.0);
    double easedDraw = const Cubic(0.4, 0, 0.2, 1).transform(strokeStepProgress);
    
    double pathOpacity = 1.0;
    if (drawProgress > 0.85) {
      pathOpacity = 1.0 - ((drawProgress - 0.85) / 0.15);
    }
    
    Paint pathPaint = Paint()
      ..color = color.withOpacity(pathOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Paint shadowPaint = Paint()
      ..color = color.withOpacity(0.3 * pathOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0);
    
    for (var metric in qPath.computeMetrics()) {
      Path extract = metric.extractPath(0, metric.length * easedDraw);
      canvas.drawPath(extract, shadowPaint);
      canvas.drawPath(extract, pathPaint);
      
      // 4. Traveling Dot
      double dotOpacity = 0.0;
      if (drawProgress > 0 && drawProgress <= 0.05) {
        dotOpacity = drawProgress / 0.05;
      } else if (drawProgress > 0.05 && drawProgress <= 0.70) {
        dotOpacity = 1.0;
      } else if (drawProgress > 0.70 && drawProgress <= 0.85) {
        dotOpacity = 1.0 - ((drawProgress - 0.70) / 0.15);
      }
      
      if (dotOpacity > 0) {
          Tangent? t = metric.getTangentForOffset(metric.length * easedDraw);
          if (t != null) {
              Paint dotShadowPaint = Paint()
                ..color = Colors.white.withOpacity(dotOpacity * 0.5)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
              
              Paint dotPaint = Paint()
                ..color = const Color(0xFFF5CFC8).withOpacity(dotOpacity)
                ..style = PaintingStyle.fill;
              
              canvas.drawCircle(t.position, 18, dotShadowPaint);
              canvas.drawCircle(t.position, 18, dotPaint);
          }
      }
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(QPainter oldDelegate) {
    return oldDelegate.drawProgress != drawProgress || 
           oldDelegate.color != color;
  }
}
