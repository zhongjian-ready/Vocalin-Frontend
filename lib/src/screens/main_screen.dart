import 'package:flutter/material.dart';

import '../navigation/app_destinations.dart';
import '../navigation/app_routes.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.initialRoute = AppRoutes.home});

  final String initialRoute;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex < 0 ? 0 : _currentIndex,
        children: [
          for (final destination in appDestinations) destination.screen,
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          for (final destination in appDestinations)
            BottomNavigationBarItem(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
