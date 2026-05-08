import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/post.dart';
import '../../../services/data_service.dart';
import '../record_delete_confirmation_dialog.dart';

class NotesTab extends StatelessWidget {
  const NotesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DataService>(
      builder: (context, dataService, child) {
        final notes =
            dataService.posts.where((p) => p.type == PostType.note).toList();

        if (dataService.isLoading && notes.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (notes.isEmpty) {
          return Stack(
            children: [
              const Center(child: Text('No notes yet. Leave a message!')),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: () => _showNoteDialog(
                        context,
                        dataService,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Note'),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return Card(
                  color: Colors.yellow[100],
                  margin: const EdgeInsets.only(bottom: 16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showNoteDialog(
                      context,
                      dataService,
                      note: note,
                    ),
                    onLongPress: () => _confirmDeleteNote(
                      context,
                      dataService,
                      note,
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              Text(
                                note.content ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Cursive',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    DateFormat.yMMMd()
                                        .add_jm()
                                        .format(note.updatedAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _showNoteDialog(context, dataService),
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

  Future<void> _showNoteDialog(
    BuildContext context,
    DataService dataService, {
    Post? note,
  }) async {
    final result = await showDialog<_NoteFormResult>(
      context: context,
      builder: (context) => _NoteDialog(note: note),
    );

    if (result == null || result.content.isEmpty) {
      return;
    }

    if (note == null) {
      await dataService.addPost(
        Post(
          id: 0,
          type: PostType.note,
          content: result.content,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          color: 'yellow',
          isShared: result.isShared,
        ),
      );
      return;
    }

    await dataService.updateNote(
      note.id,
      content: result.content,
      isShared: result.isShared,
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

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({this.note});

  final Post? note;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _controller;
  late bool _isShared;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note?.content ?? '');
    _isShared = widget.note?.isShared ?? false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.note != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Note' : 'New Note'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Write something for yourself or your space...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _VisibilitySelector(
              value: _isShared,
              onChanged: (value) {
                setState(() {
                  _isShared = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final content = _controller.text.trim();
            if (content.isEmpty) {
              return;
            }

            Navigator.pop(
              context,
              _NoteFormResult(content: content, isShared: _isShared),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _VisibilitySelector extends StatelessWidget {
  const _VisibilitySelector({
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

class _NoteFormResult {
  const _NoteFormResult({required this.content, required this.isShared});

  final String content;
  final bool isShared;
}
