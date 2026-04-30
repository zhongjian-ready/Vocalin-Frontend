import 'package:flutter/material.dart';

import '../screens/auth/auth_screen.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name ?? AppRoutes.root;

    if (routeName == AppRoutes.root) {
      return _buildRoute(settings, const AuthGate());
    }

    if (AppRoutes.tabRoutes.contains(routeName)) {
      return _buildRoute(
        settings,
        AuthGate(initialRoute: routeName),
      );
    }

    return _buildRoute(settings, const AuthGate());
  }

  static MaterialPageRoute<dynamic> _buildRoute(
    RouteSettings settings,
    Widget child,
  ) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) => child,
    );
  }
}
