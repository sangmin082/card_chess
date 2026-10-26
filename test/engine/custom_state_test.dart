import 'package:card_chess/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

GameState _sample() => GameState.custom(
  pieces: {
    Pos.parse('c3'): const Piece(PlayerColor.white, Facing.minusFile),
    Pos.parse('d4'): const Piece(PlayerColor.white, Facing.minusFile),
    Pos.parse('a1'): const Piece(PlayerColor.black, Facing.plusFile),
    Pos.parse('b4'): const Piece(PlayerColor.black, Facing.plusFile),
  },
  toMove: PlayerColor.white,
  whiteHand: const [CardType.rook, CardType.bishop],
  blackHand: const [CardType.attacker, CardType.knight],
  waiting: CardType.jumper,
);

void main() {
  group('GameState.custom', () {
    test('지정한 말과 카드로 시작한다', () {
      final s = _sample();
      expect(s.totalPieces, 4);
      expect(s.toMove, PlayerColor.white);
      expect(s.whiteHand, [CardType.rook, CardType.bishop]);
      expect(s.waiting, CardType.jumper);
      expect(s.legalMoves(), isNotEmpty);
      expect(s.customStart, isNotNull);
    });

    test('카드가 2/2/1 로 서로 다르지 않으면 예외', () {
      expect(
        () => GameState.custom(
          pieces: const {},
          toMove: PlayerColor.white,
          whiteHand: const [CardType.rook, CardType.rook],
          blackHand: const [CardType.attacker, CardType.knight],
          waiting: CardType.jumper,
        ),
        throwsArgumentError,
      );
    });

    test('퀸이 들어간 국면도 만들 수 있다', () {
      final s = GameState.custom(
        pieces: {
          Pos.parse('c3'): const Piece(PlayerColor.white, Facing.minusFile),
          Pos.parse('a1'): const Piece(PlayerColor.black, Facing.plusFile),
        },
        toMove: PlayerColor.white,
        whiteHand: const [CardType.queen, CardType.rook],
        blackHand: const [CardType.attacker, CardType.knight],
        waiting: CardType.bishop,
      );
      expect(s.legalMovesWith(CardType.queen).length, 8);
    });

    test('undo 와 replay 는 사용자 지정 시작 국면으로 돌아간다', () {
      final s0 = _sample();
      final s1 = s0.apply(Move.parse('Rc3→b3'));
      final s2 = s1.apply(Move.parse('Ab4→c4'));
      final back = s2.undo()!;
      expect(back.squares, s1.squares);
      expect(back.whiteHand, s1.whiteHand);
      expect(back.waiting, s1.waiting);
      expect(s2.replay(0).squares, s0.squares);
      expect(s2.replay(0).customStart, isNotNull);
    });
  });
}
