import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../navigation/app_routes.dart';
import '../../services/data_service.dart';
import '../main_screen.dart';
import 'tabs/album_tab.dart';
import 'tabs/notes_tab.dart';
import 'tabs/wishlist_tab.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DataService>(
      builder: (context, dataService, child) {
        if (dataService.isLoading && dataService.currentGroup == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (dataService.currentGroup == null) {
          return const Scaffold(
            body: SafeArea(
              child: _NoSpaceRecordsState(),
            ),
          );
        }

        return const DefaultTabController(
          length: 3,
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFFFF7F0),
                        borderRadius: BorderRadius.all(Radius.circular(28)),
                        border: Border.fromBorderSide(
                          BorderSide(color: Color(0xFFE8D8CA)),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: TabBar(
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: Color(0xFFFFE7D6),
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                        ),
                        indicatorPadding: EdgeInsets.all(8),
                        labelColor: Color(0xFFCA7C56),
                        unselectedLabelColor: Color(0xFF6D5A4D),
                        labelStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: [
                          Tab(
                            icon: Icon(Icons.photo_album_rounded),
                            text: 'Album',
                          ),
                          Tab(
                            icon: Icon(Icons.note_alt_rounded),
                            text: 'Notes',
                          ),
                          Tab(
                            icon: Icon(Icons.check_circle_rounded),
                            text: 'Wishlist',
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        AlbumTab(),
                        NotesTab(),
                        WishlistTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NoSpaceRecordsState extends StatelessWidget {
  const _NoSpaceRecordsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFFBF6), Color(0xFFF7EEE6)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFF0DCCF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEAD8),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.collections_bookmark_rounded,
                      size: 40,
                      color: Color(0xFFC9793A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No space joined yet',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6C4630),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Records belong to a shared space. Go to Home first to create a new space or join one with an invite code.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF7A6658),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          MainScreen.switchToRoute(context, AppRoutes.home),
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Go to Home'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
