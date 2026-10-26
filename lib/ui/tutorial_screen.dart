import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../state/app_settings.dart';
import '../state/game_controller.dart';
import '../tutorial/tutorial_controller.dart';
import 'game_screen.dart';
import 'widgets/board_widget.dart';
import 'widgets/card_widget.dart';

/// 보드를 직접 조작하며 규칙을 배우는 튜토리얼.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, this.controller});

  /// 테스트에서 주입할 수 있다. null 이면 새로 만든다.
  final TutorialController? controller;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late final TutorialController c = widget.controller ?? TutorialController();

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
    if (!AppSettings.instance.tutorialSeen) {
      AppSettings.instance.update((s) => s.tutorialSeen = true);
    }
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    if (widget.controller == null) c.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _onTap(Pos p) async {
    final candidates = c.tapSquare(p);
    if (candidates.length < 2) return;
    final chosen = await showModalBottomSheet<Move>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '어떤 카드로 이동할까요?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final m in candidates)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: CardView(
                      card: m.card,
                      width: 96,
                      onTap: () => Navigator.pop(ctx, m),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (chosen != null) c.playMove(chosen);
  }

  void _startAiGame() {
    final s = AppSettings.instance;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          controller: GameController(
            mode: const AiMode(
              level: AiLevel.easy,
              humanColor: PlayerColor.white,
            ),
            firstPlayerOfSet1: PlayerColor.white,
            names: const {PlayerColor.white: '나', PlayerColor.black: 'AI(쉬움)'},
            options: s.ruleOptions,
            allowUndo: s.allowUndo,
            haptics: s.haptics,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('튜토리얼 ${c.index + 1}/${c.steps.length}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: c.progress),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > constraints.maxHeight * 1.1;
            final board = Padding(
              padding: const EdgeInsets.all(6),
              child: BoardWidget(
                state: c.state,
                selectedFrom: c.selectedFrom,
                movable: c.movablePieces,
                targets: c.targets,
                lastMove: c.lastMove,
                hint: c.hint,
                onTap: c.interactive ? _onTap : null,
              ),
            );
            final side = [
              _lessonPanel(scheme),
              _hand(PlayerColor.black, scheme),
              if (!wide) Expanded(child: Center(child: board)),
              _hand(PlayerColor.white, scheme),
              _buttons(scheme),
            ];
            if (wide) {
              return Row(
                children: [
                  Expanded(child: Center(child: board)),
                  SizedBox(width: 360, child: Column(children: side)),
                ],
              );
            }
            return Column(children: side);
          },
        ),
      ),
    );
  }

  Widget _lessonPanel(ColorScheme scheme) {
    final step = c.step;
    final fb = c.feedback;
    String? status;
    if (c.busy) {
      status = '상대가 생각 중…';
    } else if (step.isInteractive && !c.completed) {
      status = step.task;
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 190),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                step.body,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
              ),
              if (status != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.touch_app, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        status,
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (fb != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      c.feedbackIsError
                          ? Icons.info_outline
                          : Icons.check_circle,
                      size: 18,
                      color: c.feedbackIsError ? scheme.error : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        fb,
                        style: TextStyle(
                          color: c.feedbackIsError
                              ? scheme.error
                              : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _hand(PlayerColor color, ColorScheme scheme) {
    final mine = color == PlayerColor.white;
    final hand = c.state.hand(color);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              mine ? '내 카드' : '상대 카드',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: mine ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          for (final card in hand)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: CardView(
                card: card,
                width: mine ? 70 : 52,
                selected: mine && c.selectedCard == card,
                enabled: !mine || c.interactive || !c.step.isInteractive,
                onTap: mine && c.interactive ? () => c.selectCard(card) : null,
              ),
            ),
          if (mine) ...[
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '대기 존',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                CardView(card: c.state.waiting, width: 48, enabled: false),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buttons(ColorScheme scheme) {
    if (c.isLast) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('홈으로'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _startAiGame,
                icon: const Icon(Icons.smart_toy),
                label: const Text('AI 와 한 판 (쉬움)'),
              ),
            ),
          ],
        ),
      );
    }
    final step = c.step;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
      child: Row(
        children: [
          IconButton(
            tooltip: '이전',
            onPressed: c.isFirst ? null : c.previous,
            icon: const Icon(Icons.chevron_left),
          ),
          if (step.isInteractive) ...[
            TextButton.icon(
              onPressed: c.interactive && step.hint != null ? c.showHint : null,
              icon: const Icon(Icons.lightbulb_outline, size: 18),
              label: const Text('힌트'),
            ),
            TextButton.icon(
              onPressed: c.busy ? null : c.restart,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('다시'),
            ),
          ],
          const Spacer(),
          FilledButton(
            onPressed: c.canAdvance ? c.next : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('다음'), Icon(Icons.chevron_right, size: 18)],
            ),
          ),
        ],
      ),
    );
  }
}
