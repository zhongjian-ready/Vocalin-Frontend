import 'package:flutter/material.dart';
import 'tabs/album_tab.dart';
import 'tabs/notes_tab.dart';
import 'tabs/wishlist_tab.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Records'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.photo_album), text: 'Album'),
              Tab(icon: Icon(Icons.note), text: 'Notes'),
              Tab(icon: Icon(Icons.check_circle), text: 'Wishlist'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AlbumTab(),
            NotesTab(),
            WishlistTab(),
          ],
        ),
      ),
    );
  }
}
