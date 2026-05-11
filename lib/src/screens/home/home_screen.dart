import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/post.dart';
import '../../models/wish.dart';
import '../../services/data_service.dart';
import '../../widgets/blackboard_card.dart';
import '../../widgets/companion_timer_card.dart';
import '../profile/space_management_screen.dart';
import 'note_viewer_page.dart';

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

  void _openNoteViewerPage(BuildContext context, Post note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NoteViewerPage(note: note),
      ),
    );
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

          final publicNotes = dataService.posts
              .where((post) => post.type == PostType.note && post.isShared)
              .take(2)
              .toList(growable: false);

          final publicWishes = _sortWishesByPriority(
            dataService.wishes
                .where((wish) => wish.isShared && !wish.isCompleted),
          ).take(5).toList(growable: false);

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
                if (publicNotes.isNotEmpty || publicWishes.isNotEmpty)
                  _buildRecentActivitySection(
                    context,
                    dataService,
                    publicNotes,
                    publicWishes,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentActivitySection(
    BuildContext context,
    DataService dataService,
    List<Post> publicNotes,
    List<Wish> publicWishes,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Recent Activity',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A6658),
                fontSize: 14,
              ),
            ),
          ),
          if (publicNotes.isNotEmpty) ...[
            _buildNotesSection(context, dataService, publicNotes),
            if (publicWishes.isNotEmpty) const SizedBox(height: 16),
          ],
          if (publicWishes.isNotEmpty) _buildWishesSection(publicWishes),
        ],
      ),
    );
  }

  Widget _buildNotesSection(
    BuildContext context,
    DataService dataService,
    List<Post> notes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.sticky_note_2_outlined,
                size: 16, color: Color(0xFFC96F3D)),
            SizedBox(width: 6),
            Text(
              'Notes',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFFC96F3D),
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...notes.map((note) => _buildNoteCard(context, dataService, note)),
      ],
    );
  }

  Widget _buildNoteCard(
    BuildContext context,
    DataService dataService,
    Post note,
  ) {
    final folderLabel = dataService.noteFolderLabelFor(note);

    return Card(
      color: const Color(0xFFFFF6D9),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openNoteViewerPage(context, note),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title?.trim().isNotEmpty == true
                          ? note.title!.trim()
                          : 'Untitled Note',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _buildFilterPill(folderLabel),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.content ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF52473B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                DateFormat.yMMMd().add_jm().format(note.updatedAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8A8175),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF675B4F),
        ),
      ),
    );
  }

  Widget _buildWishesSection(List<Wish> wishes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.star_outline, size: 16, color: Color(0xFF4E8B62)),
            SizedBox(width: 6),
            Text(
              'Wishlist',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF4E8B62),
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          color: const Color(0xFFEAF6ED),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: wishes.map((wish) => _buildWishItem(wish)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWishItem(Wish wish) {
    final priorityStyle = _WishPriorityStyle.fromPriority(wish.priority);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  wish.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: priorityStyle.accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 2, 0, 1),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: wish.title),
                      ],
                    ),
                    softWrap: true,
                    style: TextStyle(
                      decoration:
                          wish.isCompleted ? TextDecoration.lineThrough : null,
                      color: wish.isCompleted
                          ? const Color(0xFF8E8A84)
                          : const Color(0xFF2F2A25),
                      fontSize: 15,
                      fontWeight: wish.priority == WishPriority.high
                          ? FontWeight.w700
                          : FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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

  List<Wish> _sortWishesByPriority(Iterable<Wish> wishes) {
    final sorted = wishes.toList(growable: false);
    sorted.sort((left, right) {
      final priorityCompare =
          _priorityRank(right.priority).compareTo(_priorityRank(left.priority));
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return left.id.compareTo(right.id);
    });
    return sorted;
  }

  int _priorityRank(WishPriority? priority) {
    return switch (priority) {
      WishPriority.high => 3,
      WishPriority.medium => 2,
      WishPriority.low => 1,
      null => 0,
    };
  }
}

class _WishPriorityStyle {
  const _WishPriorityStyle({
    required this.accentColor,
  });

  final Color accentColor;

  static _WishPriorityStyle fromPriority(WishPriority? priority) {
    return switch (priority) {
      WishPriority.high => const _WishPriorityStyle(
          accentColor: Color(0xFFC44747),
        ),
      WishPriority.medium => const _WishPriorityStyle(
          accentColor: Color(0xFFC77712),
        ),
      WishPriority.low => const _WishPriorityStyle(
          accentColor: Color(0xFF7FB77E),
        ),
      null => const _WishPriorityStyle(
          accentColor: Color(0xFF7B6B5E),
        ),
    };
  }
}
