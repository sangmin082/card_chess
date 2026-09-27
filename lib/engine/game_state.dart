/// 한 세트의 게임 상태와 착수 적용.
library;

import 'model.dart';
import 'move_gen.dart';

/// 불변 게임 상태. [apply]는 항상 새 객체를 반환한다.
class GameState {
  GameState._({
    required List<Piece?> squares,
    required this.toMove,
    required List<CardType> whiteHand,
    required List<CardType> blackHand,
    required this.waiting,
    required List<Move> history,
    required this.result,
    required this.options,
    required this.firstPlayer,
    required this.placement,
  })  : squares = List.unmodifiable(squares),
        whiteHand = List.unmodifiable(whiteHand),
        blackHand = List.unmodifiable(blackHand),
        history = List.unmodifiable(history);

  /// 세트 시작 상태. 후공이 정한 [placement]에 따라 카드를 나눈다.
  factory GameState.initial({
    required PlayerColor firstPlayer,
    required CardPlacement placement,
    RuleOptions options = RuleOptions.standard,
  }) {
    if (!placement.isValid) {
      throw ArgumentError('카드 배치가 올바르지 않습니다: 5장을 2/2/1로 나눠야 합니다.');
    }
    final squares = List<Piece?>.filled(Pos.size * Pos.size, null);
    for (final color in PlayerColor.values) {
      for (var rank = 0; rank < Pos.size; rank++) {
        squares[Pos(color.homeFile, rank).index] =
            Piece(color, color.initialFacing);
      }
    }
    final second = firstPlayer.opponent;
    return GameState._(
      squares: squares,
      toMove: firstPlayer,
      whiteHand: firstPlayer == PlayerColor.white
          ? placement.firstPlayerHand
          : placement.secondPlayerHand,
      blackHand: second == PlayerColor.black
          ? placement.secondPlayerHand
          : placement.firstPlayerHand,
      waiting: placement.waiting,
      history: const [],
      result: null,
      options: options,
      firstPlayer: firstPlayer,
      placement: placement,
    );
  }

  /// 25칸. 인덱스는 [Pos.index].
  final List<Piece?> squares;
  final PlayerColor toMove;
  final List<CardType> whiteHand;
  final List<CardType> blackHand;
  final CardType waiting;
  final List<Move> history;
  final GameResult? result;
  final RuleOptions options;
  final PlayerColor firstPlayer;

  /// 세트 시작 시의 카드 배치.
  final CardPlacement placement;

  bool get isOver => result != null;

  int get moveNumber => history.length;

  Piece? pieceAt(Pos p) => squares[p.index];

  List<CardType> hand(PlayerColor c) =>
      c == PlayerColor.white ? whiteHand : blackHand;

  int pieceCount(PlayerColor c) =>
      squares.where((p) => p != null && p.owner == c).length;

  int get totalPieces => squares.where((p) => p != null).length;

  /// [color] 말들의 위치.
  List<Pos> piecesOf(PlayerColor color) => [
        for (var i = 0; i < squares.length; i++)
          if (squares[i]?.owner == color) Pos.fromIndex(i),
      ];

  /// 상대 성 위에 올라가 있는 [color]의 말 위치. 없으면 null.
  Pos? intruderOf(PlayerColor color) {
    final target = color.opponent.castle;
    return pieceAt(target)?.owner == color ? target : null;
  }

  /// 현재 차례의 플레이어가 [card]로 둘 수 있는 수. 손에 없는 카드면 빈 목록.
  List<Move> legalMovesWith(CardType card) {
    if (isOver || !hand(toMove).contains(card)) return const [];
    return generateMoves(this, card, toMove);
  }

  /// 현재 차례의 모든 합법 수. 이동 가능한 수가 하나도 없고
  /// 정책이 pass면 패스 수를 돌려준다.
  List<Move> legalMoves() {
    if (isOver) return const [];
    final moves = <Move>[];
    for (final card in hand(toMove)) {
      moves.addAll(generateMoves(this, card, toMove));
    }
    if (moves.isEmpty && options.noMovePolicy == NoMovePolicy.pass) {
      return [for (final card in hand(toMove)) Move.pass(card)];
    }
    return moves;
  }

  bool isLegal(Move move) => legalMoves().any((m) => m.sameAs(move));

  /// 착수를 검증한 뒤 적용한다. 불법 수면 [ArgumentError].
  GameState apply(Move move) {
    if (isOver) throw ArgumentError('이미 끝난 게임입니다.');
    final legal = legalMoves();
    final matched = legal.where((m) => m.sameAs(move));
    if (matched.isEmpty) {
      throw ArgumentError('불법 수: ${move.notation} (${toMove.korean} 차례)');
    }
    return applyUnchecked(matched.first);
  }

  /// 검증 없이 적용. [move]는 [legalMoves]에서 나온 객체여야 한다.
  GameState applyUnchecked(Move move) {
    final me = toMove;
    final opp = me.opponent;
    final squares = List<Piece?>.of(this.squares);

    if (!move.isPass) {
      final from = move.from!;
      final to = move.to!;
      var piece = squares[from.index]!;
      squares[from.index] = null;
      // 진행 방향의 끝 줄에 도착하면 방향 반전.
      if (to.file == piece.facing.lastFile) {
        piece = piece.withFacing(piece.facing.flipped);
      }
      squares[to.index] = piece;
    }

    // 카드 순환: 사용 카드 -> 대기 존, 대기 존 카드 -> 내 손.
    var myHand = List<CardType>.of(hand(me));
    final idx = myHand.indexOf(move.card);
    myHand[idx] = waiting;
    var newWaiting = move.card;
    var oppHand = List<CardType>.of(hand(opp));

    // 보드 위 말이 2개면 점퍼는 퀸이 된다.
    final total = squares.where((p) => p != null).length;
    if (total == 2) {
      CardType q(CardType c) => c == CardType.jumper ? CardType.queen : c;
      myHand = myHand.map(q).toList();
      oppHand = oppHand.map(q).toList();
      newWaiting = q(newWaiting);
    }

    // 승리 판정.
    GameResult? result;
    final oppCount = squares.where((p) => p?.owner == opp).length;
    if (oppCount == 0) {
      result = GameResult(me, WinReason.annihilation);
    } else if (squares[me.castle.index]?.owner == opp) {
      // 상대가 지난 턴에 내 성에 올린 말이 이번 내 수 뒤에도 살아 있다.
      result = GameResult(opp, WinReason.castle);
    }

    final next = GameState._(
      squares: squares,
      toMove: opp,
      whiteHand: me == PlayerColor.white ? myHand : oppHand,
      blackHand: me == PlayerColor.black ? myHand : oppHand,
      waiting: newWaiting,
      history: [...history, move],
      result: result,
      options: options,
      firstPlayer: firstPlayer,
      placement: placement,
    );

    if (result == null &&
        options.noMovePolicy == NoMovePolicy.lose &&
        next.legalMoves().isEmpty) {
      return next._withResult(GameResult(me, WinReason.noMoves));
    }
    return next;
  }

  GameState _withResult(GameResult r) => GameState._(
        squares: squares,
        toMove: toMove,
        whiteHand: whiteHand,
        blackHand: blackHand,
        waiting: waiting,
        history: history,
        result: r,
        options: options,
        firstPlayer: firstPlayer,
        placement: placement,
      );

  /// 직전 수를 되돌린 상태. 처음부터 다시 재생한다.
  GameState? undo({int count = 1}) {
    if (history.length < count) return null;
    return replay(history.length - count);
  }

  /// 처음 상태에서 [n]수까지 재생한 상태.
  GameState replay(int n) {
    var s = initialOf(this);
    for (var i = 0; i < n; i++) {
      s = s.applyUnchecked(s.legalMoves().firstWhere((m) => m.sameAs(history[i])));
    }
    return s;
  }

  /// [state]와 같은 설정의 시작 상태.
  static GameState initialOf(GameState state) => GameState.initial(
        firstPlayer: state.firstPlayer,
        placement: state.placement,
        options: state.options,
      );

  /// 디버그용 보드 문자열. 위가 a열(흑), 아래가 e열(백).
  String toBoardString() {
    final b = StringBuffer();
    for (var file = 0; file < Pos.size; file++) {
      b.write('${'abcde'[file]} ');
      for (var rank = 0; rank < Pos.size; rank++) {
        final p = squares[Pos(file, rank).index];
        if (p == null) {
          b.write(Pos(file, rank) == PlayerColor.white.castle ||
                  Pos(file, rank) == PlayerColor.black.castle
              ? ' ◇'
              : ' ·');
        } else {
          final c = p.owner == PlayerColor.white ? 'W' : 'B';
          b.write(p.facing == Facing.minusFile ? ' $c↑' : ' $c↓');
        }
      }
      b.writeln();
    }
    b.writeln('   1  2  3  4  5');
    b.writeln('백: ${whiteHand.map((c) => c.symbol).join(',')}  '
        '대기: ${waiting.symbol}  흑: ${blackHand.map((c) => c.symbol).join(',')}  '
        '차례: ${toMove.korean}');
    return b.toString();
  }
}
