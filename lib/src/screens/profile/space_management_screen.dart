import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/group.dart';
import '../../services/data_service.dart';

class SpaceManagementScreen extends StatefulWidget {
  const SpaceManagementScreen({super.key});

  @override
  State<SpaceManagementScreen> createState() => _SpaceManagementScreenState();
}

class _SpaceManagementScreenState extends State<SpaceManagementScreen> {
  final _createController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _createController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Space Management'),
      ),
      body: Consumer<DataService>(
        builder: (context, dataService, child) {
          final group = dataService.currentGroup;

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFFBF6), Color(0xFFF8F0E8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _HeaderCard(group: group),
                  const SizedBox(height: 16),
                  if (dataService.errorMessage != null) ...[
                    _ErrorBanner(message: dataService.errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  if (group == null) ...[
                    _ActionCard(
                      icon: Icons.add_home_rounded,
                      title: 'Create a space',
                      description:
                          'Create your own private space and invite others with a generated code.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _createController,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Space name',
                              hintText: 'For example: Warm Home',
                            ),
                            onSubmitted: (_) => _createSpace(context),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _createSpace(context),
                              icon: const Icon(Icons.auto_awesome),
                              label: Text(
                                _isSubmitting ? 'Creating...' : 'Create Space',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ActionCard(
                      icon: Icons.key_rounded,
                      title: 'Join with invite code',
                      description:
                          'Enter the invite code shared by your partner or family to join an existing space.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _inviteCodeController,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Invite code',
                              hintText: 'Enter code',
                            ),
                            onSubmitted: (_) => _joinSpace(context),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _joinSpace(context),
                              icon: const Icon(Icons.login_rounded),
                              label: Text(
                                _isSubmitting ? 'Joining...' : 'Join Space',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    _ActionCard(
                      icon: Icons.group_rounded,
                      title: group.name,
                      description:
                          'Manage your current space here. Share the invite code so others can join.',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _InfoTile(
                                  label: 'Invite code',
                                  value: group.inviteCode,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InfoTile(
                                  label: 'Members',
                                  value: '${group.members.length}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      _copyInviteCode(context, group),
                                  icon: const Icon(Icons.copy_rounded),
                                  label: const Text('Copy Code'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => _refreshSpace(context),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Refresh'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ActionCard(
                      icon: Icons.people_alt_rounded,
                      title: 'Members',
                      description: 'Current members in this space.',
                      child: Column(
                        children: [
                          for (final member in group.members)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFFFE3C8),
                                child: Text(
                                    member.name.characters.first.toUpperCase()),
                              ),
                              title: Text(member.name),
                              subtitle: Text(
                                  member.currentStatus?.isNotEmpty == true
                                      ? member.currentStatus!
                                      : 'No status yet'),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    group == null
                        ? 'You can always come back here from Profile > Space Management.'
                        : 'Profile > Space Management is your dedicated place to manage this space.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF7D6B5D),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createSpace(BuildContext context) async {
    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);

    if (_createController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a space name.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    await dataService.createGroup(_createController.text);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (dataService.currentGroup != null) {
      _createController.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Space created successfully.')),
      );
    }
  }

  Future<void> _joinSpace(BuildContext context) async {
    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);

    if (_inviteCodeController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter an invite code.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    await dataService
        .joinGroup(_inviteCodeController.text.trim().toUpperCase());

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (dataService.currentGroup != null) {
      _inviteCodeController.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Joined space successfully.')),
      );
    }
  }

  Future<void> _refreshSpace(BuildContext context) async {
    final dataService = context.read<DataService>();

    setState(() {
      _isSubmitting = true;
    });

    await dataService.refreshData();

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });
  }

  Future<void> _copyInviteCode(BuildContext context, Group group) async {
    await Clipboard.setData(ClipboardData(text: group.inviteCode));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invite code copied: ${group.inviteCode}')),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.group});

  final Group? group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE2C0), Color(0xFFFFF1E3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A9A5A1A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              group == null
                  ? Icons.meeting_room_rounded
                  : Icons.holiday_village,
              color: const Color(0xFFB56C37),
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            group == null ? 'Start your first space' : group!.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF69422A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            group == null
                ? 'Create a private space for the two of you, or join one with an invite code.'
                : 'This is the control point for your space, members, and invite code.',
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.45,
              color: const Color(0xFF7A5642),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1D8C2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFB56C37)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF7D6B5D),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF8A7668),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEFEA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC5B3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline, color: Color(0xFFD85A3D)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB4432D),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
