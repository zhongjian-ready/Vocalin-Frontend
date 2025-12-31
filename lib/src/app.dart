import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

class VocalinApp extends StatelessWidget {
  const VocalinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocalin',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const MainScreen(),
    );
  }
}
