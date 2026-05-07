import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/data_service.dart';
import '../../widgets/blackboard_card.dart';
import '../../widgets/companion_timer_card.dart';
import '../../widgets/recent_activity_card.dart';
import '../profile/space_management_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<DataService>(
        builder: (context, dataService, child) {
          if (dataService.isLoading && dataService.currentGroup == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (dataService.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: ${dataService.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final group = dataService.currentGroup;
          if (group == null) {
            return _NoSpaceState(
              errorMessage: dataService.errorMessage,
              onManageSpace: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SpaceManagementScreen(),
                  ),
                );
              },
            );
          }

          final latestPost =
              dataService.posts.isNotEmpty ? dataService.posts.first : null;

          return SingleChildScrollView(
            child: Column(
              children: [
                CompanionTimerCard(
                  startDate: group.createdAt,
                  onTap: () => _showMembersDialog(context, group.members),
                ),
                if (group.topMessage != null)
                  BlackboardCard(
                    message: group.topMessage!,
                    onEdit: () {
                      _showEditBlackboardDialog(context, dataService);
                    },
                  ),
                RecentActivityCard(latestPost: latestPost),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditBlackboardDialog(
      BuildContext context, DataService dataService) {
    final controller =
        TextEditingController(text: dataService.currentGroup?.topMessage);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Blackboard'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter a message...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              dataService.updateTopMessage(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMembersDialog(BuildContext context, List<dynamic> members) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Our People',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap the card anytime to see everyone in your space.',
                  style: TextStyle(
                    color: Color(0xFF7A6658),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final status = member.currentStatus as String?;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8F2),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF1DDD1)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFFFFDCC8),
                              backgroundImage: member.avatarUrl != null
                                  ? NetworkImage(member.avatarUrl! as String)
                                  : null,
                              child: member.avatarUrl == null
                                  ? Text(
                                      member.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFFA85D38),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    status == null || status.isEmpty
                                        ? 'No current status'
                                        : status,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: status == null || status.isEmpty
                                          ? const Color(0xFF9C8B81)
                                          : const Color(0xFF7A6658),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

class _NoSpaceState extends StatelessWidget {
  const _NoSpaceState({
    required this.onManageSpace,
    this.errorMessage,
  });

  final VoidCallback onManageSpace;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFFCF7), Color(0xFFF8EFE6)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8CF),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.holiday_village_rounded,
                      size: 44,
                      color: Color(0xFFC9793A),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Create or join a space',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6C4630),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You have not joined any space yet. Create one for yourself, or join an existing one with an invite code.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF7A6658),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (errorMessage != null && errorMessage!.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0EA),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFFFCAB8)),
                      ),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFBA4D34),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  _EntryCard(
                    icon: Icons.add_home_work_rounded,
                    title: 'Create a new space',
                    description:
                        'Set up your own space first, then share the generated invite code with others.',
                    buttonLabel: 'Create Space',
                    onTap: onManageSpace,
                  ),
                  const SizedBox(height: 14),
                  _EntryCard(
                    icon: Icons.password_rounded,
                    title: 'Join with invite code',
                    description:
                        'Use the invite code shared with you to join a space directly.',
                    buttonLabel: 'Enter Invite Code',
                    isPrimary: false,
                    onTap: onManageSpace,
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: onManageSpace,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Open Space Management'),
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

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onTap,
    this.isPrimary = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0DAC7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141F0F05),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFFC9793A)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF7A6658),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: isPrimary
                ? FilledButton(
                    onPressed: onTap,
                    child: Text(buttonLabel),
                  )
                : OutlinedButton(
                    onPressed: onTap,
                    child: Text(buttonLabel),
                  ),
          ),
        ],
      ),
    );
  }
}
