import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'widgets/card_widget.dart';

/// 후공이 카드 5장을 [내 손 2 / 상대 손 2 / 대기 1]로 나누는 화면.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.placer,
    required this.placerName,
    required this.opponentName,
    required this.onConfirm,
  });

  final PlayerColor placer;
  final String placerName;
  final String opponentName;
  final ValueChanged<CardPlacement> onConfirm;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

enum _Slot { mine, theirs, waiting }

class _SetupScreenState extends State<SetupScreen> {
  final Map<CardType, _Slot?> _assign = {for (final c in initialCards) c: null};

  int _count(_Slot s) => _assign.values.where((v) => v == s).length;

  bool get _complete =>
      _count(_Slot.mine) == 2 &&
      _count(_Slot.theirs) == 2 &&
      _count(_Slot.waiting) == 1;

  int _limit(_Slot s) => s == _Slot.waiting ? 1 : 2;

  void _cycle(CardType c) {
    setState(() {
      final cur = _assign[c];
      final order = [null, _Slot.mine, _Slot.theirs, _Slot.waiting];
      var i = order.indexOf(cur);
      for (var k = 0; k < order.length; k++) {
        i = (i + 1) % order.length;
        final next = order[i];
        if (next == null || _count(next) < _limit(next)) {
          _assign[c] = next;
          return;
        }
      }
    });
  }

  void _put(CardType c, _Slot? slot) {
    setState(() {
      if (slot != null && _count(slot) >= _limit(slot) && _assign[c] != slot) {
        return;
      }
      _assign[c] = slot;
    });
  }

  CardPlacement _placement() {
    final mine = [
      for (final e in _assign.entries)
        if (e.value == _Slot.mine) e.key,
    ];
    final theirs = [
      for (final e in _assign.entries)
        if (e.value == _Slot.theirs) e.key,
    ];
    final waiting = _assign.entries
        .firstWhere((e) => e.value == _Slot.waiting)
        .key;
    return CardPlacement(
      firstPlayerHand: theirs,
      secondPlayerHand: mine,
      waiting: waiting,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pool = [
      for (final e in _assign.entries)
        if (e.value == null) e.key,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('카드 배치')),
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '후공 ${widget.placerName}(${widget.placer.korean})이 카드를 배치합니다.\n'
                '카드를 탭해 슬롯으로 보내거나, 슬롯 위로 드래그하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            _slot(_Slot.theirs, '${widget.opponentName} (선공) 손패', 2),
            _slot(_Slot.waiting, '대기 존', 1),
            _slot(_Slot.mine, '${widget.placerName} (후공) 손패', 2),
            const SizedBox(height: 12),
            Text(
              '남은 카드',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 130,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final c in pool)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _draggable(c, () => _cycle(c)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _complete
                      ? () => widget.onConfirm(_placement())
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('세트 시작'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _draggable(CardType c, VoidCallback onTap) {
    return LongPressDraggable<CardType>(
      data: c,
      delay: const Duration(milliseconds: 80),
      feedback: Material(
        color: Colors.transparent,
        child: CardView(card: c, width: 90),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: CardView(card: c, width: 84),
      ),
      child: CardView(card: c, width: 84, onTap: onTap),
    );
  }

  Widget _slot(_Slot slot, String title, int capacity) {
    final scheme = Theme.of(context).colorScheme;
    final cards = [
      for (final e in _assign.entries)
        if (e.value == slot) e.key,
    ];
    return DragTarget<CardType>(
      onWillAcceptWithDetails: (d) =>
          cards.length < capacity || cards.contains(d.data),
      onAcceptWithDetails: (d) => _put(d.data, slot),
      builder: (context, candidates, rejected) {
        final active = candidates.isNotEmpty;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active
                ? scheme.primaryContainer.withValues(alpha: 0.4)
                : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              for (var i = 0; i < capacity; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: i < cards.length
                      ? _draggable(cards[i], () => _put(cards[i], null))
                      : Container(
                          width: 84,
                          height: 112,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: scheme.outlineVariant,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Icon(Icons.add, color: scheme.outlineVariant),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}
