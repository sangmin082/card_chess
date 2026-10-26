import 'package:flutter/foundation.dart';

import '../engine/engine.dart';
import 'lessons.dart';

/// 튜토리얼 진행 상태. 사용자는 항상 백이다.
class TutorialController extends ChangeNotifier {
  TutorialController({
    List<TutorialStep>? steps,
    this.replyDelay = const Duration(milliseconds: 700),
  }) : steps = steps ?? tutorialSteps {
    _load(0);
  }

  final List<TutorialStep> steps;
  final Duration replyDelay;

  int index = 0;
  late GameState state;
  CardType? selectedCard;
  Pos? selectedFrom;
  Move? lastMove;
  Move? hint;

  /// 현재 단계의 목표를 이뤘는지.
  bool completed = false;

  /// 상대가 응수하는 중인지.
  bool busy = false;

  String? feedback;
  bool feedbackIsError = false;

  int _token = 0;
  bool _disposed = false;

  TutorialStep get step => steps[index];
  bool get isFirst => index == 0;
  bool get isLast => index == steps.length - 1;
  bool get canAdvance => !busy && (!step.isInteractive || completed);
  double get progress => (index + 1) / steps.length;

  void _load(int i) {
    _token++;
    index = i;
    state = step.setup();
    selectedCard = null;
    selectedFrom = null;
    lastMove = null;
    hint = null;
    completed = false;
    busy = false;
    feedback = null;
    feedbackIsError = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void next() {
    if (!canAdvance || isLast) return;
    _load(index + 1);
  }

  void previous() {
    if (isFirst) return;
    _load(index - 1);
  }

  void restart() => _load(index);

  // ---------------------------------------------------------------- 입력

  /// 지금 보드를 조작할 수 있는지.
  bool get interactive =>
      step.isInteractive &&
      !completed &&
      !busy &&
      !state.isOver &&
      state.toMove == PlayerColor.white;

  List<Move> get _legal => interactive ? state.legalMoves() : const [];

  Set<Pos> get movablePieces {
    if (!interactive) {
      return {for (final s in step.focus) Pos.parse(s)};
    }
    return {
      for (final m in _legal)
        if (!m.isPass && (selectedCard == null || m.card == selectedCard))
          m.from!,
    };
  }

  List<Move> get targets {
    final from = selectedFrom;
    if (!interactive || from == null) return const [];
    return _legal
        .where(
          (m) =>
              m.from == from &&
              (selectedCard == null || m.card == selectedCard),
        )
        .toList();
  }

  void selectCard(CardType card) {
    if (!interactive) return;
    selectedCard = selectedCard == card ? null : card;
    if (selectedCard != null &&
        selectedFrom != null &&
        !_legal.any((m) => m.card == card && m.from == selectedFrom)) {
      selectedFrom = null;
    }
    _notify();
  }

  /// 칸을 눌렀을 때. 두 카드로 모두 갈 수 있는 칸이면 후보를 돌려준다.
  List<Move> tapSquare(Pos pos) {
    if (!interactive) return const [];
    final hits = targets.where((m) => m.to == pos).toList();
    if (hits.length == 1) {
      playMove(hits.first);
      return const [];
    }
    if (hits.length > 1) return hits;
    final piece = state.pieceAt(pos);
    selectedFrom =
        piece != null && piece.owner == PlayerColor.white && selectedFrom != pos
        ? pos
        : null;
    _notify();
    return const [];
  }

  void showHint() {
    final h = step.hintMove;
    if (!interactive || h == null) return;
    hint = h;
    selectedCard = h.card;
    selectedFrom = h.from;
    _notify();
  }

  Future<void> playMove(Move move) async {
    if (!interactive) return;
    final legal = state.legalMoves().where((m) => m.sameAs(move));
    if (legal.isEmpty) return;
    final m = legal.first;
    final after = state.applyUnchecked(m);
    selectedCard = null;
    selectedFrom = null;
    hint = null;

    if (!step.goal!(m, after)) {
      feedback = '조금 다릅니다. ${step.task ?? '다시 해 보세요.'}';
      feedbackIsError = true;
      _notify();
      return;
    }

    state = after;
    lastMove = m;
    feedback = null;
    if (step.opponentReplies && !after.isOver) {
      busy = true;
      _notify();
      final token = _token;
      await Future<void>.delayed(replyDelay);
      if (_disposed || token != _token) return;
      final replies = state.legalMoves();
      if (replies.isNotEmpty) {
        // 설명용 응수: 잡지 않는 수를 먼저 고른다.
        final reply = replies.firstWhere(
          (r) => !r.capture,
          orElse: () => replies.first,
        );
        state = state.applyUnchecked(reply);
        lastMove = reply;
      }
      busy = false;
    }
    completed = true;
    feedback = step.success;
    feedbackIsError = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _token++;
    super.dispose();
  }
}
