import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/group.dart';
import '../../models/group_list_item.dart';
import '../../models/space_inbox_item.dart';
import '../../models/user.dart';
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
  String? _lastHandledErrorMessage;

  @override
  void dispose() {
    _createController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _showErrorMessageIfNeeded(
    BuildContext context,
    DataService dataService,
  ) {
    final errorMessage = dataService.errorMessage;
    if (errorMessage == null) {
      _lastHandledErrorMessage = null;
      return;
    }

    if (errorMessage == _lastHandledErrorMessage) {
      return;
    }

    _lastHandledErrorMessage = errorMessage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final currentDataService = context.read<DataService>();
      if (currentDataService.errorMessage != errorMessage) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFD85A3D),
          content: Text(errorMessage),
        ),
      );
      currentDataService.clearErrorMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Space Management'),
      ),
      body: Consumer<DataService>(
        builder: (context, dataService, child) {
          _showErrorMessageIfNeeded(context, dataService);

          final theme = Theme.of(context);
          final group = dataService.currentGroup;
          final currentUser = dataService.currentUser;
          final currentUserId = currentUser?.id;
          final joinedGroups = dataService.joinedGroups;
          final pendingMessages = group == null
              ? const <SpaceInboxItem>[]
              : dataService.spaceInboxItems
                  .where((item) => item.groupId == group.id)
                  .toList();
          final hasOtherGroups =
              group != null && joinedGroups.any((item) => item.id != group.id);
          final canManageOwnership = group != null &&
              currentUser != null &&
              group.isOwnedBy(currentUser.id);
          final canApproveJoinRequests = group?.canManageMembers == true;
          final joinRequestMessages = canApproveJoinRequests
              ? pendingMessages.where((item) => item.isJoinRequest).toList()
              : const <SpaceInboxItem>[];
          final transferApprovalMessage = pendingMessages
              .where((item) =>
                  item.isOwnershipTransfer &&
                  item.targetUserId == currentUserId)
              .firstOrNull;
          final canKickMembers = group?.myRole == 'owner';
          final shouldSelectSuccessorBeforeLeaving =
              canManageOwnership && group.members.length > 1;
          final hasPendingApprovals =
              joinRequestMessages.isNotEmpty || transferApprovalMessage != null;

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
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InfoTile(
                                  label: 'Your role',
                                  value: canManageOwnership
                                      ? 'Owner'
                                      : _formatRoleLabel(group.myRole),
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
                    if (hasPendingApprovals) ...[
                      _ActionCard(
                        icon: Icons.mark_email_unread_rounded,
                        title: 'Pending approvals',
                        description:
                            'Review join requests and ownership transfers from here.',
                        child: Column(
                          children: [
                            if (transferApprovalMessage != null) ...[
                              _PendingApprovalTile(
                                title: 'Ownership transfer',
                                description:
                                    '${transferApprovalMessage.requesterNickname ?? 'The current owner'} wants to transfer ${group.name} to you.',
                                actions: [
                                  OutlinedButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _rejectOwnershipTransfer(
                                              context,
                                              group,
                                              transferApprovalMessage,
                                            ),
                                    child: const Text('Reject'),
                                  ),
                                  FilledButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _acceptOwnershipTransfer(
                                              context,
                                              group,
                                            ),
                                    child: const Text('Approve'),
                                  ),
                                ],
                              ),
                              if (joinRequestMessages.isNotEmpty)
                                const SizedBox(height: 12),
                            ],
                            for (var index = 0;
                                index < joinRequestMessages.length;
                                index++) ...[
                              _PendingApprovalTile(
                                title: joinRequestMessages[index]
                                        .requesterNickname ??
                                    'New member',
                                description: 'Requested to join ${group.name}.',
                                actions: [
                                  OutlinedButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _rejectJoinRequest(
                                              context,
                                              group,
                                              joinRequestMessages[index],
                                            ),
                                    child: const Text('Reject'),
                                  ),
                                  FilledButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _approveJoinRequest(
                                              context,
                                              group,
                                              joinRequestMessages[index],
                                            ),
                                    child: const Text('Approve'),
                                  ),
                                ],
                              ),
                              if (index != joinRequestMessages.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _ActionCard(
                      icon: Icons.swap_horiz_rounded,
                      title: 'Switch space',
                      description:
                          'Tap here to switch groups, join another one with an invite code, or create a new group.',
                      onTap: _isSubmitting
                          ? null
                          : () => _openSwitchSpaceDialog(
                                context,
                                currentGroupId: group.id,
                                joinedGroups: joinedGroups,
                              ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7F0),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                hasOtherGroups
                                    ? 'You have ${joinedGroups.length} joined groups. Tap to open the switcher.'
                                    : 'This is your only joined group right now. Tap to join or create another one.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF7D6B5D),
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFFB56C37),
                            ),
                          ],
                        ),
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
                                _memberSubtitle(
                                  group: group,
                                  member: member,
                                  currentUserId: currentUserId,
                                ),
                              ),
                              trailing: _buildMemberAction(
                                context,
                                group: group,
                                member: member,
                                currentUserId: currentUserId,
                                canKickMembers: canKickMembers,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ActionCard(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Current space actions',
                      description:
                          'Leave this space, or if you are the owner, transfer management and dissolve it.',
                      child: Column(
                        children: [
                          _DangerActionTile(
                            icon: Icons.logout_rounded,
                            title: 'Leave current space',
                            description: shouldSelectSuccessorBeforeLeaving
                                ? 'Choose the next owner first. After confirmation, ownership will transfer and you will leave this space.'
                                : hasOtherGroups
                                    ? 'After leaving, the first remaining space will become current automatically.'
                                    : 'If this is your only space, you will return to the empty-space state after leaving.',
                            buttonLabel: 'Leave',
                            onPressed: _isSubmitting
                                ? null
                                : () =>
                                    _handleLeaveCurrentGroup(context, group),
                          ),
                          if (canManageOwnership) ...[
                            const SizedBox(height: 12),
                            _DangerActionTile(
                              icon: Icons.workspace_premium_rounded,
                              title: 'Transfer ownership',
                              description: group.isOwnershipTransferPending
                                  ? 'A transfer request is in progress. The target member needs to approve it before roles change.'
                                  : group.members.length > 1
                                      ? 'Hand this space over to another member before you step back.'
                                      : 'You need at least one other member in the space before transferring ownership.',
                              buttonLabel: group.isOwnershipTransferPending
                                  ? 'Transferring'
                                  : 'Transfer',
                              isDestructive: false,
                              onPressed: _isSubmitting ||
                                      group.isOwnershipTransferPending ||
                                      group.members.length <= 1
                                  ? null
                                  : () =>
                                      _pickAndTransferOwnership(context, group),
                            ),
                            const SizedBox(height: 12),
                            _DangerActionTile(
                              icon: Icons.delete_forever_rounded,
                              title: 'Dissolve this space',
                              description:
                                  'This removes the space for every member. They will no longer be able to enter it.',
                              buttonLabel: 'Dissolve',
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _dissolveCurrentGroup(context, group),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _createSpace(BuildContext context) async {
    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);
    final beforeGroupId = dataService.currentGroup?.id;

    if (_createController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a space name.')),
      );
      return false;
    }

    setState(() {
      _isSubmitting = true;
    });

    await dataService.createGroup(_createController.text);

    if (!mounted) {
      return false;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (dataService.currentGroup != null &&
        dataService.currentGroup!.id != beforeGroupId) {
      _createController.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Space created successfully.')),
      );
      return true;
    }

    return false;
  }

  Future<bool> _joinSpace(BuildContext context) async {
    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);
    final beforeGroupId = dataService.currentGroup?.id;

    if (_inviteCodeController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter an invite code.')),
      );
      return false;
    }

    setState(() {
      _isSubmitting = true;
    });

    final result = await dataService
        .joinGroup(_inviteCodeController.text.trim().toUpperCase());

    if (!mounted) {
      return false;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (dataService.errorMessage == null && result.isPendingApproval) {
      _inviteCodeController.clear();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.message ??
                'Join request sent. Stay in your current space until it is approved.',
          ),
        ),
      );
      return true;
    }

    if (dataService.currentGroup != null &&
        dataService.currentGroup!.id != beforeGroupId) {
      _inviteCodeController.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Joined space successfully.')),
      );
      return true;
    }

    return false;
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
    final messenger = ScaffoldMessenger.of(context);

    await Clipboard.setData(ClipboardData(text: group.inviteCode));

    if (!context.mounted) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text('Invite code copied: ${group.inviteCode}')),
    );
  }

  Future<bool> _switchGroup(BuildContext context, GroupListItem item) async {
    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);

    if (item.isPendingApproval) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${item.name} is still waiting for approval. You cannot switch to it yet.',
          ),
        ),
      );
      return false;
    }

    setState(() {
      _isSubmitting = true;
    });

    await dataService.switchCurrentGroup(item.id);

    if (!context.mounted) {
      return false;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (dataService.errorMessage == null &&
        dataService.currentGroup?.id == item.id) {
      messenger.showSnackBar(
        SnackBar(content: Text('Switched to ${item.name}.')),
      );
      return true;
    }

    return false;
  }

  Future<void> _openSwitchSpaceDialog(
    BuildContext context, {
    required int currentGroupId,
    required List<GroupListItem> joinedGroups,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SpaceSwitcherSheet(
        currentGroupId: currentGroupId,
        joinedGroups: joinedGroups,
        onSwitch: (item) => _switchGroup(context, item),
        onJoin: (inviteCode) async {
          _inviteCodeController.text = inviteCode;
          return _joinSpace(context);
        },
        onCreate: (spaceName) async {
          _createController.text = spaceName;
          return _createSpace(context);
        },
      ),
    );
  }

  Future<void> _leaveCurrentGroup(BuildContext context, Group group) async {
    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _showConfirmationDialog(
      context,
      title: 'Leave current space?',
      content:
          'You will leave ${group.name}. If you have other spaces, the first remaining one becomes current automatically.',
      confirmLabel: 'Leave space',
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    await dataService.leaveGroup(group.id);

    if (!context.mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (dataService.errorMessage == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('You left ${group.name}.')),
      );
    }
  }

  Future<void> _handleLeaveCurrentGroup(
    BuildContext context,
    Group group,
  ) async {
    final dataService = context.read<DataService>();
    final currentUserId = dataService.currentUser?.id;

    if (currentUserId == null || !group.isOwnedBy(currentUserId)) {
      await _leaveCurrentGroup(context, group);
      return;
    }

    final candidates =
        group.members.where((member) => member.id != currentUserId).toList();

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invite another member or dissolve this space before leaving.',
          ),
        ),
      );
      return;
    }

    final target = await _showOwnershipPicker(context, candidates);
    if (target == null || !context.mounted) {
      return;
    }

    final confirmed = await _showConfirmationDialog(
      context,
      title: 'Transfer ownership and leave?',
      content:
          '${target.name} will become the new owner of ${group.name}. After that, you will leave this space.',
      confirmLabel: 'Confirm and leave',
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSubmitting = true;
    });

    final result = await dataService.transferGroupOwnership(
      groupId: group.id,
      targetUserId: target.id,
    );

    if (!context.mounted) {
      return;
    }

    if (dataService.errorMessage == null && !result.isPendingApproval) {
      await dataService.leaveGroup(group.id);
    }

    if (!context.mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (dataService.errorMessage == null && result.isPendingApproval) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.message ??
                'Transfer request sent to ${target.name}. You can leave after approval.',
          ),
        ),
      );
    } else if (dataService.errorMessage == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${target.name} is now the owner. You left ${group.name}.',
          ),
        ),
      );
    }
  }

  Future<void> _pickAndTransferOwnership(
    BuildContext context,
    Group group,
  ) async {
    final dataService = context.read<DataService>();
    final currentUserId = dataService.currentUser?.id;
    final candidates =
        group.members.where((member) => member.id != currentUserId).toList();
    final messenger = ScaffoldMessenger.of(context);

    final target = await _showOwnershipPicker(context, candidates);
    if (target == null || !context.mounted) {
      return;
    }

    final confirmed = await _showConfirmationDialog(
      context,
      title: 'Transfer ownership?',
      content:
          'After transferring ${group.name} to ${target.name}, you will no longer be able to dissolve it unless ownership comes back to you.',
      confirmLabel: 'Transfer ownership',
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final result = await dataService.transferGroupOwnership(
      groupId: group.id,
      targetUserId: target.id,
    );

    if (!context.mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (dataService.errorMessage == null && result.isPendingApproval) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.message ??
                'Transfer request sent to ${target.name}. Waiting for approval.',
          ),
        ),
      );
    } else if (dataService.errorMessage == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Ownership transferred to ${target.name}.')),
      );
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    Group group,
    User member,
  ) async {
    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _showConfirmationDialog(
      context,
      title: 'Kick member from space?',
      content:
          '${member.name} will be removed from ${group.name} and need a new invite to join again.',
      confirmLabel: 'Kick member',
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    await dataService.removeGroupMember(
      groupId: group.id,
      targetUserId: member.id,
    );

    if (!context.mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (dataService.errorMessage == null) {
      messenger.showSnackBar(
        SnackBar(
            content: Text('${member.name} was removed from ${group.name}.')),
      );
    }
  }

  Future<void> _dissolveCurrentGroup(BuildContext context, Group group) async {
    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _showConfirmationDialog(
      context,
      title: 'Dissolve this space?',
      content:
          'This permanently removes ${group.name} for every member. Anyone who joined it will lose access immediately.',
      confirmLabel: 'Dissolve space',
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    await dataService.dissolveGroup(group.id);

    if (!context.mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (dataService.errorMessage == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('${group.name} has been dissolved.')),
      );
    }
  }

  Future<bool> _showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmLabel,
    bool isDestructive = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD85A3D),
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<User?> _showOwnershipPicker(
    BuildContext context,
    List<User> candidates,
  ) {
    return showDialog<User>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Choose the next owner',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Only another member in the same space can take ownership.',
                  style: TextStyle(color: Color(0xFF7D6B5D), height: 1.4),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: candidates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final member = candidates[index];

                      return Material(
                        color: const Color(0xFFFFF7F0),
                        borderRadius: BorderRadius.circular(18),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFFE3C8),
                            child: Text(
                                member.name.characters.first.toUpperCase()),
                          ),
                          title: Text(member.name),
                          subtitle: Text(
                            member.currentStatus?.isNotEmpty == true
                                ? member.currentStatus!
                                : 'No status yet',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).pop(member),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatRoleLabel(String? role) {
    if (role == null || role.isEmpty) {
      return 'Member';
    }

    return switch (role) {
      'owner' => 'Owner',
      'admin' => 'Admin',
      _ => role[0].toUpperCase() + role.substring(1),
    };
  }

  String _memberSubtitle({
    required Group group,
    required User member,
    required int? currentUserId,
  }) {
    if (group.isOwnershipTransferPending && group.pendingOwnerId == member.id) {
      return member.id == currentUserId
          ? 'Ownership transfer pending your approval'
          : 'Ownership transfer pending acceptance';
    }

    return member.currentStatus?.isNotEmpty == true
        ? member.currentStatus!
        : 'No status yet';
  }

  Widget? _buildMemberAction(
    BuildContext context, {
    required Group group,
    required User member,
    required int? currentUserId,
    required bool canKickMembers,
  }) {
    if (canKickMembers &&
        currentUserId != null &&
        member.role == 'member' &&
        member.id != currentUserId) {
      return TextButton.icon(
        onPressed: _isSubmitting
            ? null
            : () => _removeMember(
                  context,
                  group,
                  member,
                ),
        icon: const Icon(Icons.person_remove),
        label: const Text('Kick'),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFD85A3D),
        ),
      );
    }

    return null;
  }

  Future<void> _approveJoinRequest(
    BuildContext context,
    Group group,
    SpaceInboxItem message,
  ) async {
    final confirmed = await _showConfirmationDialog(
      context,
      title: 'Approve join request?',
      content:
          '${message.requesterNickname ?? 'This member'} will join ${group.name} after approval.',
      confirmLabel: 'Approve',
      isDestructive: false,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSubmitting = true;
    });

    await dataService.approveJoinRequest(
      groupId: group.id,
      requestId: message.id,
    );

    if (!context.mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (dataService.errorMessage == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${message.requesterNickname ?? 'The request'} has been approved.',
          ),
        ),
      );
    }
  }

  Future<void> _rejectJoinRequest(
    BuildContext context,
    Group group,
    SpaceInboxItem message,
  ) async {
    final confirmed = await _showConfirmationDialog(
      context,
      title: 'Reject join request?',
      content:
          '${message.requesterNickname ?? 'This member'} will stay outside ${group.name}.',
      confirmLabel: 'Reject',
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSubmitting = true;
    });

    await dataService.rejectJoinRequest(
      groupId: group.id,
      requestId: message.id,
    );

    if (!context.mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (dataService.errorMessage == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${message.requesterNickname ?? 'The request'} has been rejected.',
          ),
        ),
      );
    }
  }

  Future<void> _acceptOwnershipTransfer(
    BuildContext context,
    Group group,
  ) async {
    final confirmed = await _showConfirmationDialog(
      context,
      title: 'Accept ownership transfer?',
      content: 'After approval, you will become the owner of ${group.name}.',
      confirmLabel: 'Approve',
      isDestructive: false,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSubmitting = true;
    });

    await dataService.approveOwnershipTransfer(groupId: group.id);

    if (!context.mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (dataService.errorMessage == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('You are now the owner of ${group.name}.')),
      );
    }
  }

  Future<void> _rejectOwnershipTransfer(
    BuildContext context,
    Group group,
    SpaceInboxItem message,
  ) async {
    final confirmed = await _showConfirmationDialog(
      context,
      title: 'Reject ownership transfer?',
      content:
          'Rejecting this request keeps ${message.requesterNickname ?? 'the current owner'} as the owner of ${group.name}.',
      confirmLabel: 'Reject',
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSubmitting = true;
    });

    await dataService.rejectOwnershipTransfer(groupId: group.id);

    if (!context.mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (dataService.errorMessage == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Ownership transfer for ${group.name} has been rejected.',
          ),
        ),
      );
    }
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
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
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
        ),
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

class _PendingApprovalTile extends StatelessWidget {
  const _PendingApprovalTile({
    required this.title,
    required this.description,
    required this.actions,
  });

  final String title;
  final String description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1D8C2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF7D6B5D),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: actions,
          ),
        ],
      ),
    );
  }
}

class _GroupListTile extends StatelessWidget {
  const _GroupListTile({
    required this.item,
    required this.actionLabel,
    this.onPressed,
  });

  final GroupListItem item;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE3C8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.holiday_village_rounded,
                color: Color(0xFFB56C37)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.isPendingApproval
                      ? 'Approval required before you can switch to this group.'
                      : '${item.memberCount} members · Invite ${item.inviteCode}',
                  style: const TextStyle(
                    color: Color(0xFF7D6B5D),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onPressed,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _DangerActionTile extends StatelessWidget {
  const _DangerActionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    this.onPressed,
    this.isDestructive = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final Color accentColor =
        isDestructive ? const Color(0xFFD85A3D) : const Color(0xFFB56C37);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7F0),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDestructive
                  ? const Color(0xFFF4C6BA)
                  : const Color(0xFFF1D8C2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF7D6B5D),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: isDestructive ? accentColor : null,
                ),
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpaceSwitcherSheet extends StatefulWidget {
  const _SpaceSwitcherSheet({
    required this.currentGroupId,
    required this.joinedGroups,
    required this.onSwitch,
    required this.onJoin,
    required this.onCreate,
  });

  final int currentGroupId;
  final List<GroupListItem> joinedGroups;
  final Future<bool> Function(GroupListItem item) onSwitch;
  final Future<bool> Function(String inviteCode) onJoin;
  final Future<bool> Function(String groupName) onCreate;

  @override
  State<_SpaceSwitcherSheet> createState() => _SpaceSwitcherSheetState();
}

class _SpaceSwitcherSheetState extends State<_SpaceSwitcherSheet> {
  final _inviteCodeController = TextEditingController();
  final _createController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _createController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 640),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBF7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8D6C8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Switch space',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Switch to a joined group, join another with an invite code, or create a new group.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF7D6B5D),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1E6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: const Color(0xFF7F471D),
                      unselectedLabelColor: const Color(0xFF9A7B63),
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      tabs: const [
                        Tab(text: 'Joined groups'),
                        Tab(text: 'Create group'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildJoinedGroupsTab(context),
                      _buildCreateGroupTab(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinedGroupsTab(BuildContext context) {
    final switchableGroups = widget.joinedGroups
        .where((item) => item.id != widget.currentGroupId)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        if (switchableGroups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7F0),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'You are currently only in this one group. Join or create another one below, then you can switch here.',
              style: TextStyle(
                color: Color(0xFF7D6B5D),
                height: 1.4,
              ),
            ),
          ),
        for (final item in switchableGroups) ...[
          _GroupListTile(
            item: item,
            actionLabel: item.isPendingApproval ? 'Pending' : 'Switch',
            onPressed: _isSubmitting || item.isPendingApproval
                ? null
                : () => _handleSwitch(item),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1D8C2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Join another group',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter an invite code. Join requests stay pending until an owner or admin approves them.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF7D6B5D),
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inviteCodeController,
                      enabled: !_isSubmitting,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Invite code',
                        hintText: 'Enter code',
                      ),
                      onSubmitted: (_) => _handleJoin(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _handleJoin,
                    child: Text(_isSubmitting ? 'Joining...' : 'Join'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreateGroupTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1D8C2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a new group',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create it here and you will enter the new group immediately after success.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF7D6B5D),
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _createController,
                enabled: !_isSubmitting,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  hintText: 'For example: Warm Home',
                ),
                onSubmitted: (_) => _handleCreate(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _handleCreate,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    _isSubmitting ? 'Creating...' : 'Create and Enter',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleSwitch(GroupListItem item) async {
    final success = await _runAction(() => widget.onSwitch(item));
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleJoin() async {
    final success = await _runAction(
      () => widget.onJoin(_inviteCodeController.text.trim().toUpperCase()),
    );
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleCreate() async {
    final success = await _runAction(
      () => widget.onCreate(_createController.text.trim()),
    );
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _runAction(Future<bool> Function() action) async {
    setState(() {
      _isSubmitting = true;
    });

    final success = await action();

    if (!mounted) {
      return false;
    }

    setState(() {
      _isSubmitting = false;
    });

    return success;
  }
}
