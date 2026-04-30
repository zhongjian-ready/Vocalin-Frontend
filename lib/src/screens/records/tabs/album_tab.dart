import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/post.dart';
import '../../../services/data_service.dart';

class AlbumTab extends StatelessWidget {
  const AlbumTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DataService>(
      builder: (context, dataService, child) {
        final photos =
            dataService.posts.where((p) => p.type == PostType.photo).toList();

        if (dataService.isLoading && photos.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (photos.isEmpty) {
          return const Center(child: Text('No photos yet. Upload one!'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    photo.imageUrl ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image)),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        photo.content ?? '',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
