import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../state/app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          children: [
            _header(context, '하우스룰'),
            SwitchListTile(
              title: const Text('점퍼가 상대 말도 넘을 수 있음'),
              subtitle: const Text('원작 해석은 자기 말만 넘는다. 새 게임부터 적용.'),
              value: s.jumperOverEnemy,
              onChanged: (v) => s.update((x) => x.jumperOverEnemy = v),
            ),
            ListTile(
              title: const Text('두 카드 모두 둘 수 없을 때'),
              subtitle: Text(
                s.noMovePolicy == NoMovePolicy.pass
                    ? '카드 한 장을 대기 존과 교환하고 턴을 넘긴다'
                    : '즉시 패배한다',
              ),
              trailing: SegmentedButton<NoMovePolicy>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: NoMovePolicy.pass, label: Text('패스')),
                  ButtonSegment(value: NoMovePolicy.lose, label: Text('패배')),
                ],
                selected: {s.noMovePolicy},
                onSelectionChanged: (v) =>
                    s.update((x) => x.noMovePolicy = v.first),
              ),
            ),
            _header(context, '플레이'),
            SwitchListTile(
              title: const Text('무르기 허용'),
              value: s.allowUndo,
              onChanged: (v) => s.update((x) => x.allowUndo = v),
            ),
            SwitchListTile(
              title: const Text('이동 가능한 말 표시'),
              subtitle: const Text('카드를 고르면 움직일 수 있는 말에 테두리를 그린다'),
              value: s.showHints,
              onChanged: (v) => s.update((x) => x.showHints = v),
            ),
            SwitchListTile(
              title: const Text('진동 피드백'),
              value: s.haptics,
              onChanged: (v) => s.update((x) => x.haptics = v),
            ),
            ListTile(
              title: const Text('기본 AI 난이도'),
              trailing: SegmentedButton<AiLevel>(
                showSelectedIcon: false,
                segments: [
                  for (final l in AiLevel.values)
                    ButtonSegment(value: l, label: Text(l.korean)),
                ],
                selected: {s.aiLevel},
                onSelectionChanged: (v) => s.update((x) => x.aiLevel = v.first),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '하우스룰 변경은 진행 중인 게임에는 적용되지 않습니다.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
