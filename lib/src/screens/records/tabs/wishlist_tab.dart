import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/wish.dart';
import '../../../services/data_service.dart';

class WishlistTab extends StatefulWidget {
  const WishlistTab({super.key});

  @override
  State<WishlistTab> createState() => _WishlistTabState();
}

class _WishlistTabState extends State<WishlistTab> {
  bool _showActive = true;
  bool _showCompleted = false;

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

  @override
  Widget build(BuildContext context) {
    return Consumer<DataService>(
      builder: (context, dataService, child) {
        final wishes = dataService.wishes;
        final activeWishes = _sortWishesByPriority(
          wishes.where((wish) => !wish.isCompleted),
        );
        final completedWishes = _sortWishesByPriority(
          wishes.where((wish) => wish.isCompleted),
        );
        const activeSectionColor = Color(0xFFFFF3E8);
        const activeTextColor = Color(0xFFC96F3D);
        const completedSectionColor = Color(0xFFEAF6ED);
        const completedTextColor = Color(0xFF4E8B62);

        if (dataService.isLoading && wishes.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: 112),
              children: [
                if (activeWishes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                    child: Card(
                      color: activeSectionColor,
                      child: ExpansionTile(
                        key: const PageStorageKey('active-wishes-tile'),
                        initiallyExpanded: _showActive,
                        iconColor: activeTextColor,
                        collapsedIconColor: activeTextColor,
                        textColor: activeTextColor,
                        collapsedTextColor: activeTextColor,
                        shape: const RoundedRectangleBorder(
                          side: BorderSide.none,
                        ),
                        collapsedShape: const RoundedRectangleBorder(
                          side: BorderSide.none,
                        ),
                        onExpansionChanged: (value) {
                          setState(() {
                            _showActive = value;
                          });
                        },
                        title: Text('In Progress (${activeWishes.length})'),
                        children: [
                          ...activeWishes.map(
                            (wish) => _WishListItem(
                              wish: wish,
                              onToggle: () => dataService.toggleWish(wish.id),
                              onEdit: () => _showEditWishDialog(
                                  context, dataService, wish),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (completedWishes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                    child: Card(
                      color: completedSectionColor,
                      child: ExpansionTile(
                        key: const PageStorageKey('completed-wishes-tile'),
                        initiallyExpanded: _showCompleted,
                        iconColor: completedTextColor,
                        collapsedIconColor: completedTextColor,
                        textColor: completedTextColor,
                        collapsedTextColor: completedTextColor,
                        shape: const RoundedRectangleBorder(
                          side: BorderSide.none,
                        ),
                        collapsedShape: const RoundedRectangleBorder(
                          side: BorderSide.none,
                        ),
                        onExpansionChanged: (value) {
                          setState(() {
                            _showCompleted = value;
                          });
                        },
                        title: Text('Completed (${completedWishes.length})'),
                        children: [
                          ...completedWishes.map(
                            (wish) => _WishListItem(
                              wish: wish,
                              onToggle: () => dataService.toggleWish(wish.id),
                              onEdit: () => _showEditWishDialog(
                                  context, dataService, wish),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddWishDialog(context, dataService),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Wish'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddWishDialog(BuildContext context, DataService dataService) {
    _showWishDialog(
      context,
      title: 'New Wish',
      initialName: '',
      initialPriority: WishPriority.medium,
    ).then((result) {
      if (result == null || result.name.isEmpty) {
        return;
      }

      dataService.addWish(result.name, priority: result.priority);
    });
  }

  void _showEditWishDialog(
    BuildContext context,
    DataService dataService,
    Wish wish,
  ) {
    final initialPriority = wish.priority ?? WishPriority.medium;
    final messenger = ScaffoldMessenger.maybeOf(context);

    _showWishDialog(
      context,
      title: 'Edit Wish',
      initialName: wish.title,
      initialPriority: initialPriority,
      helperText: 'Priority will be synced immediately after saving.',
    ).then((result) async {
      if (!mounted || result == null) {
        return;
      }

      final normalizedName = result.name.trim();
      final hasNameChange = normalizedName != wish.title.trim();
      final hasPriorityChange = result.priority != wish.priority;

      if (hasPriorityChange) {
        await dataService.updateWishPriority(wish.id, result.priority);
      }

      if (mounted && hasNameChange) {
        messenger?.showSnackBar(
          const SnackBar(
            content:
                Text('Wish name update is waiting for backend API support.'),
          ),
        );
      }
    });
  }

  Future<_WishFormResult?> _showWishDialog(
    BuildContext context, {
    required String title,
    required String initialName,
    required WishPriority initialPriority,
    String? helperText,
  }) {
    final controller = TextEditingController(text: initialName);
    var selectedPriority = initialPriority;

    return showDialog<_WishFormResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'What do you want to do together?',
                ),
              ),
              const SizedBox(height: 16),
              if (helperText != null) ...[
                Text(
                  helperText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<WishPriority>(
                initialValue: selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: WishPriority.values
                    .map(
                      (priority) => DropdownMenuItem<WishPriority>(
                        value: priority,
                        child: Text(priority.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setDialogState(() {
                    selectedPriority = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  return;
                }
                Navigator.pop(
                  context,
                  _WishFormResult(name: name, priority: selectedPriority),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishListItem extends StatelessWidget {
  const _WishListItem({
    required this.wish,
    required this.onToggle,
    required this.onEdit,
  });

  final Wish wish;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final priorityStyle = _WishPriorityStyle.fromPriority(wish.priority);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: priorityStyle.accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            wish.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              decoration: wish.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: wish.isCompleted
                                  ? const Color(0xFF8E8A84)
                                  : const Color(0xFF2F2A25),
                              fontSize: 16,
                              fontWeight: wish.priority == WishPriority.high
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Checkbox(
                value: wish.isCompleted,
                onChanged: (_) => onToggle(),
                activeColor: priorityStyle.accentColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity:
                    const VisualDensity(horizontal: -2, vertical: -2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                side: BorderSide(color: priorityStyle.accentColor, width: 1.8),
              ),
            ],
          ),
        ),
      ),
    );
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

class _WishFormResult {
  const _WishFormResult({required this.name, required this.priority});

  final String name;
  final WishPriority priority;
}
