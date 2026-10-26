import 'package:flutter/material.dart';

import '../../engine/engine.dart';
import '../theme.dart';

/// 카드 한 장. 이동 패턴 다이어그램을 함께 그린다.
class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.card,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    this.width = 84,
    this.label,
  });

  final CardType card;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final double width;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = selected ? AppColors.selected : scheme.outlineVariant;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: width,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: selected ? 2.5 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.selected.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    card.symbol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: width * 0.22,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    card.korean,
                    style: TextStyle(
                      fontSize: width * 0.14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(painter: MovePatternPainter(card, scheme)),
              ),
              if (label != null) ...[
                const SizedBox(height: 4),
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: width * 0.13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 5×5 격자에 이동 패턴을 그린다. 위쪽이 전방이다.
class MovePatternPainter extends CustomPainter {
  MovePatternPainter(this.card, this.scheme);

  final CardType card;
  final ColorScheme scheme;

  /// (dx, dy): dx 오른쪽, dy 위쪽(전방). kind: 0 이동, 1 넘는 말(자기), 2 조건부.
  List<(int, int, int)> get _cells => switch (card) {
    CardType.rook => const [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0)],
    CardType.bishop => const [(1, 1, 0), (-1, 1, 0), (1, -1, 0), (-1, -1, 0)],
    CardType.queen => const [
      (1, 0, 0),
      (-1, 0, 0),
      (0, 1, 0),
      (0, -1, 0),
      (1, 1, 0),
      (-1, 1, 0),
      (1, -1, 0),
      (-1, -1, 0),
    ],
    CardType.attacker => const [(0, 1, 0), (0, 2, 2), (1, 1, 0), (-1, 1, 0)],
    CardType.knight => const [
      (1, 2, 0),
      (-1, 2, 0),
      (1, -2, 0),
      (-1, -2, 0),
      (2, 1, 0),
      (-2, 1, 0),
      (2, -1, 0),
      (-2, -1, 0),
    ],
    CardType.jumper => const [(0, 1, 1), (0, 2, 2), (1, 1, 1), (2, 2, 2)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 5;
    final grid = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (var i = 0; i <= 5; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), grid);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), grid);
    }
    Rect rectOf(int dx, int dy) =>
        Rect.fromLTWH((2 + dx) * cell, (2 - dy) * cell, cell, cell).deflate(1);

    for (final (dx, dy, kind) in _cells) {
      final paint = Paint()
        ..color = switch (kind) {
          0 => scheme.primary,
          1 => scheme.tertiary.withValues(alpha: 0.7),
          _ => scheme.primary.withValues(alpha: 0.45),
        };
      canvas.drawRect(rectOf(dx, dy), paint);
    }
    // 기준 말.
    final c = rectOf(0, 0).center;
    canvas.drawCircle(c, cell * 0.38, Paint()..color = scheme.onSurface);
    if (card == CardType.attacker || card == CardType.jumper) {
      // 방향 표시 화살.
      final p = Path()
        ..moveTo(c.dx, c.dy - cell * 0.3)
        ..lineTo(c.dx + cell * 0.2, c.dy + cell * 0.1)
        ..lineTo(c.dx - cell * 0.2, c.dy + cell * 0.1)
        ..close();
      canvas.drawPath(p, Paint()..color = scheme.surface);
    }
  }

  @override
  bool shouldRepaint(covariant MovePatternPainter old) =>
      old.card != card || old.scheme != scheme;
}
