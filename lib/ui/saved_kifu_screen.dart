import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../state/kifu_store.dart';
import 'replay_screen.dart';

/// 저장된 기보 목록 + 텍스트 붙여넣기.
class SavedKifuScreen extends StatefulWidget {
  const SavedKifuScreen({super.key});

  @override
  State<SavedKifuScreen> createState() => _SavedKifuScreenState();
}

class _SavedKifuScreenState extends State<SavedKifuScreen> {
  final _store = KifuStore();
  List<SavedKifu>? _items;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final items = await _store.load();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _paste() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기보 붙여넣기'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'first: white\nwhite: R,J\nblack: B,A\nwaiting: N\nmoves: Re3→d3 ...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('열기'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    try {
      final kifu = KifuSet.parse(text);
      kifu.replayAll(); // 유효성 검사
      await _store.save(kifu);
      await _reload();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => ReplayScreen(kifu: kifu)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('기보를 읽을 수 없습니다: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('저장된 기보'),
        actions: [
          IconButton(
            tooltip: '기보 붙여넣기',
            onPressed: _paste,
            icon: const Icon(Icons.content_paste),
          ),
        ],
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? Center(
              child: Text(
                '저장된 기보가 없습니다.\n세트가 끝나면 자동으로 저장됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final item = items[i];
                KifuSet? kifu;
                try {
                  kifu = item.kifu;
                } catch (_) {}
                final names = kifu?.playerNames ?? const {};
                final subtitle = kifu == null
                    ? '손상된 기보'
                    : '${names[PlayerColor.white] ?? '백'}(백) vs '
                          '${names[PlayerColor.black] ?? '흑'}(흑) · ${kifu.moves.length}수'
                          '${kifu.winner != null ? ' · ${kifu.winner!.korean} 승' : ''}';
                final d = item.savedAt;
                final when =
                    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
                    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: scheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete, color: scheme.onErrorContainer),
                  ),
                  onDismissed: (_) async {
                    await _store.delete(item.id);
                    await _reload();
                  },
                  child: ListTile(
                    title: Text(
                      '${kifu?.title.isNotEmpty == true ? kifu!.title : '기보'} · $when',
                    ),
                    subtitle: Text(subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: kifu == null
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ReplayScreen(kifu: kifu!),
                            ),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
