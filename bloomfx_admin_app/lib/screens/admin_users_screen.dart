import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_user_provider.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminUserProvider>(context, listen: false).loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminUserProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF1A1F2E),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search users...', hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true, fillColor: const Color(0xFF0D1117),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _FilterChip(label: 'All', selected: provider.filter == 'all', onTap: () => provider.setFilter('all')),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Flagged', selected: provider.filter == 'flagged', onTap: () => provider.setFilter('flagged')),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Banned', selected: provider.filter == 'banned', onTap: () => provider.setFilter('banned')),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : () {
                      final filtered = provider.users.where((u) {
                        if (_searchQuery.isEmpty) return true;
                        final name = '${_userDisplayName(u)}'.toLowerCase();
                        final email = u.email.toLowerCase();
                        return name.contains(_searchQuery) || email.contains(_searchQuery);
                      }).toList();
                      if (filtered.isEmpty) {
                        return const Center(child: Text('No users found', style: TextStyle(color: Colors.white54)));
                      }
                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _UserCard(user: filtered[i], provider: provider),
                      );
                    }(),
            ),
          ],
        );
      },
    );
  }
}

String _userInitial(User u) {
  final name = (u.firstName.isNotEmpty)
      ? u.firstName
      : (u.lastName.isNotEmpty)
          ? u.lastName
          : u.username;
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

String _userDisplayName(User u) {
  final full = '${u.firstName} ${u.lastName}'.trim();
  return full.isNotEmpty ? full : u.username;
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'just now';
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E3A8A) : const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF1E3A8A) : Colors.white24),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;
  final AdminUserProvider provider;

  const _UserCard({required this.user, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1F2E),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF1E3A8A),
                  child: Text(_userInitial(user), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userDisplayName(user), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(user.email ?? '', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                    ],
                  ),
                ),
                if (user.isFlagged) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange)),
                  child: const Text('FLAGGED', style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
                if (user.isBanned) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red)),
                    child: const Text('BANNED', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!user.isFlagged)
                  TextButton.icon(onPressed: () => _confirmAction(context, 'Flag ${_userDisplayName(user)}?', () => provider.flagUser(user.id)), icon: const Icon(Icons.flag, color: Colors.orange, size: 18), label: const Text('Flag', style: TextStyle(color: Colors.orange, fontSize: 12)))
                else
                  TextButton.icon(onPressed: () => provider.unflagUser(user.id), icon: const Icon(Icons.flag, color: Colors.green, size: 18), label: const Text('Unflag', style: TextStyle(color: Colors.green, fontSize: 12))),
                if (!user.isBanned)
                  TextButton.icon(onPressed: () => _confirmAction(context, 'Ban ${_userDisplayName(user)}?', () => provider.banUser(user.id)), icon: const Icon(Icons.block, color: Colors.red, size: 18), label: const Text('Ban', style: TextStyle(color: Colors.red, fontSize: 12)))
                else
                  TextButton.icon(onPressed: () => _confirmAction(context, 'Unban ${_userDisplayName(user)}?', () => provider.unbanUser(user.id)), icon: const Icon(Icons.check_circle, color: Colors.green, size: 18), label: const Text('Unban', style: TextStyle(color: Colors.green, fontSize: 12))),
                TextButton.icon(
                  onPressed: () => _showResetPasswordDialog(context),
                  icon: const Icon(Icons.lock_reset, color: Colors.blue, size: 18),
                  label: const Text('Reset PW', style: TextStyle(color: Colors.blue, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAction(BuildContext context, String title, VoidCallback onConfirm) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1F2E),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); onConfirm(); }, child: const Text('Confirm')),
      ],
    ));
  }

  void _showResetPasswordDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1F2E),
      title: const Text('Reset Password', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter a new password for this user. They will be logged out and must log in with the new password.', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'New password', hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: const Color(0xFF0D1117),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              provider.resetPassword(user.id, controller.text.trim());
              Navigator.pop(ctx);
            }
          },
          child: const Text('Reset Password'),
        ),
      ],
    ));
  }

}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.white54),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]),
    );
  }
}
