import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yumemi_recruit_exam/catch_game.dart';
import 'package:yumemi_recruit_exam/character.dart';
import 'package:yumemi_recruit_exam/character_picker.dart';
import 'package:yumemi_recruit_exam/l10n.dart';
import 'package:yumemi_recruit_exam/ranking.dart';
import 'package:yumemi_recruit_exam/records.dart';

void main() {
  test('practice has no time limit, keeps dropping and never scores', () {
    final g = CatchGame()..practice = true;
    g.start(seed: 3);
    g.phase = Phase.playing;
    var events = 0, last = 0;
    for (var i = 0; i < 90 * 60; i++) {
      // Chase the next drop so catches (good and bad) actually happen.
      g.tick(1 / 60, inputX: g.demoInput().x);
      if (g.eventId != last) {
        last = g.eventId;
        events++;
      }
    }
    expect(g.phase, Phase.playing);
    expect(g.time, greaterThan(89));
    expect(events, greaterThan(20));
    expect(g.message, isIn([GameMessage.caught, GameMessage.bad]));
    expect(g.messagePoints, isNull);
    expect([g.score, g.combo, g.caught, g.bad, g.missed], [0, 0, 0, 0, 0]);
    expect(g.drops.where((d) => d.spawn > g.time), isNotEmpty);
    // Resolved drops are pruned so the list stays bounded.
    expect(g.drops.length, lessThan(60));
    final ids = g.drops.map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('a normal round after practice is unchanged and ends', () {
    final g = CatchGame();
    g.start(seed: 1);
    final normal = g.drops.map((d) => (d.kind, d.x, d.spawn)).toList();
    g
      ..practice = true
      ..start(seed: 1)
      ..practice = false
      ..start(seed: 1);
    expect(g.drops.map((d) => (d.kind, d.x, d.spawn)).toList(), normal);
    g.phase = Phase.playing;
    g.tick(.25);
    for (var i = 0; i < 25 * 60; i++) {
      g.tick(1 / 60);
    }
    expect(g.phase, Phase.result);
  });

  test('records persist per device and rank per character', () async {
    SharedPreferences.setMockInitialValues({});
    final store = RecordStore();
    await store.load();
    GameRecord r(String name, int score, CatchCharacter c, int minute) =>
        GameRecord(
          name: name,
          score: score,
          character: c,
          caught: 1,
          bad: 0,
          missed: 0,
          at: DateTime(2026, 10, 21, 10, minute),
        );
    await store.add(r('a', 500, CatchCharacter.sobaya, 0));
    await store.add(r('b', 900, CatchCharacter.sobaya, 1));
    await store.add(r('c', 2000, CatchCharacter.fukuchan, 2));
    final tie = r('d', 500, CatchCharacter.sobaya, 3);
    await store.add(tie);
    expect(store.ranking(CatchCharacter.sobaya).map((e) => e.name), [
      'b',
      'a',
      'd',
    ]);
    expect(store.rankOf(tie), 2);
    final reloaded = RecordStore();
    await reloaded.load();
    expect(reloaded.records.length, 4);
    expect(reloaded.ranking(CatchCharacter.fukuchan).single.name, 'c');
  });

  test(
    'unnamed rounds stay in the history until they get a nickname',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = RecordStore();
      await store.load();
      GameRecord r(String name, int score, int minute) => GameRecord(
        name: name,
        score: score,
        character: CatchCharacter.ctoOdatetsu,
        caught: 1,
        bad: 0,
        missed: 0,
        at: DateTime(2026, 10, 27, 10, minute),
      );
      final named = r('a', 70, 0), blank = r('', 95, 1);
      await store.add(named);
      await store.add(blank);
      expect(store.ranking(CatchCharacter.ctoOdatetsu), [named]);
      expect(store.history, [blank, named]);
      final renamed = await store.rename(blank, 'b');
      expect(store.ranking(CatchCharacter.ctoOdatetsu).map((e) => e.name), [
        'b',
        'a',
      ]);
      expect(store.rankOf(renamed), 1);
      expect(store.records.length, 2);
      final reloaded = RecordStore();
      await reloaded.load();
      expect(reloaded.history.map((e) => e.name), ['b', 'a']);
    },
  );

  test('the cap drops the oldest unnamed round before any named one', () async {
    SharedPreferences.setMockInitialValues({});
    final store = RecordStore();
    for (var i = 0; i < RecordStore.maxRecords; i++) {
      store.records.add(
        GameRecord(
          name: i == 0 ? '' : 'n$i',
          score: 0,
          character: CatchCharacter.sobaya,
          caught: 0,
          bad: 0,
          missed: 0,
          at: DateTime(2026, 10, 27).add(Duration(minutes: i)),
        ),
      );
    }
    final oldestBlank = store.records.first;
    await store.add(store.records.last.withName('late'));
    expect(store.records.length, RecordStore.maxRecords);
    expect(store.records.contains(oldestBlank), false);
    expect(store.records.every((r) => r.named), true);
  });

  testWidgets('picker translates into English', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: L10n(
          strings: const Strings(AppLang.en),
          child: Scaffold(
            body: CharacterPicker(
              selected: CatchCharacter.ctoOdatetsu,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('CTO Odatetsu'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    const en = Strings(AppLang.en);
    expect(en.dropDetail(CanKind.chikuwa).note, contains('fish cake'));
  });

  testWidgets('nickname dialog needs a name and returns it trimmed', (
    tester,
  ) async {
    String? result = 'unset';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showDialog<String>(
              context: context,
              builder: (_) => const RecordDialog(
                score: 1200,
                character: CatchCharacter.sobaya,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('record_save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    // No keyboard until the field is tapped.
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.byKey(const ValueKey('record_name')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(find.byKey(const ValueKey('record_name')), '  ゆめみ ');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(result, 'ゆめみ');
  });

  testWidgets('result dialog shows the score and records only on request', (
    tester,
  ) async {
    final record = GameRecord(
      name: '',
      score: 86,
      character: CatchCharacter.ctoOdatetsu,
      caught: 11,
      bad: 0,
      missed: 1,
      at: DateTime(2026, 10, 27),
    );
    var asked = 0;
    Object? result = 'unset';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showDialog<GameRecord>(
              context: context,
              builder: (_) => ResultDialog(
                record: record,
                onRecord: () async {
                  asked++;
                  return asked == 1 ? null : record.withName('ゆめみ');
                },
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('86点'), findsOneWidget);
    expect(find.text('合格'), findsOneWidget);
    expect(find.byType(RecordDialog), findsNothing);
    // A cancelled nickname keeps the result open.
    await tester.tap(find.byKey(const ValueKey('result_record')));
    await tester.pumpAndSettle();
    expect(find.byType(ResultDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('result_record')));
    await tester.pumpAndSettle();
    expect(find.byType(ResultDialog), findsNothing);
    expect((result as GameRecord).name, 'ゆめみ');
  });

  testWidgets('records open on the ranking; the history can add a name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = RecordStore();
    GameRecord r(String name, int score, int minute) => GameRecord(
      name: name,
      score: score,
      character: CatchCharacter.fukuchan,
      caught: 1,
      bad: 0,
      missed: 0,
      at: DateTime(2026, 10, 27, 10, minute),
    );
    store.records.addAll([r('a', 60, 0), r('', 100, 1)]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordsDialog(
            store: store,
            initial: CatchCharacter.fukuchan,
            onName: (record) => store.rename(record, 'b'),
          ),
        ),
      ),
    );
    expect(find.text('a'), findsOneWidget);
    expect(find.text('100点'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('records_tab_history')));
    await tester.pumpAndSettle();
    expect(find.text('100点'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history_name_0')));
    await tester.pumpAndSettle();
    expect(find.text('b'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('records_tab_ranking')));
    await tester.pumpAndSettle();
    expect(find.text('b'), findsOneWidget);
    expect(find.text('100点'), findsOneWidget);
  });

  test(
    'best score per character counts unnamed rounds; best combo is kept',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = RecordStore();
      expect(store.bestScore(CatchCharacter.sobaya), isNull);
      GameRecord record(int score, CatchCharacter c, {int bestCombo = 0}) =>
          GameRecord(
            name: '',
            score: score,
            character: c,
            caught: 0,
            bad: 0,
            missed: 0,
            bestCombo: bestCombo,
            at: DateTime(2026, 10, 30, 12, score),
          );
      await store.add(record(40, CatchCharacter.sobaya, bestCombo: 4));
      await store.add(record(75, CatchCharacter.sobaya, bestCombo: 9));
      await store.add(record(90, CatchCharacter.fukuchan));
      expect(store.bestScore(CatchCharacter.sobaya), 75);
      expect(store.bestScore(CatchCharacter.fukuchan), 90);
      expect(store.bestScore(CatchCharacter.ctoOdatetsu), isNull);
      final reloaded = RecordStore();
      await reloaded.load();
      expect(reloaded.records.map((r) => r.bestCombo), [4, 9, 0]);
      // Records saved before the combo was kept read back as 0.
      expect(
        GameRecord.fromMap(
          record(10, CatchCharacter.sobaya).toMap()..remove('bestCombo'),
        )?.bestCombo,
        0,
      );
    },
  );

  testWidgets(
    'result dialog counts up, stamps the verdict once and shows the ribbons',
    (tester) async {
      final record = GameRecord(
        name: '',
        score: 100,
        character: CatchCharacter.sobaya,
        caught: 13,
        bad: 0,
        missed: 0,
        bestCombo: 13,
        at: DateTime(2026, 10, 30),
      );
      final verdicts = <bool>[];
      var counts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ResultDialog(
                  record: record,
                  isBest: true,
                  onVerdict: verdicts.add,
                  onCount: () => counts++,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Still counting: the final score is not on screen yet.
      expect(find.text('100点'), findsNothing);
      expect(verdicts, isEmpty);
      await tester.pumpAndSettle();
      expect(find.text('100点'), findsOneWidget);
      expect(find.byKey(const ValueKey('verdict_passed')), findsOneWidget);
      expect(find.text('最大 13 コンボ'), findsOneWidget);
      expect(find.text('パーフェクト！'), findsOneWidget);
      expect(find.text('自己ベスト更新！'), findsOneWidget);
      expect(verdicts, [true]);
      // The rank letter is drawn twice: outline and fill.
      expect(find.text('S'), findsNWidgets(2));
      expect(counts, greaterThan(0));
    },
  );

  test('rank letters: S for a perfect round, then A to D', () {
    expect(ResultDialog.grade(100), 'S');
    expect(ResultDialog.grade(99), 'A');
    expect(ResultDialog.grade(90), 'A');
    expect(ResultDialog.grade(80), 'B');
    expect(ResultDialog.grade(79), 'C');
    expect(ResultDialog.grade(60), 'C');
    expect(ResultDialog.grade(0), 'D');
  });
}
