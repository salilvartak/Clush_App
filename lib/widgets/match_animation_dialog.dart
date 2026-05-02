import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

// ─── Confetti ─────────────────────────────────────────────────────────────────

enum _Shape { rect, circle, triangle }

class _Confetti {
  final double startX;
  final double startY;
  final double vx;
  final double vy;
  final double gravity;
  final Color color;
  final double size;
  final double initialRotation;
  final double rotSpeed;
  final _Shape shape;
  final double delay;

  const _Confetti({
    required this.startX, required this.startY,
    required this.vx, required this.vy, required this.gravity,
    required this.color, required this.size,
    required this.initialRotation, required this.rotSpeed,
    required this.shape, required this.delay,
  });
}

// Confetti palette — warm, earthy, aligned to kRose / kGold / kCream
const _colors = [
  Color(0xFFCD9D8F), // kRose
  Color(0xFFD4A99F), // kRoseLight
  Color(0xFFB87C70), // deep rose
  Color(0xFFE8B4A0), // warm peach
  Color(0xFFF3E8E3), // kRosePale
  Color(0xFFD4AF37), // kGold
  Color(0xFFE8C87A), // light gold
  Color(0xFFF0D898), // pale gold
  Color(0xFFE6DFD5), // kBone
  Color(0xFFFAF8F5), // kTan / white-warm
  Color(0xFFFFFFFF), // white
  Color(0xFFC4846C), // terracotta
];

List<_Confetti> _makeConfetti() {
  final rng = math.Random(99);
  final list = <_Confetti>[];

  // Left burst — shoot right-upward fan
  for (int i = 0; i < 45; i++) {
    final angle = math.pi * (0.05 + rng.nextDouble() * 0.45); // 9°–90°
    final speed = 0.5 + rng.nextDouble() * 0.75;
    list.add(_Confetti(
      startX:          -0.02 + rng.nextDouble() * 0.04,
      startY:          0.35 + rng.nextDouble() * 0.25,
      vx:               math.cos(angle) * speed,
      vy:              -math.sin(angle) * speed,
      gravity:          0.7 + rng.nextDouble() * 0.5,
      color:           _colors[rng.nextInt(_colors.length)],
      size:             7 + rng.nextDouble() * 9,
      initialRotation:  rng.nextDouble() * math.pi * 2,
      rotSpeed:         (rng.nextDouble() - 0.5) * 14,
      shape:           _Shape.values[rng.nextInt(_Shape.values.length)],
      delay:            rng.nextDouble() * 0.12,
    ));
  }

  // Right burst — shoot left-upward fan
  for (int i = 0; i < 45; i++) {
    final angle = math.pi * (0.05 + rng.nextDouble() * 0.45);
    final speed = 0.5 + rng.nextDouble() * 0.75;
    list.add(_Confetti(
      startX:          1.02 - rng.nextDouble() * 0.04,
      startY:          0.35 + rng.nextDouble() * 0.25,
      vx:              -math.cos(angle) * speed,
      vy:              -math.sin(angle) * speed,
      gravity:          0.7 + rng.nextDouble() * 0.5,
      color:           _colors[rng.nextInt(_colors.length)],
      size:             7 + rng.nextDouble() * 9,
      initialRotation:  rng.nextDouble() * math.pi * 2,
      rotSpeed:         (rng.nextDouble() - 0.5) * 14,
      shape:           _Shape.values[rng.nextInt(_Shape.values.length)],
      delay:            rng.nextDouble() * 0.12,
    ));
  }

  // Top-centre shower — rains down
  for (int i = 0; i < 20; i++) {
    final speed = 0.2 + rng.nextDouble() * 0.35;
    list.add(_Confetti(
      startX:          0.2 + rng.nextDouble() * 0.6,
      startY:          -0.02,
      vx:              (rng.nextDouble() - 0.5) * 0.3,
      vy:               speed,
      gravity:          0.4 + rng.nextDouble() * 0.3,
      color:           _colors[rng.nextInt(_colors.length)],
      size:             6 + rng.nextDouble() * 8,
      initialRotation:  rng.nextDouble() * math.pi * 2,
      rotSpeed:         (rng.nextDouble() - 0.5) * 10,
      shape:           _Shape.values[rng.nextInt(_Shape.values.length)],
      delay:            0.08 + rng.nextDouble() * 0.25,
    ));
  }

  return list;
}

// ─── Floating heart particles ─────────────────────────────────────────────────

class _Particle {
  final double x, size, speed, drift, delay;
  const _Particle({required this.x, required this.size, required this.speed, required this.drift, required this.delay});
}

List<_Particle> _makeParticles(int n) {
  final rng = math.Random(42);
  return List.generate(n, (_) => _Particle(
    x:     0.15 + rng.nextDouble() * 0.70,
    size:  7 + rng.nextDouble() * 10,
    speed: 0.5 + rng.nextDouble() * 0.7,
    drift: (rng.nextDouble() - 0.5) * 2,
    delay: rng.nextDouble() * 0.4,
  ));
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class _MatchPage extends StatefulWidget {
  final String myPhotoUrl, matchPhotoUrl, matchName;
  final VoidCallback onMessage;

  const _MatchPage({
    required this.myPhotoUrl, required this.matchPhotoUrl,
    required this.matchName,  required this.onMessage,
  });

  @override
  State<_MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<_MatchPage> with TickerProviderStateMixin {

  late final AnimationController _bg;
  late final AnimationController _slide;
  late final AnimationController _pulse;
  late final AnimationController _confetti;
  late final AnimationController _text;
  late final AnimationController _hearts;

  late final Animation<double> _bgOpacity;
  late final Animation<double> _slideL, _slideR;
  late final Animation<double> _avatarScale;
  late final Animation<double> _textFade;
  late final Animation<double> _btnSlide;

  final _pieces    = _makeConfetti();
  final _particles = _makeParticles(14);

  @override
  void initState() {
    super.initState();

    _bg       = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide    = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _pulse    = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _confetti = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _text     = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _hearts   = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

    _bgOpacity   = CurvedAnimation(parent: _bg,    curve: Curves.easeOut);
    _slideL      = CurvedAnimation(parent: _slide, curve: Curves.easeOutBack);
    _slideR      = CurvedAnimation(parent: _slide, curve: Curves.easeOutBack);
    _avatarScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0),  weight: 60),
    ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _textFade  = CurvedAnimation(parent: _text, curve: Curves.easeOut);
    _btnSlide  = CurvedAnimation(parent: _text, curve: Curves.easeOutCubic);

    _bg.forward().then((_) {
      _slide.forward().then((_) {
        _pulse.forward().then((_) {
          _confetti.forward().then((_) => _text.forward());
          _hearts.forward();
        });
      });
    });
  }

  @override
  void dispose() {
    _bg.dispose(); _slide.dispose(); _pulse.dispose();
    _confetti.dispose(); _text.dispose(); _hearts.dispose();
    super.dispose();
  }

  void _dismiss() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([_bg, _slide, _pulse, _confetti, _text, _hearts]),
      builder: (_, child) {
        return Material(
          // Warm cream background — matches app kTan
          color: Color.lerp(Colors.transparent, const Color(0xFFFAF8F5), _bgOpacity.value),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Soft radial blush glow ─────────────────────────────────
              Opacity(
                opacity: _bgOpacity.value,
                child: CustomPaint(size: size, painter: _GlowPainter()),
              ),

              // ── Confetti ───────────────────────────────────────────────
              CustomPaint(
                size: size,
                painter: _ConfettiPainter(pieces: _pieces, progress: _confetti.value),
              ),

              // ── Floating hearts ────────────────────────────────────────
              ..._buildHearts(size),

              // ── Main content ───────────────────────────────────────────
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    // Header
                    Opacity(
                      opacity: _textFade.value,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - _textFade.value)),
                        child: _buildHeader(),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Avatars — overlapping, user's DP on top
                    SizedBox(
                      width: 200,
                      height: 120,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // Match's DP — slides from right, sits behind
                          Positioned(
                            right: 0,
                            child: Transform.translate(
                              offset: Offset(220 * (1 - _slideR.value), 0),
                              child: Transform.scale(
                                scale: _avatarScale.value,
                                child: _Avatar(url: widget.matchPhotoUrl, ring: kRosePale),
                              ),
                            ),
                          ),
                          // User's DP — slides from left, sits on top
                          Positioned(
                            left: 0,
                            child: Transform.translate(
                              offset: Offset(-220 * (1 - _slideL.value), 0),
                              child: Transform.scale(
                                scale: _avatarScale.value,
                                child: _Avatar(url: widget.myPhotoUrl, ring: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Subtitle
                    Opacity(
                      opacity: _textFade.value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'You and ${widget.matchName} like each other',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.gabarito(
                            color: kInkMuted,
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
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
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _dismiss,
                              child: Text(
                                'Keep Discovering',
                                style: GoogleFonts.figtree(
                                  color: kInkMuted,
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
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: kRose.withAlpha(18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kRose.withAlpha(60), width: 1),
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
      const SizedBox(height: 12),
      
    ]);
  }

  List<Widget> _buildHearts(Size screen) {
    final t = _hearts.value;
    return _particles.map((p) {
      final localT = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (localT <= 0) return const SizedBox.shrink();
      final x = p.x * screen.width + p.drift * 28 * localT;
      final y = screen.height * 0.6 - localT * screen.height * 0.5 * p.speed;
      final opacity = (localT < 0.2 ? localT / 0.2 : 1 - (localT - 0.55).clamp(0.0, 1.0) / 0.45).clamp(0.0, 1.0);
      return Positioned(
        left: x - p.size / 2,
        top:  y - p.size / 2,
        child: Opacity(
          opacity: opacity * 0.6,
          child: Icon(Icons.favorite_rounded, color: kRose, size: p.size),
        ),
      );
    }).toList();
  }
}

// ─── Confetti painter ─────────────────────────────────────────────────────────

class _ConfettiPainter extends CustomPainter {
  final List<_Confetti> pieces;
  final double progress;

  const _ConfettiPainter({required this.pieces, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in pieces) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final x = (p.startX + p.vx * t) * size.width;
      final y = (p.startY + p.vy * t + 0.5 * p.gravity * t * t) * size.height;

      // Fade out last 35 %
      final alpha = (t < 0.65 ? 1.0 : 1.0 - (t - 0.65) / 0.35).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: alpha);

      final rot = p.initialRotation + p.rotSpeed * t;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);

      switch (p.shape) {
        case _Shape.rect:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.45),
              const Radius.circular(2),
            ),
            paint,
          );
        case _Shape.circle:
          canvas.drawCircle(Offset.zero, p.size * 0.42, paint);
        case _Shape.triangle:
          final h = p.size * 0.85;
          final path = Path()
            ..moveTo(0, -h / 2)
            ..lineTo(h * 0.55, h / 2)
            ..lineTo(-h * 0.55, h / 2)
            ..close();
          canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// ─── Background glow ──────────────────────────────────────────────────────────

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.42;
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.75,
      Paint()
        ..shader = RadialGradient(
          colors: [kRose.withAlpha(28), Colors.transparent],
          radius: 0.6,
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.75)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter _) => false;
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String url;
  final Color ring;
  const _Avatar({required this.url, this.ring = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 114,
      height: 114,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 4),
        boxShadow: [
          BoxShadow(color: kRose.withAlpha(70), blurRadius: 18, spreadRadius: 2),
          BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipOval(
        child: url.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: kRosePale,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kRose)),
                ),
                errorWidget: (context, url, error) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: kRosePale,
    child: const Icon(Icons.person_rounded, size: 50, color: kRose),
  );
}

// ─── Primary button ───────────────────────────────────────────────────────────

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
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4A99F), kRose, Color(0xFFB87C70)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: kRose.withAlpha(90), blurRadius: 18, offset: const Offset(0, 7)),
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
