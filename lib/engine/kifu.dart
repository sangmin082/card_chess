/// 기보(棋譜) 표기와 파싱.
library;

import 'game_state.dart';
import 'model.dart';

/// 한 세트의 기보.
class KifuSet {
  const KifuSet({
    required this.title,
    required this.firstPlayer,
    required this.placement,
    required this.moves,
    this.winner,
    this.playerNames = const {},
    this.options = RuleOptions.standard,
  });

  final String title;
  final PlayerColor firstPlayer;
  final CardPlacement placement;
  final List<Move> moves;
  final PlayerColor? winner;
  final Map<PlayerColor, String> playerNames;

  /// 이 기보가 두어진 하우스룰. 재생 시 같은 규칙을 쓴다.
  final RuleOptions options;

  GameState initialState({RuleOptions? options}) => GameState.initial(
    firstPlayer: firstPlayer,
    placement: placement,
    options: options ?? this.options,
  );

  /// 처음부터 끝까지 재생하며 각 단계 상태를 돌려준다. 첫 원소는 시작 상태.
  List<GameState> replayAll({RuleOptions? options}) {
    final states = <GameState>[initialState(options: options)];
    for (final move in moves) {
      states.add(states.last.apply(move));
    }
    return states;
  }

  /// 텍스트 형식:
  /// ```
  /// title: 1세트
  /// first: white
  /// white: R,J
  /// black: B,A
  /// waiting: N
  /// names: white=강지후, black=윤비
  /// options: jumperOverEnemy=true, noMovePolicy=lose   (생략 시 표준 규칙)
  /// moves: Re3→d3 Ba4→b3 ...
  /// winner: white
  /// ```
  factory KifuSet.parse(String text) {
    String? title;
    PlayerColor? first;
    PlayerColor? winner;
    List<CardType>? white;
    List<CardType>? black;
    CardType? waiting;
    final moves = <Move>[];
    final names = <PlayerColor, String>{};
    var jumperOverEnemy = false;
    var noMovePolicy = NoMovePolicy.pass;

    List<CardType> cards(String v) => v
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map(CardType.fromSymbol)
        .toList();

    PlayerColor color(String v) => switch (v.trim().toLowerCase()) {
      'white' || 'w' || '백' => PlayerColor.white,
      'black' || 'b' || '흑' => PlayerColor.black,
      _ => throw FormatException('색 형식 오류: $v'),
    };

    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final colon = line.indexOf(':');
      if (colon < 0) throw FormatException('기보 줄 형식 오류: $line');
      final key = line.substring(0, colon).trim().toLowerCase();
      final value = line.substring(colon + 1).trim();
      switch (key) {
        case 'title':
          title = value;
        case 'first':
          first = color(value);
        case 'winner':
          winner = color(value);
        case 'white':
          white = cards(value);
        case 'black':
          black = cards(value);
        case 'waiting':
          waiting = CardType.fromSymbol(value);
        case 'names':
          for (final part in value.split(',')) {
            final eq = part.indexOf('=');
            if (eq < 0) continue;
            names[color(part.substring(0, eq))] = part.substring(eq + 1).trim();
          }
        case 'options':
          for (final part in value.split(',')) {
            final eq = part.indexOf('=');
            if (eq < 0) continue;
            final k = part.substring(0, eq).trim();
            final v = part.substring(eq + 1).trim().toLowerCase();
            switch (k) {
              case 'jumperOverEnemy':
                jumperOverEnemy = v == 'true';
              case 'noMovePolicy':
                noMovePolicy = NoMovePolicy.values.firstWhere(
                  (e) => e.name == v,
                  orElse: () => NoMovePolicy.pass,
                );
            }
          }
        case 'moves':
          for (final tok in value.split(RegExp(r'\s+'))) {
            if (tok.isEmpty) continue;
            // "01." 같은 번호는 무시.
            if (RegExp(r'^\d+\.?$').hasMatch(tok)) continue;
            moves.add(Move.parse(tok));
          }
        default:
          throw FormatException('알 수 없는 키: $key');
      }
    }
    if (first == null || white == null || black == null || waiting == null) {
      throw const FormatException('first/white/black/waiting 은 필수입니다.');
    }
    return KifuSet(
      title: title ?? '',
      firstPlayer: first,
      placement: CardPlacement(
        firstPlayerHand: first == PlayerColor.white ? white : black,
        secondPlayerHand: first == PlayerColor.white ? black : white,
        waiting: waiting,
      ),
      moves: moves,
      winner: winner,
      playerNames: names,
      options: RuleOptions(
        jumperOverEnemy: jumperOverEnemy,
        noMovePolicy: noMovePolicy,
      ),
    );
  }

  /// [KifuSet.parse]가 읽을 수 있는 텍스트로 직렬화.
  String serialize() {
    final s = initialState();
    final b = StringBuffer();
    if (title.isNotEmpty) b.writeln('title: $title');
    b.writeln('first: ${firstPlayer.name}');
    b.writeln('white: ${s.whiteHand.map((c) => c.symbol).join(',')}');
    b.writeln('black: ${s.blackHand.map((c) => c.symbol).join(',')}');
    b.writeln('waiting: ${s.waiting.symbol}');
    if (playerNames.isNotEmpty) {
      b.writeln(
        'names: ${playerNames.entries.map((e) => '${e.key.name}=${e.value}').join(', ')}',
      );
    }
    if (options.jumperOverEnemy || options.noMovePolicy != NoMovePolicy.pass) {
      b.writeln(
        'options: jumperOverEnemy=${options.jumperOverEnemy}, '
        'noMovePolicy=${options.noMovePolicy.name}',
      );
    }
    b.writeln('moves: ${moves.map((m) => m.notation).join(' ')}');
    if (winner != null) b.writeln('winner: ${winner!.name}');
    return b.toString();
  }

  /// 진행 중이거나 끝난 [state]로부터 기보를 만든다.
  factory KifuSet.fromState(
    GameState state, {
    String title = '',
    Map<PlayerColor, String> playerNames = const {},
  }) {
    return KifuSet(
      title: title,
      firstPlayer: state.firstPlayer,
      placement: state.placement,
      moves: state.history,
      winner: state.result?.winner,
      playerNames: playerNames,
      options: state.options,
    );
  }
}
