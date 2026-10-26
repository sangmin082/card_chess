import 'package:card_chess/engine/engine.dart';
import 'package:card_chess/tutorial/lessons.dart';
import 'package:card_chess/tutorial/tutorial_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('튜토리얼 단계', () {
    test('모든 단계의 국면이 만들어진다', () {
      for (final step in tutorialSteps) {
        final s = step.setup();
        expect(s.isOver, isFalse, reason: step.title);
        for (final f in step.focus) {
          expect(() => Pos.parse(f), returnsNormally, reason: step.title);
        }
      }
    });

    test('조작 단계는 백 차례이고, 힌트 수가 합법이며 목표를 이룬다', () {
      for (final step in tutorialSteps.where((s) => s.isInteractive)) {
        final s = step.setup();
        expect(s.toMove, PlayerColor.white, reason: step.title);
        expect(step.hint, isNotNull, reason: step.title);
        expect(step.task, isNotNull, reason: step.title);
        expect(step.success, isNotNull, reason: step.title);
        final hint = step.hintMove!;
        final legal = s.legalMoves().where((m) => m.sameAs(hint)).toList();
        expect(legal, hasLength(1), reason: '${step.title}: ${hint.notation}');
        final after = s.applyUnchecked(legal.first);
        expect(step.goal!(legal.first, after), isTrue, reason: step.title);
        expect(
          legal.first.capture,
          hint.capture,
          reason: '${step.title} 잡음 표기',
        );
      }
    });

    test('조작 단계마다 목표가 아닌 합법 수도 있다 (틀린 수 안내가 의미 있음)', () {
      for (final step in tutorialSteps.where((s) => s.isInteractive)) {
        final s = step.setup();
        final wrong = s.legalMoves().where(
          (m) => !step.goal!(m, s.applyUnchecked(m)),
        );
        expect(wrong, isNotEmpty, reason: step.title);
      }
    });

    test('성 점령 단계: 상대가 어떻게 두어도 백이 성 점령으로 이긴다', () {
      final step = tutorialSteps.firstWhere((s) => s.opponentReplies);
      final s = step.setup();
      final after = s.apply(step.hintMove!);
      expect(after.isOver, isFalse);
      for (final reply in after.legalMoves()) {
        final end = after.applyUnchecked(reply);
        expect(
          end.result,
          const GameResult(PlayerColor.white, WinReason.castle),
          reason: reply.notation,
        );
      }
    });
  });

  group('TutorialController', () {
    test('설명 단계는 바로 넘어가고, 조작 단계는 목표를 이뤄야 넘어간다', () async {
      final c = TutorialController(replyDelay: Duration.zero);
      expect(c.step.isInteractive, isFalse);
      expect(c.canAdvance, isTrue);
      c.next();
      c.next();
      expect(c.step.isInteractive, isTrue);
      expect(c.canAdvance, isFalse);

      // 틀린 수: 비숍은 이 단계 목표가 아니다.
      final wrong = c.state.legalMoves().firstWhere(
        (m) => m.card == CardType.bishop,
      );
      final before = c.state;
      await c.playMove(wrong);
      expect(c.feedbackIsError, isTrue);
      expect(c.state, same(before));
      expect(c.canAdvance, isFalse);

      // 힌트대로 두기: 카드 선택 → 말 선택 → 칸 탭.
      c.showHint();
      expect(c.selectedCard, CardType.rook);
      expect(c.targets.map((m) => m.to!.algebraic), contains('d3'));
      c.tapSquare(Pos.parse('d3'));
      await Future<void>.delayed(Duration.zero);
      expect(c.completed, isTrue);
      expect(c.feedbackIsError, isFalse);
      expect(c.canAdvance, isTrue);
      expect(c.interactive, isFalse);
    });

    test('성 점령 단계는 상대 응수 뒤 승리로 끝난다', () async {
      final c = TutorialController(replyDelay: Duration.zero);
      final i = c.steps.indexWhere((s) => s.opponentReplies);
      while (c.index < i) {
        if (!c.canAdvance) {
          await c.playMove(c.step.hintMove!);
        }
        c.next();
      }
      await c.playMove(c.step.hintMove!);
      expect(c.completed, isTrue);
      expect(c.state.result?.reason, WinReason.castle);
      expect(c.state.result?.winner, PlayerColor.white);
    });

    test('모든 단계를 힌트로 끝까지 진행할 수 있다', () async {
      final c = TutorialController(replyDelay: Duration.zero);
      var guard = 0;
      while (!c.isLast && guard++ < 100) {
        if (c.step.isInteractive) {
          c.showHint();
          await c.playMove(c.step.hintMove!);
          expect(c.completed, isTrue, reason: c.step.title);
        }
        c.next();
      }
      expect(c.isLast, isTrue);
      c.previous();
      expect(c.isLast, isFalse);
      c.restart();
      expect(c.completed, isFalse);
    });
  });
}
