import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/engine.dart';
import '../state/game_controller.dart';
import 'setup_screen.dart';
import 'widgets/board_widget.dart';
import 'widgets/card_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController get c => widget.controller;
  Phase? _dialogShownFor;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    c.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    if ((c.phase == Phase.setOver || c.phase == Phase.matchOver) &&
        _dialogShownFor != c.phase) {
      _dialogShownFor = c.phase;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
    if (c.phase == Phase.playing) _dialogShownFor = null;
  }

  Future<void> _showResult() async {
    final g = c.game!;
    final r = g.result!;
    final m = c.match;
    final matchOver = c.phase == Phase.matchOver;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(matchOver ? '매치 종료' : '${m.sets.length}세트 종료'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${c.nameOf(r.winner)}(${r.winner.korean}) 승리 · ${r.reason.korean}',
            ),
            const SizedBox(height: 8),
            Text(
              '세트 스코어  ${c.nameOf(PlayerColor.white)} ${m.wins(PlayerColor.white)} : '
              '${m.wins(PlayerColor.black)} ${c.nameOf(PlayerColor.black)}',
            ),
            if (matchOver) ...[
              const SizedBox(height: 8),
              Text(
                '최종 우승: ${c.nameOf(m.matchWinner!)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _copyKifu(ctx),
            child: const Text('기보 복사'),
          ),
          if (matchOver)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('홈으로'),
            )
          else
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                c.nextSet();
              },
              child: Text('${m.sets.length + 1}세트 시작'),
            ),
        ],
      ),
    );
  }

  Future<void> _copyKifu(BuildContext ctx) async {
    await Clipboard.setData(ClipboardData(text: c.kifuText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('기보를 복사했습니다.')));
  }

  Future<void> _onTapSquare(Pos p) async {
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
                      width: 100,
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

  @override
  Widget build(BuildContext context) {
    if (c.phase == Phase.placement) {
      if (c.aiThinking || !c.mode.isHuman(c.placer)) {
        return Scaffold(
          appBar: AppBar(title: Text('${c.match.nextSetIndex}세트 준비')),
          body: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('AI가 카드를 배치하는 중…'),
              ],
            ),
          ),
        );
      }
      return SetupScreen(
        key: ValueKey('setup-${c.match.nextSetIndex}'),
        placer: c.placer,
        placerName: c.nameOf(c.placer),
        opponentName: c.nameOf(c.placer.opponent),
        onConfirm: c.startSet,
      );
    }
    final g = c.game!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${c.match.sets.length + (g.isOver ? 0 : 1)}세트 · ${c.mode.label}',
        ),
        actions: [
          IconButton(
            tooltip: '무르기',
            onPressed: c.canUndo ? c.undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: '기보 복사',
            onPressed: () => _copyKifu(context),
            icon: const Icon(Icons.content_copy),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > constraints.maxHeight * 1.1;
            final board = Padding(
              padding: const EdgeInsets.all(8),
              child: BoardWidget(
                state: g,
                selectedFrom: c.selectedFrom,
                movable: c.movablePieces,
                targets: c.highlightedMoves,
                lastMove: c.lastMove,
                onTap: _onTapSquare,
              ),
            );
            final top = _handPanel(PlayerColor.black, scheme);
            final bottom = _handPanel(PlayerColor.white, scheme);
            final status = _statusBar(g, scheme);
            if (wide) {
              return Row(
                children: [
                  Expanded(child: Center(child: board)),
                  SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        top,
                        const Spacer(),
                        status,
                        const Spacer(),
                        bottom,
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                top,
                Expanded(child: Center(child: board)),
                status,
                bottom,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statusBar(GameState g, ColorScheme scheme) {
    final m = c.match;
    String text;
    if (g.isOver) {
      text = '${c.nameOf(g.result!.winner)} 승리 · ${g.result!.reason.korean}';
    } else if (c.aiThinking) {
      text = 'AI 생각 중…';
    } else if (c.mustPass) {
      text = '둘 수 있는 수가 없습니다. 교환할 카드를 고르세요.';
    } else if (c.selectedCard == null && c.selectedFrom == null) {
      text = '${c.nameOf(g.toMove)}(${g.toMove.korean}) 차례 · 카드 또는 말을 선택';
    } else if (c.selectedFrom == null) {
      text = '${c.selectedCard!.korean}로 움직일 말을 선택';
    } else {
      text = '목적지를 선택';
    }
    final intruderW = g.intruderOf(PlayerColor.white);
    final intruderB = g.intruderOf(PlayerColor.black);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '대기 존',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              CardView(card: g.waiting, width: 56, enabled: false),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (c.aiThinking)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    Flexible(child: Text(text, textAlign: TextAlign.center)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${g.moveNumber}수 · 세트 ${m.wins(PlayerColor.white)}:${m.wins(PlayerColor.black)}'
                  '${intruderW != null ? ' · 백이 흑 성 점령 중!' : ''}'
                  '${intruderB != null ? ' · 흑이 백 성 점령 중!' : ''}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _handPanel(PlayerColor color, ColorScheme scheme) {
    final g = c.game!;
    final active = g.toMove == color && !g.isOver;
    final hand = g.hand(color);
    final isMine = c.isHumanTurn && active;
    final captured = 5 - g.pieceCount(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? scheme.primary.withValues(alpha: 0.12) : null,
        border: Border(
          top: color == PlayerColor.white
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
          bottom: color == PlayerColor.black
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color == PlayerColor.white
                            ? Colors.white
                            : Colors.black,
                        border: Border.all(color: scheme.outline),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      c.nameOf(color),
                      style: TextStyle(
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.play_arrow, size: 16, color: scheme.primary),
                    ],
                  ],
                ),
                Text(
                  '말 ${g.pieceCount(color)}개 · 잃음 $captured',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (g.firstPlayer == color)
                  Text(
                    '선공',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          for (final card in hand)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: CardView(
                card: card,
                width: 78,
                selected: isMine && c.selectedCard == card,
                enabled: !active || isMine || c.aiThinking,
                onTap: isMine
                    ? () => c.mustPass ? c.pass(card) : c.selectCard(card)
                    : null,
                label: isMine && c.mustPass ? '교환' : null,
              ),
            ),
        ],
      ),
    );
  }
}
