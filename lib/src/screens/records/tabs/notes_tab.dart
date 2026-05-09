import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/post.dart';
import '../../../services/data_service.dart';
import '../note_editor_page.dart';
import '../record_delete_confirmation_dialog.dart';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  late final TextEditingController _searchController;
  String _selectedFilterKey = _NoteFilterOption.allKey;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataService>(
      builder: (context, dataService, child) {
        final notes = dataService.posts
            .where((post) => post.type == PostType.note)
            .toList();
        final filterOptions = _buildFilterOptions(dataService, notes);
        final activeFilter = filterOptions.any(
          (option) => option.key == _selectedFilterKey,
        )
            ? _selectedFilterKey
            : _NoteFilterOption.allKey;
        final query = _searchController.text.trim().toLowerCase();
        final filteredNotes = notes.where((note) {
          final matchesFilter = switch (activeFilter) {
            _NoteFilterOption.allKey => true,
            _NoteFilterOption.shareKey =>
              dataService.isSharedNoteFromOtherUser(note),
            _ => activeFilter ==
                'folder:${dataService.noteFolderNameFor(note.id)}',
          };
          if (!matchesFilter) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }

          final title = note.title?.toLowerCase() ?? '';
          final content = note.content?.toLowerCase() ?? '';
          return title.contains(query) || content.contains(query);
        }).toList(growable: false);

        if (dataService.isLoading && notes.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFECE8E1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search Notes',
                            hintStyle: TextStyle(fontSize: 15),
                            prefixIcon: Icon(Icons.search_rounded, size: 22),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final option in filterOptions)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  selected: activeFilter == option.key,
                                  avatar: activeFilter == option.key
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                        )
                                      : null,
                                  label: Text(option.label),
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedFilterKey = option.key;
                                    });
                                  },
                                  selectedColor: const Color(0xFFE6E0D5),
                                  backgroundColor: Colors.white,
                                  labelStyle: TextStyle(
                                    fontSize: 14,
                                    fontWeight: activeFilter == option.key
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: activeFilter == option.key
                                          ? Colors.transparent
                                          : const Color(0xFFD9CDBE),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                ),
                              ),
                            _AddFolderChip(
                              onTap: () => _createFolder(context, dataService),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredNotes.isEmpty
                      ? Center(
                          child: Text(
                            notes.isEmpty
                                ? 'No notes yet. Leave a message!'
                                : 'No notes match this filter.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
                          itemCount: filteredNotes.length,
                          itemBuilder: (context, index) {
                            final note = filteredNotes[index];
                            final folderLabel =
                                dataService.noteFolderLabelFor(note);

                            return Card(
                              color: const Color(0xFFFFF6D9),
                              margin: const EdgeInsets.only(bottom: 16),
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () => _openNotePage(context, note: note),
                                onLongPress: () => _confirmDeleteNote(
                                  context,
                                  dataService,
                                  note,
                                ),
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  note.title
                                                              ?.trim()
                                                              .isNotEmpty ==
                                                          true
                                                      ? note.title!.trim()
                                                      : 'Untitled Note',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              _FilterPill(label: folderLabel),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            note.content ?? '',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              height: 1.5,
                                              color: Color(0xFF52473B),
                                            ),
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            DateFormat.yMMMd()
                                                .add_jm()
                                                .format(note.updatedAt),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF8A8175),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!note.isShared)
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        child: _NoteVisibilityCornerBadge(
                                          isShared: note.isShared,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
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
                    onPressed: () => _openNotePage(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Note'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<_NoteFilterOption> _buildFilterOptions(
    DataService dataService,
    List<Post> notes,
  ) {
    final options = <_NoteFilterOption>[
      const _NoteFilterOption(
        key: _NoteFilterOption.allKey,
        label: 'All',
      ),
    ];

    if (notes.any(dataService.isSharedNoteFromOtherUser)) {
      options.add(
        const _NoteFilterOption(
          key: _NoteFilterOption.shareKey,
          label: 'Share',
        ),
      );
    }

    for (final folderName in dataService.noteFoldersForCurrentGroup) {
      options.add(
        _NoteFilterOption(
          key: 'folder:$folderName',
          label: folderName,
        ),
      );
    }

    return options;
  }

  Future<void> _createFolder(
    BuildContext context,
    DataService dataService,
  ) async {
    if (dataService.currentGroup == null) {
      return;
    }

    final controller = TextEditingController();
    final folderName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New Folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Folder name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                controller.text.trim(),
              ),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    final normalizedName = folderName?.trim();
    if (normalizedName == null || normalizedName.isEmpty) {
      return;
    }

    dataService.createNoteFolder(normalizedName);

    setState(() {
      _selectedFilterKey = 'folder:$normalizedName';
    });
  }

  Future<void> _openNotePage(BuildContext context, {Post? note}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => NoteEditorPage(note: note),
      ),
    );
  }

  Future<void> _confirmDeleteNote(
    BuildContext context,
    DataService dataService,
    Post note,
  ) async {
    final shouldDelete = await showRecordDeleteConfirmationDialog(
      context,
      title: 'Delete Note',
      message: 'Delete this note permanently?',
    );
    if (!shouldDelete) {
      return;
    }

    await dataService.deleteNote(note.id);
  }
}

class _NoteFilterOption {
  const _NoteFilterOption({required this.key, required this.label});

  static const allKey = 'all';
  static const shareKey = 'share';

  final String key;
  final String label;
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
}

class _AddFolderChip extends StatelessWidget {
  const _AddFolderChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.create_new_folder_outlined, size: 18),
      label: const Text('New Folder'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF6A594B),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFD9CDBE)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NoteVisibilityCornerBadge extends StatelessWidget {
  const _NoteVisibilityCornerBadge({required this.isShared});

  final bool isShared;
  static const double _badgeSize = 24;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        isShared ? const Color(0xFFD8DDB8) : const Color(0xFFE7CCB3);
    final accentColor =
        isShared ? const Color(0xFF6C7A4E) : const Color(0xFF9A765D);
    final icon = isShared ? Icons.groups_2_rounded : Icons.lock_rounded;
    final label = isShared ? 'Public' : 'Private';

    return Container(
      width: _badgeSize,
      height: _badgeSize,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Tooltip(
              message: label,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 10,
                  color: accentColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
