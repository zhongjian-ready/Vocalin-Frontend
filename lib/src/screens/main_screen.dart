import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/space_inbox_item.dart';
import '../navigation/app_destinations.dart';
import '../navigation/app_routes.dart';
import '../services/data_service.dart';
import 'profile/space_management_screen.dart';

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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Consumer<DataService>(
        builder: (context, dataService, child) {
          final inboxItems = dataService.spaceInboxItems;
          if (inboxItems.isEmpty) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton.extended(
            backgroundColor: const Color(0xFFCA7C56),
            foregroundColor: Colors.white,
            onPressed: () => _openInbox(context, inboxItems),
            icon: const Icon(Icons.mark_chat_unread_rounded),
            label: Text('${inboxItems.length}'),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _setCurrentRoute(appDestinations[index].route);
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

  Future<void> _openInbox(
    BuildContext context,
    List<SpaceInboxItem> inboxItems,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _InboxSheet(
        items: inboxItems,
        onOpenItem: (item) {
          Navigator.of(sheetContext).pop();
          setState(() {
            _currentIndex = _indexForRoute(AppRoutes.profile);
          });
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SpaceManagementScreen(),
            ),
          );
        },
      ),
    );
  }
}

class _InboxSheet extends StatelessWidget {
  const _InboxSheet({required this.items, required this.onOpenItem});

  final List<SpaceInboxItem> items;
  final ValueChanged<SpaceInboxItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBF7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Messages',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Material(
                        color: const Color(0xFFFFF7F0),
                        borderRadius: BorderRadius.circular(18),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFFE3C8),
                            child: Icon(
                              item.type == SpaceInboxItemType.joinRequest
                                  ? Icons.person_add_alt_1_rounded
                                  : Icons.workspace_premium_rounded,
                              color: const Color(0xFFB56C37),
                            ),
                          ),
                          title: Text(item.title),
                          titleTextStyle: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2E2520),
                            height: 1.3,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => onOpenItem(item),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
