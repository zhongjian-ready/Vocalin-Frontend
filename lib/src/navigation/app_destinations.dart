import 'package:flutter/cupertino.dart';

import '../screens/home/home_screen.dart';
import '../screens/messages/messages_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/records/records_screen.dart';
import 'app_routes.dart';

class AppDestination {
  const AppDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.screen,
  });

  final String route;
  final String label;
  final IconData icon;
  final Widget screen;
}

const appDestinations = <AppDestination>[
  AppDestination(
    route: AppRoutes.home,
    label: 'Home',
    icon: CupertinoIcons.home,
    screen: HomeScreen(),
  ),
  AppDestination(
    route: AppRoutes.records,
    label: 'Records',
    icon: CupertinoIcons.collections,
    screen: RecordsScreen(),
  ),
  AppDestination(
    route: AppRoutes.messages,
    label: 'Messages',
    icon: CupertinoIcons.chat_bubble_2,
    screen: MessagesScreen(),
  ),
  AppDestination(
    route: AppRoutes.profile,
    label: 'Profile',
    icon: CupertinoIcons.person,
    screen: ProfileScreen(),
  ),
];
