import 'package:flutter/material.dart';
import '../models/post.dart';
import 'package:intl/intl.dart';

class RecentActivityCard extends StatelessWidget {
  final Post? latestPost;

  const RecentActivityCard({super.key, this.latestPost});

  @override
  Widget build(BuildContext context) {
    if (latestPost == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (latestPost!.type == PostType.photo && latestPost!.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      latestPost!.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(width: 60, height: 60, color: Colors.grey),
                    ),
                  )
                else
                  const Icon(Icons.note, size: 40, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latestPost!.content ?? (latestPost!.type == PostType.photo ? 'Shared a photo' : 'Shared a note'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat.yMMMd().add_jm().format(latestPost!.createdAt),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
