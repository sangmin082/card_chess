import 'package:card_chess/engine/engine.dart';
import 'package:card_chess/main.dart';
import 'package:card_chess/state/app_settings.dart';
import 'package:card_chess/state/game_controller.dart';
import 'package:card_chess/tutorial/tutorial_controller.dart';
import 'package:card_chess/ui/game_screen.dart';
import 'package:card_chess/ui/tutorial_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('처음 실행하면 튜토리얼을 권한다', (tester) async {
    AppSettings.instance.tutorialSeen = false;
    await tester.pumpWidget(const CardChessApp());
    await tester.pumpAndSettle();
    expect(find.text('처음이신가요?'), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();
    expect(find.text('처음이신가요?'), findsNothing);
    expect(AppSettings.instance.tutorialSeen, isTrue);
  });

  testWidgets('튜토리얼 화면: 다음으로 넘기고 힌트로 첫 조작 단계를 푼다', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = TutorialController(replyDelay: Duration.zero);
    await tester.pumpWidget(MaterialApp(home: TutorialScreen(controller: c)));
    expect(find.text('카드 체스에 오신 걸 환영합니다'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('성'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('카드로 말 움직이기'), findsOneWidget);
    await tester.tap(find.text('힌트'));
    await tester.pumpAndSettle();
    c.tapSquare(Pos.parse('d3'));
    await tester.pumpAndSettle();
    expect(find.textContaining('잘했어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('홈 화면에 메뉴가 보인다', (tester) async {
    AppSettings.instance.tutorialSeen = true;
    await tester.pumpWidget(const CardChessApp());
    expect(find.text('카드 체스'), findsOneWidget);
    expect(find.text('AI 대전'), findsOneWidget);
    expect(find.text('로컬 2인 대전'), findsOneWidget);
    expect(find.text('규칙'), findsOneWidget);
    expect(find.text('튜토리얼'), findsOneWidget);
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
