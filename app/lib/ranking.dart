import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_style.dart';
import 'catch_game.dart' show CatchGame;
import 'character.dart';
import 'juice.dart';
import 'l10n.dart';
import 'records.dart';

/// Pass/fail stamp for a 100-point score.
class VerdictBadge extends StatelessWidget {
  const VerdictBadge({super.key, required this.score, this.small = false});
  final int score;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final passed = score >= CatchGame.passScore;
    return Container(
      key: ValueKey(passed ? 'verdict_passed' : 'verdict_failed'),
      padding: EdgeInsets.symmetric(
        horizontal: small ? 7 : 14,
        vertical: small ? 1 : 4,
      ),
      decoration: BoxDecoration(
        gradient: passed ? brandGradient : null,
        color: passed ? null : const Color(0xffeef2f4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        passed ? t.passed : t.failed,
        style: TextStyle(
          fontSize: small ? 11 : 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: passed ? Colors.white : brandMuted,
        ),
      ),
    );
  }
}

/// Shown once when a scored round ends. The dialog bounces in, the score
/// rolls up from zero with a click every ten points ([onCount]), the verdict
/// stamps in ([onVerdict] fires then, for sound and confetti), the rank
/// letter follows, and the ribbons for a perfect round or a new best blink.
/// The round is already in the history; the nickname entry opens only when
/// the player chooses to record it.
class ResultDialog extends StatefulWidget {
  const ResultDialog({
    super.key,
    required this.record,
    this.onRecord,
    this.isBest = false,
    this.onVerdict,
    this.onCount,
  });
  final GameRecord record;

  /// Asks for a nickname; returns the named record, or null if cancelled.
  /// Null for a TAS round, which is not recorded.
  final Future<GameRecord?> Function()? onRecord;

  /// The score beat every earlier round of this character on the device.
  final bool isBest;

  /// Called once, the moment the verdict appears.
  final void Function(bool passed)? onVerdict;

  /// Called every ten points while the score counts up.
  final VoidCallback? onCount;

  /// Rank letter for a 100-point score: S for a perfect round, then A to D.
  static String grade(int score) => score >= 100
      ? 'S'
      : score >= 90
      ? 'A'
      : score >= CatchGame.passScore
      ? 'B'
      : score >= 60
      ? 'C'
      : 'D';

  static LinearGradient gradeGradient(String grade) => switch (grade) {
    'S' => brandGradient,
    'A' => tierGradient(1),
    'B' => tierGradient(2),
    _ => const LinearGradient(colors: [brandMuted, brandMuted]),
  };

  @override
  State<ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<ResultDialog>
    with SingleTickerProviderStateMixin {
  /// Fractions of the controller: bounce-in, count-up, stamp, rank, ribbons,
  /// then the ribbons blink to the end.
  static const popEnd = .08,
      countEnd = .3,
      stampEnd = .4,
      rankEnd = .5,
      ribbonEnd = .58;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  bool _stamped = false;
  int _lastTens = 0;

  bool get passed => widget.record.score >= CatchGame.passScore;
  bool get perfect => widget.record.score >= 100;

  /// The score while it counts up; the real one from [countEnd] on.
  int get shownScore =>
      (widget.record.score *
              Curves.easeOutCubic.transform(
                (_controller.value / countEnd).clamp(0.0, 1.0),
              ))
          .round();

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_tick)
      ..forward();
  }

  void _tick() {
    // A click every ten points while counting, like a meter filling up.
    final tens = shownScore ~/ 10;
    if (tens != _lastTens) {
      _lastTens = tens;
      HapticFeedback.selectionClick();
      widget.onCount?.call();
    }
    if (!_stamped && _controller.value >= countEnd) {
      _stamped = true;
      widget.onVerdict?.call(passed);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget ribbon(String text, double scale, double blink) => Opacity(
    opacity: blink,
    child: Transform.scale(
      scale: scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xffffc233), Color(0xffff7a1f)],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffffc233).withValues(alpha: .45),
              blurRadius: 12,
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final record = widget.record;
    final grade = ResultDialog.grade(record.score);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final v = _controller.value;
        double phase(double from, double to) => Curves.easeOutBack.transform(
          ((v - from) / (to - from)).clamp(0.0, 1.0),
        );
        final pop = phase(0, popEnd),
            stamp = phase(countEnd, stampEnd),
            rank = phase(stampEnd, rankEnd),
            ribbonIn = phase(rankEnd, ribbonEnd);
        final blink = v < ribbonEnd
            ? 1.0
            : .55 +
                  .45 * (.5 + .5 * math.sin((v - ribbonEnd) * 2 * math.pi * 7));
        // The score slams when the count stops, as the stamp lands.
        final slam = v < countEnd ? 1.0 : 1 + .25 * (1 - stamp);
        return Transform.scale(
          scale: pop,
          child: AlertDialog(
            key: const ValueKey('result_dialog'),
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: 12,
            ),
            contentPadding: const EdgeInsets.fromLTRB(28, 20, 28, 4),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${t.character(record.character)}  ·  ${t.difficulty(record.character)}',
                  style: const TextStyle(fontSize: 13, color: brandMuted),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lands big and tilted like a rubber stamp, then settles.
                    Transform.scale(
                      scale: stamp,
                      child: Transform.rotate(
                        angle: passed ? -.35 * (1 - stamp) - .06 : 0,
                        child: Opacity(
                          opacity: stamp.clamp(0.0, 1.0),
                          child: VerdictBadge(score: record.score),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Transform.scale(
                      scale: slam,
                      child: Text(
                        t.points(shownScore),
                        key: const ValueKey('result_score'),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    // The rank letter slams in after the verdict.
                    Transform.scale(
                      scale: rank,
                      child: Transform.rotate(
                        angle: .5 * (1 - rank),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.rank,
                              style: const TextStyle(
                                fontSize: 10,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w800,
                                color: brandMuted,
                              ),
                            ),
                            OutlinedText(
                              grade,
                              size: 54,
                              gradient: ResultDialog.gradeGradient(grade),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  t.results(record.caught, record.bad, record.missed),
                  style: const TextStyle(fontSize: 12, color: brandMuted),
                ),
                if (record.bestCombo > 1)
                  Text(
                    t.bestCombo(record.bestCombo),
                    style: const TextStyle(fontSize: 12, color: brandMuted),
                  ),
                if (perfect || widget.isBest)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (perfect) ribbon(t.perfect, ribbonIn, blink),
                        if (widget.isBest) ribbon(t.newBest, ribbonIn, blink),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  widget.onRecord == null ? t.tasNotRecorded : t.recordHint,
                  style: const TextStyle(fontSize: 12, color: brandMuted),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                key: const ValueKey('result_close'),
                onPressed: () => Navigator.pop(context),
                child: Text(t.close),
              ),
              if (widget.onRecord != null)
                FilledButton.icon(
                  key: const ValueKey('result_record'),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(t.save),
                  onPressed: () async {
                    final named = await widget.onRecord!();
                    if (named != null && context.mounted) {
                      Navigator.pop(context, named);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Nickname entry. Centered; the dialog moves into the space above the
/// keyboard on its own while typing.
class RecordDialog extends StatefulWidget {
  const RecordDialog({super.key, required this.score, required this.character});
  final int score;
  final CatchCharacter character;
  @override
  State<RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<RecordDialog> {
  final name = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void submit() {
    final text = name.text.trim();
    if (text.isNotEmpty) Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return AlertDialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.fromLTRB(40, 12, 40, 12),
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      title: Text(
        '${t.recordTitle}  ·  ${t.points(widget.score)}  ·  ${t.character(widget.character)}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 420,
        child: TextField(
          key: const ValueKey('record_name'),
          controller: name,
          // The keyboard opens on tap so the score stays visible first.
          maxLength: RecordStore.maxName,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: t.nickname),
          onSubmitted: (_) => submit(),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('record_skip'),
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        ValueListenableBuilder(
          valueListenable: name,
          builder: (context, value, _) => FilledButton(
            key: const ValueKey('record_save'),
            onPressed: value.text.trim().isEmpty ? null : submit,
            child: Text(t.save),
          ),
        ),
      ],
    );
  }
}

enum RecordsTab { ranking, history }

/// Ranking of named records per character (scores are not comparable across
/// difficulties) and the history of every round, where a missed nickname can
/// still be added.
class RecordsDialog extends StatefulWidget {
  const RecordsDialog({
    super.key,
    required this.store,
    required this.initial,
    required this.onName,
    this.highlight,
    this.tab = RecordsTab.ranking,
  });
  final RecordStore store;
  final CatchCharacter initial;
  final GameRecord? highlight;
  final RecordsTab tab;

  /// Asks for a nickname for a history entry; returns the named record.
  final Future<GameRecord?> Function(GameRecord record) onName;
  @override
  State<RecordsDialog> createState() => _RecordsDialogState();
}

class _RecordsDialogState extends State<RecordsDialog> {
  late var character = widget.initial;
  late var tab = widget.tab;
  late GameRecord? highlight = widget.highlight;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Dialog(
      key: const ValueKey('records'),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_outlined, color: brandBlue),
                  const SizedBox(width: 6),
                  Text(
                    t.records,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 14),
                  SegmentedButton<RecordsTab>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: [
                      ButtonSegment(
                        value: RecordsTab.ranking,
                        label: Text(
                          t.ranking,
                          key: const ValueKey('records_tab_ranking'),
                        ),
                      ),
                      ButtonSegment(
                        value: RecordsTab.history,
                        label: Text(
                          t.history,
                          key: const ValueKey('records_tab_history'),
                        ),
                      ),
                    ],
                    selected: {tab},
                    onSelectionChanged: (v) => setState(() => tab = v.first),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey('ranking_close'),
                    tooltip: t.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (tab == RecordsTab.ranking) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in pickerOrder)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            key: ValueKey('ranking_${c.id}'),
                            visualDensity: VisualDensity.compact,
                            labelStyle: const TextStyle(fontSize: 12),
                            label: Text(t.character(c)),
                            selected: c == character,
                            onSelected: (_) => setState(() => character = c),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Same height for both tabs so switching doesn't jump.
                SizedBox(height: 220, child: _ranking(t)),
              ] else
                SizedBox(height: 260, child: _history(t)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(Strings t) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(
      t.noRecords,
      textAlign: TextAlign.center,
      style: const TextStyle(color: brandMuted),
    ),
  );

  Widget _row(
    Strings t, {
    required GameRecord record,
    required Widget lead,
    required Widget name,
    Widget? detail,
  }) => Container(
    color: identical(record, highlight) ? brandPale : null,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    child: Row(
      children: [
        lead,
        Expanded(child: name),
        ?detail,
        const SizedBox(width: 10),
        VerdictBadge(score: record.score, small: true),
        SizedBox(
          width: 76,
          child: Text(
            t.points(record.score),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _ranking(Strings t) {
    final list = widget.store.ranking(character);
    if (list.isEmpty) return _empty(t);
    return ListView.builder(
      key: const ValueKey('ranking_list'),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final r = list[i];
        // Ties share a rank.
        final rank = list.where((o) => o.score > r.score).length + 1;
        return _row(
          t,
          record: r,
          lead: SizedBox(
            width: 40,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: rank <= 3 ? brandBlue : brandInk,
              ),
            ),
          ),
          name: Text(
            r.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }

  Widget _history(Strings t) {
    final list = widget.store.history;
    if (list.isEmpty) return _empty(t);
    String two(int n) => n.toString().padLeft(2, '0');
    return ListView.builder(
      key: const ValueKey('history_list'),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final r = list[i];
        final at = r.at;
        return _row(
          t,
          record: r,
          lead: SizedBox(
            width: 92,
            child: Text(
              '${at.month}/${at.day} ${two(at.hour)}:${two(at.minute)}',
              style: const TextStyle(
                fontSize: 12,
                color: brandMuted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          name: r.named
              ? Text(
                  r.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: ValueKey('history_name_$i'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(t.addName),
                    onPressed: () async {
                      final named = await widget.onName(r);
                      if (named != null && mounted) {
                        setState(() => highlight = named);
                      }
                    },
                  ),
                ),
          detail: Text(
            t.character(r.character),
            style: const TextStyle(fontSize: 12, color: brandMuted),
          ),
        );
      },
    );
  }
}
