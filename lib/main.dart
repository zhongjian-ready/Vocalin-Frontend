import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/services/auth_service.dart';
import 'src/services/data_service.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => AuthService()),
          ChangeNotifierProxyProvider<AuthService, DataService>(
            create: (context) => DataService(),
            update: (context, authService, dataService) {
              final service = dataService ?? DataService();
              service.syncAuthState(authService.currentUser);
              return service;
            },
          ),
        ],
        child: const VocalinApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stack');
  });
}
