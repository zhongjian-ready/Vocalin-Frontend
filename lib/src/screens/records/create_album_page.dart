import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/album.dart';

class CreateAlbumResult {
  const CreateAlbumResult({
    required this.title,
    required this.description,
    required this.photos,
    required this.isShared,
  });

  final String title;
  final String description;
  final List<AlbumPhotoDraft> photos;
  final bool isShared;
}

class CreateAlbumPage extends StatefulWidget {
  const CreateAlbumPage({super.key});

  @override
  State<CreateAlbumPage> createState() => _CreateAlbumPageState();
}

class _CreateAlbumPageState extends State<CreateAlbumPage> {
  static const _draftStorageKey = 'records.create_album_draft';
  static const _maxPhotoCount = 9;

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final ImagePicker _imagePicker = ImagePicker();
  final List<AlbumPhotoDraft> _photos = [];

  bool _isDraftReady = false;
  bool _isSavingDraft = false;
  bool _isPublishing = false;
  bool _isPickingPhotos = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _restoreDraft();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final preferences = await SharedPreferences.getInstance();
    final rawDraft = preferences.getString(_draftStorageKey);

    if (rawDraft != null && rawDraft.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDraft);
        if (decoded is Map<String, dynamic>) {
          final title = (decoded['title'] as String? ?? '').trim();
          final description = (decoded['description'] as String? ?? '').trim();
          final rawPhotos = decoded['photos'];
          final restoredPhotos = <AlbumPhotoDraft>[];

          if (rawPhotos is List) {
            for (final photo in rawPhotos) {
              if (photo is! Map) {
                continue;
              }

              final url = (photo['url'] as String? ?? '').trim();
              if (url.isEmpty) {
                continue;
              }

              final descriptionValue =
                  (photo['description'] as String?)?.trim();
              final sourceValue =
                  (photo['source'] as String? ?? '').trim().toLowerCase();

              restoredPhotos.add(
                AlbumPhotoDraft(
                  url: url,
                  description: descriptionValue?.isEmpty == true
                      ? null
                      : descriptionValue,
                  source: sourceValue == 'camera'
                      ? AlbumPhotoSource.camera
                      : AlbumPhotoSource.library,
                ),
              );
            }
          }

          _titleController.text = title;
          _descriptionController.text = description;
          _photos
            ..clear()
            ..addAll(restoredPhotos);
        }
      } catch (_) {}
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isDraftReady = true;
    });
  }

  Future<void> _pickPhotos() async {
    if (_isPickingPhotos) {
      return;
    }

    final remainingSlots = _maxPhotoCount - _photos.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 9 photos only.')),
      );
      return;
    }

    setState(() {
      _isPickingPhotos = true;
    });

    try {
      final files = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (!mounted || files.isEmpty) {
        return;
      }

      final pickedPhotos = <AlbumPhotoDraft>[];
      final limitedFiles = files.take(remainingSlots).toList();
      for (final file in limitedFiles) {
        final bytes = await file.readAsBytes();
        final mimeType =
            _detectMimeType(file.name.isEmpty ? file.path : file.name);
        pickedPhotos.add(
          AlbumPhotoDraft(
            url: 'data:$mimeType;base64,${base64Encode(bytes)}',
            source: AlbumPhotoSource.library,
          ),
        );
      }

      if (!mounted || pickedPhotos.isEmpty) {
        return;
      }

      setState(() {
        _photos.addAll(pickedPhotos);
      });

      if (files.length > limitedFiles.length && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'You can add up to 9 photos only. Extra photos were ignored.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingPhotos = false;
        });
      }
    }
  }

  Future<void> _saveDraft() async {
    if (_isSavingDraft) {
      return;
    }

    setState(() {
      _isSavingDraft = true;
    });

    try {
      final preferences = await SharedPreferences.getInstance();
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();

      if (title.isEmpty && description.isEmpty && _photos.isEmpty) {
        await preferences.remove(_draftStorageKey);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Draft was empty, so the local draft was cleared.')),
        );
        return;
      }

      await preferences.setString(
        _draftStorageKey,
        jsonEncode({
          'title': title,
          'description': description,
          'photos': _photos.map((photo) => photo.toJson()).toList(),
        }),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
        });
      }
    }
  }

  Future<void> _publish() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an album title first.')),
      );
      return;
    }

    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one photo.')),
      );
      return;
    }

    final isShared = await _showPublishVisibilityDialog();
    if (isShared == null || !mounted) {
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_draftStorageKey);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        CreateAlbumResult(
          title: title,
          description: _descriptionController.text.trim(),
          photos: List<AlbumPhotoDraft>.unmodifiable(_photos),
          isShared: isShared,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  Future<bool?> _showPublishVisibilityDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => const _PublishVisibilityDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: _isDraftReady
          ? SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var index = 0; index < _photos.length; index++)
                          _SelectedPhotoTile(
                            photo: _photos[index],
                            onRemove: () {
                              setState(() {
                                _photos.removeAt(index);
                              });
                            },
                          ),
                        if (_photos.length < _maxPhotoCount)
                          _AddPhotoTile(
                            isLoading: _isPickingPhotos,
                            onTap: _pickPhotos,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Added ${_photos.length}/$_maxPhotoCount photos',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFA39B93),
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF2F2A25),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Add title',
                        hintStyle: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFFCBC5BE),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _descriptionController,
                      minLines: 5,
                      maxLines: null,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.6,
                        color: Color(0xFF5A514A),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Add text or description',
                        hintStyle: TextStyle(
                          fontSize: 18,
                          color: Color(0xFFD8D2CB),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isDraftReady && !_isPublishing ? _saveDraft : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: Color(0xFFD9D2CA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSavingDraft
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Draft'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _isDraftReady && !_isPublishing ? _publish : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: const Color(0xFF2F2A25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isPublishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Publish'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F7F4),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 92,
          height: 92,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.add,
                    size: 34,
                    color: Color(0xFFD0CCC6),
                  ),
          ),
        ),
      ),
    );
  }
}

class _PublishVisibilityDialog extends StatefulWidget {
  const _PublishVisibilityDialog();

  @override
  State<_PublishVisibilityDialog> createState() =>
      _PublishVisibilityDialogState();
}

class _PublishVisibilityDialogState extends State<_PublishVisibilityDialog> {
  bool _isShared = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Visibility'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<bool>(
            value: true,
            groupValue: _isShared,
            contentPadding: EdgeInsets.zero,
            title: const Text('Public'),
            subtitle: const Text('Everyone in the group can see this album.'),
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _isShared = value;
              });
            },
          ),
          RadioListTile<bool>(
            value: false,
            groupValue: _isShared,
            contentPadding: EdgeInsets.zero,
            title: const Text('Private'),
            subtitle: const Text('Only you can see this album.'),
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _isShared = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_isShared),
          child: const Text('Confirm Publish'),
        ),
      ],
    );
  }
}

class _SelectedPhotoTile extends StatelessWidget {
  const _SelectedPhotoTile({required this.photo, required this.onRemove});

  final AlbumPhotoDraft photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 92,
            height: 92,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFFF3EFEA)),
              child: _DraftPhotoImage(photoUrl: photo.url),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: const Color(0xAA000000),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DraftPhotoImage extends StatelessWidget {
  const _DraftPhotoImage({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final memoryBytes = _tryDecodeDataImage(photoUrl);
    if (memoryBytes != null) {
      return Image.memory(memoryBytes, fit: BoxFit.cover);
    }

    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Color(0xFFB9B2AA),
          ),
        );
      },
    );
  }
}

Uint8List? _tryDecodeDataImage(String value) {
  final normalized = value.trim();
  if (!normalized.startsWith('data:image/')) {
    return null;
  }

  final commaIndex = normalized.indexOf(',');
  if (commaIndex < 0 || commaIndex == normalized.length - 1) {
    return null;
  }

  try {
    return base64Decode(normalized.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}

String _detectMimeType(String fileName) {
  final normalized = fileName.trim().toLowerCase();
  if (normalized.endsWith('.png')) {
    return 'image/png';
  }
  if (normalized.endsWith('.webp')) {
    return 'image/webp';
  }
  if (normalized.endsWith('.gif')) {
    return 'image/gif';
  }

  return 'image/jpeg';
}
