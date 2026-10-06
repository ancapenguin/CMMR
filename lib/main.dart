import 'package:flutter/material.dart';

import 'video_cutter_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CmmrApp());
}

class CmmrApp extends StatelessWidget {
  const CmmrApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF101418);
    const surface = Color(0xFF191F24);
    const accent = Color(0xFF7CE0C3);

    return MaterialApp(
      title: 'CMMR Cut',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: surface,
        ),
        useMaterial3: true,
      ),
      home: const VideoCutterPage(),
    );
  }
}
