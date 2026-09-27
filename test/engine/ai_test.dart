import 'dart:math';

import 'package:card_chess/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI', () {
    test('1수 승리(전멸)를 찾는다', () {
      final s = originalSet1.replayAll()[22];
      final ai = AiPlayer(AiLevel.normal, random: Random(1));
      final r = ai.search(s)!;
      expect(r.move.notation, 'Nd1→b2x');
      expect(s.applyUnchecked(r.move).result?.winner, PlayerColor.white);
    });

    test('성에 올라온 상대 말을 잡아 패배를 막는다', () {
      var s = GameState.initial(
        firstPlayer: PlayerColor.white,
        placement: const CardPlacement(
          firstPlayerHand: [CardType.knight, CardType.jumper],
          secondPlayerHand: [CardType.rook, CardType.bishop],
          waiting: CardType.attacker,
        ),
      );
      for (final m in 'Ne1→c2 Ra1→b1 Ac2→b2 Na2→c3 Rb2→c2 Aa3→b3 Nc2→a3'.split(
        ' ',
      )) {
        s = s.apply(Move.parse(m));
      }
      final ai = AiPlayer(AiLevel.normal);
      final r = ai.search(s)!;
      expect(r.move.to, Pos.parse('a3'));
      expect(r.move.capture, isTrue);
    });

    test('카드 배치는 항상 유효', () {
      for (final level in AiLevel.values) {
        final ai = AiPlayer(level, random: Random(3));
        final p = ai.choosePlacement(PlayerColor.white, depth: 1);
        expect(p.isValid, isTrue);
      }
    });

    test('보통 난이도가 무작위 플레이어를 압도한다', () {
      final rng = Random(11);
      var aiWins = 0;
      const games = 12;
      for (var g = 0; g < games; g++) {
        final aiColor = g.isEven ? PlayerColor.white : PlayerColor.black;
        final ai = AiPlayer(AiLevel.normal, random: Random(g));
        final first = g % 4 < 2 ? PlayerColor.white : PlayerColor.black;
        final placement = first.opponent == aiColor
            ? ai.choosePlacement(first, depth: 1)
            : CardPlacement.all()[rng.nextInt(30)];
        var s = GameState.initial(firstPlayer: first, placement: placement);
        while (!s.isOver && s.moveNumber < 200) {
          if (s.toMove == aiColor) {
            s = s.applyUnchecked(
              ai.search(s, maxDepth: 2, timeLimitMs: 5000)!.move,
            );
          } else {
            final moves = s.legalMoves();
            s = s.applyUnchecked(moves[rng.nextInt(moves.length)]);
          }
        }
        if (s.result?.winner == aiColor) aiWins++;
      }
      expect(aiWins, greaterThanOrEqualTo(games - 1));
    });
  });
}
