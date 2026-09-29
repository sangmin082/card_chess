import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine.dart';

/// 앱 전역 설정. shared_preferences 에 저장한다.
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const _kJumperOverEnemy = 'rule.jumperOverEnemy';
  static const _kNoMovePolicy = 'rule.noMovePolicy';
  static const _kAllowUndo = 'ui.allowUndo';
  static const _kHaptics = 'ui.haptics';
  static const _kAiLevel = 'ai.level';
  static const _kShowHints = 'ui.showHints';

  bool jumperOverEnemy = false;
  NoMovePolicy noMovePolicy = NoMovePolicy.pass;
  bool allowUndo = true;
  bool haptics = true;
  bool showHints = true;
  AiLevel aiLevel = AiLevel.normal;

  bool _loaded = false;
  bool get loaded => _loaded;

  RuleOptions get ruleOptions =>
      RuleOptions(jumperOverEnemy: jumperOverEnemy, noMovePolicy: noMovePolicy);

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      jumperOverEnemy = p.getBool(_kJumperOverEnemy) ?? jumperOverEnemy;
      final policy = p.getString(_kNoMovePolicy);
      if (policy != null) {
        noMovePolicy = NoMovePolicy.values.firstWhere(
          (e) => e.name == policy,
          orElse: () => NoMovePolicy.pass,
        );
      }
      allowUndo = p.getBool(_kAllowUndo) ?? allowUndo;
      haptics = p.getBool(_kHaptics) ?? haptics;
      showHints = p.getBool(_kShowHints) ?? showHints;
      final level = p.getString(_kAiLevel);
      if (level != null) {
        aiLevel = AiLevel.values.firstWhere(
          (e) => e.name == level,
          orElse: () => AiLevel.normal,
        );
      }
    } catch (_) {
      // 저장소를 못 읽으면 기본값 유지.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kJumperOverEnemy, jumperOverEnemy);
      await p.setString(_kNoMovePolicy, noMovePolicy.name);
      await p.setBool(_kAllowUndo, allowUndo);
      await p.setBool(_kHaptics, haptics);
      await p.setBool(_kShowHints, showHints);
      await p.setString(_kAiLevel, aiLevel.name);
    } catch (_) {}
  }

  void update(void Function(AppSettings s) change) {
    change(this);
    notifyListeners();
    _save();
  }
}
