/// 3세트 매치 진행.
library;

import 'game_state.dart';
import 'model.dart';

class SetRecord {
  const SetRecord({required this.index, required this.firstPlayer, required this.result, required this.history});
  final int index;
  final PlayerColor firstPlayer;
  final GameResult result;
  final List<Move> history;
}

/// 매치 상태: 세트 스코어와 다음 세트의 선공을 관리한다.
class MatchState {
  MatchState({
    required this.firstPlayerOfSet1,
    this.setsToWin = 2,
    this.maxSets = 3,
    this.playerNames = const {PlayerColor.white: '백', PlayerColor.black: '흑'},
    this.options = RuleOptions.standard,
  });

  final PlayerColor firstPlayerOfSet1;
  final int setsToWin;
  final int maxSets;
  final Map<PlayerColor, String> playerNames;
  final RuleOptions options;

  final List<SetRecord> sets = [];

  int wins(PlayerColor c) => sets.where((s) => s.result.winner == c).length;

  PlayerColor? get matchWinner {
    for (final c in PlayerColor.values) {
      if (wins(c) >= setsToWin) return c;
    }
    return null;
  }

  bool get isOver => matchWinner != null || sets.length >= maxSets;

  /// 다음 세트 번호 (1부터).
  int get nextSetIndex => sets.length + 1;

  /// 다음 세트의 선공. 세트마다 교대한다.
  PlayerColor get nextFirstPlayer =>
      sets.length.isEven ? firstPlayerOfSet1 : firstPlayerOfSet1.opponent;

  /// 다음 세트에서 카드를 배치하는 플레이어 (후공).
  PlayerColor get nextCardPlacer => nextFirstPlayer.opponent;

  GameState startSet(CardPlacement placement) {
    if (isOver) throw StateError('매치가 이미 끝났습니다.');
    return GameState.initial(
      firstPlayer: nextFirstPlayer,
      placement: placement,
      options: options,
    );
  }

  void recordSet(GameState finished) {
    if (!finished.isOver) throw ArgumentError('끝나지 않은 세트입니다.');
    sets.add(SetRecord(
      index: nextSetIndex,
      firstPlayer: finished.firstPlayer,
      result: finished.result!,
      history: finished.history,
    ));
  }
}
