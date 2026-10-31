import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_style.dart';

/// A one-shot shower of brand-colored confetti over the whole view, for a
/// passed exam. Calls [onDone] when every piece has fallen out.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    required this.onDone,
    this.seed = 7,
    this.duration = const Duration(milliseconds: 2600),
  });
  final VoidCallback onDone;
  final int seed;
  final Duration duration;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final r = math.Random(widget.seed);
    _pieces = List.generate(150, (_) => _Piece.random(r));
    _controller
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _ConfettiPainter(
          _pieces,
          progress: _controller.value,
          seconds: widget.duration.inMilliseconds / 1000,
        ),
        size: Size.infinite,
      ),
    ),
  );
}

class _Piece {
  _Piece({
    required this.x0,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.angle,
    required this.flip,
    required this.width,
    required this.height,
    required this.color,
  });

  /// Positions and speeds are fractions of the view, per second.
  final double x0, vx, vy, spin, angle, flip, width, height;
  final Color color;

  static const colors = [
    brandMint,
    brandBlue,
    Color(0xffffc233),
    Color(0xffff6a8e),
    Colors.white,
  ];

  factory _Piece.random(math.Random r) => _Piece(
    x0: .5 + (r.nextDouble() - .5) * .8,
    vx: (r.nextDouble() - .5) * .9,
    vy: .05 + r.nextDouble() * .35,
    spin: (r.nextDouble() - .5) * 14,
    angle: r.nextDouble() * math.pi,
    flip: 4 + r.nextDouble() * 8,
    width: 7 + r.nextDouble() * 6,
    height: 4 + r.nextDouble() * 4,
    color: colors[r.nextInt(colors.length)],
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(
    this.pieces, {
    required this.progress,
    required this.seconds,
  });
  final List<_Piece> pieces;
  final double progress, seconds;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * seconds;
    final paint = Paint();
    final fade = progress < .8 ? 1.0 : (1 - (progress - .8) / .2);
    for (final p in pieces) {
      // Sideways drift dies out; gravity takes over.
      final x = (p.x0 + p.vx * (1 - math.exp(-2 * t)) / 2) * size.width;
      final y = (-.04 + p.vy * t + .22 * t * t) * size.height;
      if (y > size.height + 20) continue;
      paint.color = p.color.withValues(alpha: fade);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.angle + p.spin * t)
        ..scale(1, math.cos(p.flip * t))
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.width,
            height: p.height,
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

/// A few seconds of fireworks across the whole view, for a passed exam.
/// Calls [onDone] when the last spark has faded.
class FireworksOverlay extends StatefulWidget {
  const FireworksOverlay({
    super.key,
    required this.onDone,
    this.seed = 11,
    this.duration = const Duration(milliseconds: 3200),
  });
  final VoidCallback onDone;
  final int seed;
  final Duration duration;

  @override
  State<FireworksOverlay> createState() => _FireworksOverlayState();
}

class _FireworksOverlayState extends State<FireworksOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final List<_Rocket> _rockets;

  @override
  void initState() {
    super.initState();
    final r = math.Random(widget.seed);
    _rockets = List.generate(8, (i) => _Rocket.random(r, i * .22));
    _controller
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _FireworksPainter(
          _rockets,
          seconds: _controller.value * widget.duration.inMilliseconds / 1000,
        ),
        size: Size.infinite,
      ),
    ),
  );
}

class _Rocket {
  _Rocket({
    required this.start,
    required this.x,
    required this.y,
    required this.color,
    required this.angles,
    required this.speeds,
  });

  /// Burst time in seconds, center as fractions of the view, spark headings
  /// and speeds as fractions of the shorter side per second.
  final double start, x, y;
  final Color color;
  final List<double> angles, speeds;

  static const colors = [
    brandMint,
    brandBlue,
    Color(0xffffc233),
    Color(0xffff6a8e),
    Color(0xffb13cff),
    Colors.white,
  ];

  factory _Rocket.random(math.Random r, double start) => _Rocket(
    start: start + r.nextDouble() * .15,
    x: .12 + r.nextDouble() * .76,
    y: .12 + r.nextDouble() * .45,
    color: colors[r.nextInt(colors.length)],
    angles: List.generate(
      36,
      (i) => i / 36 * 2 * math.pi + r.nextDouble() * .1,
    ),
    speeds: List.generate(36, (_) => .22 + r.nextDouble() * .24),
  );
}

class _FireworksPainter extends CustomPainter {
  _FireworksPainter(this.rockets, {required this.seconds});
  final List<_Rocket> rockets;
  final double seconds;
  static const life = 1.3;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    for (final rocket in rockets) {
      final t = seconds - rocket.start;
      if (t < 0 || t > life) continue;
      final center = Offset(rocket.x * size.width, rocket.y * size.height);
      final fade = (1 - t / life).clamp(0.0, 1.0);
      if (t < .12) {
        canvas.drawCircle(
          center,
          unit * .08 * (1 - t / .12),
          Paint()..color = Colors.white.withValues(alpha: .8),
        );
      }
      paint.color = rocket.color.withValues(alpha: fade);
      for (var i = 0; i < rocket.angles.length; i++) {
        // Drag slows each spark; gravity bends its tail down.
        Offset at(double t) {
          final d = unit * rocket.speeds[i] * (1 - math.exp(-2.2 * t)) / 2.2;
          return center +
              Offset(math.cos(rocket.angles[i]), math.sin(rocket.angles[i])) *
                  d +
              Offset(0, unit * .35 * t * t);
        }

        canvas.drawLine(at(math.max(0, t - .07)), at(t), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_FireworksPainter old) => old.seconds != seconds;
}

/// A tint that swells over the whole view and drains away; for the gloom of
/// a failed exam. Calls [onDone] at the end.
class TintBurst extends StatefulWidget {
  const TintBurst({
    super.key,
    required this.onDone,
    required this.color,
    this.alpha = .45,
    this.duration = const Duration(milliseconds: 1600),
  });
  final VoidCallback onDone;
  final Color color;
  final double alpha;
  final Duration duration;

  @override
  State<TintBurst> createState() => _TintBurstState();
}

class _TintBurstState extends State<TintBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _controller
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final v = _controller.value;
        final level = v < .2
            ? v / .2
            : v < .5
            ? 1.0
            : 1 - (v - .5) / .5;
        return ColoredBox(
          color: widget.color.withValues(alpha: widget.alpha * level),
          child: const SizedBox.expand(),
        );
      },
    ),
  );
}
