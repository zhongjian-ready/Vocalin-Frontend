import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/data_service.dart';

class WishlistTab extends StatelessWidget {
  const WishlistTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DataService>(
      builder: (context, dataService, child) {
        final wishes = dataService.wishes;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: () => _showAddWishDialog(context, dataService),
                icon: const Icon(Icons.add),
                label: const Text('Add Wish'),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: wishes.length,
                itemBuilder: (context, index) {
                  final wish = wishes[index];
                  return CheckboxListTile(
                    title: Text(
                      wish.title,
                      style: TextStyle(
                        decoration: wish.isCompleted ? TextDecoration.lineThrough : null,
                        color: wish.isCompleted ? Colors.grey : Colors.black,
                      ),
                    ),
                    value: wish.isCompleted,
                    onChanged: (value) {
                      dataService.toggleWish(wish.id);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddWishDialog(BuildContext context, DataService dataService) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Wish'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'What do you want to do together?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                dataService.addWish(controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
