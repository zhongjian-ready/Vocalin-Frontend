import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/data_service.dart';
import '../../widgets/blackboard_card.dart';
import '../../widgets/companion_timer_card.dart';
import '../../widgets/recent_activity_card.dart';
import '../profile/space_management_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showErrorMessageIfNeeded(
    BuildContext context,
    DataService dataService,
  ) {
    final errorMessage = dataService.errorMessage;
    if (errorMessage == null || errorMessage.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentDataService = context.read<DataService>();
      if (currentDataService.errorMessage != errorMessage) {
        return;
      }

      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFD85A3D),
          content: Text(errorMessage),
        ),
      );
      currentDataService.clearErrorMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<DataService>(
        builder: (context, dataService, child) {
          _showErrorMessageIfNeeded(context, dataService);

          if (dataService.isLoading && dataService.currentGroup == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final group = dataService.currentGroup;
          if (group == null) {
            return const SpaceManagementScreen(showAppBar: false);
          }

          final latestPost =
              dataService.posts.isNotEmpty ? dataService.posts.first : null;

          return SingleChildScrollView(
            child: Column(
              children: [
                CompanionTimerCard(
                  startDate: group.createdAt,
                  title: "We've been together in ${group.name} for",
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
