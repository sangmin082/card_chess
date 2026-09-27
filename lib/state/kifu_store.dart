import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine.dart';

/// 저장된 기보 한 건.
class SavedKifu {
  const SavedKifu({
    required this.id,
    required this.savedAt,
    required this.text,
  });

  final String id;
  final DateTime savedAt;
  final String text;

  KifuSet get kifu => KifuSet.parse(text);

  Map<String, Object?> toJson() => {
    'id': id,
    'savedAt': savedAt.toIso8601String(),
    'text': text,
  };

  factory SavedKifu.fromJson(Map<String, Object?> j) => SavedKifu(
    id: j['id'] as String,
    savedAt: DateTime.parse(j['savedAt'] as String),
    text: j['text'] as String,
  );
}

/// shared_preferences 에 기보를 JSON 목록으로 저장한다.
class KifuStore {
  static const _key = 'saved_kifu_v1';

  Future<List<SavedKifu>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SavedKifu.fromJson(e as Map<String, Object?>))
          .toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<SavedKifu> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<SavedKifu> save(KifuSet kifu) async {
    final items = await load();
    final now = DateTime.now();
    final item = SavedKifu(
      id: now.microsecondsSinceEpoch.toString(),
      savedAt: now,
      text: kifu.serialize(),
    );
    await _write([item, ...items]);
    return item;
  }

  Future<void> delete(String id) async {
    final items = await load();
    await _write(items.where((e) => e.id != id).toList());
  }
}
