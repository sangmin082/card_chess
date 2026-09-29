import 'package:flutter/material.dart';

import '../../engine/engine.dart';
import '../theme.dart';
import 'piece_widget.dart';

/// 5×5 보드. 화면 위쪽이 a열(흑 진영), 아래쪽이 e열(백 진영).
/// 화면 가로 = rank(1~5), 세로 = file(a~e).
class BoardWidget extends StatefulWidget {
  const BoardWidget({
    super.key,
    required this.state,
    this.selectedFrom,
    this.movable = const {},
    this.targets = const [],
    this.lastMove,
    this.hint,
    this.onTap,
    this.showCoordinates = true,
  });

  final GameState state;
  final Pos? selectedFrom;
  final Set<Pos> movable;
  final List<Move> targets;
  final Move? lastMove;

  /// AI 추천 수. 출발/도착 칸에 점선 테두리를 그린다.
  final Move? hint;
  final ValueChanged<Pos>? onTap;
  final bool showCoordinates;

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> {
  /// 애니메이션을 위한 말 식별자. 위치 → id.
  Map<Pos, int> _ids = {};
  int _nextId = 0;
  List<Move>? _seenHistory;

  @override
  void initState() {
    super.initState();
    _rebuildIds();
  }

  void _rebuildIds() {
    _ids = {};
    for (final c in PlayerColor.values) {
      for (final p in widget.state.piecesOf(c)) {
        _ids[p] = _nextId++;
      }
    }
    _seenHistory = widget.state.history;
  }

  @override
  void didUpdateWidget(covariant BoardWidget old) {
    super.didUpdateWidget(old);
    final h = widget.state.history;
    final prev = _seenHistory;
    if (prev != null &&
        h.length == prev.length + 1 &&
        !h.last.isPass &&
        _ids.containsKey(h.last.from)) {
      // 한 수 진행: from 의 id 를 to 로 옮긴다.
      final m = h.last;
      final id = _ids.remove(m.from!)!;
      _ids[m.to!] = id;
      _seenHistory = h;
    } else if (prev != null && h.length == prev.length + 1 && h.last.isPass) {
      _seenHistory = h;
    } else if (prev == null || h.length != prev.length || !identical(h, prev)) {
      _rebuildIds();
    }
    // 보드와 id 맵이 어긋났으면 다시 만든다.
    for (final p in _ids.keys) {
      if (widget.state.pieceAt(p) == null) {
        _rebuildIds();
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth;
          final margin = widget.showCoordinates ? side * 0.06 : 0.0;
          final boardSide = side - margin;
          final cell = boardSide / Pos.size;
          return Stack(
            children: [
              if (widget.showCoordinates) ..._coordinates(margin, cell),
              Positioned(
                left: margin,
                top: 0,
                width: boardSide,
                height: boardSide,
                child: _board(cell),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _coordinates(double margin, double cell) {
    final style = TextStyle(
      fontSize: cell * 0.22,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return [
      for (var file = 0; file < Pos.size; file++)
        Positioned(
          left: 0,
          top: file * cell,
          width: margin,
          height: cell,
          child: Center(child: Text('abcde'[file], style: style)),
        ),
      for (var rank = 0; rank < Pos.size; rank++)
        Positioned(
          left: margin + rank * cell,
          top: Pos.size * cell,
          width: cell,
          height: margin,
          child: Center(child: Text('${rank + 1}', style: style)),
        ),
    ];
  }

  Offset _offsetOf(Pos p, double cell) => Offset(p.rank * cell, p.file * cell);

  Widget _board(double cell) {
    final state = widget.state;
    final targetsByPos = {for (final m in widget.targets) m.to!: m};
    final squares = <Widget>[];
    for (var i = 0; i < Pos.size * Pos.size; i++) {
      final p = Pos.fromIndex(i);
      final isDark = (p.file + p.rank).isOdd;
      final isCastle =
          p == PlayerColor.white.castle || p == PlayerColor.black.castle;
      final target = targetsByPos[p];
      final isLast =
          widget.lastMove != null &&
          !widget.lastMove!.isPass &&
          (widget.lastMove!.from == p || widget.lastMove!.to == p);
      final isHint =
          widget.hint != null &&
          !widget.hint!.isPass &&
          (widget.hint!.from == p || widget.hint!.to == p);
      final o = _offsetOf(p, cell);
      squares.add(
        Positioned(
          left: o.dx,
          top: o.dy,
          width: cell,
          height: cell,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap == null ? null : () => widget.onTap!(p),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.boardDark : AppColors.boardLight,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isCastle) Container(color: AppColors.castleTint),
                  if (isCastle)
                    Center(
                      child: Icon(
                        Icons.castle,
                        size: cell * 0.6,
                        color: Colors.black.withValues(alpha: 0.18),
                      ),
                    ),
                  if (isLast) Container(color: AppColors.lastMove),
                  if (isHint)
                    Container(
                      margin: EdgeInsets.all(cell * 0.06),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.hint,
                          width: cell * 0.07,
                        ),
                        borderRadius: BorderRadius.circular(cell * 0.12),
                      ),
                    ),
                  if (widget.selectedFrom == p)
                    Container(color: AppColors.selected),
                  if (widget.movable.contains(p) && widget.selectedFrom != p)
                    Center(
                      child: Container(
                        width: cell * 0.9,
                        height: cell * 0.9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.selected,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  if (target != null)
                    Center(
                      child: target.capture
                          ? Container(
                              width: cell * 0.92,
                              height: cell * 0.92,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.capture,
                                  width: cell * 0.09,
                                ),
                              ),
                            )
                          : Container(
                              width: cell * 0.36,
                              height: cell * 0.36,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.highlight,
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final pieces = <Widget>[];
    for (final entry in _ids.entries) {
      final piece = state.pieceAt(entry.key);
      if (piece == null) continue;
      final o = _offsetOf(entry.key, cell);
      pieces.add(
        AnimatedPositioned(
          key: ValueKey('piece-${entry.value}'),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          left: o.dx,
          top: o.dy,
          width: cell,
          height: cell,
          child: IgnorePointer(
            child: Center(
              child: PieceView(piece: piece, size: cell * 0.82),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(children: [...squares, ...pieces]),
    );
  }
}
