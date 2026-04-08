import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firestore/firestore_service.dart';
import '../../core/ui/subpage_app_bar.dart';
import '../../models/team_member.dart';
import '../../models/user_profile.dart';
import '../auth/effective_user_provider.dart';
import 'provider_account_controller.dart';

/// Team Members page: add, edit, delete team members for the provider's business.
class TeamMembersPage extends ConsumerWidget {
  const TeamMembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildSubpageAppBar(
        context,
        title: 'Team Members',
        fallbackRoute: '/profile/business',
      ),
      body: effectiveUser.when(
        data: (appUser) {
          if (appUser == null || appUser.isDemo) {
            return const Center(child: Text('Sign in to manage team members.'));
          }
          if (fs == null) {
            return const Center(child: Text('Firebase not configured.'));
          }
          return StreamBuilder<UserProfile>(
            stream: fs.streamUserProfile(appUser.uid),
            builder: (context, userSnap) {
              final userProfile = userSnap.data;
              final activeId = userProfile?.activeProviderProfileId;
              if (activeId == null || activeId.isEmpty) {
                return const Center(child: Text('Set up your business first.'));
              }
              return StreamBuilder<List<TeamMember>>(
                stream: fs.streamTeamMembers(activeId),
                builder: (context, listSnap) {
                  final list = listSnap.data ?? [];
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...list.map((m) => _TeamMemberCard(
                            member: m,
                            providerProfileId: activeId,
                            onEdit: () => _showEditTeamMemberDialog(context, ref, activeId, m, fs),
                            onDelete: () => _deleteTeamMember(context, ref, activeId, m, fs),
                          )),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _showAddTeamMemberDialog(context, ref, activeId, fs),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Team Member'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({
    required this.member,
    required this.providerProfileId,
    required this.onEdit,
    required this.onDelete,
  });

  final TeamMember member;
  final String providerProfileId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(member.displayName),
        subtitle: Text([if (member.email != null) member.email, if (member.role != null) member.role!].join(' · ')),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: ListTile(title: Text('Edit'), leading: Icon(Icons.edit))),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

void _showAddTeamMemberDialog(BuildContext context, WidgetRef ref, String providerProfileId, FirestoreService fs) {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final roleCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add Team Member'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email (optional)', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: 'Role (optional)', border: OutlineInputBorder())),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            try {
              await fs.addTeamMember(
                providerProfileId: providerProfileId,
                displayName: name,
                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                role: roleCtrl.text.trim().isEmpty ? null : roleCtrl.text.trim(),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team member successfully added')));
              }
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
            }
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
}

void _showEditTeamMemberDialog(BuildContext context, WidgetRef ref, String providerProfileId, TeamMember m, FirestoreService fs) {
  final nameCtrl = TextEditingController(text: m.displayName);
  final emailCtrl = TextEditingController(text: m.email ?? '');
  final roleCtrl = TextEditingController(text: m.role ?? '');
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Edit Team Member'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email (optional)', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: 'Role (optional)', border: OutlineInputBorder())),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            try {
              await fs.updateTeamMember(
                providerProfileId: providerProfileId,
                teamMemberId: m.teamMemberId,
                displayName: name,
                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                role: roleCtrl.text.trim().isEmpty ? null : roleCtrl.text.trim(),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team member successfully updated')));
              }
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<void> _deleteTeamMember(BuildContext context, WidgetRef ref, String providerProfileId, TeamMember m, FirestoreService fs) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete team member?'),
      content: Text('Remove "${m.displayName}" from your team?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirm != true) return;
  try {
    await fs.deleteTeamMember(providerProfileId: providerProfileId, teamMemberId: m.teamMemberId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team member successfully deleted')));
    }
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
  }
}
