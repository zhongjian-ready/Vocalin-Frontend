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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocalin/src/app.dart';
import 'package:vocalin/src/models/album.dart';
import 'package:vocalin/src/models/user.dart';
import 'package:vocalin/src/navigation/app_router.dart';
import 'package:vocalin/src/navigation/app_routes.dart';
import 'package:vocalin/src/screens/auth/auth_screen.dart';
import 'package:vocalin/src/screens/profile/profile_screen.dart';
import 'package:vocalin/src/screens/records/create_album_page.dart';
import 'package:vocalin/src/screens/records/tabs/album_tab.dart';
import 'package:vocalin/src/services/auth_service.dart';
import 'package:vocalin/src/services/data_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
          ChangeNotifierProvider<AuthService>(
            create: (context) => _FakeAuthenticatedAuthService(),
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

    expect(find.text('Albums'), findsOneWidget);
  });

  testWidgets('Messages tab route opens the message center', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>(
            create: (context) => _FakeAuthenticatedAuthService(),
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
          initialRoute: AppRoutes.messages,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text(
        'Private messages and system notices are organized separately here.',
      ),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
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

  testWidgets('Album cards keep details in preview footer only', (
    WidgetTester tester,
  ) async {
    final album = Album(
      id: 1,
      title: 'Weekend vibes',
      description: 'Weekend vibes',
      coverImageUrl:
          'https://images.example.com/albums/weekend-vibes-cover.jpg',
      ownerNickname: 'Alice',
      createdAt: DateTime(2026, 4, 23),
      updatedAt: DateTime(2026, 4, 23),
      photos: [
        AlbumPhoto(
          id: 101,
          imageUrl: 'https://images.example.com/albums/weekend-vibes-1.jpg',
          description: 'Sunset by the water',
          createdAt: DateTime(2026, 4, 23),
          updatedAt: DateTime(2026, 4, 23),
        ),
      ],
      photoCount: 88,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<DataService>.value(
        value: _FakeAlbumDataService([album]),
        child: const MaterialApp(home: Scaffold(body: AlbumTab())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Weekend vibes'), findsOneWidget);
    expect(find.text('Sunset by the water'), findsNothing);
    expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
    expect(find.text('88'), findsOneWidget);

    await tester.tap(find.text('Weekend vibes'));
    await tester.pumpAndSettle();

    expect(find.text('Weekend vibes'), findsWidgets);
    expect(find.text('Sunset by the water'), findsNothing);
  });

  testWidgets('Create album opens the dedicated editor page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DataService>.value(
        value: _FakeAlbumDataService(const []),
        child: const MaterialApp(home: Scaffold(body: AlbumTab())),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Album'));
    await tester.pumpAndSettle();

    expect(find.text('Add title'), findsOneWidget);
    expect(find.text('Add text or description'), findsOneWidget);
    expect(find.text('Save Draft'), findsOneWidget);
    expect(find.text('Publish'), findsOneWidget);
  });

  testWidgets('Create album publish confirmation defaults to public', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'records.create_album_draft':
          '{"title":"家庭相册","description":"周末记录","photos":[{"url":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9sot7mwAAAAASUVORK5CYII=","source":"library"}]}'
    });

    CreateAlbumResult? publishResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  publishResult = await Navigator.of(context).push(
                    MaterialPageRoute<CreateAlbumResult>(
                      builder: (context) => const CreateAlbumPage(),
                    ),
                  );
                },
                child: const Text('Open Create Album'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Create Album'));
    await tester.pumpAndSettle();

    expect(find.text('Added 1/9 photos'), findsOneWidget);

    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Visibility'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);

    await tester.tap(find.text('Confirm Publish'));
    await tester.pumpAndSettle();

    expect(publishResult, isNotNull);
    expect(publishResult!.isShared, isTrue);
  });

  testWidgets('Create album hides the add tile after reaching 9 photos', (
    WidgetTester tester,
  ) async {
    const photoJson =
        '{"url":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9sot7mwAAAAASUVORK5CYII=","source":"library"}';
    SharedPreferences.setMockInitialValues({
      'records.create_album_draft':
          '{"title":"Album","description":"Desc","photos":[$photoJson,$photoJson,$photoJson,$photoJson,$photoJson,$photoJson,$photoJson,$photoJson,$photoJson]}'
    });

    await tester.pumpWidget(
      const MaterialApp(home: CreateAlbumPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Added 9/9 photos'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
  });
}

class _FakeAuthenticatedAuthService extends AuthService {
  _FakeAuthenticatedAuthService();

  static final _user = User(
    id: 1,
    nickname: 'Alice',
    groupId: 5,
    role: 'member',
  );

  @override
  User? get currentUser => _user;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isRestoringSession => false;
}

class _FakeAlbumDataService extends DataService {
  _FakeAlbumDataService(this._albums) : super(autoInitialize: false);

  final List<Album> _albums;

  @override
  List<Album> get albums => _albums;

  @override
  bool get isLoading => false;
}
