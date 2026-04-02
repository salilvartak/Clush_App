import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clush/theme/colors.dart';

Future<void> showMatchAnimation(
  BuildContext context, {
  required String myPhotoUrl,
  required String matchPhotoUrl,
  required String matchName,
  required VoidCallback onMessage,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, _, __) => _MatchPage(
      myPhotoUrl: myPhotoUrl,
      matchPhotoUrl: matchPhotoUrl,
      matchName: matchName,
      onMessage: onMessage,
    ),
  );
}

// ─── Particle data ────────────────────────────────────────────────────────────

class _Particle {
  final double x;      // 0–1 normalised horizontal start
  final double size;
  final double speed;  // 0.6–1.4 multiplier
  final double drift;  // horizontal wander, –1 to 1
  final double delay;  // 0–1 fraction of particle controller duration

  _Particle({
    required this.x,
    required this.size,
    required this.speed,
    required this.drift,
    required this.delay,
  });
}

List<_Particle> _makeParticles(int n) {
  final rng = math.Random(42);
  return List.generate(n, (_) => _Particle(
    x:     0.15 + rng.nextDouble() * 0.70,
    size:  8 + rng.nextDouble() * 12,
    speed: 0.6 + rng.nextDouble() * 0.8,
    drift: (rng.nextDouble() - 0.5) * 2,
    delay: rng.nextDouble() * 0.45,
  ));
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class _MatchPage extends StatefulWidget {
  final String myPhotoUrl, matchPhotoUrl, matchName;
  final VoidCallback onMessage;

  const _MatchPage({
    required this.myPhotoUrl,
    required this.matchPhotoUrl,
    required this.matchName,
    required this.onMessage,
  });

  @override
  State<_MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<_MatchPage> with TickerProviderStateMixin {

  // Controllers
  late final AnimationController _bg;          // 400 ms – background fade
  late final AnimationController _slide;       // 750 ms – DPs fly in
  late final AnimationController _pulse;       // 300 ms – impact bounce
  late final AnimationController _heart;       // 1100 ms – heart draws + scale
  late final AnimationController _text;        // 550 ms – labels fade
  late final AnimationController _particlesCtrl; // 2400 ms – hearts float up

  // Derived animations
  late final Animation<double> _bgOpacity;
  late final Animation<double> _slideL, _slideR;
  late final Animation<double> _avatarScale;
  late final Animation<double> _heartDraw;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartGlow;
  late final Animation<double> _textFade;
  late final Animation<double> _btnSlide;

  final _heartParticles = _makeParticles(16);

  @override
  void initState() {
    super.initState();

    _bg        = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slide     = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _pulse     = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _heart     = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _text      = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _particlesCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

    _bgOpacity   = CurvedAnimation(parent: _bg,    curve: Curves.easeOut);
    _slideL      = CurvedAnimation(parent: _slide, curve: Curves.easeOutBack);
    _slideR      = CurvedAnimation(parent: _slide, curve: Curves.easeOutBack);
    _avatarScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.10), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.10, end: 1.0),  weight: 60),
    ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _heartDraw   = CurvedAnimation(parent: _heart, curve: const Interval(0.0, 0.75, curve: Curves.easeInOut));
    _heartScale  = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.04), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0),  weight: 30),
    ]).animate(CurvedAnimation(parent: _heart, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)));
    _heartGlow   = CurvedAnimation(parent: _heart, curve: const Interval(0.55, 1.0, curve: Curves.easeOut));
    _textFade    = CurvedAnimation(parent: _text, curve: Curves.easeOut);
    _btnSlide    = CurvedAnimation(parent: _text, curve: Curves.easeOutCubic);

    // Sequence
    _bg.forward().then((_) {
      _slide.forward().then((_) {
        _pulse.forward().then((_) {
          _heart.forward().then((_) => _text.forward());
          _particlesCtrl.forward();
        });
      });
    });
  }

  @override
  void dispose() {
    _bg.dispose(); _slide.dispose(); _pulse.dispose();
    _heart.dispose(); _text.dispose(); _particlesCtrl.dispose();
    super.dispose();
  }

  void _dismiss() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([_bg, _slide, _pulse, _heart, _text, _particlesCtrl]),
      builder: (_, __) {
        return Material(
          color: Colors.black.withAlpha((220 * _bgOpacity.value).round()),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Radial glow background ───────────────────────────────────
              Opacity(
                opacity: _bgOpacity.value,
                child: CustomPaint(
                  size: size,
                  painter: _BgGlowPainter(intensity: _heartGlow.value),
                ),
              ),

              // ── Floating heart particles ──────────────────────────────────
              ..._buildParticles(size),

              // ── Main content ──────────────────────────────────────────────
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header label
                    Opacity(
                      opacity: _textFade.value,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - _textFade.value)),
                        child: _buildHeader(),
                      ),
                    ),

                    const SizedBox(height: 44),

                    // Avatars + heart
                    SizedBox(
                      width: 300,
                      height: 260,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Heart behind avatars
                          Transform.scale(
                            scale: _heartScale.value,
                            child: CustomPaint(
                              size: const Size(300, 260),
                              painter: _HeartPainter(
                                progress: _heartDraw.value,
                                glow: _heartGlow.value,
                              ),
                            ),
                          ),
                          // Avatars
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Transform.translate(
                                offset: Offset(-200 * (1 - _slideL.value), 0),
                                child: Transform.scale(
                                  scale: _avatarScale.value,
                                  child: _Avatar(url: widget.myPhotoUrl, glow: _heartGlow.value),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Transform.translate(
                                offset: Offset(200 * (1 - _slideR.value), 0),
                                child: Transform.scale(
                                  scale: _avatarScale.value,
                                  child: _Avatar(url: widget.matchPhotoUrl, glow: _heartGlow.value),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Name
                    Opacity(
                      opacity: _textFade.value,
                      child: Text(
                        'You and ${widget.matchName} like each other',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.gabarito(
                          color: Colors.white60,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Buttons
                    Opacity(
                      opacity: _textFade.value,
                      child: Transform.translate(
                        offset: Offset(0, 28 * (1 - _btnSlide.value)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36),
                          child: Column(children: [
                            _PrimaryBtn(
                              label: 'Send a Message',
                              onTap: () { _dismiss(); widget.onMessage(); },
                            ),
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: _dismiss,
                              child: Text(
                                'Keep Discovering',
                                style: GoogleFonts.figtree(
                                  color: Colors.white38,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(children: [
      // Pill label
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: kRose.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kRose.withAlpha(80), width: 1),
        ),
        child: Text(
          'IT\'S A MATCH',
          style: GoogleFonts.figtree(
            color: kRose,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.5,
          ),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        'It\'s Mutual',
        style: GoogleFonts.gabarito(
          color: Colors.white,
          fontSize: 46,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
          letterSpacing: -1,
          height: 1.0,
        ),
      ),
    ]);
  }

  List<Widget> _buildParticles(Size screen) {
    final t = _particlesCtrl.value;
    return _heartParticles.map((p) {
      final localT = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (localT <= 0) return const SizedBox.shrink();
      final x = p.x * screen.width + p.drift * 30 * localT;
      final y = screen.height * 0.65 - localT * screen.height * 0.55 * p.speed;
      final opacity = (localT < 0.2 ? localT / 0.2 : 1 - (localT - 0.5).clamp(0.0, 1.0) / 0.5).clamp(0.0, 1.0);
      return Positioned(
        left: x - p.size / 2,
        top:  y - p.size / 2,
        child: Opacity(
          opacity: opacity * 0.75,
          child: Icon(Icons.favorite_rounded, color: kRose, size: p.size),
        ),
      );
    }).toList();
  }
}

// ─── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String url;
  final double glow; // 0–1

  const _Avatar({required this.url, required this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: kRose.withAlpha((100 + (80 * glow)).round()),
            blurRadius: 16 + 20 * glow,
            spreadRadius: 2 + 4 * glow,
          ),
        ],
      ),
      child: ClipOval(
        child: url.startsWith('http')
            ? Image.network(url, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder())
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: kRosePale,
    child: const Icon(Icons.person_rounded, size: 52, color: kRose),
  );
}

// ─── Primary button ─────────────────────────────────────────────────────────

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B8A), kRose, Color(0xFFD94F70)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: kRose.withAlpha(100),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.figtree(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ─── Background glow painter ─────────────────────────────────────────────────

class _BgGlowPainter extends CustomPainter {
  final double intensity;
  _BgGlowPainter({required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;
    final cx = size.width / 2;
    final cy = size.height * 0.44;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          kRose.withAlpha((40 * intensity).round()),
          Colors.transparent,
        ],
        radius: 0.55,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.7));
    canvas.drawCircle(Offset(cx, cy), size.width * 0.7, paint);
  }

  @override
  bool shouldRepaint(_BgGlowPainter old) => old.intensity != intensity;
}

// ─── Heart outline painter ────────────────────────────────────────────────────

class _HeartPainter extends CustomPainter {
  final double progress; // 0→1 path draw progress
  final double glow;     // 0→1 glow intensity

  _HeartPainter({required this.progress, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = _heart(size);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final drawn = metrics.first.extractPath(0, metrics.first.length * progress);

    // Outer glow — wide soft
    if (glow > 0) {
      canvas.drawPath(
        drawn,
        Paint()
          ..color = kRose.withAlpha((55 * glow).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18),
      );
      // Inner glow — tighter
      canvas.drawPath(
        drawn,
        Paint()
          ..color = kRose.withAlpha((90 * glow).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Crisp stroke
    canvas.drawPath(
      drawn,
      Paint()
        ..color = kRose.withAlpha(220)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Clean symmetric heart path — single continuous stroke, start = bottom tip.
  Path _heart(Size s) {
    final w = s.width;
    final h = s.height;
    // Visual centre sits slightly above geometric centre
    final cx = w * 0.5;
    final cy = h * 0.50;

    // Key anchor points (normalised to canvas size)
    final tip   = Offset(cx,          cy + h * 0.39);   // bottom tip
    final notch = Offset(cx,          cy - h * 0.10);   // top centre indent
    final lTop  = Offset(cx - w * 0.26, cy - h * 0.39); // left lobe peak
    final rTop  = Offset(cx + w * 0.26, cy - h * 0.39); // right lobe peak
    final lMid  = Offset(cx - w * 0.46, cy - h * 0.05); // left widest point
    final rMid  = Offset(cx + w * 0.46, cy - h * 0.05); // right widest point

    final p = Path()..moveTo(tip.dx, tip.dy);

    // tip → lMid (lower-left curve)
    p.cubicTo(
      cx - w * 0.26, cy + h * 0.28,
      lMid.dx - w * 0.02, cy + h * 0.12,
      lMid.dx, lMid.dy,
    );
    // lMid → lTop (left lobe up)
    p.cubicTo(
      lMid.dx + w * 0.01, cy - h * 0.24,
      lTop.dx - w * 0.10, lTop.dy - h * 0.06,
      lTop.dx, lTop.dy,
    );
    // lTop → notch (left lobe → centre indent)
    p.cubicTo(
      lTop.dx + w * 0.12, lTop.dy + h * 0.04,
      notch.dx - w * 0.14, notch.dy - h * 0.08,
      notch.dx, notch.dy,
    );
    // notch → rTop (centre → right lobe)
    p.cubicTo(
      notch.dx + w * 0.14, notch.dy - h * 0.08,
      rTop.dx - w * 0.12, rTop.dy + h * 0.04,
      rTop.dx, rTop.dy,
    );
    // rTop → rMid (right lobe down)
    p.cubicTo(
      rTop.dx + w * 0.10, rTop.dy - h * 0.06,
      rMid.dx - w * 0.01, cy - h * 0.24,
      rMid.dx, rMid.dy,
    );
    // rMid → tip (lower-right curve)
    p.cubicTo(
      rMid.dx + w * 0.02, cy + h * 0.12,
      cx + w * 0.26, cy + h * 0.28,
      tip.dx, tip.dy,
    );

    return p;
  }

  @override
  bool shouldRepaint(_HeartPainter old) =>
      old.progress != progress || old.glow != glow;
}
