import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'character.dart';

/// One finished round. Difficulty differs per character, so ranks are per character.
/// Every scored round is kept in the history; it joins the ranking once it has
/// a nickname, which can be added right after the round or later from the history.
class GameRecord {
  const GameRecord({
    required this.name,
    required this.score,
    required this.character,
    required this.caught,
    required this.bad,
    required this.missed,
    required this.at,
    this.bestCombo = 0,
  });
  final String name;
  final int score, caught, bad, missed;

  /// Longest run of good catches; 0 on records saved before it was kept.
  final int bestCombo;
  final CatchCharacter character;
  final DateTime at;

  /// Empty until the player saves a nickname.
  bool get named => name.isNotEmpty;
  GameRecord withName(String name) => GameRecord(
    name: name,
    score: score,
    character: character,
    caught: caught,
    bad: bad,
    missed: missed,
    at: at,
    bestCombo: bestCombo,
  );

  Map<String, Object> toMap() => {
    'name': name,
    'score': score,
    'character': character.id,
    'caught': caught,
    'bad': bad,
    'missed': missed,
    'bestCombo': bestCombo,
    'at': at.toIso8601String(),
  };

  static GameRecord? fromMap(Object? data) {
    if (data is! Map) return null;
    final character = CatchCharacter.values
        .where((c) => c.id == data['character'])
        .firstOrNull;
    final at = DateTime.tryParse('${data['at']}');
    if (character == null || at == null || data['name'] is! String) return null;
    int n(String key) => data[key] is int ? data[key] as int : 0;
    return GameRecord(
      name: data['name'] as String,
      score: n('score'),
      character: character,
      caught: n('caught'),
      bad: n('bad'),
      missed: n('missed'),
      at: at,
      bestCombo: n('bestCombo'),
    );
  }
}

/// Device-local records for the event booth. v2 scores out of 100; the raw
/// point records of v1 are left behind.
class RecordStore {
  static const key = 'yumemi.records.v2', maxRecords = 500, maxName = 12;
  final records = <GameRecord>[];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    records.clear();
    try {
      final data = jsonDecode(prefs.getString(key) ?? '[]') as List;
      records.addAll(data.map(GameRecord.fromMap).nonNulls);
    } catch (_) {
      /* Corrupt data starts an empty board. */
    }
  }

  Future<void> add(GameRecord record) async {
    records.add(record);
    // At the cap, unnamed history goes first (oldest), then the lowest scores.
    while (records.length > maxRecords) {
      final unnamed = records.where((r) => !r.named);
      records.remove(
        unnamed.isNotEmpty
            ? unnamed.reduce((a, b) => a.at.isBefore(b.at) ? a : b)
            : (records.toList()..sort(compare)).last,
      );
    }
    await _save();
  }

  /// Gives [record] a nickname in place and returns the named copy.
  Future<GameRecord> rename(GameRecord record, String name) async {
    final i = records.indexWhere((r) => identical(r, record));
    final named = record.withName(name);
    if (i < 0) {
      records.add(named);
    } else {
      records[i] = named;
    }
    await _save();
    return named;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(records.map((r) => r.toMap()).toList()),
    );
  }

  /// Higher score first; ties go to the earlier record.
  static int compare(GameRecord a, GameRecord b) =>
      a.score != b.score ? b.score.compareTo(a.score) : a.at.compareTo(b.at);

  /// Named records of [character], best first.
  List<GameRecord> ranking(CatchCharacter character) =>
      records.where((r) => r.named && r.character == character).toList()
        ..sort(compare);

  /// Every round, newest first.
  List<GameRecord> get history =>
      records.toList()..sort((a, b) => b.at.compareTo(a.at));

  /// Best score of [character] in every round so far, or null before the first.
  int? bestScore(CatchCharacter character) => records
      .where((r) => r.character == character)
      .map((r) => r.score)
      .fold<int?>(null, (a, b) => a == null ? b : math.max(a, b));

  /// 1-based rank among named records; equal scores share the best rank.
  int rankOf(GameRecord record) =>
      ranking(record.character).where((r) => r.score > record.score).length + 1;
}
