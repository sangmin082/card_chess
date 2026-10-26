/// 카드별 합법 수 생성.
library;

import 'game_state.dart';
import 'model.dart';

const List<(int, int)> _orthogonal = [(1, 0), (-1, 0), (0, 1), (0, -1)];
const List<(int, int)> _diagonal = [(1, 1), (1, -1), (-1, 1), (-1, -1)];
const List<(int, int)> _all8 = [..._orthogonal, ..._diagonal];
const List<(int, int)> _knight = [
  (2, 1),
  (2, -1),
  (-2, 1),
  (-2, -1),
  (1, 2),
  (1, -2),
  (-1, 2),
  (-1, -2),
];

/// [player]가 [card]로 둘 수 있는 모든 수.
List<Move> generateMoves(GameState state, CardType card, PlayerColor player) {
  final moves = <Move>[];
  for (var i = 0; i < Pos.size * Pos.size; i++) {
    final piece = state.squares[i];
    if (piece == null || piece.owner != player) continue;
    final from = Pos.fromIndex(i);
    switch (card) {
      case CardType.rook:
        _steps(state, moves, card, from, player, _orthogonal);
      case CardType.bishop:
        _steps(state, moves, card, from, player, _diagonal);
      case CardType.queen:
        _steps(state, moves, card, from, player, _all8);
      case CardType.knight:
        _steps(state, moves, card, from, player, _knight);
      case CardType.attacker:
        _attacker(state, moves, card, from, piece, player);
      case CardType.jumper:
        _jumper(state, moves, card, from, player);
    }
  }
  return moves;
}

void _tryAdd(
  GameState state,
  List<Move> moves,
  CardType card,
  Pos from,
  Pos to,
  PlayerColor player,
) {
  if (!to.onBoard) return;
  final target = state.pieceAt(to);
  if (target != null && target.owner == player) return;
  moves.add(Move(card: card, from: from, to: to, capture: target != null));
}

void _steps(
  GameState state,
  List<Move> moves,
  CardType card,
  Pos from,
  PlayerColor player,
  List<(int, int)> deltas,
) {
  for (final (df, dr) in deltas) {
    _tryAdd(state, moves, card, from, from.offset(df, dr), player);
  }
}

void _attacker(
  GameState state,
  List<Move> moves,
  CardType card,
  Pos from,
  Piece piece,
  PlayerColor player,
) {
  final f = piece.facing.df;
  final one = from.offset(f, 0);
  _tryAdd(state, moves, card, from, one, player);
  // 직진 2칸: 중간 칸이 비어 있어야 한다.
  if (one.onBoard && state.pieceAt(one) == null) {
    _tryAdd(state, moves, card, from, from.offset(2 * f, 0), player);
  }
  // 전방 대각선 2방향.
  _tryAdd(state, moves, card, from, from.offset(f, 1), player);
  _tryAdd(state, moves, card, from, from.offset(f, -1), player);
}

void _jumper(
  GameState state,
  List<Move> moves,
  CardType card,
  Pos from,
  PlayerColor player,
) {
  for (final (df, dr) in _all8) {
    final mid = from.offset(df, dr);
    if (!mid.onBoard) continue;
    final over = state.pieceAt(mid);
    if (over == null) continue;
    if (over.owner != player && !state.options.jumperOverEnemy) continue;
    _tryAdd(state, moves, card, from, from.offset(2 * df, 2 * dr), player);
  }
}
