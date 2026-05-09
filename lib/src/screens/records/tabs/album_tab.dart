import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/album.dart';
import '../../../services/data_service.dart';
import '../create_album_page.dart';
import '../record_delete_confirmation_dialog.dart';
import 'photo_download_helper.dart';

String _photoSourceLabel(AlbumPhotoSource source) {
  switch (source) {
    case AlbumPhotoSource.library:
      return 'Library';
    case AlbumPhotoSource.camera:
      return 'Camera';
  }
}

bool _isDataImageUrl(String? value) {
  if (value == null) {
    return false;
  }

  return value.trim().startsWith('data:image/');
}

Uint8List? _decodeDataImageUrl(String? value) {
  if (!_isDataImageUrl(value)) {
    return null;
  }

  final normalized = value!.trim();
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

class AlbumTab extends StatelessWidget {
  const AlbumTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DataService>(
      builder: (context, dataService, child) {
        final albums = dataService.albums;

        if (dataService.isLoading && albums.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (albums.isEmpty) {
          return Stack(
            children: [
              const Center(child: Text('No albums yet. Create one!')),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showCreateAlbumDialog(context, dataService),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Create Album'),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Stack(
          children: [
            MasonryGridView.count(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return _AlbumCard(
                  album: album,
                  onTap: () {
                    if (album.photos.isEmpty) {
                      return;
                    }

                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => _AlbumPreviewPage(
                          albumTitle: album.title,
                          albumDescription: album.description,
                          photos: album.photos,
                          initialIndex: 0,
                        ),
                      ),
                    );
                  },
                  onLongPress: () =>
                      _confirmDeleteAlbum(context, dataService, album),
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
                    onPressed: () =>
                        _showCreateAlbumDialog(context, dataService),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Create Album'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateAlbumDialog(
    BuildContext context,
    DataService dataService,
  ) async {
    final result = await Navigator.of(context).push<CreateAlbumResult>(
      MaterialPageRoute<CreateAlbumResult>(
        builder: (context) => const CreateAlbumPage(),
      ),
    );

    if (result == null) {
      return;
    }

    await dataService.createAlbum(
      title: result.title,
      description: result.description,
      photos: result.photos,
      isShared: result.isShared,
    );
  }

  Future<void> _confirmDeleteAlbum(
    BuildContext context,
    DataService dataService,
    Album album,
  ) async {
    final shouldDelete = await showRecordDeleteConfirmationDialog(
      context,
      title: 'Delete Album',
      message: 'Delete this album and all photos inside it permanently?',
    );
    if (!shouldDelete) {
      return;
    }

    await dataService.deleteAlbum(album.id);
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.album,
    required this.onTap,
    required this.onLongPress,
  });

  final Album album;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final ownerNickname = album.ownerNickname ?? 'Unknown member';

    return Card(
      elevation: 2,
      shadowColor: const Color(0x14000000),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _NetworkAlbumImage(
                  imageUrl: album.coverImageUrl,
                  height: 188,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _AlbumPhotoCountBadge(count: album.totalPhotos),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!album.isShared) ...[
                        const Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: Color(0xFF58473C),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          album.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF4C382D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _OwnerAvatar(
                        nickname: ownerNickname,
                        avatarUrl: album.ownerAvatarUrl,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ownerNickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6A584B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('yyyy/M/d').format(album.updatedAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8D7A6C),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumPreviewPage extends StatefulWidget {
  const _AlbumPreviewPage({
    required this.albumTitle,
    this.albumDescription,
    required this.photos,
    required this.initialIndex,
  });

  final String albumTitle;
  final String? albumDescription;
  final List<AlbumPhoto> photos;
  final int initialIndex;

  @override
  State<_AlbumPreviewPage> createState() => _AlbumPreviewPageState();
}

class _AlbumPreviewPageState extends State<_AlbumPreviewPage> {
  late final PageController _pageController;
  late int _currentIndex;
  final Set<String> _preloadedImageUrls = <String>{};
  bool _isCurrentPhotoZoomed = false;
  bool _isChromeVisible = true;
  Timer? _chromeHideTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _scheduleChromeAutoHide();
      _precacheNearbyImages(_currentIndex);
    });
  }

  @override
  void dispose() {
    _chromeHideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _scheduleChromeAutoHide() {
    _chromeHideTimer?.cancel();
    if (!_isChromeVisible) {
      return;
    }

    _chromeHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _isCurrentPhotoZoomed) {
        return;
      }

      setState(() {
        _isChromeVisible = false;
      });
    });
  }

  void _handlePreviewActivity({bool showChrome = true}) {
    if (showChrome && !_isChromeVisible) {
      setState(() {
        _isChromeVisible = true;
      });
    }

    if (_isChromeVisible || showChrome) {
      _scheduleChromeAutoHide();
    }
  }

  void _toggleChromeVisibility() {
    setState(() {
      _isChromeVisible = !_isChromeVisible;
    });

    if (_isChromeVisible) {
      _scheduleChromeAutoHide();
    } else {
      _chromeHideTimer?.cancel();
    }
  }

  Future<void> _precacheNearbyImages(int centerIndex) async {
    final nearbyIndexes = <int>{centerIndex - 1, centerIndex + 1};
    for (final index in nearbyIndexes) {
      if (index < 0 || index >= widget.photos.length) {
        continue;
      }

      final imageUrl = widget.photos[index].imageUrl.trim();
      if (imageUrl.isEmpty || _isDataImageUrl(imageUrl)) {
        continue;
      }

      if (!_preloadedImageUrls.add(imageUrl)) {
        continue;
      }

      try {
        await precacheImage(NetworkImage(imageUrl), context);
      } catch (_) {
        _preloadedImageUrls.remove(imageUrl);
      }
    }
  }

  Future<void> _showPhotoActions(AlbumPhoto photo) async {
    _handlePreviewActivity();
    final imageUrl = photo.imageUrl.trim();
    if (imageUrl.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share photo'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await SharePlus.instance.share(ShareParams(text: imageUrl));
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Save original'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final saved = await savePhotoFromUrl(
                    imageUrl,
                    suggestedFileName: 'vocalin-album-photo-${photo.id}.jpg',
                  );

                  if (!mounted) {
                    return;
                  }

                  if (saved) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Image download started')),
                    );
                    return;
                  }

                  await Clipboard.setData(ClipboardData(text: imageUrl));
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Direct save is unavailable here. Image URL copied.',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('Copy image URL'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await Clipboard.setData(ClipboardData(text: imageUrl));
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Image URL copied')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPhoto = widget.photos[_currentIndex];
    final albumDescription = widget.albumDescription?.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              physics: _isCurrentPhotoZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: widget.photos.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _isCurrentPhotoZoomed = false;
                  _isChromeVisible = true;
                });
                _scheduleChromeAutoHide();
                _precacheNearbyImages(index);
              },
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                return _ZoomableAlbumPreviewPhoto(
                  key: ValueKey(photo.id),
                  photo: photo,
                  isActive: index == _currentIndex,
                  onZoomChanged: (isZoomed) {
                    if (index != _currentIndex ||
                        _isCurrentPhotoZoomed == isZoomed) {
                      return;
                    }

                    setState(() {
                      _isCurrentPhotoZoomed = isZoomed;
                      if (isZoomed) {
                        _isChromeVisible = true;
                      }
                    });

                    if (isZoomed) {
                      _chromeHideTimer?.cancel();
                    } else {
                      _scheduleChromeAutoHide();
                    }
                  },
                  onDismiss: () => Navigator.of(context).pop(),
                  onLongPress: () => _showPhotoActions(photo),
                  onTap: _toggleChromeVisibility,
                  onInteraction: (showChrome) {
                    _handlePreviewActivity(showChrome: showChrome);
                  },
                );
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_isChromeVisible,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isChromeVisible ? 1 : 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0x66000000),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.albumTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x66000000),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_currentIndex + 1}/${widget.photos.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: () => _showPhotoActions(currentPhoto),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0x66000000),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.more_vert_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !_isChromeVisible,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isChromeVisible ? 1 : 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: const Color(0x66000000),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (albumDescription != null &&
                            albumDescription.isNotEmpty) ...[
                          Text(
                            albumDescription,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (_isCurrentPhotoZoomed) ...[
                          if (albumDescription != null &&
                              albumDescription.isNotEmpty)
                            const SizedBox(height: 8),
                          const Text(
                            'Double tap to reset',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomableAlbumPreviewPhoto extends StatefulWidget {
  const _ZoomableAlbumPreviewPhoto({
    super.key,
    required this.photo,
    required this.isActive,
    required this.onZoomChanged,
    required this.onDismiss,
    required this.onLongPress,
    required this.onTap,
    required this.onInteraction,
  });

  final AlbumPhoto photo;
  final bool isActive;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onDismiss;
  final VoidCallback onLongPress;
  final VoidCallback onTap;
  final ValueChanged<bool> onInteraction;

  @override
  State<_ZoomableAlbumPreviewPhoto> createState() =>
      _ZoomableAlbumPreviewPhotoState();
}

class _ZoomableAlbumPreviewPhotoState
    extends State<_ZoomableAlbumPreviewPhoto> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;
  double _verticalDragOffset = 0;
  bool _isZoomed = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ZoomableAlbumPreviewPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      _resetTransform(notify: false);
    }
  }

  void _resetTransform({bool notify = true}) {
    _transformationController.value = Matrix4.identity();
    _verticalDragOffset = 0;
    if (_isZoomed) {
      _isZoomed = false;
      if (notify) {
        widget.onZoomChanged(false);
      }
    } else if (notify) {
      widget.onZoomChanged(false);
    }
  }

  void _handleDoubleTap() {
    final details = _doubleTapDetails;
    if (_isZoomed || details == null) {
      setState(() {
        _resetTransform();
      });
      widget.onInteraction(true);
      return;
    }

    const scale = 2.5;
    final position = details.localPosition;
    _transformationController.value = Matrix4.identity()
      ..translate(-position.dx * (scale - 1), -position.dy * (scale - 1))
      ..scale(scale);

    setState(() {
      _isZoomed = true;
    });
    widget.onZoomChanged(true);
    widget.onInteraction(true);
  }

  void _handleInteractionEnd(ScaleEndDetails details) {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.01;
    if (_isZoomed != isZoomed) {
      setState(() {
        _isZoomed = isZoomed;
      });
      widget.onZoomChanged(isZoomed);
    }
    widget.onInteraction(true);
  }

  @override
  Widget build(BuildContext context) {
    final dragProgress = (_verticalDragOffset / 180).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onDoubleTapDown: (details) {
        _doubleTapDetails = details;
      },
      onDoubleTap: _handleDoubleTap,
      onVerticalDragUpdate: _isZoomed
          ? null
          : (details) {
              final delta = details.primaryDelta ?? 0;
              final nextOffset =
                  (_verticalDragOffset + delta).clamp(0.0, 240.0);
              if (nextOffset == _verticalDragOffset) {
                return;
              }

              setState(() {
                _verticalDragOffset = nextOffset;
              });
              widget.onInteraction(true);
            },
      onVerticalDragEnd: _isZoomed
          ? null
          : (details) {
              if (_verticalDragOffset > 120 ||
                  (details.primaryVelocity != null &&
                      details.primaryVelocity! > 800)) {
                widget.onDismiss();
                return;
              }

              setState(() {
                _verticalDragOffset = 0;
              });
              widget.onInteraction(true);
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: 1 - dragProgress * 0.35,
        child: Transform.translate(
          offset: Offset(0, _verticalDragOffset),
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1,
            maxScale: 4,
            onInteractionStart: (_) => widget.onInteraction(true),
            onInteractionEnd: _handleInteractionEnd,
            child: Center(
              child: _PreviewAlbumImage(imageUrl: widget.photo.imageUrl),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewAlbumImage extends StatelessWidget {
  const _PreviewAlbumImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final imageBytes = _decodeDataImageUrl(imageUrl);
    if (imageBytes != null) {
      return Image.memory(
        imageBytes,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.broken_image_outlined,
            color: Colors.white70,
            size: 56,
          );
        },
      );
    }

    return Image.network(
      imageUrl,
      width: double.infinity,
      fit: BoxFit.contain,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: child,
          );
        }

        return const _PreviewAlbumImagePlaceholder();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return _PreviewAlbumImagePlaceholder(
          progress: loadingProgress.expectedTotalBytes != null
              ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
              : null,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Icon(
          Icons.broken_image_outlined,
          color: Colors.white70,
          size: 56,
        );
      },
    );
  }
}

class _PreviewAlbumImagePlaceholder extends StatelessWidget {
  const _PreviewAlbumImagePlaceholder({this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          value: progress,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _NetworkAlbumImage extends StatelessWidget {
  const _NetworkAlbumImage({
    required this.imageUrl,
    required this.height,
  });

  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl?.trim();
    if (normalizedUrl == null || normalizedUrl.isEmpty) {
      return _AlbumImagePlaceholder(height: height);
    }

    final imageBytes = _decodeDataImageUrl(normalizedUrl);
    if (imageBytes != null) {
      return Image.memory(
        imageBytes,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _AlbumImagePlaceholder(height: height, showError: true);
        },
      );
    }

    return Image.network(
      normalizedUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }

        return _AlbumImagePlaceholder(height: height);
      },
      errorBuilder: (context, error, stackTrace) {
        return _AlbumImagePlaceholder(height: height, showError: true);
      },
    );
  }
}

class _AlbumImagePlaceholder extends StatelessWidget {
  const _AlbumImagePlaceholder({
    required this.height,
    this.showError = false,
  });

  final double height;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: const Color(0xFFF1E6DB),
      alignment: Alignment.center,
      child: Icon(
        showError ? Icons.broken_image_outlined : Icons.photo_album_outlined,
        color: const Color(0xFF9A7B64),
        size: 36,
      ),
    );
  }
}

class _AlbumPhotoCountBadge extends StatelessWidget {
  const _AlbumPhotoCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC251812),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_rounded,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerAvatar extends StatelessWidget {
  const _OwnerAvatar({required this.nickname, this.avatarUrl});

  final String nickname;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final normalizedAvatarUrl = avatarUrl?.trim();
    final hasAvatar =
        normalizedAvatarUrl != null && normalizedAvatarUrl.isNotEmpty;

    return CircleAvatar(
      radius: 12,
      backgroundColor: const Color(0xFFFFE7D6),
      foregroundImage: hasAvatar ? NetworkImage(normalizedAvatarUrl) : null,
      child: hasAvatar
          ? null
          : Text(
              nickname.characters.first.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFFC9793A),
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _AlbumDialog extends StatefulWidget {
  const _AlbumDialog();

  @override
  State<_AlbumDialog> createState() => _AlbumDialogState();
}

class _AlbumDialogState extends State<_AlbumDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final List<_EditableAlbumPhotoInput> _photoInputs;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isShared = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _photoInputs = [_EditableAlbumPhotoInput()];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final input in _photoInputs) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhotosFromLibrary() async {
    final files = await _imagePicker.pickMultiImage(imageQuality: 85);
    if (!mounted || files.isEmpty) {
      return;
    }

    await _appendPickedPhotos(files, AlbumPhotoSource.library);
  }

  Future<void> _takePhoto() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (!mounted || file == null) {
      return;
    }

    await _appendPickedPhotos([file], AlbumPhotoSource.camera);
  }

  Future<void> _appendPickedPhotos(
    List<XFile> files,
    AlbumPhotoSource source,
  ) async {
    final pickedInputs = <_EditableAlbumPhotoInput>[];

    for (final file in files) {
      final bytes = await file.readAsBytes();
      final mimeType =
          _detectMimeType(file.name.isEmpty ? file.path : file.name);
      final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
      pickedInputs.add(
        _EditableAlbumPhotoInput.fromSelectedImage(
          dataUrl: dataUrl,
          source: source,
          fileLabel: file.name.isEmpty ? 'Selected photo' : file.name,
        ),
      );
    }

    if (!mounted || pickedInputs.isEmpty) {
      return;
    }

    setState(() {
      if (_photoInputs.length == 1 && _photoInputs.single.isBlank) {
        final emptyInput = _photoInputs.removeAt(0);
        emptyInput.dispose();
      }
      _photoInputs.addAll(pickedInputs);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Album'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Album name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Album intro',
                hintText: 'Optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Photos',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickPhotosFromLibrary,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose From Library'),
                ),
                OutlinedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take Photo'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _photoInputs.add(_EditableAlbumPhotoInput());
                    });
                  },
                  icon: const Icon(Icons.link_outlined),
                  label: const Text('Add URL Entry'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < _photoInputs.length; index++) ...[
              _AlbumPhotoDraftCard(
                key: ValueKey('photo-draft-$index'),
                input: _photoInputs[index],
                index: index,
                canRemove: _photoInputs.length > 1,
                onRemove: () {
                  setState(() {
                    final input = _photoInputs.removeAt(index);
                    input.dispose();
                  });
                },
                onClearSelectedImage:
                    _photoInputs[index].selectedImageDataUrl == null
                        ? null
                        : () {
                            setState(() {
                              _photoInputs[index].clearSelectedImage();
                            });
                          },
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Text(
              'Each album must contain at least one photo. You can choose multiple images from the library, take a photo, or keep using a URL entry when needed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8D7A6C),
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 16),
            _AlbumVisibilitySelector(
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
            final title = _titleController.text.trim();
            final photos = _photoInputs
                .map((input) => input.toDraft())
                .whereType<AlbumPhotoDraft>()
                .toList();

            if (title.isEmpty || photos.isEmpty) {
              return;
            }

            Navigator.pop(
              context,
              _AlbumFormResult(
                title: title,
                description: _descriptionController.text.trim(),
                photos: photos,
                isShared: _isShared,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _EditableAlbumPhotoInput {
  _EditableAlbumPhotoInput()
      : urlController = TextEditingController(),
        descriptionController = TextEditingController();

  _EditableAlbumPhotoInput.fromSelectedImage({
    required String dataUrl,
    required AlbumPhotoSource source,
    required String fileLabel,
  })  : urlController = TextEditingController(),
        descriptionController = TextEditingController(),
        source = source,
        selectedImageDataUrl = dataUrl,
        selectedImageLabel = fileLabel;

  final TextEditingController urlController;
  final TextEditingController descriptionController;
  AlbumPhotoSource source = AlbumPhotoSource.library;
  String? selectedImageDataUrl;
  String? selectedImageLabel;

  bool get isBlank =>
      urlController.text.trim().isEmpty &&
      descriptionController.text.trim().isEmpty &&
      (selectedImageDataUrl == null || selectedImageDataUrl!.trim().isEmpty);

  AlbumPhotoDraft? toDraft() {
    final url = selectedImageDataUrl?.trim().isNotEmpty == true
        ? selectedImageDataUrl!.trim()
        : urlController.text.trim();
    if (url.isEmpty) {
      return null;
    }

    final description = descriptionController.text.trim();
    return AlbumPhotoDraft(
      url: url,
      description: description.isEmpty ? null : description,
      source: source,
    );
  }

  void clearSelectedImage() {
    selectedImageDataUrl = null;
    selectedImageLabel = null;
  }

  void dispose() {
    urlController.dispose();
    descriptionController.dispose();
  }
}

class _AlbumPhotoDraftCard extends StatelessWidget {
  const _AlbumPhotoDraftCard({
    super.key,
    required this.input,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    this.onClearSelectedImage,
  });

  final _EditableAlbumPhotoInput input;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback? onClearSelectedImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3EE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Photo ${index + 1}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              if (onClearSelectedImage != null)
                IconButton(
                  onPressed: onClearSelectedImage,
                  icon: const Icon(Icons.refresh_outlined),
                  tooltip: 'Clear selected image',
                ),
              if (canRemove)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove photo',
                ),
            ],
          ),
          if (input.selectedImageDataUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _NetworkAlbumImage(
                imageUrl: input.selectedImageDataUrl,
                height: 148,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              input.selectedImageLabel == null ||
                      input.selectedImageLabel!.trim().isEmpty
                  ? 'Selected from ${_photoSourceLabel(input.source).toLowerCase()}'
                  : input.selectedImageLabel!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6A584B),
                  ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: input.urlController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: input.selectedImageDataUrl == null
                  ? 'Photo URL'
                  : 'Replace with URL',
              hintText: input.selectedImageDataUrl == null
                  ? 'Paste a URL or use the picker buttons above'
                  : 'Optional override',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: input.descriptionController,
            decoration: const InputDecoration(
              labelText: 'Photo description',
              hintText: 'Optional',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Upload source',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          StatefulBuilder(
            builder: (context, setChipState) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    selected: input.source == AlbumPhotoSource.library,
                    avatar: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Library'),
                    onSelected: (_) {
                      setChipState(() {
                        input.source = AlbumPhotoSource.library;
                      });
                    },
                  ),
                  ChoiceChip(
                    selected: input.source == AlbumPhotoSource.camera,
                    avatar: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Camera'),
                    onSelected: (_) {
                      setChipState(() {
                        input.source = AlbumPhotoSource.camera;
                      });
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AlbumVisibilitySelector extends StatelessWidget {
  const _AlbumVisibilitySelector({
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

class _AlbumFormResult {
  const _AlbumFormResult({
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
