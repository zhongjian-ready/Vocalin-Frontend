import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/app_destinations.dart';
import '../navigation/app_routes.dart';
import '../services/data_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.initialRoute = AppRoutes.home});

  final String initialRoute;

  static void switchToRoute(BuildContext context, String route) {
    final state = context.findAncestorStateOfType<_MainScreenState>();
    state?._setCurrentRoute(route);
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = _indexForRoute(widget.initialRoute);
  }

  int _indexForRoute(String route) {
    return appDestinations
        .indexWhere((destination) => destination.route == route);
  }

  void _setCurrentRoute(String route) {
    final nextIndex = _indexForRoute(route);
    if (nextIndex < 0 || nextIndex == _currentIndex) {
      return;
    }

    setState(() {
      _currentIndex = nextIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex < 0 ? 0 : _currentIndex,
        children: [
          for (final destination in appDestinations) destination.screen,
        ],
      ),
      bottomNavigationBar: Consumer<DataService>(
        builder: (context, dataService, child) {
          final inboxCount = dataService.spaceInboxItems.length;

          return BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: const Color(0xFFFFFBF7),
            selectedItemColor: const Color(0xFFCA7C56),
            unselectedItemColor: const Color(0xFF9C8778),
            elevation: 0,
            currentIndex: _currentIndex,
            onTap: (index) {
              _setCurrentRoute(appDestinations[index].route);
            },
            items: [
              for (final destination in appDestinations)
                BottomNavigationBarItem(
                  icon: _NavigationIcon(
                    icon: destination.icon,
                    badgeCount: destination.route == AppRoutes.messages
                        ? inboxCount
                        : 0,
                  ),
                  label: destination.label,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({required this.icon, required this.badgeCount});

  final IconData icon;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (badgeCount > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFCA7C56),
                borderRadius: BorderRadius.circular(999),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
