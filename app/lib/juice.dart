import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'app_style.dart';
import 'catch_game.dart';
import 'confetti.dart';
import 'l10n.dart';

/// Colors that climb with the combo tier (0..4): ink, gold, orange, pink,
/// then the brand gradient for the top tier.
LinearGradient tierGradient(int tier) => switch (tier) {
  <= 0 => const LinearGradient(colors: [brandInk, brandInk]),
  1 => const LinearGradient(colors: [Color(0xffffc233), Color(0xffff9a1f)]),
  2 => const LinearGradient(colors: [Color(0xffff8a1f), Color(0xffff4b2e)]),
  3 => const LinearGradient(colors: [Color(0xffff4d8d), Color(0xffb13cff)]),
  _ => brandGradient,
};
Color tierColor(int tier) => tierGradient(tier).colors.first;
const badGradient = LinearGradient(
  colors: [Color(0xffff6a5c), Color(0xffb63c32)],
);
const missGradient = LinearGradient(
  colors: [Color(0xffa7b4bd), Color(0xff5d6b76)],
);

/// Four hues a quarter turn apart, rotated by [phase] turns.
LinearGradient rainbow(double phase) => LinearGradient(
  colors: [
    for (var i = 0; i < 4; i++)
      HSVColor.fromAHSV(1, ((phase + i / 4) % 1) * 360, .85, 1).toColor(),
  ],
);

/// White outline under a gradient fill, like the countdown numbers.
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    required this.size,
    this.gradient = brandGradient,
    this.weight = FontWeight.w900,
  });
  final String text;
  final double size;
  final LinearGradient gradient;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: size, fontWeight: weight, height: 1.1);
    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size / 9
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white,
            shadows: [
              Shadow(blurRadius: size / 10, color: const Color(0x66000000)),
            ],
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: gradient.createShader,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: style.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Scales its child from [from] back to 1 whenever [trigger] changes, and
/// once when it first appears unless [onMount] is false.
class Punch extends StatefulWidget {
  const Punch({
    super.key,
    required this.trigger,
    required this.child,
    this.from = 1.3,
    this.duration = const Duration(milliseconds: 280),
    this.onMount = true,
  });
  final Object? trigger;
  final Widget child;
  final double from;
  final Duration duration;
  final bool onMount;

  @override
  State<Punch> createState() => _PunchState();
}

class _PunchState extends State<Punch> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.onMount) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(Punch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => Transform.scale(
      scale:
          widget.from +
          (1 - widget.from) * Curves.easeOutBack.transform(_controller.value),
      child: child,
    ),
  );
}

/// A number that rolls to each new [value] instead of jumping.
class RollingNumber extends StatelessWidget {
  const RollingNumber(
    this.value, {
    super.key,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 380),
  });
  final int value;
  final String Function(int) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.toDouble()),
    duration: duration,
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => Text(format(v.round()), style: style),
  );
}

/// Full-screen tint that flashes in and fades out when [trigger] changes.
/// Nothing on first build, so a fresh round does not start with a flash.
class FlashOnTrigger extends StatefulWidget {
  const FlashOnTrigger({
    super.key,
    required this.trigger,
    required this.color,
    this.alpha = .5,
    this.duration = const Duration(milliseconds: 300),
  });
  final Object? trigger;
  final Color color;
  final double alpha;
  final Duration duration;

  @override
  State<FlashOnTrigger> createState() => _FlashOnTriggerState();
}

class _FlashOnTriggerState extends State<FlashOnTrigger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didUpdateWidget(FlashOnTrigger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      if (!_controller.isAnimating) return const SizedBox.shrink();
      final fade = 1 - Curves.easeOutQuad.transform(_controller.value);
      return IgnorePointer(
        child: ColoredBox(
          color: widget.color.withValues(alpha: widget.alpha * fade),
          child: const SizedBox.expand(),
        ),
      );
    },
  );
}

/// Whole-screen flash on a catch: red for a bad one, gold for a good one and
/// mint once the combo is in fever. Ignores pointers so tilt and swipes still
/// land on the scene underneath.
class CatchFlash extends StatefulWidget {
  const CatchFlash({
    super.key,
    required this.eventId,
    required this.bad,
    required this.fever,
  });
  final int eventId;
  final bool bad, fever;

  @override
  State<CatchFlash> createState() => _CatchFlashState();
}

class _CatchFlashState extends State<CatchFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  bool _bad = false, _fever = false;

  @override
  void didUpdateWidget(CatchFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eventId != oldWidget.eventId) {
      _bad = widget.bad;
      _fever = widget.fever;
      _controller
        ..duration = Duration(milliseconds: _bad ? 200 : 300)
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_controller.isAnimating) return const SizedBox.shrink();
        final fade = 1 - _controller.value;
        final color = _bad
            ? const Color(0xffb63c32)
            : _fever
            ? brandMint
            : const Color(0xffffc233);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: (_bad ? .3 : .22) * fade),
                color.withValues(alpha: (_bad ? .7 : .55) * fade),
              ],
              stops: const [.3, 1],
            ),
          ),
        );
      },
    );
  }
}

enum PopupKind { good, bad, miss }

class CatchPopup {
  CatchPopup({
    required this.worldX,
    required this.kind,
    required this.index,
    required this.points,
    required this.combo,
    required this.lostCombo,
    required this.tier,
    required this.start,
  });
  final double worldX;
  final PopupKind kind;
  final int index, combo, lostCombo, tier;
  final int? points;
  final Duration start;
}

/// A shout, the points and the combo rising from where a drop landed: bigger
/// and warmer with the combo tier, red for a bad catch, grey for a miss.
/// [project] maps a world point to the view, so the text sits over the
/// landing spot whatever the camera does.
class CatchPopups extends StatefulWidget {
  const CatchPopups({
    super.key,
    required this.eventId,
    required this.missId,
    required this.game,
    required this.project,
  });
  final int eventId, missId;
  final CatchGame game;
  final Offset? Function(vm.Vector3 world) project;

  @override
  State<CatchPopups> createState() => _CatchPopupsState();
}

class _CatchPopupsState extends State<CatchPopups>
    with SingleTickerProviderStateMixin {
  static const life = Duration(milliseconds: 1100);
  late final Ticker _ticker = createTicker(_onTick);
  final _popups = <CatchPopup>[];
  Duration _now = Duration.zero;

  void _onTick(Duration elapsed) {
    _now = elapsed;
    _popups.removeWhere((p) => elapsed - p.start > life);
    if (_popups.isEmpty) _ticker.stop();
    setState(() {});
  }

  void _add(double x, PopupKind kind, int index) {
    // The ticker's clock restarts with it, so an idle restart begins at zero.
    if (!_ticker.isActive) {
      _now = Duration.zero;
      _ticker.start();
    }
    final g = widget.game;
    _popups.add(
      CatchPopup(
        worldX: x,
        kind: kind,
        index: index,
        points: kind == PopupKind.miss ? null : g.messagePoints,
        combo: g.combo,
        lostCombo: g.lostCombo,
        tier: kind == PopupKind.good ? g.comboTier : 0,
        start: _now,
      ),
    );
  }

  @override
  void didUpdateWidget(CatchPopups oldWidget) {
    super.didUpdateWidget(oldWidget);
    final g = widget.game, x = g.fxX, mx = g.missX;
    if (widget.eventId != oldWidget.eventId && x != null) {
      _add(x, g.fxBad ? PopupKind.bad : PopupKind.good, widget.eventId);
    }
    if (widget.missId != oldWidget.missId && mx != null) {
      _add(mx, PopupKind.miss, widget.missId);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  List<Widget> _lines(Strings t, CatchPopup p) => switch (p.kind) {
    PopupKind.good => [
      OutlinedText(
        t.hype(p.index),
        size: 30 + 6.0 * p.tier,
        gradient: tierGradient(math.max(1, p.tier)),
      ),
      if (p.points != null)
        OutlinedText(
          '+${p.points}',
          size: 40 + 6.0 * p.tier,
          gradient: tierGradient(math.max(1, p.tier)),
        ),
      if (p.combo >= 2)
        OutlinedText(
          '×${p.combo} ${t.combo}',
          size: 18,
          gradient: tierGradient(math.max(1, p.tier)),
          weight: FontWeight.w800,
        ),
    ],
    PopupKind.bad => [
      OutlinedText(t.boo(p.index), size: 32, gradient: badGradient),
      if (p.points != null)
        OutlinedText('−${p.points}', size: 40, gradient: badGradient),
      if (p.lostCombo >= 2)
        OutlinedText(
          t.comboLost(p.lostCombo),
          size: 18,
          gradient: badGradient,
          weight: FontWeight.w800,
        ),
    ],
    PopupKind.miss => [
      OutlinedText(t.miss, size: 34, gradient: missGradient),
      if (p.lostCombo >= 2)
        OutlinedText(
          t.comboLost(p.lostCombo),
          size: 18,
          gradient: missGradient,
          weight: FontWeight.w800,
        ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final children = <Widget>[];
    for (final p in _popups) {
      final age = ((_now - p.start).inMicroseconds / life.inMicroseconds).clamp(
        0.0,
        1.0,
      );
      final at = widget.project(vm.Vector3(p.worldX, catchHeight + .6, 0));
      if (at == null) continue;
      final pop = Curves.easeOutBack.transform(math.min(1, age / .25));
      final rise = 96 * Curves.easeOutCubic.transform(age);
      final opacity = age < .7 ? 1.0 : (1 - (age - .7) / .3).clamp(0.0, 1.0);
      final tilt = (p.index.isEven ? 1 : -1) * .12 * (1 - age);
      children.add(
        Positioned(
          left: at.dx - 160,
          top: at.dy - rise - 70,
          width: 320,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: tilt,
              child: Transform.scale(
                scale: pop,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _lines(t, p),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return IgnorePointer(
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }
}

/// The combo, huge and in the middle of the screen: it grows with the count,
/// punches on every catch, and in fever cycles through the rainbow, wobbles
/// and wears a FEVER banner with flames.
class ComboCounter extends StatefulWidget {
  const ComboCounter({
    super.key,
    required this.combo,
    required this.label,
    required this.fever,
    required this.feverLabel,
  });
  final int combo;
  final String label, feverLabel;
  final bool fever;

  @override
  State<ComboCounter> createState() => _ComboCounterState();
}

class _ComboCounterState extends State<ComboCounter>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(
    (elapsed) => setState(() => _t = elapsed.inMicroseconds / 1e6),
  );
  double _t = 0;

  void _sync() {
    if (widget.fever && !_ticker.isActive) _ticker.start();
    if (!widget.fever && _ticker.isActive) _ticker.stop();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ComboCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = CatchGame.tierOf(widget.combo);
    final gradient = widget.fever
        ? rainbow(_t * .6)
        : tierGradient(math.max(1, tier));
    final size = math.min(110.0, 48 + 5.0 * widget.combo);
    final wobble = widget.fever ? math.sin(_t * 9) * .06 : 0.0;
    final pulse = widget.fever ? 1 + .06 * math.sin(_t * 12) : 1.0;
    return IgnorePointer(
      child: Punch(
        trigger: widget.combo,
        from: 1.5,
        child: Transform.rotate(
          angle: wobble,
          child: Transform.scale(
            scale: pulse,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.fever)
                      Text('🔥', style: TextStyle(fontSize: size * .5)),
                    OutlinedText(
                      '×${widget.combo}',
                      size: size,
                      gradient: gradient,
                    ),
                    if (widget.fever)
                      Text('🔥', style: TextStyle(fontSize: size * .5)),
                  ],
                ),
                OutlinedText(
                  widget.label,
                  size: 22,
                  gradient: gradient,
                  weight: FontWeight.w800,
                ),
                if (widget.fever)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: rainbow(_t * .9),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x88ff8a1f), blurRadius: 18),
                      ],
                    ),
                    child: Text(
                      widget.feverLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Manga speed lines radiating from the middle of the screen: on while the
/// combo is in fever, and a bright burst whenever [trigger] changes.
class SpeedLines extends StatefulWidget {
  const SpeedLines({super.key, required this.active, required this.trigger});
  final bool active;
  final int trigger;

  @override
  State<SpeedLines> createState() => _SpeedLinesState();
}

class _SpeedLinesState extends State<SpeedLines>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  double _t = 0, _burst = 0;
  Duration _last = Duration.zero;

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _t += dt;
    _burst = math.max(0, _burst - dt * 1.6);
    if (!widget.active && _burst <= 0) _ticker.stop();
    setState(() {});
  }

  void _run() {
    if (_ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) _run();
  }

  @override
  void didUpdateWidget(SpeedLines oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _burst = 1;
    if (widget.active || _burst > 0) _run();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active && _burst <= 0) return const SizedBox.shrink();
    final base = widget.active ? .14 + .07 * math.sin(_t * 10) : 0.0;
    return IgnorePointer(
      child: CustomPaint(
        painter: _SpeedLinesPainter(
          t: _t,
          alpha: (base + .4 * _burst).clamp(0.0, 1.0),
          color: widget.active ? const Color(0xffffd54a) : Colors.white,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SpeedLinesPainter extends CustomPainter {
  _SpeedLinesPainter({
    required this.t,
    required this.alpha,
    required this.color,
  });
  final double t, alpha;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final reach = size.longestSide;
    final paint = Paint()..strokeCap = StrokeCap.round;
    const n = 72;
    for (var i = 0; i < n; i++) {
      final angle =
          i / n * 2 * math.pi + t * .35 + math.sin(i * 12.9 + t * 7) * .02;
      final inner = size.shortestSide * .24 + 28 * math.sin(t * 6 + i);
      paint
        ..color = color.withValues(alpha: alpha * (.5 + .5 * ((i * 7) % 5) / 4))
        ..strokeWidth = 2 + 3 * ((i * 3) % 4) / 3;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * reach,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpeedLinesPainter old) =>
      old.t != t || old.alpha != alpha || old.color != color;
}

/// Red edges throbbing twice a second through the last seconds of a round.
class HurryVignette extends StatefulWidget {
  const HurryVignette({super.key, required this.active});
  final bool active;

  @override
  State<HurryVignette> createState() => _HurryVignetteState();
}

class _HurryVignetteState extends State<HurryVignette>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(
    (elapsed) => setState(() => _t = elapsed.inMicroseconds / 1e6),
  );
  double _t = 0;

  void _sync() {
    if (widget.active && !_ticker.isActive) _ticker.start();
    if (!widget.active && _ticker.isActive) _ticker.stop();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(HurryVignette oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    final throb = .5 + .5 * math.sin(_t * 2 * math.pi * 2);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              const Color(0x00b63c32),
              const Color(0xffb63c32).withValues(alpha: .25 + .35 * throb),
            ],
            stops: const [.5, 1],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Fires a [ConfettiBurst] every time [trigger] changes; bursts overlap.
class ConfettiOnTrigger extends StatefulWidget {
  const ConfettiOnTrigger({super.key, required this.trigger, this.seed = 1});
  final int trigger, seed;

  @override
  State<ConfettiOnTrigger> createState() => _ConfettiOnTriggerState();
}

class _ConfettiOnTriggerState extends State<ConfettiOnTrigger> {
  final _active = <int>[];

  @override
  void didUpdateWidget(ConfettiOnTrigger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _active.add(widget.trigger);
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: [
        for (final id in _active)
          ConfettiBurst(
            key: ValueKey(id),
            seed: widget.seed + id,
            onDone: () => setState(() => _active.remove(id)),
          ),
      ],
    ),
  );
}

/// Big "5 COMBO!" with a cheer under it, popping in above the beam whenever
/// [trigger] changes, shivering, and drifting away on its own.
class MilestoneCallout extends StatefulWidget {
  const MilestoneCallout({
    super.key,
    required this.trigger,
    required this.title,
    required this.cheer,
    required this.tier,
  });
  final int trigger, tier;
  final String title, cheer;

  @override
  State<MilestoneCallout> createState() => _MilestoneCalloutState();
}

class _MilestoneCalloutState extends State<MilestoneCallout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
    value: 1,
  );

  @override
  void didUpdateWidget(MilestoneCallout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      if (!_controller.isAnimating) return const SizedBox.shrink();
      final v = _controller.value;
      final pop = Curves.easeOutBack.transform(math.min(1, v / .2));
      final fade = v < .75 ? 1.0 : (1 - (v - .75) / .25).clamp(0.0, 1.0);
      final shiver = math.sin(v * 60) * .05 * (1 - v);
      final gradient = tierGradient(widget.tier);
      return IgnorePointer(
        child: Align(
          alignment: const Alignment(0, -.1),
          child: Transform.translate(
            offset: Offset(0, -40 * v),
            child: Opacity(
              opacity: fade,
              child: Transform.rotate(
                angle: shiver,
                child: Transform.scale(
                  scale: pop,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedText(widget.title, size: 76, gradient: gradient),
                      OutlinedText(
                        widget.cheer,
                        size: 30,
                        gradient: gradient,
                        weight: FontWeight.w800,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
