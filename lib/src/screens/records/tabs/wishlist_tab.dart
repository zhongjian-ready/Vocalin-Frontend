import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/wish.dart';
import '../../../services/data_service.dart';
import '../record_delete_confirmation_dialog.dart';

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
                              onLongPress: () => _confirmDeleteWish(
                                context,
                                dataService,
                                wish,
                              ),
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
                              onLongPress: () => _confirmDeleteWish(
                                context,
                                dataService,
                                wish,
                              ),
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
      initialIsShared: false,
    ).then((result) {
      if (result == null || result.name.isEmpty) {
        return;
      }

      dataService.addWish(
        result.name,
        priority: result.priority,
        isShared: result.isShared,
      );
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
      initialIsShared: wish.isShared,
    ).then((result) async {
      if (!mounted || result == null) {
        return;
      }

      final normalizedName = result.name.trim();
      final hasContentChange = normalizedName != wish.title.trim();
      final hasPriorityChange = result.priority != wish.priority;
      final hasVisibilityChange = result.isShared != wish.isShared;

      if (!hasContentChange && !hasPriorityChange && !hasVisibilityChange) {
        return;
      }

      await dataService.updateWish(
        wish.id,
        content: normalizedName,
        priority: result.priority,
        isShared: result.isShared,
      );

      if (mounted) {
        messenger?.hideCurrentSnackBar();
      }
    });
  }

  Future<void> _confirmDeleteWish(
    BuildContext context,
    DataService dataService,
    Wish wish,
  ) async {
    final shouldDelete = await showRecordDeleteConfirmationDialog(
      context,
      title: 'Delete Wish',
      message: 'Delete this wish permanently?',
    );
    if (!shouldDelete) {
      return;
    }

    await dataService.deleteWish(wish.id);
  }

  Future<_WishFormResult?> _showWishDialog(
    BuildContext context, {
    required String title,
    required String initialName,
    required WishPriority initialPriority,
    required bool initialIsShared,
  }) {
    final controller = TextEditingController(text: initialName);
    var selectedPriority = initialPriority;
    var isShared = initialIsShared;

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
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'What do you want to do together?',
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              _WishVisibilitySelector(
                value: isShared,
                onChanged: (value) {
                  setDialogState(() {
                    isShared = value;
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
                  _WishFormResult(
                    name: name,
                    priority: selectedPriority,
                    isShared: isShared,
                  ),
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
    required this.onLongPress,
  });

  final Wish wish;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final priorityStyle = _WishPriorityStyle.fromPriority(wish.priority);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onEdit,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Checkbox(
                    value: wish.isCompleted,
                    onChanged: (_) => onToggle(),
                    activeColor: priorityStyle.accentColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity:
                        const VisualDensity(horizontal: -2, vertical: -2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    side: BorderSide(
                      color: priorityStyle.accentColor,
                      width: 1.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 7, 0, 1),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (!wish.isShared)
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.lock_outline,
                                  size: 16,
                                  color: Color(0xFF8E8A84),
                                ),
                              ),
                            ),
                          TextSpan(text: wish.title),
                        ],
                      ),
                      softWrap: true,
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
                        height: 1.35,
                      ),
                    ),
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

class _WishVisibilitySelector extends StatelessWidget {
  const _WishVisibilitySelector({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visibility',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              selected: value == false,
              avatar: const Icon(Icons.lock_outline, size: 18),
              label: const Text('Private'),
              onSelected: (_) => onChanged(false),
            ),
            ChoiceChip(
              selected: value == true,
              avatar: const Icon(Icons.groups_2_outlined, size: 18),
              label: const Text('Public'),
              onSelected: (_) => onChanged(true),
            ),
          ],
        ),
      ],
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
  const _WishFormResult({
    required this.name,
    required this.priority,
    required this.isShared,
  });

  final String name;
  final WishPriority priority;
  final bool isShared;
}
