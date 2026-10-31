import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Sound effects: the countdown, catches, misses, combo milestones, the fever
/// riff, the closing seconds and the verdict. Calls are queued so platform
/// messages never overlap, and a missing audio device never blocks the game.
class GameAudio {
  /// Good catches climb a scale for this many combo steps, then hold.
  static const catchSteps = 8, milestoneSounds = 4;
  static const _fever = 'audio/fever_loop.wav';

  static List<String> get files => [
    'audio/countdown_tick.wav',
    'audio/countdown_go.wav',
    for (var i = 1; i <= catchSteps; i++) 'audio/catch_$i.wav',
    'audio/catch_bad.wav',
    for (var i = 1; i <= milestoneSounds; i++) 'audio/combo_$i.wav',
    'audio/result_pass.wav',
    'audio/result_fail.wav',
    'audio/cheer.wav',
    'audio/score_tick.wav',
    'audio/miss.wav',
    'audio/hurry.wav',
    'audio/firework.wav',
    _fever,
  ];

  // One low-latency player per sound keeps it loaded; replaying restarts it.
  final _players = <String, AudioPlayer>{};
  Future<void> _pending = Future.value();
  bool enabled = true, _disposed = false, _feverOn = false;

  void _queue(Future<void> Function() action) {
    if (!enabled || _disposed) return;
    _pending = _pending
        .then((_) async {
          if (!_disposed) await action();
        })
        .catchError((Object _) {});
  }

  Future<AudioPlayer> _player(String file) async {
    var player = _players[file];
    if (player == null) {
      player = AudioPlayer();
      _players[file] = player;
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(
        file == _fever ? ReleaseMode.loop : ReleaseMode.stop,
      );
    }
    return player;
  }

  void _play(String file, {double volume = 1}) => _queue(() async {
    final player = await _player(file);
    await player.stop();
    await player.play(
      AssetSource(file),
      mode: PlayerMode.lowLatency,
      volume: volume,
    );
  });

  /// Copies the assets into the platform cache and creates the players, so
  /// the first catch of a round is not late.
  void warm() => _queue(() async {
    for (final file in files) {
      await AudioCache.instance.load(file);
      await _player(file);
    }
  });

  /// One of the "3, 2, 1" counts.
  void tick() => _play('audio/countdown_tick.wav');

  /// The round starts.
  void go() => _play('audio/countdown_go.wav');

  /// A good catch; the note rises with [combo] up to [catchSteps].
  void catchGood(int combo) =>
      _play('audio/catch_${combo.clamp(1, catchSteps)}.wav');

  /// A bad catch.
  void catchBad() => _play('audio/catch_bad.wav');

  /// A good drop landed uncaught.
  void miss() => _play('audio/miss.wav', volume: .7);

  /// A combo milestone; [tier] counts from 1.
  void milestone(int tier) =>
      _play('audio/combo_${tier.clamp(1, milestoneSounds)}.wav');

  /// Pop and crackle for the sky bursts of a milestone.
  void firework() => _play('audio/firework.wav', volume: .8);

  /// One of the last five seconds.
  void hurry() => _play('audio/hurry.wav');

  /// Loops the fever riff until [stopFever].
  void startFever() {
    if (_feverOn) return;
    _feverOn = true;
    _queue(() async {
      final player = await _player(_fever);
      await player.stop();
      await player.play(
        AssetSource(_fever),
        mode: PlayerMode.lowLatency,
        volume: .5,
      );
    });
  }

  void stopFever() {
    if (!_feverOn) return;
    _feverOn = false;
    _queue(() async => (await _player(_fever)).stop());
  }

  /// Ten more points on the result dialog.
  void countTick() => _play('audio/score_tick.wav', volume: .6);

  /// The verdict, when the result dialog stamps it.
  void verdict({required bool passed}) =>
      _play(passed ? 'audio/result_pass.wav' : 'audio/result_fail.wav');

  /// The crowd, under the pass fanfare.
  void cheer() => _play('audio/cheer.wav', volume: .8);

  void dispose() {
    _disposed = true;
    unawaited(
      _pending.whenComplete(() async {
        for (final player in _players.values) {
          await player.dispose();
        }
      }),
    );
  }
}
