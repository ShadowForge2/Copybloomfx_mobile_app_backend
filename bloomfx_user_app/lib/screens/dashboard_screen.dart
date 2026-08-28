import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/notification_provider.dart';
import '../models/notification_model.dart';
import '../services/investment_logic.dart';
import '../providers/theme_provider.dart';
import '../widgets/copy_trading/copy_trades_hub.dart';
import '../widgets/notification_ui.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.activeIndex});

  /// Current active tab index. When it becomes 0 (dashboard selected),
  /// the rank ladder auto-scrolls to the user's current rank.
  final ValueListenable<int>? activeIndex;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _rankScrollController = ScrollController();
  bool _claimedRewardLocally = false;

  @override
  void initState() {
    super.initState();
    widget.activeIndex?.addListener(_onActiveIndexChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<DashboardProvider>().fetchDashboardData(userId: auth.user?.id);
      context.read<NotificationProvider>().startPolling();
    });
  }

  @override
  void dispose() {
    widget.activeIndex?.removeListener(_onActiveIndexChanged);
    _rankScrollController.dispose();
    super.dispose();
  }

  void _onActiveIndexChanged() {
    if (widget.activeIndex?.value == 0 && mounted) {
      _scrollToCurrentRank();
    }
  }

  void _scrollToCurrentRank() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final data = context.read<DashboardProvider>().data;
      final ranks = data?.ranks ?? [];
      final idx = ranks.indexWhere((r) => r.isCurrent);
      if (idx < 0 || !_rankScrollController.hasClients) return;
      double offset = 0;
      for (var i = 0; i < idx; i++) {
        offset += _rankCardWidth(ranks[i]) + 8;
      }
      _rankScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  double _rankCardWidth(Rank rank) {
    const baseWidth = 120.0;
    return baseWidth + rank.name.length * 7.0;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthProvider, DashboardProvider, ThemeProvider>(
      builder: (context, authProvider, dashboardProvider, themeProvider, child) {
        if (authProvider.user == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final user = authProvider.user!;
        final dashboardData = dashboardProvider.data;
        final c = themeProvider.colors;

        if (dashboardData != null && !dashboardProvider.isLoading) {
          _scrollToCurrentRank();
        }

        return SafeArea(
          child: Column(
            children: [
              _buildHeader(context, user, c),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => dashboardProvider.fetchDashboardData(
                        userId: authProvider.user?.id,
                      ),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_activePendingBanners(dashboardData).isNotEmpty)
                          ..._activePendingBanners(dashboardData).map(
                            (deposit) => _buildPendingDepositBanner(deposit, c),
                          ),

                        if (_activePendingBanners(dashboardData).isNotEmpty)
                          const SizedBox(height: 16),

                        const SizedBox(height: 24),

                        _buildBalancesSection(dashboardData, c),
                        const SizedBox(height: 24),

                        _buildDailyRewardSection(dashboardData, c),
                        const SizedBox(height: 24),

                        _buildRankLadderSection(dashboardData, c),
                        const SizedBox(height: 24),

                        Consumer<DashboardProvider>(
                          builder: (context, dashboardProvider, child) {
                            return CopyTradesHub(
                              dashboardData: dashboardData,
                              isSimulating: dashboardProvider.isSimulating,
                              onPlaceTrade: _simulateCopyTrade,
                              colors: c,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, User user, AppColors c) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: c.cardBg,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
            children: [
              Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: c.iconColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Search',
                        style: TextStyle(color: c.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: c.surfaceBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: c.iconColor,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'E8 Account',
                      style: TextStyle(color: c.textPrimary, fontSize: 11),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: c.iconColor,
                      size: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Consumer<NotificationProvider>(
                builder: (context, notifProvider, child) {
                  final unread = notifProvider.unreadCount;
                  return GestureDetector(
                    onTap: () => _showNotifications(context, c),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.surfaceBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.border),
                      ),
                      child: Stack(
                        children: [
                          Icon(
                            Icons.notifications,
                            color: c.iconColor,
                            size: 18,
                          ),
                          if (unread > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  NotificationBell.badgeLabel(unread),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  context.read<DashboardProvider>().fetchDashboardData(
                    userId: context.read<AuthProvider>().user?.id,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.surfaceBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(Icons.refresh, color: c.iconColor, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: c.surfaceBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      color: c.iconColor,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.username,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          user.email ?? 'No email',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: c.iconColor,
                        size: 16,
                      ),
                      color: c.surfaceBg,
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'logout') {
                          context.read<AuthProvider>().logout();
                          context.go('/login');
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'logout',
                          child: Text(
                            'Logout',
                            style: TextStyle(color: c.textPrimary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }

  void _showNotifications(BuildContext context, AppColors c) {
    final notifProvider = context.read<NotificationProvider>();
    notifProvider.fetchNotifications();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Consumer<NotificationProvider>(
          builder: (context, notifProvider, _) {
            final notifications = notifProvider.notifications;
            final unread = notifProvider.unreadCount;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: c.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications,
                          color: c.textPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Notifications',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              NotificationBell.badgeLabel(unread),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (unread > 0)
                          GestureDetector(
                            onTap: () => notifProvider.markAllAsRead(),
                            child: Text(
                              'Mark all read',
                              style: TextStyle(
                                color: c.accentBlue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (notifications.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No notifications',
                        style: TextStyle(color: c.textSecondary, fontSize: 14),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: notifications.length,
                        separatorBuilder: (_, _) => Divider(
                          color: c.border,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final n = notifications[index];
                          return _buildNotificationItem(
                            n,
                            c: c,
                            onTap: () {
                              if (!n.isRead) {
                                notifProvider.markOneAsRead(n.id);
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationItem(AppNotification n, {required AppColors c, VoidCallback? onTap}) {
    final color = _notificationColor(n.type);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: n.isRead ? Colors.transparent : const Color(0x0DFFFFFF),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _notificationIcon(n.type),
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 13,
                            fontWeight:
                                n.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.accentBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.message,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.timeAgo,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _notificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.info:
        return Icons.info_outline;
      case NotificationType.warning:
        return Icons.warning_amber;
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.urgent:
        return Icons.error_outline;
      case NotificationType.maintenance:
        return Icons.construction;
    }
  }

  Color _notificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.info:
        return const Color(0xFFD4AF37);
      case NotificationType.warning:
        return const Color(0xFFFFA726);
      case NotificationType.success:
        return const Color(0xFF4CAF50);
      case NotificationType.urgent:
        return const Color(0xFFEF5350);
      case NotificationType.maintenance:
        return const Color(0xFFAB47BC);
    }
  }

  /// Only show the payment banner while the generated wallet address is still
  /// valid (within the wallet window). Once the address expires, hide the banner
  /// so it isn't shown forever, but the pending deposit itself stays on the
  /// backend for admin review and approval.
  List<PendingDeposit> _activePendingBanners(DashboardData? data) {
    final deposits = data?.pendingDeposits ?? const <PendingDeposit>[];
    final now = DateTime.now();
    return deposits.where((d) {
      final expires = d.walletExpiresAt ?? d.expiresAt;
      if (expires == null) return true;
      return expires.isAfter(now);
    }).toList();
  }

  String _walletTimeRemaining(PendingDeposit d) {
    final expires = d.walletExpiresAt ?? d.expiresAt;
    if (expires == null) return 'Awaiting admin approval';
    final now = DateTime.now();
    if (expires.isBefore(now)) return 'Address expired';
    final remaining = expires.difference(now);
    final minutes = remaining.inMinutes;
    final secs = remaining.inSeconds % 60;
    return '${minutes}m ${secs}s left';
  }

  Widget _buildPendingDepositBanner(PendingDeposit deposit, AppColors c) {
    final timeRemaining = _walletTimeRemaining(deposit);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Color(0xFFFF6F00), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Pending Deposit',
                  style: TextStyle(
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  'ID: ${deposit.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '\$${deposit.amount.toStringAsFixed(2)} (${deposit.network}) — $timeRemaining',
            style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
          ),
          if (deposit.walletAddress != null && deposit.walletAddress!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    deposit.walletAddress!,
                    style: const TextStyle(color: Color(0xFF1565C0), fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final addr = deposit.walletAddress!.trim();
                    await Clipboard.setData(ClipboardData(text: addr));
                    if (mounted) {
                      Fluttertoast.showToast(
                        msg: 'Address copied',
                        backgroundColor: Colors.green,
                        textColor: Colors.white,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, color: Color(0xFF1565C0), size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(color: Color(0xFF1565C0), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalancesSection(DashboardData? dashboardData, AppColors c) {
    final profile = dashboardData?.profile;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balances',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildBalanceCard(
                  'Tradable',
                  '\$${profile?.lockedBalance.toStringAsFixed(2) ?? '0.00'}',
                  Colors.orange,
                  c,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBalanceCard(
                  'Withdrawable',
                  '\$${profile?.withdrawableBalance.toStringAsFixed(2) ?? '0.00'}',
                  Colors.green,
                  c,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBalanceCard(
                  'Total',
                  '\$${profile?.totalBalance.toStringAsFixed(2) ?? '0.00'}',
                  c.accentBlue,
                  c,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String label, String amount, Color color, AppColors c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyRewardSection(DashboardData? dashboardData, AppColors c) {
    final canClaim = (dashboardData?.canClaimDaily ?? false) && !_claimedRewardLocally;
    final amount = dashboardData?.dailyRewardAmount ?? 0.1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Sign-In Reward',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${amount.toStringAsFixed(2)}/day bonus, claim every 24h.',
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canClaim ? () => _claimDailyReward() : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canClaim ? Colors.green : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Consumer<DashboardProvider>(
                builder: (context, provider, child) {
                  return provider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          canClaim
                              ? 'Claim \$${amount.toStringAsFixed(2)}'
                              : 'Already claimed today',
                        );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildRankLadderSection(DashboardData? dashboardData, AppColors c) {
    final ranks = dashboardData?.ranks ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Brain Box Rank Ladder',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _rankScrollController,
            child: Row(
              spacing: 8,
              children: ranks.map((rank) => _buildRankCard(rank, c)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankCard(Rank rank, AppColors c) {
    final isCurrent = rank.isCurrent;
    final color = _parseColor(rank.color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent ? color : c.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent ? color : c.border,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrent) ...[
            const Text('👑', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              rank.name,
              style: TextStyle(
                color: isCurrent ? Colors.white : c.textSecondary,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            rank.maxBalance >= InvestmentLogic.openEndedMaxBalance - 1
                ? '\$${rank.minBalance.toInt()}+ · ${rank.dailyProfitPct}%'
                : '\$${rank.minBalance.toInt()}–\$${rank.maxBalance.toInt()} · ${rank.dailyProfitPct}%',
            style: TextStyle(
              color: isCurrent ? Colors.white70 : c.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '×${rank.copyTradesLimit}',
            style: TextStyle(
              color: isCurrent ? Colors.white70 : c.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF4CAF50);
    }
  }

  Future<void> _claimDailyReward() async {
    setState(() => _claimedRewardLocally = true);
    final success = await context.read<DashboardProvider>().claimDailyReward();
    if (!mounted) return;
    if (success) {
      Fluttertoast.showToast(
        msg: "Daily reward \$0.10 claimed! Added to withdrawable.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } else {
      setState(() => _claimedRewardLocally = false);
      Fluttertoast.showToast(
        msg: context.read<DashboardProvider>().errorMessage ?? "Claim failed",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _simulateCopyTrade() async {
    final trade = await context.read<DashboardProvider>().simulateCopyTrade();
    if (!mounted) return;
    if (trade != null) {
      Fluttertoast.showToast(
        msg: '${trade.pair} ${trade.action.toUpperCase()} — session live',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } else {
      Fluttertoast.showToast(
        msg:
            context.read<DashboardProvider>().errorMessage ??
            "Trade failed",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
}
