import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'widgets/card_widget.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = TextStyle(color: scheme.onSurfaceVariant, height: 1.5);
    Widget section(String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(text, style: body),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('규칙')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section(
            '개요',
            '가로 5칸, 세로 5칸 보드에서 각자 말 5개를 사용한다. 말은 앞뒤가 구분되며, '
                '자기 진영 첫 줄에 앞을 보고 배치된다. 중앙 말이 놓인 칸이 그 플레이어의 성이다.',
          ),
          section(
            '카드 배치',
            '후공이 카드 5장 중 2장을 자기 앞에, 2장을 선공 앞에 놓고 남은 1장은 대기 존에 둔다.',
          ),
          section(
            '턴 진행',
            '자기 앞의 카드 2장 중 1장을 골라 그 이동 규칙대로 말 1개를 옮긴다. '
                '사용한 카드는 대기 존으로 가고, 대기 존에 있던 카드를 가져온다.\n'
                '이동을 마친 칸에 상대 말이 있으면 그 말을 잡는다.\n'
                '말이 보드의 마지막 줄에 도착하면 방향을 반대로 돌린다.',
          ),
          section(
            '승리 조건 (세트)',
            '① 상대 말을 모두 잡는다.\n'
                '② 상대 성에 내 말을 올려놓고 한 턴을 버틴다 (상대가 그 말을 잡지 못하면 승리).\n'
                '최대 3세트, 먼저 2세트를 이기면 최종 승리. 세트마다 선공이 바뀐다.',
          ),
          Text('카드', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final card in CardType.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CardView(card: card, width: 84),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${card.korean} (${card.symbol})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(card.description, style: body),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          section(
            '이 앱의 해석',
            '· 점퍼는 자기 말만 뛰어넘는다 (원작 해설 근거).\n'
                '· 방향 전환은 끝 줄에 도착할 때마다 반복된다.\n'
                '· 두 카드 모두 둘 수 없으면 카드 한 장을 대기 존과 교환하고 턴을 넘긴다.\n'
                '· 다이어그램의 위쪽이 말이 바라보는 방향이다.',
          ),
        ],
      ),
    );
  }
}
