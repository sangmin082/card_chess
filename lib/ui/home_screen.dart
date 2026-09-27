import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../state/game_controller.dart';
import 'game_screen.dart';
import 'replay_screen.dart';
import 'rules_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.castle, size: 72, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    '카드 체스',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '카드의 이동 규칙에 따라 말을 옮겨 상대의 말을 모두 잡아라',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 36),
                  FilledButton.icon(
                    onPressed: () => _startAi(context),
                    icon: const Icon(Icons.smart_toy),
                    label: const Text('AI 대전'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => _startLocal(context),
                    icon: const Icon(Icons.people),
                    label: const Text('로컬 2인 대전'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openReplay(context),
                    icon: const Icon(Icons.history),
                    label: const Text('원작 기보 보기'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const RulesScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.menu_book),
                    label: const Text('규칙'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startLocal(BuildContext context) async {
    final first = await _pickFirst(context, '선공 선택');
    if (first == null || !context.mounted) return;
    _push(
      context,
      GameController(mode: const LocalMode(), firstPlayerOfSet1: first),
    );
  }

  Future<void> _startAi(BuildContext context) async {
    final cfg = await showDialog<_AiConfig>(
      context: context,
      builder: (_) => const _AiConfigDialog(),
    );
    if (cfg == null || !context.mounted) return;
    final first = switch (cfg.first) {
      _First.me => cfg.humanColor,
      _First.ai => cfg.humanColor.opponent,
      _First.random =>
        Random().nextBool() ? PlayerColor.white : PlayerColor.black,
    };
    _push(
      context,
      GameController(
        mode: AiMode(level: cfg.level, humanColor: cfg.humanColor),
        firstPlayerOfSet1: first,
        names: {
          cfg.humanColor: '나',
          cfg.humanColor.opponent: 'AI(${cfg.level.korean})',
        },
      ),
    );
  }

  void _push(BuildContext context, GameController controller) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(controller: controller),
      ),
    );
  }

  Future<PlayerColor?> _pickFirst(BuildContext context, String title) {
    return showDialog<PlayerColor>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, PlayerColor.white),
            child: const Text('백 선공 (흑이 카드 배치)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, PlayerColor.black),
            child: const Text('흑 선공 (백이 카드 배치)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
              ctx,
              Random().nextBool() ? PlayerColor.white : PlayerColor.black,
            ),
            child: const Text('무작위'),
          ),
        ],
      ),
    );
  }

  Future<void> _openReplay(BuildContext context) async {
    final kifu = await showDialog<KifuSet>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('원작 기보'),
        children: [
          for (final k in originalGames)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, k),
              child: Text(
                '${k.title} · ${k.playerNames[PlayerColor.white]}(백) vs '
                '${k.playerNames[PlayerColor.black]}(흑) · ${k.moves.length}수',
              ),
            ),
        ],
      ),
    );
    if (kifu == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ReplayScreen(kifu: kifu)),
    );
  }
}

enum _First { me, ai, random }

class _AiConfig {
  const _AiConfig(this.level, this.humanColor, this.first);
  final AiLevel level;
  final PlayerColor humanColor;
  final _First first;
}

class _AiConfigDialog extends StatefulWidget {
  const _AiConfigDialog();

  @override
  State<_AiConfigDialog> createState() => _AiConfigDialogState();
}

class _AiConfigDialogState extends State<_AiConfigDialog> {
  AiLevel _level = AiLevel.normal;
  PlayerColor _color = PlayerColor.white;
  _First _first = _First.random;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI 대전 설정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('난이도'),
          const SizedBox(height: 6),
          SegmentedButton<AiLevel>(
            showSelectedIcon: false,
            segments: [
              for (final l in AiLevel.values)
                ButtonSegment(value: l, label: Text(l.korean)),
            ],
            selected: {_level},
            onSelectionChanged: (s) => setState(() => _level = s.first),
          ),
          const SizedBox(height: 16),
          const Text('내 색'),
          const SizedBox(height: 6),
          SegmentedButton<PlayerColor>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: PlayerColor.white, label: Text('백')),
              ButtonSegment(value: PlayerColor.black, label: Text('흑')),
            ],
            selected: {_color},
            onSelectionChanged: (s) => setState(() => _color = s.first),
          ),
          const SizedBox(height: 16),
          const Text('1세트 선공'),
          const SizedBox(height: 6),
          SegmentedButton<_First>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _First.me, label: Text('나')),
              ButtonSegment(value: _First.ai, label: Text('AI')),
              ButtonSegment(value: _First.random, label: Text('무작위')),
            ],
            selected: {_first},
            onSelectionChanged: (s) => setState(() => _first = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _AiConfig(_level, _color, _first)),
          child: const Text('시작'),
        ),
      ],
    );
  }
}
