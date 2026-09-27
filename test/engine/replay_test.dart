import 'package:card_chess/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// 원작 진행표의 카드 열. 각 행: (선공 손패, 대기, 후공 손패). 0행은 준비 상태.
const _set1Cards = [
  ('R,J', 'N', 'B,A'),
  ('J,N', 'R', 'B,A'),
  ('J,N', 'B', 'R,A'),
  ('N,B', 'J', 'R,A'),
  ('N,B', 'R', 'J,A'),
  ('N,R', 'B', 'J,A'),
  ('N,R', 'J', 'B,A'),
  ('R,J', 'N', 'B,A'),
  ('R,J', 'B', 'N,A'),
  ('R,B', 'J', 'N,A'),
  ('R,B', 'A', 'J,N'),
  ('R,A', 'B', 'J,N'),
  ('R,A', 'N', 'B,J'),
  ('A,N', 'R', 'B,J'),
  ('A,N', 'B', 'R,J'),
  ('A,B', 'N', 'R,J'),
  ('A,B', 'J', 'N,R'),
  ('B,J', 'A', 'N,R'),
  ('B,J', 'R', 'A,N'),
  ('J,R', 'B', 'A,N'),
  ('J,R', 'N', 'B,A'),
  ('R,N', 'J', 'B,A'),
  ('R,N', 'B', 'J,A'),
  ('R,B', 'N', 'J,A'),
];

const _set2Cards = [
  ('J,A', 'R', 'B,N'),
  ('J,R', 'A', 'B,N'),
  ('J,R', 'B', 'A,N'),
  ('J,B', 'R', 'A,N'),
  ('J,B', 'N', 'R,A'),
  ('J,N', 'B', 'R,A'),
  ('J,N', 'R', 'B,A'),
  ('J,R', 'N', 'B,A'),
  ('J,R', 'B', 'N,A'),
  ('J,B', 'R', 'N,A'),
  ('J,B', 'N', 'R,A'),
  ('J,N', 'B', 'R,A'),
  ('J,N', 'R', 'B,A'),
  ('J,R', 'N', 'B,A'),
  ('J,R', 'A', 'N,B'),
  ('R,A', 'J', 'N,B'),
  ('R,A', 'B', 'J,N'),
  ('A,B', 'R', 'J,N'),
  ('A,B', 'N', 'R,J'),
  ('A,N', 'B', 'R,J'),
  ('A,N', 'J', 'B,R'),
  ('N,J', 'A', 'B,R'),
  ('N,J', 'R', 'A,B'),
];

Set<CardType> _cards(String s) =>
    s.split(',').map((e) => CardType.fromSymbol(e.trim())).toSet();

/// 원작 진행표는 1:1 이후에도 점퍼를 J로 적고 있다. 룰 원문대로 엔진은 퀸으로
/// 바꾸므로 비교 시 퀸을 점퍼로 정규화한다.
CardType _norm(CardType c) => c == CardType.queen ? CardType.jumper : c;

void _checkCards(
  List<GameState> states,
  PlayerColor first,
  List<(String, String, String)> table,
) {
  expect(states.length, table.length);
  for (var i = 0; i < table.length; i++) {
    final (f, w, s) = table[i];
    final st = states[i];
    expect(st.hand(first).map(_norm).toSet(), _cards(f), reason: '$i수 후 선공 손패');
    expect(_norm(st.waiting), CardType.fromSymbol(w), reason: '$i수 후 대기 존');
    expect(
      st.hand(first.opponent).map(_norm).toSet(),
      _cards(s),
      reason: '$i수 후 후공 손패',
    );
  }
}

void main() {
  group('원작 기보 재생', () {
    test('1세트: 23수 모두 합법, 백 승 (전멸), 백 2개 잔존', () {
      final states = originalSet1.replayAll();
      expect(states.length, 24);
      final last = states.last;
      expect(last.isOver, isTrue);
      expect(last.result!.winner, PlayerColor.white);
      expect(last.result!.reason, WinReason.annihilation);
      expect(last.pieceCount(PlayerColor.black), 0);
      expect(last.pieceCount(PlayerColor.white), 2);
      expect(last.pieceAt(Pos.parse('d2'))?.owner, PlayerColor.white);
      expect(last.pieceAt(Pos.parse('b2'))?.owner, PlayerColor.white);
      // 마지막 수 직전까지는 끝나지 않았어야 한다.
      for (final s in states.take(23)) {
        expect(s.isOver, isFalse, reason: '${s.moveNumber}수 후');
      }
    });

    test('1세트: 카드 흐름이 진행표와 일치', () {
      _checkCards(originalSet1.replayAll(), PlayerColor.white, _set1Cards);
    });

    test('1세트: 잡는 수(x) 표기가 엔진 판정과 일치', () {
      var s = originalSet1.initialState();
      for (final m in originalSet1.moves) {
        final legal = s.legalMoves().firstWhere((l) => l.sameAs(m));
        expect(legal.capture, m.capture, reason: m.notation);
        s = s.applyUnchecked(legal);
      }
    });

    test('2세트: 22수 모두 합법, 백 승 (전멸)', () {
      final states = originalSet2.replayAll();
      expect(states.length, 23);
      final last = states.last;
      expect(last.result!.winner, PlayerColor.white);
      expect(last.result!.reason, WinReason.annihilation);
      expect(last.pieceCount(PlayerColor.black), 0);
      for (final s in states.take(22)) {
        expect(s.isOver, isFalse, reason: '${s.moveNumber}수 후');
      }
    });

    test('2세트: 카드 흐름이 진행표와 일치', () {
      _checkCards(originalSet2.replayAll(), PlayerColor.black, _set2Cards);
    });

    test('2세트: 21수 후 1:1이 되면 점퍼가 퀸으로 바뀐다', () {
      final states = originalSet2.replayAll();
      expect(states[20].totalPieces, 3);
      expect(states[21].totalPieces, 2);
      expect(states[20].waiting, CardType.jumper);
      expect(states[21].hand(PlayerColor.black), contains(CardType.queen));
      expect(
        states[21].hand(PlayerColor.black),
        isNot(contains(CardType.jumper)),
      );
    });

    test('2세트: 잡는 수(x) 표기가 엔진 판정과 일치', () {
      var s = originalSet2.initialState();
      for (final m in originalSet2.moves) {
        final legal = s.legalMoves().firstWhere((l) => l.sameAs(m));
        expect(legal.capture, m.capture, reason: m.notation);
        s = s.applyUnchecked(legal);
      }
    });

    test('1세트 17수 Ac2→a2x 후 백 말이 a열에서 방향 전환', () {
      final s = originalSet1.replayAll()[17];
      final p = s.pieceAt(Pos.parse('a2'));
      expect(p?.owner, PlayerColor.white);
      expect(p?.facing, Facing.plusFile);
    });

    test('기보 직렬화 → 파싱 왕복', () {
      for (final k in originalGames) {
        final text = k.serialize();
        final parsed = KifuSet.parse(text);
        expect(parsed.moves, k.moves);
        expect(parsed.firstPlayer, k.firstPlayer);
        expect(parsed.winner, k.winner);
        expect(parsed.replayAll().last.result, isNotNull);
      }
    });

    test('GameState → KifuSet → 재생 결과 동일', () {
      final last = originalSet2.replayAll().last;
      final kifu = KifuSet.fromState(last, title: 'copy');
      final again = kifu.replayAll().last;
      expect(again.squares, last.squares);
      expect(again.result?.winner, last.result?.winner);
    });
  });
}
