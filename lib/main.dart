import 'package:flutter/material.dart';

import 'ui/home_screen.dart';
import 'ui/theme.dart';

void main() {
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
