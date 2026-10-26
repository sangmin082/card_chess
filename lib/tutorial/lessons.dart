/// 튜토리얼 단계 정의. 각 단계는 보드 국면, 설명, (있다면) 목표 수로 이루어진다.
library;

import '../engine/engine.dart';

/// 사용자가 둔 수가 이 단계의 목표를 이뤘는지 판단한다.
typedef MoveGoal = bool Function(Move move, GameState after);

class TutorialStep {
  const TutorialStep({
    required this.title,
    required this.body,
    required this.setup,
    this.goal,
    this.task,
    this.success,
    this.hint,
    this.opponentReplies = false,
    this.focus = const [],
  });

  final String title;
  final String body;

  /// 이 단계의 시작 국면. 항상 백(사용자) 차례로 만든다.
  final GameState Function() setup;

  /// null 이면 설명만 있는 단계 ("다음" 으로 넘어간다).
  final MoveGoal? goal;

  /// 상태 줄에 보여 줄 짧은 지시.
  final String? task;

  /// 목표를 이뤘을 때 보여 줄 말.
  final String? success;

  /// 힌트로 보여 줄 수 (기보 표기).
  final String? hint;

  /// 목표를 이룬 뒤 상대(흑)가 한 수 응수한다.
  final bool opponentReplies;

  /// 설명 단계에서 강조할 칸.
  final List<String> focus;

  bool get isInteractive => goal != null;

  Move? get hintMove => hint == null ? null : Move.parse(hint!);
}

// ------------------------------------------------------------------ 국면 도우미

const _w = PlayerColor.white;
const _b = PlayerColor.black;

List<CardType> _cards(String s) =>
    s.split(',').map((e) => CardType.fromSymbol(e.trim())).toList();

GameState _custom({
  required List<String> white,
  required List<String> black,
  required String whiteHand,
  required String blackHand,
  required String waiting,
  Map<String, Facing> facing = const {},
}) {
  final pieces = <Pos, Piece>{
    for (final s in white)
      Pos.parse(s): Piece(_w, facing[s] ?? _w.initialFacing),
    for (final s in black)
      Pos.parse(s): Piece(_b, facing[s] ?? _b.initialFacing),
  };
  return GameState.custom(
    pieces: pieces,
    toMove: _w,
    whiteHand: _cards(whiteHand),
    blackHand: _cards(blackHand),
    waiting: CardType.fromSymbol(waiting),
  );
}

GameState _standardStart() => GameState.initial(
  firstPlayer: _w,
  placement: const CardPlacement(
    firstPlayerHand: [CardType.rook, CardType.bishop],
    secondPlayerHand: [CardType.attacker, CardType.jumper],
    waiting: CardType.knight,
  ),
);

const _allBlack = ['a1', 'a2', 'a3', 'a4', 'a5'];
const _afterRook = ['e1', 'e2', 'd3', 'e4', 'e5'];

// ------------------------------------------------------------------ 단계

final List<TutorialStep> tutorialSteps = [
  TutorialStep(
    title: '카드 체스에 오신 걸 환영합니다',
    body:
        '5×5 보드에서 말 5개씩으로 겨루는 2인 전략 게임입니다.\n'
        '아래쪽 흰 말이 내 말, 위쪽 검은 말이 상대 말입니다.\n'
        '말에 그려진 화살표는 그 말이 바라보는 방향입니다.',
    setup: _standardStart,
  ),
  TutorialStep(
    title: '성',
    body:
        '양쪽 첫 줄 가운데 붉은 칸이 성입니다.\n'
        '아래 e3 이 내 성, 위 a3 이 상대 성입니다.\n'
        '상대 성을 차지하는 것도 이기는 방법 중 하나입니다.',
    setup: _standardStart,
    focus: ['e3', 'a3'],
  ),
  TutorialStep(
    title: '카드로 말 움직이기',
    body:
        '말은 카드에 적힌 규칙대로만 움직입니다.\n'
        '① 아래 내 카드 중 룩(R)을 누르고\n'
        '② 움직일 말을 누른 뒤\n'
        '③ 초록 점이 찍힌 칸을 누르세요.\n'
        '룩은 상하좌우로 한 칸 움직입니다.',
    setup: _standardStart,
    task: '룩(R) 카드로 말을 한 칸 움직여 보세요.',
    goal: (m, _) => m.card == CardType.rook,
    hint: 'Re3→d3',
    success: '잘했어요! 카드 그림의 칸이 말이 갈 수 있는 곳입니다.',
  ),
  TutorialStep(
    title: '카드는 돌고 돈다',
    body:
        '방금 쓴 룩은 가운데 대기 존으로 갔고, 대기 존에 있던 나이트가 내 손에 들어왔습니다.\n'
        '상대도 카드를 쓰면 대기 존의 카드를 가져가므로, 내가 쓴 카드는 곧 상대 손으로 넘어갑니다.\n'
        '어떤 카드를 쓰느냐가 곧 상대에게 무엇을 주느냐입니다.',
    setup: () => _standardStart().apply(Move.parse('Re3→d3')),
  ),
  TutorialStep(
    title: '비숍',
    body: '비숍은 대각선 네 방향으로 한 칸 움직입니다.',
    setup: () => _custom(
      white: _afterRook,
      black: _allBlack,
      whiteHand: 'B,N',
      blackHand: 'A,J',
      waiting: 'R',
    ),
    task: '비숍(B) 카드로 말을 대각선으로 움직여 보세요.',
    goal: (m, _) => m.card == CardType.bishop,
    hint: 'Bd3→c2',
    success: '좋아요!',
  ),
  TutorialStep(
    title: '나이트',
    body:
        '나이트는 두 칸 곧게 간 뒤 옆으로 한 칸 꺾어(ㄱ자) 이동합니다.\n'
        '가는 길에 다른 말이 있어도 뛰어넘을 수 있습니다.',
    setup: () => _custom(
      white: _afterRook,
      black: _allBlack,
      whiteHand: 'N,A',
      blackHand: 'B,J',
      waiting: 'R',
    ),
    task: '나이트(N) 카드로 말을 움직여 보세요.',
    goal: (m, _) => m.card == CardType.knight,
    hint: 'Ne2→c3',
    success: '좋아요! 나이트는 멀리 뛰는 대신 바로 옆 칸으로는 못 갑니다.',
  ),
  TutorialStep(
    title: '어태커와 잡기',
    body:
        '어태커는 말이 바라보는 방향(화살표)으로만 갑니다.\n'
        '앞으로 한 칸이나 두 칸, 또는 앞쪽 대각선 한 칸. 뒤로는 못 가고, 바로 앞이 막혀 있으면 두 칸도 못 갑니다.\n'
        '이동을 마친 칸에 상대 말이 있으면 그 말을 잡습니다.',
    setup: () => _custom(
      white: ['e1', 'e3', 'e5'],
      black: ['a1', 'a2', 'a4', 'a5', 'c3'],
      whiteHand: 'A,R',
      blackHand: 'N,J',
      waiting: 'B',
    ),
    task: '어태커(A)로 c3 의 상대 말을 잡아 보세요.',
    goal: (m, _) => m.card == CardType.attacker && m.capture,
    hint: 'Ae3→c3x',
    success: '잡았습니다! 붉은 테두리가 표시된 칸은 잡을 수 있는 칸입니다.',
  ),
  TutorialStep(
    title: '점퍼',
    body:
        '점퍼는 바로 옆(8방향)에 있는 내 말을 뛰어넘어야만 움직일 수 있습니다.\n'
        '옆에 내 말이 없으면 쓸 수 없는 카드라서, 말이 줄어들수록 짐이 됩니다.\n'
        '그래서 점퍼를 상대에게 떠넘기는 것이 중요한 전략입니다.',
    setup: () => _custom(
      white: ['e1', 'e3', 'd3', 'e5'],
      black: ['a1', 'a2', 'a4', 'a5', 'c3'],
      whiteHand: 'J,R',
      blackHand: 'B,N',
      waiting: 'A',
    ),
    task: '점퍼(J)로 d3 의 내 말을 뛰어넘어 c3 을 잡아 보세요.',
    goal: (m, _) => m.card == CardType.jumper,
    hint: 'Je3→c3x',
    success: '훌륭해요! 이제 점퍼는 대기 존으로 가서 상대가 가져가게 됩니다.',
  ),
  TutorialStep(
    title: '끝 줄에서 방향 바꾸기',
    body:
        '말이 바라보는 방향의 끝 줄에 닿으면 방향이 반대로 바뀝니다.\n'
        '어태커로 b2 의 말을 맨 윗줄로 보내 보세요.',
    setup: () => _custom(
      white: ['b2', 'e1', 'e5'],
      black: ['a3', 'a4', 'a5'],
      whiteHand: 'A,B',
      blackHand: 'N,J',
      waiting: 'R',
    ),
    task: '어태커(A)로 말을 맨 윗줄(a)까지 보내 보세요.',
    goal: (m, _) => m.card == CardType.attacker && m.to!.file == 0,
    hint: 'Ab2→a2',
    success: '화살표가 아래로 바뀌었죠? 이제 이 말은 어태커로 다시 내려올 수 있습니다.',
  ),
  TutorialStep(
    title: '퀸',
    body:
        '보드 위에 말이 딱 두 개만 남으면 점퍼 카드는 즉시 퀸으로 바뀝니다.\n'
        '퀸은 상하좌우와 대각선, 8방향으로 한 칸 움직입니다.',
    setup: () => _custom(
      white: ['c3'],
      black: ['a1'],
      whiteHand: 'Q,R',
      blackHand: 'A,N',
      waiting: 'B',
    ),
    task: '퀸(Q) 카드로 말을 움직여 보세요.',
    goal: (m, _) => m.card == CardType.queen,
    hint: 'Qc3→b2',
    success: '좋아요! 1:1 상황에서는 퀸을 누가 쥐느냐가 승부를 가릅니다.',
  ),
  TutorialStep(
    title: '이기는 법 ① 전멸',
    body: '상대 말을 모두 잡으면 그 세트를 이깁니다.\n마지막 남은 상대 말을 잡아 보세요.',
    setup: () => _custom(
      white: ['c3', 'd4'],
      black: ['b2'],
      whiteHand: 'B,R',
      blackHand: 'A,J',
      waiting: 'N',
    ),
    task: '마지막 상대 말(b2)을 잡아 보세요.',
    goal: (_, after) =>
        after.result?.winner == _w &&
        after.result?.reason == WinReason.annihilation,
    hint: 'Bc3→b2x',
    success: '승리! 상대 말을 모두 잡았습니다.',
  ),
  TutorialStep(
    title: '이기는 법 ② 성 점령',
    body:
        '상대 성(a3)에 내 말을 올려놓고, 상대가 그 말을 잡지 못한 채 한 턴이 지나면 이깁니다.\n'
        'b3 의 말을 상대 성에 올려 보세요. 상대가 한 수 둔 뒤 결과가 나옵니다.',
    setup: () => _custom(
      white: ['b3', 'e1', 'e5'],
      black: ['a1', 'a5'],
      whiteHand: 'R,A',
      blackHand: 'B,N',
      waiting: 'J',
    ),
    task: 'b3 의 말을 상대 성 a3 으로 옮겨 보세요.',
    goal: (m, _) => m.to == Pos.parse('a3'),
    hint: 'Rb3→a3',
    opponentReplies: true,
    success: '상대가 막지 못해 성 점령으로 승리했습니다!',
  ),
  TutorialStep(
    title: '카드 배치',
    body:
        '실제 게임은 후공이 카드 5장을 나누는 것으로 시작합니다.\n'
        '내 손 2장, 상대 손 2장, 대기 존 1장.\n'
        '다루기 어려운 점퍼를 상대 손에 넣는 등, 배치부터가 전략입니다. 그 대신 선공은 먼저 둡니다.',
    setup: _standardStart,
  ),
  TutorialStep(
    title: '준비 완료!',
    body:
        '규칙을 모두 배웠습니다.\n'
        '세트는 최대 3번, 먼저 2세트를 이기면 최종 승리입니다. 세트마다 선공이 바뀝니다.\n'
        '이제 AI 와 한 판 겨뤄 보세요.',
    setup: _standardStart,
  ),
];
