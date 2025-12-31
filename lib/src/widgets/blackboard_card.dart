import 'package:flutter/material.dart';

class BlackboardCard extends StatelessWidget {
  final String message;
  final VoidCallback? onEdit;

  const BlackboardCard({
    super.key,
    required this.message,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF333333),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '📌 Blackboard',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Icon(Icons.edit, color: Colors.white70, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Courier', // Monospace for blackboard feel
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
