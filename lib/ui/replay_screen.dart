import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'widgets/board_widget.dart';
import 'widgets/card_widget.dart';

/// 기보 재생 화면.
class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key, required this.kifu});

  final KifuSet kifu;

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  late final List<GameState> _states = widget.kifu.replayAll();
  int _index = 0;

  void _go(int i) => setState(() => _index = i.clamp(0, _states.length - 1));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = _states[_index];
    final names = widget.kifu.playerNames;
    String name(PlayerColor c) => names[c] ?? c.korean;
    final last = _index == 0 ? null : widget.kifu.moves[_index - 1];
    return Scaffold(
      appBar: AppBar(title: Text('기보 · ${widget.kifu.title}')),
      body: SafeArea(
        child: Column(
          children: [
            _hand(s, PlayerColor.black, name(PlayerColor.black), scheme),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: BoardWidget(state: s, lastMove: last),
                ),
              ),
            ),
            _hand(s, PlayerColor.white, name(PlayerColor.white), scheme),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _index == 0
                    ? '시작 배치 · 선공 ${name(widget.kifu.firstPlayer)}'
                    : '$_index수 ${s.toMove.opponent.korean} ${last!.notation}'
                          '${s.isOver ? ' · ${s.result}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (_states.length > 1)
              Slider(
                value: _index.toDouble(),
                min: 0,
                max: (_states.length - 1).toDouble(),
                divisions: _states.length - 1,
                onChanged: (v) => _go(v.round()),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _go(0),
                  icon: const Icon(Icons.first_page),
                ),
                IconButton(
                  onPressed: () => _go(_index - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('$_index / ${_states.length - 1}'),
                IconButton(
                  onPressed: () => _go(_index + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  onPressed: () => _go(_states.length - 1),
                  icon: const Icon(Icons.last_page),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _hand(
    GameState s,
    PlayerColor color,
    String name,
    ColorScheme scheme,
  ) {
    final active = s.toMove == color && !s.isOver;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$name (${color.korean}) · 말 ${s.pieceCount(color)}개',
              style: TextStyle(
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          for (final card in s.hand(color))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: CardView(card: card, width: 60),
            ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '대기',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
              CardView(card: s.waiting, width: 44, enabled: false),
            ],
          ),
        ],
      ),
    );
  }
}
