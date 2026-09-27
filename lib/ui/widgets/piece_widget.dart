import 'package:flutter/material.dart';

import '../../engine/engine.dart';
import '../theme.dart';

/// 말. 원형에 바라보는 방향의 화살표를 그린다.
class PieceView extends StatelessWidget {
  const PieceView({
    super.key,
    required this.piece,
    this.size = 40,
    this.dimmed = false,
  });

  final Piece piece;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PiecePainter(piece, dimmed)),
    );
  }
}

class _PiecePainter extends CustomPainter {
  _PiecePainter(this.piece, this.dimmed);

  final Piece piece;
  final bool dimmed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final isWhite = piece.owner == PlayerColor.white;
    final fill = isWhite ? AppColors.whitePiece : AppColors.blackPiece;
    final ink = isWhite ? AppColors.blackPiece : AppColors.whitePiece;
    canvas.drawCircle(
      c.translate(0, r * 0.08),
      r * 0.86,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      c,
      r * 0.86,
      Paint()..color = dimmed ? fill.withValues(alpha: 0.5) : fill,
    );
    canvas.drawCircle(
      c,
      r * 0.86,
      Paint()
        ..color = ink.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08,
    );
    // 방향 화살표. 화면 위쪽 = a열(-file).
    final up = piece.facing == Facing.minusFile;
    final dir = up ? -1.0 : 1.0;
    final path = Path()
      ..moveTo(c.dx, c.dy + dir * r * 0.55)
      ..lineTo(c.dx + r * 0.38, c.dy - dir * r * 0.15)
      ..lineTo(c.dx + r * 0.14, c.dy - dir * r * 0.15)
      ..lineTo(c.dx + r * 0.14, c.dy - dir * r * 0.5)
      ..lineTo(c.dx - r * 0.14, c.dy - dir * r * 0.5)
      ..lineTo(c.dx - r * 0.14, c.dy - dir * r * 0.15)
      ..lineTo(c.dx - r * 0.38, c.dy - dir * r * 0.15)
      ..close();
    canvas.drawPath(path, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(covariant _PiecePainter old) =>
      old.piece != piece || old.dimmed != dimmed;
}
