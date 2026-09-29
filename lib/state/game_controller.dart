import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../engine/engine.dart';

/// 대전 모드.
sealed class GameMode {
  const GameMode();

  bool isHuman(PlayerColor c);

  String get label;
}

class LocalMode extends GameMode {
  const LocalMode();

  @override
  bool isHuman(PlayerColor c) => true;

  @override
  String get label => '로컬 2인 대전';
}

class AiMode extends GameMode {
  const AiMode({required this.level, required this.humanColor});

  final AiLevel level;
  final PlayerColor humanColor;

  PlayerColor get aiColor => humanColor.opponent;

  @override
  bool isHuman(PlayerColor c) => c == humanColor;

  @override
  String get label => 'AI 대전 (${level.korean})';
}

/// 화면 단계.
enum Phase {
  /// 후공이 카드를 배치하는 중.
  placement,

  /// 세트 진행 중.
  playing,

  /// 세트가 끝나 결과를 보여주는 중.
  setOver,

  /// 매치 종료.
  matchOver,
}

/// 매치 한 판을 관리하는 컨트롤러.
class GameController extends ChangeNotifier {
  GameController({
    required this.mode,
    required PlayerColor firstPlayerOfSet1,
    Map<PlayerColor, String>? names,
    RuleOptions options = RuleOptions.standard,
    this.allowUndo = true,
    this.haptics = true,
    Random? random,
  }) : _random = random ?? Random(),
       match = MatchState(
         firstPlayerOfSet1: firstPlayerOfSet1,
         playerNames:
             names ??
             {
               PlayerColor.white:
                   mode is AiMode && mode.humanColor != PlayerColor.white
                   ? 'AI'
                   : '백',
               PlayerColor.black:
                   mode is AiMode && mode.humanColor != PlayerColor.black
                   ? 'AI'
                   : '흑',
             },
         options: options,
       ) {
    _beginSet();
  }

  final GameMode mode;
  final MatchState match;
  final bool allowUndo;
  final bool haptics;
  final Random _random;

  Phase phase = Phase.placement;
  GameState? game;

  /// 선택 상태.
  CardType? selectedCard;
  Pos? selectedFrom;
  Move? lastMove;
  bool aiThinking = false;
  int _aiToken = 0;

  /// AI 가 추천한 수. 사용자가 다음 행동을 하면 사라진다.
  Move? hintMove;
  bool hintLoading = false;

  String nameOf(PlayerColor c) => match.playerNames[c] ?? c.korean;

  PlayerColor get placer => match.nextCardPlacer;

  bool get isHumanTurn =>
      game != null && !game!.isOver && mode.isHuman(game!.toMove);

  bool get canUndo =>
      allowUndo &&
      phase == Phase.playing &&
      isHumanTurn &&
      !aiThinking &&
      game != null &&
      game!.moveNumber >= (mode is AiMode ? 2 : 1);

  // ---------------------------------------------------------------- 세트 시작

  void _beginSet() {
    game = null;
    selectedCard = null;
    selectedFrom = null;
    lastMove = null;
    if (mode.isHuman(placer)) {
      phase = Phase.placement;
      notifyListeners();
    } else {
      phase = Phase.placement;
      notifyListeners();
      _aiPlacement();
    }
  }

  Future<void> _aiPlacement() async {
    final m = mode as AiMode;
    aiThinking = true;
    notifyListeners();
    final token = ++_aiToken;
    final placement = await compute(
      _placementEntry,
      _PlacementParams(
        m.level,
        match.nextFirstPlayer,
        match.options,
        _random.nextInt(1 << 31),
      ),
    );
    if (token != _aiToken) return;
    aiThinking = false;
    startSet(placement);
  }

  /// 카드 배치를 확정하고 세트를 시작한다.
  void startSet(CardPlacement placement) {
    game = match.startSet(placement);
    phase = Phase.playing;
    selectedCard = null;
    selectedFrom = null;
    lastMove = null;
    notifyListeners();
    _maybeAiMove();
  }

  // ---------------------------------------------------------------- 선택/착수

  List<Move> get _legal => game?.legalMoves() ?? const [];

  /// 현재 선택으로 갈 수 있는 목적지.
  List<Move> get highlightedMoves {
    if (!isHumanTurn || aiThinking) return const [];
    final from = selectedFrom;
    if (from == null) return const [];
    return _legal
        .where(
          (m) =>
              m.from == from &&
              (selectedCard == null || m.card == selectedCard),
        )
        .toList();
  }

  /// 선택한 카드로 움직일 수 있는 말들.
  Set<Pos> get movablePieces {
    if (!isHumanTurn || aiThinking) return const {};
    return {
      for (final m in _legal)
        if (!m.isPass && (selectedCard == null || m.card == selectedCard))
          m.from!,
    };
  }

  /// 패스만 가능한 상황인지.
  bool get mustPass =>
      isHumanTurn && _legal.isNotEmpty && _legal.every((m) => m.isPass);

  /// 현재 국면에서 AI 추천 수를 계산해 [hintMove] 에 넣는다.
  Future<void> requestHint() async {
    final g = game;
    if (g == null || g.isOver || !isHumanTurn || aiThinking || hintLoading) {
      return;
    }
    hintLoading = true;
    notifyListeners();
    final token = ++_aiToken;
    final move = await compute(
      _moveEntry,
      _MoveParams(AiLevel.hard, g, _random.nextInt(1 << 31)),
    );
    if (token != _aiToken || game != g) {
      hintLoading = false;
      notifyListeners();
      return;
    }
    hintLoading = false;
    hintMove = move;
    if (move != null && !move.isPass) {
      selectedCard = move.card;
      selectedFrom = move.from;
    }
    notifyListeners();
  }

  void selectCard(CardType card) {
    if (!isHumanTurn || aiThinking) return;
    hintMove = null;
    if (selectedCard == card) {
      selectedCard = null;
    } else {
      selectedCard = card;
      // 선택한 말이 이 카드로 움직일 수 없으면 선택 해제.
      if (selectedFrom != null &&
          !_legal.any((m) => m.card == card && m.from == selectedFrom)) {
        selectedFrom = null;
      }
    }
    notifyListeners();
  }

  /// 칸 탭 처리. 이동/선택/취소를 결정한다. 카드 선택이 모호하면 후보를 돌려준다.
  List<Move> tapSquare(Pos pos) {
    if (!isHumanTurn || aiThinking) return const [];
    hintMove = null;
    final g = game!;
    final targets = highlightedMoves.where((m) => m.to == pos).toList();
    if (targets.isNotEmpty) {
      if (targets.length == 1) {
        playMove(targets.first);
        return const [];
      }
      return targets; // 카드가 두 장 다 가능: UI에서 선택.
    }
    final piece = g.pieceAt(pos);
    if (piece != null && piece.owner == g.toMove) {
      selectedFrom = selectedFrom == pos ? null : pos;
    } else {
      selectedFrom = null;
    }
    notifyListeners();
    return const [];
  }

  void playMove(Move move) {
    final g = game;
    if (g == null || g.isOver) return;
    game = g.apply(move);
    lastMove = move;
    selectedCard = null;
    selectedFrom = null;
    hintMove = null;
    if (haptics) {
      if (move.capture) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
    _afterMove();
  }

  /// [color]가 기권한다. 세트가 즉시 끝난다.
  void resign(PlayerColor color) {
    final g = game;
    if (g == null || g.isOver || phase != Phase.playing) return;
    _aiToken++;
    aiThinking = false;
    game = g.resign(color);
    selectedCard = null;
    selectedFrom = null;
    _afterMove();
  }

  void pass(CardType card) {
    if (!mustPass) return;
    playMove(Move.pass(card));
  }

  void _afterMove() {
    final g = game!;
    if (g.isOver) {
      match.recordSet(g);
      phase = match.isOver ? Phase.matchOver : Phase.setOver;
      notifyListeners();
      return;
    }
    notifyListeners();
    _maybeAiMove();
  }

  Future<void> _maybeAiMove() async {
    final g = game;
    if (g == null || g.isOver || mode.isHuman(g.toMove)) return;
    final m = mode as AiMode;
    aiThinking = true;
    notifyListeners();
    final token = ++_aiToken;
    // 사람이 착수 결과를 볼 시간을 준다.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final move = await compute(
      _moveEntry,
      _MoveParams(m.level, g, _random.nextInt(1 << 31)),
    );
    if (token != _aiToken || game != g) return;
    aiThinking = false;
    if (move == null) return;
    playMove(move);
  }

  void undo() {
    if (!canUndo) return;
    final steps = mode is AiMode ? 2 : 1;
    final back = game!.undo(count: steps);
    if (back == null) return;
    _aiToken++; // 계산 중인 힌트는 버린다.
    hintLoading = false;
    game = back;
    lastMove = back.history.isEmpty ? null : back.history.last;
    selectedCard = null;
    selectedFrom = null;
    hintMove = null;
    notifyListeners();
  }

  /// 다음 세트로.
  void nextSet() {
    if (phase != Phase.setOver) return;
    _beginSet();
  }

  /// 현재(또는 마지막) 세트의 기보 텍스트.
  String kifuText() {
    final g = game;
    if (g == null) return '';
    return KifuSet.fromState(
      g,
      title: '${match.sets.length + (g.isOver ? 0 : 1)}세트',
      playerNames: match.playerNames,
    ).serialize();
  }

  @override
  void dispose() {
    _aiToken++;
    super.dispose();
  }
}

// ------------------------------------------------------------------ isolate

class _MoveParams {
  const _MoveParams(this.level, this.state, this.seed);
  final AiLevel level;
  final GameState state;
  final int seed;
}

Move? _moveEntry(_MoveParams p) =>
    AiPlayer(p.level, random: Random(p.seed)).chooseMove(p.state);

class _PlacementParams {
  const _PlacementParams(this.level, this.firstPlayer, this.options, this.seed);
  final AiLevel level;
  final PlayerColor firstPlayer;
  final RuleOptions options;
  final int seed;
}

CardPlacement _placementEntry(_PlacementParams p) =>
    AiPlayer(p.level, random: Random(p.seed)).choosePlacement(
      p.firstPlayer,
      options: p.options,
      depth: p.level == AiLevel.hard ? 4 : 2,
    );
