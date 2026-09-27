/// 원작(피의 게임 파이널 3R) 기보. 엔진 회귀 테스트와 앱 내 재생에 사용한다.
library;

import 'kifu.dart';

const String originalSet1Text = '''
title: 1세트
first: white
white: R,J
black: B,A
waiting: N
names: white=강지후, black=윤비
moves: Re3→d3 Ba4→b3 Je5→e3 Ra5→b5 Be1→d2
  Ja2→c4 Ne3→c4x Bb5→c4x Je2→c4x Ab3→c4x
  Bd3→c4x Na3→b1 Re4→d4 Bb1→a2 Nd4→c2
  Ja1→a3 Ac2→a2x Ra3→a2x Bc4→d3 Na2→c1
  Jd3→d1 Bc1→b2 Nd1→b2x
winner: white
''';

const String originalSet2Text = '''
title: 2세트
first: black
black: J,A
white: B,N
waiting: R
names: white=강지후, black=윤비
moves: Aa3→b3 Be1→d2 Rb3→a3 Ne5→d3 Ba4→b5
  Re4→d4 Nb5→d4x Be3→d4x Ra3→a4 Ne2→c3
  Ba2→b3 Rc3→b3x Na1→b3x Ad3→b3x Ja5→a3
  Bb3→a4x Ra3→a4x Nd2→c4 Ba4→b5 Jd4→b4
  Ab5→c4x Rb4→c4x
winner: white
''';

/// 기보 텍스트의 "moves:" 줄 이어짐을 처리한다 (들여쓴 줄은 이전 줄에 붙인다).
String _joinContinuations(String text) {
  final out = <String>[];
  for (final line in text.split('\n')) {
    if (line.startsWith(' ') || line.startsWith('\t')) {
      if (out.isNotEmpty) out[out.length - 1] += ' ${line.trim()}';
    } else {
      out.add(line);
    }
  }
  return out.join('\n');
}

final KifuSet originalSet1 = KifuSet.parse(_joinContinuations(originalSet1Text));
final KifuSet originalSet2 = KifuSet.parse(_joinContinuations(originalSet2Text));

final List<KifuSet> originalGames = [originalSet1, originalSet2];
