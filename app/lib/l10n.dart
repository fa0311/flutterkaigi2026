import 'package:flutter/widgets.dart';

import 'billboards.dart';
import 'character.dart';
import 'drop_kind.dart';
import 'stage_time.dart';

/// UI language. Game data keeps Japanese labels and ids; screens translate here.
enum AppLang {
  ja('日本語'),
  en('English');

  const AppLang(this.label);
  final String label;
  String get id => name;
}

class L10n extends InheritedWidget {
  const L10n({super.key, required this.strings, required super.child});
  final Strings strings;
  static Strings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<L10n>()?.strings ??
      const Strings(AppLang.ja);
  @override
  bool updateShouldNotify(L10n old) => old.strings.lang != strings.lang;
}

class Strings {
  const Strings(this.lang);
  final AppLang lang;
  bool get ja => lang == AppLang.ja;
  String _(String j, String e) => ja ? j : e;

  String get appTitle => _('ゆめみ採用試験', 'Yumemi Recruitment Exam');
  String get tapToStart => _('タップして開始', 'Tap to start');
  String get loading => _('読み込み中', 'Loading');
  String get backToTitle => _('タイトルへ戻る', 'Back to title');
  String get about => _('このアプリについて', 'About');
  String get aboutBody => _(
    'FlutterKaigi 2026 のゆめみブースで遊べる、Flutter Scene製の3Dミニゲーム。',
    'A 3D mini game built with Flutter Scene for the YUMEMI booth at FlutterKaigi 2026.',
  );
  String get repository => _('リポジトリ', 'Repository');
  String get authors => _('作者', 'Authors');
  String get aboutTab => _('アプリ情報', 'About');
  String get licenses => _('ライセンス', 'Licenses');
  String licenseCount(int n) => _('$n件', n == 1 ? '1 license' : '$n licenses');

  String get chooseCharacter => _('だれで挑む？', 'Who takes the exam?');
  String roundLength(int s) => _('$s秒の一本勝負', '$s-second challenge');
  String get good => _('あたり', 'Catch');
  String get bad => _('はずれ', 'Avoid');
  String get catchIt => _('キャッチする', 'Catch these');
  String get avoidIt => _('避ける', 'Dodge these');
  String get controls =>
      _('傾けて移動、スワイプで見回す。', 'Tilt to move. Swipe to look around.');
  String get play => _('プレイする', 'Play');
  String get practice => _('お試し', 'Practice');
  String get practiceHint => _('時間無制限・得点なし', 'No time limit, no score');
  String get ranking => _('ランキング', 'Ranking');
  String get graphics => _('画質設定', 'Graphics');
  String get language => _('言語', 'Language');

  /// Round score out of 100.
  String points(int score) => _('$score点', '$score / 100');
  String get passed => _('合格', 'PASSED');
  String get failed => _('不合格', 'FAILED');
  String passLine(int score) => _('$score点以上で合格', 'Pass with $score+');
  String get allCaught => _('全部で100点', 'All = 100');
  String penaltyEach(int p) => _('1回 −$p点', '−$p each');
  String results(int caught, int bad, int missed) => _(
    'あたり $caught  /  はずれ $bad  /  逃した $missed',
    'Caught $caught  /  Wrong $bad  /  Missed $missed',
  );

  String character(CatchCharacter c) => ja
      ? c.label
      : switch (c) {
          CatchCharacter.sobaya => 'SOBAYA',
          CatchCharacter.ctoOdatetsu => 'CTO Odatetsu',
          CatchCharacter.fukuchan => 'Fukugyun',
        };
  String difficulty(CatchCharacter c) => ja
      ? c.difficulty
      : switch (c) {
          CatchCharacter.fukuchan => 'Easy',
          CatchCharacter.ctoOdatetsu => 'Normal',
          CatchCharacter.sobaya => 'Hard',
        };
  String hint(CatchCharacter c) => ja
      ? c.hint
      : switch (c) {
          CatchCharacter.fukuchan => 'Falls slowly. Catch Yumemin.',
          CatchCharacter.ctoOdatetsu =>
            'Catch the golden-toasted chikuwa. Beware of purple ones.',
          CatchCharacter.sobaya =>
            'Lots of brands. Read the labels — real beer only.',
        };

  /// Short name for the HUD and messages.
  String drop(CanKind k) => ja
      ? k.label
      : switch (k) {
          CanKind.superTry || CanKind.light => 'beer',
          CanKind.happoshu => 'happoshu',
          CanKind.chikuwa => 'chikuwa',
          CanKind.toxicChikuwa => 'toxic chikuwa',
          CanKind.yumemin => 'Yumemin',
          CanKind.yametaro => 'Yametaro',
        };

  /// Selection-screen name; English explains things unfamiliar abroad.
  ({String name, String? note}) dropDetail(CanKind k) => ja
      ? (name: k.label, note: null)
      : switch (k) {
          CanKind.superTry || CanKind.light => (name: 'Beer', note: null),
          CanKind.happoshu => (
            name: 'Happoshu',
            note: 'Low-malt, beer-like drink',
          ),
          CanKind.chikuwa => (
            name: 'Chikuwa',
            note: 'Japanese tube-shaped fish cake',
          ),
          CanKind.toxicChikuwa => (
            name: 'Toxic Chikuwa',
            note: 'A spoiled, purple fish cake',
          ),
          CanKind.yumemin => (name: 'Yumemin', note: "YUMEMI's mascot"),
          CanKind.yametaro => (
            name: 'Yametaro',
            note: 'The one who wants to quit',
          ),
        };
  String get sobayaBrands => _('つらい・LIGHT', 'TSURAI and LIGHT brands');

  String time(StageTime t) => ja
      ? t.label
      : switch (t) {
          StageTime.day => 'Day',
          StageTime.night => 'Night',
        };

  String get gallery => _('ギャラリー', 'Gallery');
  String get galleryModels => _('3Dモデル', '3D models');
  String get galleryBillboards => _('看板', 'Billboards');
  String get galleryCharacters => _('キャラクター', 'Characters');
  String get galleryDrops => _('落下物', 'Falling items');
  String get galleryStage => _('ステージ', 'Stage');
  String get stageName => _('赤坂・鉄骨', 'Akasaka steel beam');
  String get galleryHint => _(
    'ドラッグで回転・ピンチで拡大・2本指で移動・ダブルタップで戻す',
    'Drag to orbit, pinch to zoom, two fingers to pan, double-tap to reset',
  );
  String get galleryStageHint => _(
    'ダブルタップした建物へ寄る・2本指で街を移動・ピンチで拡大',
    'Double-tap a building to fly there, two fingers to move, pinch to zoom',
  );
  String get resetView => _('視点を戻す', 'Reset view');
  String get autoRotate => _('自動回転', 'Auto-rotate');
  String get darkBackground => _('背景を暗く', 'Dark background');
  String get playMotion => _('モーションを再生', 'Play motion');
  String get pauseMotion => _('モーションを止める', 'Pause motion');
  String get previous => _('前へ', 'Previous');
  String get next => _('次へ', 'Next');
  String galleryDrop(CanKind k) => switch (k) {
    CanKind.superTry => _('窓際スーパーつらい', 'Madogiwa Super Tsurai'),
    CanKind.light => _('窓際ライト', 'Madogiwa Light'),
    CanKind.happoshu => _('発泡酒 つらめ', 'Tsurame (happoshu)'),
    _ => dropDetail(k).name,
  };
  String clip(String name) => ja
      ? switch (name) {
          'Idle' => '待機',
          'Walk' => '歩く',
          'Run' => '走る',
          'Wiggle' => 'くねくね',
          'Talk' => '話す',
          'Wave' => '手を振る',
          _ => name,
        }
      : name;
  String billboardGroup(BillboardGroup g) => switch (g) {
    BillboardGroup.sponsor => _('協賛広告', 'Sponsors'),
    BillboardGroup.yumemin => _('ゆめみん', 'Yumemin'),
    BillboardGroup.vision => _('街頭ビジョン', 'Street screen'),
  };

  /// Names as printed on the boards; ids without an entry show as is.
  String billboard(String id) => switch (id) {
    'takahashigumi' => _('高橋組', 'Takahashi-gumi'),
    'mogumogu' => _('もぐもぐ先生最強！', 'Mogumogu-sensei'),
    'ykws' => 'ykws',
    'sakai' => 'Sakai',
    'nakayaman' => _('なかやまん', 'Nakayaman'),
    'fa' => _('ふぁ', 'Fa'),
    'odatetsu' => _('おだてつ', 'Odatetsu'),
    'flutter_book' => _('Flutter実践開発', 'Flutter in Practice (book)'),
    'figma_mcp_book' => _('試して学ぶ Figma MCPサーバー', 'Figma MCP Server (book)'),
    'yumemin' => _('ゆめみん', 'Yumemin'),
    'okayaman_vision' => _('おかやまん', 'Okayaman'),
    _ => id,
  };

  String player(String name) => _('プレイヤー：$name', 'Player: $name');
  String secondsLeft(int s) => _('残り $s 秒', '$s s left');
  String get practiceBadge => _('お試しモード（得点なし）', 'Practice (no score)');
  String get endPractice => _('お試しを終える', 'End practice');
  String get go => _('スタート！', 'GO!');
  String niceCatch(int? points) => points == null
      ? _('ナイスキャッチ！', 'Nice catch!')
      : _('ナイスキャッチ！  +$points', 'Nice catch!  +$points');
  String wrongCatch(CanKind k, int? penalty) {
    final p = penalty == null ? '' : '  −$penalty';
    return _('これ、${drop(k)}やないか！$p', "That's ${drop(k)}!$p");
  }

  /// Combo counter label and the milestone callouts.
  String get combo => 'COMBO';
  String comboTitle(int n) => '$n COMBO!';
  String comboCheer(int tier) => switch (tier) {
    <= 1 => _('ええ感じや！', 'Nice streak!'),
    2 => _('絶好調や！', 'On fire!'),
    3 => _('もう採用でええやろ！', 'Unstoppable!'),
    _ => _('伝説級や！', 'Legendary!'),
  };
  String get newBest => _('自己ベスト更新！', 'NEW BEST!');

  /// Shouted on every good catch, cycling with the event id.
  static const _hypeJa = [
    'ナイス！',
    'うまい！',
    'ええぞ！',
    '天才！',
    '神！',
    '採用！',
    '最高！',
    'やるやん！',
    'キレッキレ！',
    '止まらん！',
  ];
  static const _hypeEn = [
    'NICE!',
    'SWEET!',
    'YES!',
    'GENIUS!',
    'GODLIKE!',
    'HIRED!',
    'SUPERB!',
    'SLICK!',
    'ON POINT!',
    'UNSTOPPABLE!',
  ];
  String hype(int i) =>
      ja ? _hypeJa[i % _hypeJa.length] : _hypeEn[i % _hypeEn.length];
  static const _booJa = ['ウゲッ！', 'それちゃう！', 'あかん！', 'ちゃうちゃう！'];
  static const _booEn = ['BLECH!', 'WRONG ONE!', 'NOPE!', 'NOT THAT!'];
  String boo(int i) =>
      ja ? _booJa[i % _booJa.length] : _booEn[i % _booEn.length];
  String get miss => 'MISS';
  String comboLost(int n) => _('コンボ切れ ×$n', 'COMBO LOST ×$n');
  String get fever => 'FEVER!!';
  String get rank => _('ランク', 'RANK');
  String get perfect => _('パーフェクト！', 'PERFECT!');
  String bestCombo(int n) => _('最大 $n コンボ', 'Best combo $n');

  String get paused => _('ひと休み', 'Paused');
  String get resume => _('持ち方を合わせて再開', 'Hold steady and resume');
  String get backToSelect => _('キャラクター選択に戻る', 'Back to characters');

  String get recordTitle => _('記録を残す', 'Save your record');
  String get nickname => _('ニックネーム', 'Nickname');
  String get save => _('記録する', 'Save');
  String get records => _('記録', 'Records');
  String get history => _('スコア履歴', 'Score history');
  String get addName => _('名前を付ける', 'Add name');
  String get recordHint =>
      _('ニックネームを付けるとランキングに載ります', 'Add a nickname to join the ranking');
  String get close => _('閉じる', 'Close');
  String rankOf(int rank, int total) =>
      _('$total人中 $rank位', 'Rank $rank of $total');
  String get noRecords => _('まだ記録がありません', 'No records yet');

  String get cancel => _('キャンセル', 'Cancel');
  String get settings => _('設定', 'Settings');
  String get graphicsTab => _('画質', 'Graphics');
  String get demoTab => _('デモ', 'Demo');
  String get balanceTab => _('バランス', 'Balance');
  String get forDevelopers => _('開発者向け', 'For developers');
  String get resetTab => _('標準に戻す', 'Reset');
  String get applyRestart => _('適用して最初から', 'Apply and restart');
  String get tasTitle => _('TASモード（完璧な操作）', 'TAS mode (perfect play)');
  String get tasBody => _(
    'オンのあいだ、ラウンドを100点になるフレーム単位の入力で自動プレイする。'
        'プレイ中もスワイプで見回せる。記録には残らない。',
    'While on, rounds play themselves with frame-exact inputs that score 100. '
        'You can still swipe to look around. Not recorded.',
  );
  String get tasBadge => _('TAS：完璧な操作を再生中', 'TAS: perfect play');
  String get tasSearching =>
      _('TAS：100点になる入力を計算中…', 'TAS: finding a perfect input…');
  String get tasNotFound => _(
    'この設定では100点になる入力が見つからないため、通常の操作で遊びます',
    'No perfect input for these settings; playing normally',
  );
  String get tasNotRecorded =>
      _('TASのプレイは記録に残りません', 'TAS rounds are not recorded');
  String get soundTitle => _('効果音', 'Sound effects');
  String get soundBody =>
      _('開始前の「3・2・1」とスタートの音', 'Beeps for the 3-2-1 countdown and start');
  String get fpsTitle => _('FPS表示', 'FPS display');
  String get fpsBody => _(
    'プレイ画面の左下にフレームレートと描画時間を出す',
    'Frame rate and frame times at the bottom left while playing',
  );
  String get apply => _('適用', 'Apply');
  String get standard => _('標準', 'Standard');
  String get highQuality => _('高画質', 'High');
  String get lightQuality => _('軽量', 'Light');
  List<(String, String, String)> get graphicsOptions => ja
      ? const [
          ('shadows', '太陽の影', '昼の建物・キャラクターの影'),
          ('reflections', 'ガラス・金属の反射', '空と街明かりの映り込み'),
          ('surfaceDetail', '表面の凹凸', '鉄骨・路面の細かな質感'),
          ('bloom', '夜景の光のにじみ', '夜の照明を柔らかく'),
          ('fullResolution', '高精細描画', 'オンで細部と遠くの影を優先。オフでなめらかさを優先'),
        ]
      : const [
          (
            'shadows',
            'Sun shadows',
            'Shadows of buildings and characters by day',
          ),
          ('reflections', 'Glass and metal reflections', 'Sky and city lights'),
          (
            'surfaceDetail',
            'Surface detail',
            'Fine texture of steel and roads',
          ),
          ('bloom', 'Night glow', 'Softer night lighting'),
          (
            'fullResolution',
            'Full resolution',
            'On favors detail and distant shadows; off favors smoothness',
          ),
        ];
}
