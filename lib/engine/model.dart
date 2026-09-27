/// 카드 체스 엔진의 기본 모델. Flutter 의존성이 없는 순수 Dart.
library;

/// 플레이어 색. 기보상 백은 e열, 흑은 a열에서 시작한다.
enum PlayerColor {
  white,
  black;

  PlayerColor get opponent => this == white ? black : white;

  String get korean => this == white ? '백' : '흑';

  /// 시작 열(file). 백 = e(4), 흑 = a(0).
  int get homeFile => this == white ? 4 : 0;

  /// 초기 바라보는 방향.
  Facing get initialFacing =>
      this == white ? Facing.minusFile : Facing.plusFile;

  /// 성의 위치. 시작 줄의 중앙 칸.
  Pos get castle => Pos(homeFile, 2);
}

/// 카드 종류. 점퍼는 조건 충족 시 퀸으로 변한다.
enum CardType {
  rook('R', '룩'),
  bishop('B', '비숍'),
  attacker('A', '어태커'),
  knight('N', '나이트'),
  jumper('J', '점퍼'),
  queen('Q', '퀸');

  const CardType(this.symbol, this.korean);

  final String symbol;
  final String korean;

  static CardType fromSymbol(String s) {
    for (final c in CardType.values) {
      if (c.symbol == s.toUpperCase()) return c;
    }
    throw FormatException('알 수 없는 카드 기호: $s');
  }

  /// 카드의 이동 규칙 설명.
  String get description => switch (this) {
    rook => '상하좌우 방향으로 한 칸 이동한다.',
    bishop => '대각선 네 방향으로 한 칸 이동한다.',
    attacker => '바라보는 방향으로 직진 최대 두 칸, 또는 전방 대각선 두 방향으로 한 칸 이동한다. 경로에 다른 말이 있으면 뛰어넘을 수 없다.',
    knight => '상하좌우로 두 칸 직진 후 수직 방향으로 한 칸 이동한다. 다른 말을 뛰어넘을 수 있다.',
    jumper =>
      '인접한 8칸에 자기 말이 있을 때만 그 말을 뛰어넘어 이동한다. 보드 위에 말이 두 개만 남으면 즉시 퀸으로 바뀐다.',
    queen => '상하좌우 및 대각선 방향으로 한 칸 이동한다.',
  };
}

/// 세트 시작 시 사용하는 5장.
const List<CardType> initialCards = [
  CardType.rook,
  CardType.bishop,
  CardType.attacker,
  CardType.knight,
  CardType.jumper,
];

/// 말이 바라보는 방향. 열(file) 축을 따라 이동한다.
enum Facing {
  minusFile(-1),
  plusFile(1);

  const Facing(this.df);

  /// 전진 시 file 변화량.
  final int df;

  Facing get flipped => this == minusFile ? plusFile : minusFile;

  /// 이 방향으로 진행했을 때 도달하는 마지막 열.
  int get lastFile => this == minusFile ? 0 : 4;
}

/// 보드 좌표. file: a~e = 0~4, rank: 1~5 = 0~4.
class Pos {
  const Pos(this.file, this.rank);

  factory Pos.parse(String s) {
    if (s.length != 2) throw FormatException('좌표 형식 오류: $s');
    final file = 'abcde'.indexOf(s[0].toLowerCase());
    final rank = int.tryParse(s[1]);
    if (file < 0 || rank == null || rank < 1 || rank > 5) {
      throw FormatException('좌표 형식 오류: $s');
    }
    return Pos(file, rank - 1);
  }

  final int file;
  final int rank;

  static const int size = 5;

  bool get onBoard => file >= 0 && file < size && rank >= 0 && rank < size;

  int get index => file * size + rank;

  static Pos fromIndex(int i) => Pos(i ~/ size, i % size);

  Pos offset(int df, int dr) => Pos(file + df, rank + dr);

  String get algebraic => '${'abcde'[file]}${rank + 1}';

  /// 체비쇼프 거리.
  int distanceTo(Pos other) {
    final df = (file - other.file).abs();
    final dr = (rank - other.rank).abs();
    return df > dr ? df : dr;
  }

  @override
  bool operator ==(Object other) =>
      other is Pos && other.file == file && other.rank == rank;

  @override
  int get hashCode => index;

  @override
  String toString() => algebraic;
}

/// 보드 위의 말.
class Piece {
  const Piece(this.owner, this.facing);

  final PlayerColor owner;
  final Facing facing;

  Piece withFacing(Facing f) => Piece(owner, f);

  @override
  bool operator ==(Object other) =>
      other is Piece && other.owner == owner && other.facing == facing;

  @override
  int get hashCode => Object.hash(owner, facing);

  @override
  String toString() => '${owner.name}(${facing.name})';
}

/// 착수. [from]이 null이면 이동 없이 카드만 교환하는 패스.
class Move {
  const Move({
    required this.card,
    required this.from,
    required this.to,
    this.capture = false,
  });

  const Move.pass(this.card) : from = null, to = null, capture = false;

  final CardType card;
  final Pos? from;
  final Pos? to;
  final bool capture;

  bool get isPass => from == null;

  /// 기보 표기. 예: `Na1→c2x`, 패스는 `N-pass`.
  String get notation {
    if (isPass) return '${card.symbol}-pass';
    return '${card.symbol}$from→$to${capture ? 'x' : ''}';
  }

  /// `Na1→c2x` 형식 파싱. 화살표는 `→`, `-`, `>` 를 허용한다.
  factory Move.parse(String text) {
    final s = text.trim();
    if (s.isEmpty) throw FormatException('빈 착수');
    final card = CardType.fromSymbol(s[0]);
    final rest = s.substring(1);
    if (rest == '-pass' || rest == 'pass') return Move.pass(card);
    final m = RegExp(r'^([a-eA-E][1-5])\s*(?:→|->|-|>)\s*([a-eA-E][1-5])(x?)$')
        .firstMatch(rest);
    if (m == null) throw FormatException('착수 형식 오류: $text');
    return Move(
      card: card,
      from: Pos.parse(m.group(1)!),
      to: Pos.parse(m.group(2)!),
      capture: m.group(3) == 'x',
    );
  }

  /// 카드/출발/도착이 같은지 (capture 여부 무시).
  bool sameAs(Move other) =>
      card == other.card && from == other.from && to == other.to;

  @override
  bool operator ==(Object other) =>
      other is Move && sameAs(other) && other.capture == capture;

  @override
  int get hashCode => Object.hash(card, from, to, capture);

  @override
  String toString() => notation;
}

/// 세트 승리 사유.
enum WinReason {
  /// 상대 말을 모두 제거.
  annihilation('전멸'),

  /// 상대 성을 점령하고 한 턴을 버팀.
  castle('성 점령'),

  /// 상대가 둘 수 있는 수가 없음 (noMovePolicy = lose 인 경우).
  noMoves('착수 불가');

  const WinReason(this.korean);
  final String korean;
}

class GameResult {
  const GameResult(this.winner, this.reason);

  final PlayerColor winner;
  final WinReason reason;

  @override
  bool operator ==(Object other) =>
      other is GameResult && other.winner == winner && other.reason == reason;

  @override
  int get hashCode => Object.hash(winner, reason);

  @override
  String toString() => '${winner.korean} 승리 (${reason.korean})';
}

/// 두 카드 모두 합법 수가 없을 때의 처리.
enum NoMovePolicy {
  /// 카드 한 장을 대기 존과 교환하고 턴을 넘긴다.
  pass,

  /// 즉시 패배한다.
  lose,
}

/// 하우스룰 옵션.
class RuleOptions {
  const RuleOptions({
    this.jumperOverEnemy = false,
    this.noMovePolicy = NoMovePolicy.pass,
  });

  /// 점퍼가 상대 말도 뛰어넘을 수 있는지. 원작 해석상 기본 false.
  final bool jumperOverEnemy;

  final NoMovePolicy noMovePolicy;

  static const standard = RuleOptions();
}

/// 세트 시작 시 후공이 정하는 카드 배치.
class CardPlacement {
  const CardPlacement({
    required this.firstPlayerHand,
    required this.secondPlayerHand,
    required this.waiting,
  });

  final List<CardType> firstPlayerHand;
  final List<CardType> secondPlayerHand;
  final CardType waiting;

  bool get isValid {
    if (firstPlayerHand.length != 2 || secondPlayerHand.length != 2) {
      return false;
    }
    final all = {...firstPlayerHand, ...secondPlayerHand, waiting};
    return all.length == 5 && all.containsAll(initialCards);
  }

  /// 가능한 모든 배치 (30가지).
  static List<CardPlacement> all() {
    final result = <CardPlacement>[];
    final cards = initialCards;
    for (var i = 0; i < 5; i++) {
      for (var j = i + 1; j < 5; j++) {
        final second = [cards[i], cards[j]];
        final rest = [
          for (var k = 0; k < 5; k++)
            if (k != i && k != j) cards[k],
        ];
        for (var w = 0; w < 3; w++) {
          final first = [
            for (var k = 0; k < 3; k++)
              if (k != w) rest[k],
          ];
          result.add(
            CardPlacement(
              firstPlayerHand: first,
              secondPlayerHand: second,
              waiting: rest[w],
            ),
          );
        }
      }
    }
    return result;
  }
}
