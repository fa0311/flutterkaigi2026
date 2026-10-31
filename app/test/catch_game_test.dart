import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:yumemi_recruit_exam/catch_game.dart';
import 'package:yumemi_recruit_exam/character.dart';
import 'package:yumemi_recruit_exam/tilt_input.dart';

void main() {
  test('full camera orbit wraps and drops keep their own headings', () {
    final g = CatchGame();
    g.start();
    expect(g.drops.any((d) => d.facing < 0), true);
    expect(g.drops.any((d) => d.facing > 0), true);
    g.rotate(1);
    g.rotate(1);
    expect(g.targetYaw, closeTo(math.pi / 3, 1e-9));
    g.phase = Phase.playing;
    for (var i = 0; i < 60; i++) {
      g.tick(1 / 60, inputX: .5, inputY: 1);
    }
    expect(g.x, lessThan(0));
    final facings = g.drops.map((d) => d.facing).toList();
    // A full orbit has no stop and wraps back into (-pi, pi].
    for (var i = 0; i < 4; i++) {
      g.rotate(1);
    }
    expect(g.targetYaw, closeTo(math.pi, 1e-9));
    g.rotate(1);
    expect(g.targetYaw, closeTo(-5 * math.pi / 6, 1e-9));
    for (var i = 0; i < 7; i++) {
      g.rotate(1);
    }
    expect(g.targetYaw, closeTo(math.pi / 3, 1e-9));
    for (var i = 0; i < 12; i++) {
      g.rotate(-1);
    }
    expect(g.targetYaw, closeTo(math.pi / 3, 1e-9));
    expect(g.drops.map((d) => d.facing), facings);
  });
  test('lane controls follow the screen from behind the beam', () {
    final g = CatchGame();
    g.start();
    for (var i = 0; i < 6; i++) {
      g.rotate(1);
    }
    g.phase = Phase.playing;
    for (var i = 0; i < 90; i++) {
      g.tick(1 / 60, inputX: .5);
    }
    expect(g.yaw, closeTo(math.pi, .02));
    expect(g.x, greaterThan(0));
  });
  test('lane catches only on its track through a complete round', () {
    final g = CatchGame();
    g.start();
    for (var i = 0; i < 1400; i++) {
      final p = g.demoInput();
      g.tick(1 / 60, inputX: p.x, inputY: p.y);
    }
    expect(g.phase, Phase.result);
    expect(g.caught, greaterThan(5));
    expect(g.caught + g.missed, g.goodTotal);
  });
  test('camera-relative movement round trips at all camera angles', () {
    for (var i = -8; i <= 8; i++) {
      final yaw = i * math.pi / 4;
      final w = CatchGame.toWorld(.3, -.8, yaw);
      final s = CatchGame.toScreen(w.x, w.z, yaw);
      expect(s.x, closeTo(.3, 1e-10));
      expect(s.y, closeTo(-.8, 1e-10));
    }
    final w = CatchGame.toWorld(1, 0, math.pi / 2);
    expect(w.x, closeTo(0, 1e-10));
    expect(w.z, closeTo(1, 1e-10));
  });
  test('100-point score: share of good drops minus a bad-catch penalty', () {
    final g = CatchGame()..start();
    g.phase = Phase.playing;
    g
      ..goodTotal = 4
      ..drops.clear()
      ..drops.addAll([
        Drop(0, CanKind.superTry, 0, -3.1),
        Drop(1, CanKind.light, 0, -3.1),
      ]);
    g.tick(1 / 60);
    expect(g.score, 50);
    expect(g.combo, 2);
    expect(g.messagePoints, 25);
    g.tick(1 / 60);
    expect(g.score, 50);
    g.drops.add(Drop(2, CanKind.happoshu, 0, -3.1));
    g.tick(1 / 60);
    expect(g.score, 50 - g.balance['penalty'].round());
    expect(g.messagePoints, g.balance['penalty'].round());
    expect(g.combo, 0);
    expect(g.bad, 1);
    expect(g.passed, false);
    g.drops.addAll([
      Drop(3, CanKind.superTry, 0, -3.1),
      Drop(4, CanKind.superTry, 0, -3.1),
    ]);
    g.tick(1 / 60);
    // 4 of 4 caught, one bad: 100 - 10 still passes at 80.
    expect(g.score, 90);
    expect(g.passed, true);
    // The score never drops below zero.
    g.drops.addAll([
      for (var i = 5; i < 20; i++) Drop(i, CanKind.happoshu, 0, -3.1),
    ]);
    g.tick(1 / 60);
    expect(g.score, 0);
  });
  test('rounds count down from 3 and end right after the last drop', () {
    for (final c in CatchCharacter.values) {
      final g = CatchGame()
        ..selectCharacter(c)
        ..start();
      expect(g.countdown, 3);
      final last = g.drops.map((d) => d.landing).reduce(math.max);
      expect(
        g.roundEnd,
        closeTo(last + g.catchGrace + CatchGame.endBeat, 1e-9),
      );
      expect(g.roundEnd, lessThan(g.roundSeconds));
      while (g.phase != Phase.result) {
        g.tick(1 / 60);
      }
      expect(g.time, g.roundEnd);
      expect(g.caught + g.missed, g.goodTotal);
    }
    final practice = CatchGame()
      ..practice = true
      ..start();
    for (var i = 0; i < 60 * 25; i++) {
      practice.tick(1 / 60);
    }
    expect(practice.phase, Phase.playing);
  });
  test('stage limits and completed rounds stop movement', () {
    final g = CatchGame()..start();
    for (var i = 0; i < 1500; i++) {
      g.tick(1 / 60, inputX: 1, inputY: 1);
      expect(g.x.abs(), lessThanOrEqualTo(CatchGame.halfX));
    }
    expect(g.phase, Phase.result);
    final x = g.x;
    g.tick(.1, inputX: -1);
    expect(g.x, x);
  });
  test('recording controller plays full round through normal inputs', () {
    final g = CatchGame()..start();
    for (var i = 0; i < 1400; i++) {
      final input = g.demoInput();
      g.tick(1 / 60, inputX: input.x, inputY: input.y);
    }
    expect(g.phase, Phase.result);
    expect(g.caught, greaterThanOrEqualTo(6));
    expect(g.bad, greaterThanOrEqualTo(1));
    expect(g.caught + g.missed, g.goodTotal);
    expect(g.events.length, g.caught + g.bad);
  });
  test('a catch records where it landed and only a restart clears it', () {
    final g = CatchGame()..start();
    expect(g.fxX, isNull);
    g.phase = Phase.playing;
    g
      ..goodTotal = 1
      ..drops.clear()
      ..drops.add(Drop(0, CanKind.superTry, .2, -3.1));
    g.tick(1 / 60);
    expect(g.fxX, .2);
    expect(g.fxBad, false);
    expect(g.caught, 1);

    g.drops.add(Drop(1, CanKind.happoshu, -.4, -3.1));
    g.x = -.4;
    g.tick(1 / 60);
    expect(g.fxX, -.4);
    expect(g.fxBad, true);
    expect(g.bad, 1);
    expect(g.score, 100 - g.balance['penalty'].round());

    g.x = 0;
    g.drops.add(Drop(2, CanKind.light, 3, -3.1));
    // A good drop out of reach is only a miss after the grace time.
    g.tick(1 / 60);
    expect(g.missed, 0);
    g.tick(g.catchGrace);
    expect(g.missed, 1);
    expect(g.fxX, -.4);
    expect(g.eventId, 2);

    g.start();
    expect(g.fxX, isNull);
    expect(g.fxBad, false);

    final practice = CatchGame()
      ..practice = true
      ..start();
    practice.phase = Phase.playing;
    practice.drops
      ..clear()
      ..add(Drop(0, CanKind.yumemin, .1, -3.1));
    practice.tick(1 / 60);
    expect(practice.score, 0);
    expect(practice.fxX, .1);
    expect(practice.fxBad, false);
  });
  test('good drops are forgiving, bad drops are judged as drawn', () {
    final g = CatchGame()..start();
    g.phase = Phase.playing;
    final r = g.catchRadius, margin = g.balance['catchMargin'];
    expect(margin, greaterThan(0));
    expect(g.goodCatchRadius, r + margin);
    // Just outside the halo still catches a good drop, but not a bad one.
    g.drops
      ..clear()
      ..addAll([
        Drop(0, CanKind.light, r + margin / 2, -3.1),
        Drop(1, CanKind.happoshu, -(r + margin / 2), -3.1),
      ]);
    g.goodTotal = 2;
    g.tick(1 / 60);
    expect([g.caught, g.bad], [1, 0]);
    // Arriving shortly after the landing still catches it.
    g.drops.add(Drop(2, CanKind.light, 1.5, g.time - 3.1));
    g.tick(1 / 60);
    expect(g.drops.last.resolved, false);
    g.x = 1.5;
    g.tick(1 / 60);
    expect([g.caught, g.missed], [2, 0]);
    expect(g.drops.last.resolvedAt, greaterThan(g.drops.last.landing));
    // A missed drop falls from where it was judged, without a jump.
    g.drops.add(Drop(3, CanKind.light, -3, g.time - 3.1));
    for (var t = 0.0; t < g.catchGrace + .05; t += 1 / 60) {
      g.tick(1 / 60);
    }
    final d = g.drops.last;
    expect(d.caught, false);
    expect(d.height(d.resolvedAt!), closeTo(catchHeight, 1e-9));
  });
  test('sensor calibrates, rejects bad samples and expires stale data', () {
    var now = DateTime(2026);
    final t = TiltInput(now: () => now);
    t.sample(0, 0, 9.8);
    expect(t.available, true);
    expect(t.x, 0);
    now = now.add(const Duration(milliseconds: 100));
    t.sample(0, 3, 9.3);
    expect(t.x, greaterThan(0));
    t.calibrate();
    expect(t.x, 0);
    t.sample(double.nan, 0, 0);
    expect(t.gx.isFinite, true);
    now = now.add(const Duration(seconds: 1));
    expect(t.available, false);
    expect(t.x, 0);
  });

  test('combo tiers, milestones and the best combo of a round', () {
    expect(CatchGame.tierOf(0), 0);
    expect(CatchGame.tierOf(2), 0);
    expect(CatchGame.tierOf(3), 1);
    expect(CatchGame.tierOf(5), 2);
    expect(CatchGame.tierOf(8), 3);
    expect(CatchGame.tierOf(10), 4);
    expect(CatchGame.tierOf(99), 4);
    final g = CatchGame()..start();
    g.phase = Phase.playing;
    g
      ..goodTotal = 10
      ..drops.clear();
    expect(g.milestoneId, 0);
    expect(g.fever, false);
    for (var i = 0; i < 3; i++) {
      g.drops.add(Drop(i, CanKind.superTry, 0, -3.1));
    }
    g.tick(1 / 60);
    expect(g.combo, 3);
    expect(g.comboTier, 1);
    expect(g.milestoneId, 1);
    expect(g.milestoneCombo, 3);
    expect(g.bestCombo, 3);
    expect(g.fever, false);
    g.drops.addAll([
      Drop(3, CanKind.light, 0, -3.1),
      Drop(4, CanKind.superTry, 0, -3.1),
    ]);
    g.tick(1 / 60);
    expect(g.combo, 5);
    expect(g.comboTier, 2);
    expect(g.milestoneId, 2);
    expect(g.milestoneCombo, 5);
    expect(g.fever, true);
    // A bad catch ends the combo; the best of the round and the milestones
    // reached stay.
    g.drops.add(Drop(5, CanKind.happoshu, 0, -3.1));
    g.tick(1 / 60);
    expect(g.combo, 0);
    expect(g.comboTier, 0);
    expect(g.fever, false);
    expect(g.bestCombo, 5);
    expect(g.milestoneId, 2);
    expect(g.inspect()['bestCombo'], 5);
    g.start();
    expect(g.bestCombo, 0);
    expect(g.milestoneId, 0);
    expect(g.milestoneCombo, 0);

    // Practice keeps the combo at zero, so it never celebrates.
    final practice = CatchGame()
      ..practice = true
      ..start();
    practice.phase = Phase.playing;
    practice.drops.clear();
    for (var i = 0; i < 3; i++) {
      practice.drops.add(Drop(i, CanKind.yumemin, 0, -3.1));
    }
    practice.tick(1 / 60);
    expect(practice.combo, 0);
    expect(practice.milestoneId, 0);
  });

  test('a missed good drop fires a miss event and ends the combo', () {
    final g = CatchGame()..start();
    g.phase = Phase.playing;
    g
      ..goodTotal = 6
      ..drops.clear()
      ..drops.addAll([
        Drop(0, CanKind.superTry, 0, -3.1),
        Drop(1, CanKind.light, 0, -3.1),
        Drop(2, CanKind.superTry, 0, -3.1),
      ]);
    g.tick(1 / 60);
    expect(g.combo, 3);
    expect(g.missId, 0);
    g.drops.add(Drop(3, CanKind.superTry, 3, -3.1));
    // Out of reach, but a good drop is only a miss after the grace time.
    g.tick(1 / 60);
    expect(g.missId, 0);
    g.tick(g.catchGrace);
    expect(g.missId, 1);
    expect(g.missX, 3);
    expect(g.lostCombo, 3);
    expect(g.combo, 0);
    expect(g.missed, 1);
    expect(g.inspect()['missX'], 3);
    // A bad catch also records the combo it ended.
    g.drops.addAll([
      Drop(4, CanKind.light, 0, -3.1),
      Drop(5, CanKind.superTry, 0, -3.1),
    ]);
    g.tick(1 / 60);
    expect(g.combo, 2);
    g.drops.add(Drop(6, CanKind.happoshu, 0, -3.1));
    g.tick(1 / 60);
    expect(g.lostCombo, 2);
    expect(g.combo, 0);
    g.start();
    expect(g.missId, 0);
    expect(g.missX, isNull);
    expect(g.lostCombo, 0);

    // Practice shows the miss but counts nothing.
    final practice = CatchGame()
      ..practice = true
      ..start();
    practice.phase = Phase.playing;
    practice.drops
      ..clear()
      ..add(Drop(0, CanKind.yumemin, 3, -3.1));
    practice.tick(1 / 60);
    practice.tick(practice.catchGrace);
    expect(practice.missId, 1);
    expect(practice.missed, 0);
  });
  test('the closing seconds of a scored round are the hurry', () {
    final g = CatchGame()..start();
    expect(g.hurry, false);
    g.phase = Phase.playing;
    g.time = g.roundEnd - CatchGame.hurrySeconds - .5;
    expect(g.hurry, false);
    expect(g.secondsLeft, CatchGame.hurrySeconds + 1);
    g.time = g.roundEnd - 2.2;
    expect(g.hurry, true);
    expect(g.secondsLeft, 3);
    expect(g.inspect()['hurry'], true);
    final practice = CatchGame()
      ..practice = true
      ..start();
    practice.phase = Phase.playing;
    practice.time = practice.roundEnd - 1;
    expect(practice.hurry, false);
  });
}
