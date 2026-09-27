import 'dart:math';

import 'package:card_chess/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('무작위 플레이 불변식: 카드 5장 유지, 말 단조 감소, 예외 없음', () {
    final rng = Random(42);
    var finished = 0;
    var castleWins = 0;
    const games = 1500;
    const maxMoves = 400;
    for (var g = 0; g < games; g++) {
      final placements = CardPlacement.all();
      var s = GameState.initial(
        firstPlayer: g.isEven ? PlayerColor.white : PlayerColor.black,
        placement: placements[rng.nextInt(placements.length)],
      );
      var pieces = s.totalPieces;
      while (!s.isOver && s.moveNumber < maxMoves) {
        final moves = s.legalMoves();
        expect(moves, isNotEmpty, reason: '수가 없음:\n${s.toBoardString()}');
        s = s.applyUnchecked(moves[rng.nextInt(moves.length)]);
        final all = [...s.whiteHand, ...s.blackHand, s.waiting];
        expect(all.length, 5);
        final normalized = all
            .map((c) => c == CardType.queen ? CardType.jumper : c)
            .toSet();
        expect(normalized, initialCards.toSet(), reason: '카드 집합 깨짐: $all');
        expect(s.totalPieces <= pieces, isTrue);
        pieces = s.totalPieces;
        if (s.totalPieces == 2) {
          expect(all, isNot(contains(CardType.jumper)));
        } else if (s.totalPieces > 2) {
          expect(all, isNot(contains(CardType.queen)));
        }
      }
      if (s.isOver) {
        finished++;
        if (s.result!.reason == WinReason.castle) castleWins++;
        // 승리 판정 정합성.
        final w = s.result!.winner;
        if (s.result!.reason == WinReason.annihilation) {
          expect(s.pieceCount(w.opponent), 0);
        } else {
          expect(s.pieceAt(w.opponent.castle)?.owner, w);
        }
      }
    }
    // 무작위 플레이라도 대부분 끝나야 한다.
    expect(finished / games, greaterThan(0.9));
    expect(castleWins, greaterThan(0));
  });

  test('undo/replay 는 무작위 진행에서도 일치', () {
    final rng = Random(7);
    var s = GameState.initial(
      firstPlayer: PlayerColor.white,
      placement: CardPlacement.all()[5],
    );
    final trail = <GameState>[s];
    while (!s.isOver && s.moveNumber < 40) {
      final moves = s.legalMoves();
      s = s.applyUnchecked(moves[rng.nextInt(moves.length)]);
      trail.add(s);
    }
    for (var i = 0; i < trail.length; i++) {
      final r = s.replay(i);
      expect(r.squares, trail[i].squares, reason: '$i수');
      expect(r.whiteHand, trail[i].whiteHand);
      expect(r.blackHand, trail[i].blackHand);
      expect(r.waiting, trail[i].waiting);
      expect(r.result, trail[i].result);
    }
  });
}
