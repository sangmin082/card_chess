import 'package:flutter/material.dart';

import 'state/app_settings.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  runApp(const CardChessApp());
}

class CardChessApp extends StatelessWidget {
  const CardChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '카드 체스',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
