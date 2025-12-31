import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/data_service.dart';
import '../../widgets/blackboard_card.dart';
import '../../widgets/companion_timer_card.dart';
import '../../widgets/recent_activity_card.dart';
import '../../widgets/status_bubbles.dart';
import '../../widgets/vocalin_logo.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const VocalinLogo(size: 32), // Use the new Logo widget
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<DataService>(
        builder: (context, dataService, child) {
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
            return const Center(child: Text('No group joined yet.'));
          }

          final latestPost =
              dataService.posts.isNotEmpty ? dataService.posts.first : null;

          return SingleChildScrollView(
            child: Column(
              children: [
                CompanionTimerCard(startDate: group.createdAt),
                StatusBubbles(users: group.members),
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
}
