import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/data_service.dart';
import '../../../models/post.dart';
import 'package:intl/intl.dart';

class NotesTab extends StatelessWidget {
  const NotesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DataService>(
      builder: (context, dataService, child) {
        final notes = dataService.posts.where((p) => p.type == PostType.note).toList();

        if (notes.isEmpty) {
          return const Center(child: Text('No notes yet. Leave a message!'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return Card(
              color: Colors.yellow[100],
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.content ?? '',
                      style: const TextStyle(fontSize: 16, fontFamily: 'Cursive'), // Handwritten feel
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat.yMMMd().add_jm().format(note.createdAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
