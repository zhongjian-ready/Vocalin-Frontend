import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import 'space_management_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<DataService>(
        builder: (context, dataService, child) {
          final user = dataService.currentUser;
          final group = dataService.currentGroup;

          if (user == null) return const Center(child: Text('Not logged in'));

          return ListView(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8FA3), Color(0xFFF4C2F0)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.white,
                      child: Text(
                        user.name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          color: Color(0xFF7A4A35),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Status: ${user.currentStatus ?? "None"}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('WeChat Binding'),
                subtitle: const Text('Not bound'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('WeChat binding not implemented in demo')),
                  );
                },
              ),
              const Divider(),
              if (group != null) ...[
                ListTile(
                  leading: const Icon(Icons.group),
                  title: const Text('Space Management'),
                  subtitle:
                      Text('${group.name} · Invite Code: ${group.inviteCode}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SpaceManagementScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: const Text('Space Management'),
                  subtitle: const Text(
                      'Create a space or join one with an invite code'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SpaceManagementScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),
              ],
              ListTile(
                leading: const Icon(Icons.cake),
                title: const Text('Anniversary & Birthday'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.wallpaper),
                title: const Text('Customize Background'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Export Content'),
                subtitle: const Text('Send to email'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Export request sent to email')),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title:
                    const Text('Log Out', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await context.read<AuthService>().logout();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
