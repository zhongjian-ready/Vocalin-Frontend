import 'package:flutter/material.dart';

import 'tabs/album_tab.dart';
import 'tabs/notes_tab.dart';
import 'tabs/wishlist_tab.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF7F0),
                    borderRadius: BorderRadius.all(Radius.circular(28)),
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0xFFE8D8CA)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Color(0xFFFFE7D6),
                      borderRadius: BorderRadius.all(Radius.circular(22)),
                    ),
                    indicatorPadding: EdgeInsets.all(8),
                    labelColor: Color(0xFFCA7C56),
                    unselectedLabelColor: Color(0xFF6D5A4D),
                    labelStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(icon: Icon(Icons.photo_album_rounded), text: 'Album'),
                      Tab(icon: Icon(Icons.note_alt_rounded), text: 'Notes'),
                      Tab(
                          icon: Icon(Icons.check_circle_rounded),
                          text: 'Wishlist'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    AlbumTab(),
                    NotesTab(),
                    WishlistTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
