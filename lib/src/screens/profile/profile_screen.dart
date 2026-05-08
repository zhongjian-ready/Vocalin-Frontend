import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import 'space_management_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _defaultStatus = 'Running on snacks and blind optimism.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<DataService>(
        builder: (context, dataService, child) {
          final user = dataService.currentUser;
          final group = dataService.currentGroup;

          if (user == null) return const Center(child: Text('Not logged in'));

          final displayStatus = user.currentStatus?.trim().isNotEmpty == true
              ? user.currentStatus!.trim()
              : _defaultStatus;

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => _showEditProfileDialog(
                      context,
                      dataService: dataService,
                      authService: context.read<AuthService>(),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
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
                          _ProfileAvatar(
                            radius: 42,
                            name: user.name,
                            avatarUrl: user.avatarUrl,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        user.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Status: $displayStatus',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
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
                  ),
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

  Future<void> _showEditProfileDialog(
    BuildContext context, {
    required DataService dataService,
    required AuthService authService,
  }) {
    final user = dataService.currentUser;
    if (user == null) {
      return Future.value();
    }

    final formKey = GlobalKey<FormState>();
    final nicknameController = TextEditingController(text: user.nickname);
    final statusController =
        TextEditingController(text: user.currentStatus ?? '');
    final avatarController = TextEditingController(text: user.avatarUrl ?? '');

    final takenNicknames = dataService.currentGroup?.members
            .where((member) => member.id != user.id)
            .map((member) => member.nickname.trim().toLowerCase())
            .toSet() ??
        <String>{};

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var dialogError = '';
        var isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Edit Profile'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: _ProfileAvatar(
                          radius: 34,
                          name: nicknameController.text.trim().isEmpty
                              ? user.name
                              : nicknameController.text.trim(),
                          avatarUrl: avatarController.text.trim(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: avatarController,
                        decoration: const InputDecoration(
                          labelText: 'Avatar URL',
                          hintText: 'https://example.com/avatar.png',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nicknameController,
                        decoration: const InputDecoration(
                          labelText: 'Nickname',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final trimmedValue = value?.trim() ?? '';
                          if (trimmedValue.isEmpty) {
                            return 'Nickname cannot be empty';
                          }
                          if (takenNicknames
                              .contains(trimmedValue.toLowerCase())) {
                            return 'This nickname is already taken';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: statusController,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          hintText: _defaultStatus,
                          border: OutlineInputBorder(),
                        ),
                        minLines: 2,
                        maxLines: 3,
                      ),
                      if (dialogError.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          dialogError,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isSaving ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                          dialogError = '';
                        });

                        await dataService.updateProfile(
                          nickname: nicknameController.text,
                          avatarUrl: avatarController.text,
                          status: statusController.text,
                        );

                        final updatedUser = dataService.currentUser;
                        final errorMessage = dataService.errorMessage;

                        if (errorMessage != null && errorMessage.isNotEmpty) {
                          setDialogState(() {
                            isSaving = false;
                            dialogError = errorMessage;
                          });
                          return;
                        }

                        if (updatedUser != null) {
                          await authService.updateCurrentUser(updatedUser);
                        }

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.radius,
    required this.name,
    this.avatarUrl,
  });

  final double radius;
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final trimmedAvatarUrl = avatarUrl?.trim();
    final hasAvatar = trimmedAvatarUrl != null && trimmedAvatarUrl.isNotEmpty;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      backgroundImage: hasAvatar ? NetworkImage(trimmedAvatarUrl) : null,
      child: hasAvatar
          ? null
          : Text(
              initial,
              style: TextStyle(
                fontSize: radius * 0.6,
                color: const Color(0xFF7A4A35),
              ),
            ),
    );
  }
}
