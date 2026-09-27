/// AI 플레이어: 네가맥스 + 알파베타 + 반복 심화.
library;

import 'dart:math';

import 'game_state.dart';
import 'model.dart';
import 'move_gen.dart';

enum AiLevel {
  easy('쉬움', maxDepth: 1, timeLimitMs: 200, randomness: 0.5),
  normal('보통', maxDepth: 3, timeLimitMs: 800, randomness: 0.0),
  hard('어려움', maxDepth: 8, timeLimitMs: 1500, randomness: 0.0);

  const AiLevel(
    this.korean, {
    required this.maxDepth,
    required this.timeLimitMs,
    required this.randomness,
  });

  final String korean;
  final int maxDepth;
  final int timeLimitMs;

  /// 0이면 항상 최선 수, 1에 가까울수록 자주 차선 수를 고른다.
  final double randomness;
}

const int _win = 100000;
const int _inf = 1 << 30;

class _TimeUp implements Exception {
  const _TimeUp();
}

/// 탐색 결과.
class SearchResult {
  const SearchResult({
    required this.move,
    required this.score,
    required this.depth,
    required this.nodes,
    required this.elapsedMs,
  });

  final Move move;

  /// 둘 차례 플레이어 관점의 점수.
  final int score;
  final int depth;
  final int nodes;
  final int elapsedMs;
}

class AiPlayer {
  AiPlayer(this.level, {Random? random}) : _random = random ?? Random();

  final AiLevel level;
  final Random _random;

  int _nodes = 0;
  late Stopwatch _clock;
  int _limitMs = 0;

  /// [state]에서 둘 수를 고른다. 게임이 끝났으면 null.
  Move? chooseMove(GameState state) => search(state)?.move;

  /// 반복 심화 탐색.
  SearchResult? search(GameState state, {int? maxDepth, int? timeLimitMs}) {
    if (state.isOver) return null;
    final moves = _ordered(state, state.legalMoves());
    if (moves.isEmpty) return null;

    _nodes = 0;
    _clock = Stopwatch()..start();
    _limitMs = timeLimitMs ?? level.timeLimitMs;
    final depthCap = maxDepth ?? level.maxDepth;

    var bestMoves = <(Move, int)>[(moves.first, 0)];
    var bestDepth = 0;

    for (var depth = 1; depth <= depthCap; depth++) {
      try {
        final scored = <(Move, int)>[];
        var alpha = -_inf;
        for (final m in moves) {
          final v = -_negamax(state.applyUnchecked(m), depth - 1, -_inf, -alpha, 1);
          scored.add((m, v));
          if (v > alpha) alpha = v;
        }
        scored.sort((a, b) => b.$2.compareTo(a.$2));
        bestMoves = scored;
        bestDepth = depth;
        // 다음 반복에서 좋은 수부터 보도록 재정렬.
        moves
          ..clear()
          ..addAll(scored.map((e) => e.$1));
        // 확실한 승리를 찾았으면 더 깊이 볼 필요 없다.
        if (scored.first.$2 >= _win - 100) break;
      } on _TimeUp {
        break;
      }
    }

    final pick = _pickWithRandomness(bestMoves);
    return SearchResult(
      move: pick.$1,
      score: pick.$2,
      depth: bestDepth,
      nodes: _nodes,
      elapsedMs: _clock.elapsedMilliseconds,
    );
  }

  (Move, int) _pickWithRandomness(List<(Move, int)> scored) {
    if (level.randomness <= 0 || scored.length == 1) return scored.first;
    final best = scored.first.$2;
    // 즉시 지는 수는 절대 고르지 않는다.
    final candidates = scored.where((e) => e.$2 > -(_win - 100)).toList();
    if (candidates.isEmpty) return scored.first;
    if (_random.nextDouble() >= level.randomness) return candidates.first;
    // 상위 3개 중 무작위. 단 최선이 즉시 승리면 그대로.
    if (best >= _win - 100) return scored.first;
    final top = candidates.take(3).toList();
    return top[_random.nextInt(top.length)];
  }

  int _negamax(GameState s, int depth, int alpha, int beta, int ply) {
    _nodes++;
    if ((_nodes & 1023) == 0 && _clock.elapsedMilliseconds > _limitMs) {
      throw const _TimeUp();
    }
    if (s.isOver) {
      return s.result!.winner == s.toMove ? _win - ply : -(_win - ply);
    }
    if (depth <= 0) return evaluate(s, s.toMove);

    final moves = _ordered(s, s.legalMoves());
    var best = -_inf;
    var a = alpha;
    for (final m in moves) {
      final v = -_negamax(s.applyUnchecked(m), depth - 1, -beta, -a, ply + 1);
      if (v > best) best = v;
      if (best > a) a = best;
      if (a >= beta) break;
    }
    return best;
  }

  /// 잡는 수, 성으로 가는 수를 앞에 둔다.
  List<Move> _ordered(GameState s, List<Move> moves) {
    final enemyCastle = s.toMove.opponent.castle;
    int key(Move m) {
      var k = 0;
      if (m.capture) k += 10;
      if (m.to == enemyCastle) k += 5;
      return k;
    }

    final list = List<Move>.of(moves);
    list.sort((x, y) => key(y).compareTo(key(x)));
    return list;
  }

  /// 후공일 때 카드 배치를 고른다. [firstPlayer]가 먼저 둔다.
  CardPlacement choosePlacement(
    PlayerColor firstPlayer, {
    RuleOptions options = RuleOptions.standard,
    int depth = 3,
  }) {
    _nodes = 0;
    _clock = Stopwatch()..start();
    _limitMs = 1 << 30;
    CardPlacement? best;
    var bestScore = -_inf;
    final scored = <(CardPlacement, int)>[];
    for (final p in CardPlacement.all()) {
      final s = GameState.initial(
        firstPlayer: firstPlayer,
        placement: p,
        options: options,
      );
      // 선공 관점 점수를 뒤집어 후공(배치자) 관점으로.
      final v = -_negamax(s, depth, -_inf, _inf, 0);
      scored.add((p, v));
      if (v > bestScore) {
        bestScore = v;
        best = p;
      }
    }
    if (level.randomness > 0) {
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      final top = scored.take(5).toList();
      return top[_random.nextInt(top.length)].$1;
    }
    return best!;
  }
}

/// [pov] 관점의 정적 평가.
int evaluate(GameState s, PlayerColor pov) {
  if (s.result != null) return s.result!.winner == pov ? _win : -_win;
  final opp = pov.opponent;
  var score = 0;

  var myCount = 0;
  var oppCount = 0;
  for (var i = 0; i < s.squares.length; i++) {
    final p = s.squares[i];
    if (p == null) continue;
    final pos = Pos.fromIndex(i);
    if (p.owner == pov) {
      myCount++;
      score += (4 - pos.distanceTo(opp.castle)) * 4;
    } else {
      oppCount++;
      score -= (4 - pos.distanceTo(pov.castle)) * 4;
    }
  }
  score += (myCount - oppCount) * 100;

  // 성 점령 위협.
  if (s.pieceAt(opp.castle)?.owner == pov) score += 80;
  if (s.pieceAt(pov.castle)?.owner == opp) score -= 80;

  // 기동력: 손에 든 카드로 둘 수 있는 수의 개수.
  var myMob = 0;
  for (final c in s.hand(pov)) {
    myMob += generateMoves(s, c, pov).length;
  }
  var oppMob = 0;
  for (final c in s.hand(opp)) {
    oppMob += generateMoves(s, c, opp).length;
  }
  score += (myMob - oppMob) * 3;

  // 점퍼 부담: 말이 적을수록 점퍼는 짐이 된다.
  if (s.hand(opp).contains(CardType.jumper) && oppCount <= 2) score += 15;
  if (s.hand(pov).contains(CardType.jumper) && myCount <= 2) score -= 15;

  return score;
}
