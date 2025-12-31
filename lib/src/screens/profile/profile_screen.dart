import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Consumer<DataService>(
        builder: (context, dataService, child) {
          final user = dataService.currentUser;
          final group = dataService.currentGroup;

          if (user == null) return const Center(child: Text('Not logged in'));

          return ListView(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(user.name),
                accountEmail: Text('Status: ${user.currentStatus ?? "None"}'),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(user.name[0].toUpperCase(), style: const TextStyle(fontSize: 24)),
                ),
                decoration: const BoxDecoration(color: Colors.pinkAccent),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('WeChat Binding'),
                subtitle: const Text('Not bound'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('WeChat binding not implemented in demo')),
                  );
                },
              ),
              const Divider(),
              if (group != null) ...[
                ListTile(
                  leading: const Icon(Icons.group),
                  title: const Text('Space Management'),
                  subtitle: Text('Invite Code: ${group.inviteCode}'),
                  trailing: const Icon(Icons.copy),
                  onTap: () {
                    // Copy to clipboard logic would go here
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied invite code: ${group.inviteCode}')),
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
                    const SnackBar(content: Text('Export request sent to email')),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Log Out', style: TextStyle(color: Colors.red)),
                onTap: () {},
              ),
            ],
          );
        },
      ),
    );
  }
}
