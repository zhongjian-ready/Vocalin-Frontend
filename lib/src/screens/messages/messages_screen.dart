import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/space_inbox_item.dart';
import '../../navigation/app_routes.dart';
import '../../services/data_service.dart';
import '../main_screen.dart';
import '../profile/space_management_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

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
              child: _NoSpaceMessagesState(),
            ),
          );
        }

        final privateMessages = dataService.spaceInboxItems;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFBF6), Color(0xFFF8F0E8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text(
                  'Messages',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2E2520),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Private messages and system notices are organized separately here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF7A675B),
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle(
                  title: 'System Messages',
                  suffix: '1 conversation',
                ),
                const SizedBox(height: 12),
                _SystemMessageEntry(
                  onTap: () => _openSystemMessages(context),
                ),
                const SizedBox(height: 24),
                _SectionTitle(
                  title: 'Private Messages',
                  suffix: '${privateMessages.length} items',
                ),
                const SizedBox(height: 12),
                if (privateMessages.isEmpty)
                  const _EmptyMessagesCard(
                    title: 'No private messages yet',
                    description:
                        'Pending join requests and transfer notices will appear here.',
                  )
                else ...[
                  for (var index = 0;
                      index < privateMessages.length;
                      index++) ...[
                    _PrivateMessageCard(
                      item: privateMessages[index],
                      onTap: () => _openPrivateMessage(context),
                    ),
                    if (index < privateMessages.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSystemMessages(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _SystemMessagesSheet(),
    );
  }

  void _openPrivateMessage(BuildContext context) {
    MainScreen.switchToRoute(context, AppRoutes.profile);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SpaceManagementScreen(),
      ),
    );
  }
}

class _NoSpaceMessagesState extends StatelessWidget {
  const _NoSpaceMessagesState();

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
                      Icons.mark_chat_unread_rounded,
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
                    'Messages belong to a shared space. Go to Home first to create a new space or join one with an invite code.',
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.suffix});

  final String title;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF2E2520),
            ),
          ),
        ),
        Text(
          suffix,
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF9C8778),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SystemMessageEntry extends StatelessWidget {
  const _SystemMessageEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF7F0),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE7D3),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFFB56C37),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Messages',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E2520),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Announcements and reminders will be grouped here.',
                      style: TextStyle(
                        color: Color(0xFF7A675B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '0 new',
                  style: TextStyle(
                    color: Color(0xFF9C8778),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivateMessageCard extends StatelessWidget {
  const _PrivateMessageCard({required this.item, required this.onTap});

  final SpaceInboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFFFE3C8),
                child: Icon(
                  item.type == SpaceInboxItemType.joinRequest
                      ? Icons.person_add_alt_1_rounded
                      : Icons.workspace_premium_rounded,
                  color: const Color(0xFFB56C37),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2E2520),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF7A675B),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF2E5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.groupName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFB56C37),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTimestamp(item.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF9C8778),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9C8778),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Pending';
    }

    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }
}

class _EmptyMessagesCard extends StatelessWidget {
  const _EmptyMessagesCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2E2520),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF7A675B),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _SystemMessagesSheet extends StatelessWidget {
  const _SystemMessagesSheet();

  @override
  Widget build(BuildContext context) {
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
                        'System Messages',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                const SizedBox(height: 12),
                const _EmptyMessagesCard(
                  title: 'No system notices',
                  description:
                      'When the app has announcements, service reminders, or version notices, they will be grouped here.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
