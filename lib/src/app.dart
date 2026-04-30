import 'package:flutter/material.dart';

import 'navigation/app_router.dart';

class VocalinApp extends StatelessWidget {
  const VocalinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocalin',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFCA7C56),
          primary: const Color(0xFFCA7C56),
          secondary: const Color(0xFFE9B27D),
          surface: const Color(0xFFFFFBF7),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFBF7),
      ),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
