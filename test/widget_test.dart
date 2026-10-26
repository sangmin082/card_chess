import 'package:card_chess/engine/engine.dart';
import 'package:card_chess/main.dart';
import 'package:card_chess/state/game_controller.dart';
import 'package:card_chess/ui/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('홈 화면에 메뉴가 보인다', (tester) async {
    await tester.pumpWidget(const CardChessApp());
    expect(find.text('카드 체스'), findsOneWidget);
    expect(find.text('AI 대전'), findsOneWidget);
    expect(find.text('로컬 2인 대전'), findsOneWidget);
    expect(find.text('규칙'), findsOneWidget);
  });

  testWidgets('로컬 대전: 카드 배치 후 카드→말→목적지 탭으로 착수', (tester) async {
    final controller = GameController(
      mode: const LocalMode(),
      firstPlayerOfSet1: PlayerColor.white,
    );
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );
    expect(find.text('카드 배치'), findsOneWidget);

    controller.startSet(
      const CardPlacement(
        firstPlayerHand: [CardType.rook, CardType.jumper],
        secondPlayerHand: [CardType.bishop, CardType.attacker],
        waiting: CardType.knight,
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.phase, Phase.playing);

    controller.selectCard(CardType.rook);
    controller.tapSquare(Pos.parse('e3'));
    expect(controller.highlightedMoves.map((m) => m.to!.algebraic), ['d3']);
    controller.tapSquare(Pos.parse('d3'));
    await tester.pumpAndSettle();
    expect(controller.game!.moveNumber, 1);
    expect(controller.game!.toMove, PlayerColor.black);
    expect(controller.lastMove!.notation, 'Re3→d3');
    expect(find.text('Re3→d3'), findsNothing);
  });
}
