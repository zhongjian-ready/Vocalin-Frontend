// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vocalin/src/app.dart';
import 'package:vocalin/src/navigation/app_router.dart';
import 'package:vocalin/src/navigation/app_routes.dart';
import 'package:vocalin/src/screens/auth/auth_screen.dart';
import 'package:vocalin/src/screens/profile/profile_screen.dart';
import 'package:vocalin/src/services/auth_service.dart';
import 'package:vocalin/src/services/data_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => AuthService()),
          ChangeNotifierProxyProvider<AuthService, DataService>(
            create: (context) => DataService(autoInitialize: false),
            update: (context, authService, dataService) {
              final service = dataService ?? DataService(autoInitialize: false);
              service.syncAuthState(authService.currentUser);
              return service;
            },
          ),
        ],
        child: const VocalinApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('欢迎回家'), findsOneWidget);
    expect(find.text('还没有注册？去注册页面'), findsOneWidget);
  });

  testWidgets('Named routes open the configured tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (context) => AuthService()
              ..loginWithNickname(
                nickname: 'Alice',
                password: '123456',
              ),
          ),
          ChangeNotifierProxyProvider<AuthService, DataService>(
            create: (context) => DataService(autoInitialize: false),
            update: (context, authService, dataService) {
              final service = dataService ?? DataService(autoInitialize: false);
              service.syncAuthState(authService.currentUser);
              return service;
            },
          ),
        ],
        child: MaterialApp(
          initialRoute: AppRoutes.records,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Album'), findsOneWidget);
  });

  testWidgets('Logout returns to auth screen', (WidgetTester tester) async {
    final authService = AuthService();
    await authService.loginWithNickname(
      nickname: 'Alice',
      password: '123456',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (context) => authService,
          ),
          ChangeNotifierProxyProvider<AuthService, DataService>(
            create: (context) => DataService(autoInitialize: false),
            update: (context, authService, dataService) {
              final service = dataService ?? DataService(autoInitialize: false);
              service.syncAuthState(authService.currentUser);
              return service;
            },
          ),
        ],
        child: MaterialApp(
          initialRoute: AppRoutes.profile,
          routes: {
            AppRoutes.root: (context) => const AuthScreen(),
            AppRoutes.profile: (context) => const ProfileScreen(),
          },
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Log Out'), findsOneWidget);

    await tester.tap(find.text('Log Out'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('欢迎回家'), findsOneWidget);
    expect(find.text('Log Out'), findsNothing);
  });
}
