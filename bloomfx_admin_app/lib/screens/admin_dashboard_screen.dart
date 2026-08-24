import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/admin_auth_provider.dart';
import '../providers/admin_dashboard_provider.dart';
import '../providers/admin_support_provider.dart';
import '../models/admin_models.dart';
import 'admin_users_screen.dart';
import 'admin_deposits_screen.dart';
import 'admin_withdrawals_screen.dart';
import 'admin_promos_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_support_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => AdminDashboardScreenState();
}

class AdminDashboardScreenState extends State<AdminDashboardScreen>
    with WidgetsBindingObserver {
  int currentIndex = 0;
  Timer? _pollTimer;

  void navigateTo(int index) {
    setState(() => currentIndex = index);
  }

  final _pages = <Widget>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminDashboardProvider>(context, listen: false).loadStats();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      Provider.of<AdminDashboardProvider>(context, listen: false).loadStats();
    });
    _pages.addAll([
      _DashboardHome(onNavigate: navigateTo),
      const AdminUsersScreen(),
      const AdminDepositsScreen(),
      const AdminWithdrawalsScreen(),
      const AdminPromosScreen(),
      const AdminNotificationsScreen(),
      const AdminSupportScreen(),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pollTimer?.cancel();
      _pollTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      if (_pollTimer == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Provider.of<AdminDashboardProvider>(
            context,
            listen: false,
          ).loadStats();
        });
        _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          Provider.of<AdminDashboardProvider>(
            context,
            listen: false,
          ).loadStats();
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CPBloomFX Admin'),
        backgroundColor: const Color(0xFF0A0D13),
        foregroundColor: Color(0xFFE8CE8C),
        elevation: 0,
        actions: [
          Consumer<AdminAuthProvider>(
            builder: (ctx, auth, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (auth.isOffline) ...[
                  const Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  const Text(
                    'Offline',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                ],
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await auth.logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: _pages[currentIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        backgroundColor: const Color(0xFF1A1F2E),
        indicatorColor: const Color(0xFFD4AF37),
        onDestinationSelected: (i) => setState(() => currentIndex = i),
        destinations: <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
          const NavigationDestination(
            icon: Icon(Icons.account_balance),
            label: 'Deposits',
          ),
          const NavigationDestination(icon: Icon(Icons.logout), label: 'Withdrawals'),
          const NavigationDestination(icon: Icon(Icons.discount), label: 'Promos'),
          const NavigationDestination(
            icon: Icon(Icons.notifications_active),
            label: 'Notify',
          ),
          NavigationDestination(
            icon: Consumer<AdminSupportProvider>(
              builder: (ctx, support, _) {
                final unread = support.totalUnreadCount;
                return Badge(
                  isLabelVisible: unread > 0,
                  label: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.support_agent),
                );
              },
            ),
            label: 'Support',
          ),
        ],
      ),
    );
  }
}

class _DashboardHome extends StatelessWidget {
  final void Function(int index) onNavigate;

  const _DashboardHome({required this.onNavigate});

  String _formatAmount(double amt) {
    if (amt >= 1000) return '\$${(amt / 1000).toStringAsFixed(1)}k';
    return '\$${amt.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminDashboardProvider>(
      builder: (context, provider, _) {
        final s = provider.stats;
        final errMsg = provider.errorMessage;
        return RefreshIndicator(
          onRefresh: () => provider.loadStats(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errMsg != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            errMsg,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  'Welcome, Admin',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Users',
                        value: '${s.totalUsers}',
                        icon: Icons.people,
                        color: Colors.blue,
                        onTap: () => onNavigate(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Cumulative Deposits',
                        value: _formatAmount(s.totalDepositAmount),
                        icon: Icons.account_balance,
                        color: Colors.green,
                        onTap: () => onNavigate(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Cumulative Withdrawals',
                        value: _formatAmount(s.totalWithdrawalAmount),
                        icon: Icons.logout,
                        color: Colors.orange,
                        onTap: () => onNavigate(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Pending',
                        value: '${s.pendingDeposits + s.pendingWithdrawals}',
                        icon: Icons.hourglass_empty,
                        color: Colors.purple,
                        onTap: () => onNavigate(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'Flagged',
                        value: '${s.flaggedUsers}',
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: 'Banned',
                        value: '${s.bannedUsers}',
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: 'Pending Dep.',
                        value: '${s.pendingDeposits}',
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: 'Pending With.',
                        value: '${s.pendingWithdrawals}',
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                _QuickActionButton(
                  icon: Icons.person_search,
                  label: 'Manage Users',
                  color: Colors.blue,
                  onTap: () => onNavigate(1),
                ),
                _QuickActionButton(
                  icon: Icons.check_circle,
                  label: 'Pending Deposits',
                  color: Colors.green,
                  onTap: () => onNavigate(2),
                ),
                _QuickActionButton(
                  icon: Icons.pending_actions,
                  label: 'Pending Withdrawals',
                  color: Colors.orange,
                  onTap: () => onNavigate(3),
                ),
                _QuickActionButton(
                  icon: Icons.add_circle,
                  label: 'Create Promo Code',
                  color: Colors.purple,
                  onTap: () => onNavigate(4),
                ),
                _QuickActionButton(
                  icon: Icons.notifications_active,
                  label: 'Send Notification',
                  color: Colors.teal,
                  onTap: () => onNavigate(5),
                ),
                _QuickActionButton(
                  icon: Icons.support_agent,
                  label: 'Support Inbox',
                  color: Colors.indigo,
                  onTap: () => onNavigate(6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[400])),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1F2E),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1F2E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
        onTap: onTap,
      ),
    );
  }
}
