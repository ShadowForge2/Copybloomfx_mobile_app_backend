import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';
import '../models/finance_models.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/theme_provider.dart';
import '../services/investment_logic.dart';
import '../services/notification_service.dart';
import '../widgets/notification_ui.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _walletController = TextEditingController();
  String _selectedNetwork = InvestmentLogic.depositNetworks.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchFinance();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _walletController.dispose();
    super.dispose();
  }

  List<String> _networksFor(DashboardProvider dash) {
    final n = dash.finance?.networks;
    if (n != null && n.isNotEmpty) return n;
    return InvestmentLogic.depositNetworks;
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

        final c = themeProvider.colors;
        final user = authProvider.user!;
        final profile = dashboardProvider.data?.profile;
        final dashboardData = dashboardProvider.data;
        final finance = dashboardProvider.finance;

        return SafeArea(
          child: Column(
            children: [
              _buildHeader(context, user, c),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await dashboardProvider.fetchDashboardData(
                      userId: authProvider.user?.id,
                    );
                    await dashboardProvider.fetchFinance();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFinancialOverview(profile, finance?.overview, c),
                        const SizedBox(height: 8),
                        Text(
                          'Deposits stay pending until an admin approves; then funds credit to tradable balance. '
                          'Withdrawals debit withdrawable immediately and stay pending until payout is approved.',
                          style: TextStyle(color: c.textSecondary, fontSize: 11),
                        ),
                        const SizedBox(height: 24),
                        _buildActionButtons(dashboardData, dashboardProvider, user, c),
                        const SizedBox(height: 24),
                        _buildTransactionHistory(dashboardProvider, c),
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
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet,
            color: c.accentBlue,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Finance',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: NotificationBell(onTap: () => showNotificationSheet(context)),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.surfaceBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(Icons.person, color: c.iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  user.username,
                  style: TextStyle(color: c.textPrimary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialOverview(Profile? profile, FinanceOverview? overview, AppColors c) {
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
            'Financial Overview',
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
                child: _buildOverviewCard(
                  'Tradable Balance',
                  '\$${profile?.lockedBalance.toStringAsFixed(2) ?? '0.00'}',
                  Colors.orange,
                  c,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewCard(
                  'Withdrawable',
                  '\$${profile?.withdrawableBalance.toStringAsFixed(2) ?? '0.00'}',
                  Colors.green,
                  c,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  'Approved deposits (Σ)',
                  '\$${overview?.totalDeposits.toStringAsFixed(2) ?? '0.00'}',
                  c.accentBlue,
                  c,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewCard(
                  'Pending deposit amt (Σ)',
                  '\$${overview?.pendingDeposits.toStringAsFixed(2) ?? '0.00'}',
                  Colors.amber,
                  c,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  'Referral / earnings',
                  '\$${profile?.referralEarnings.toStringAsFixed(2) ?? '0.00'}',
                  const Color(0xFF9C27B0),
                  c,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewCard(
                  'Total balance',
                  '\$${profile?.totalBalance.toStringAsFixed(2) ?? '0.00'}',
                  c.textPrimary,
                  c,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(String label, String amount, Color color, AppColors c) {
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
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    DashboardData? data,
    DashboardProvider dashboardProvider,
    User user,
    AppColors c,
  ) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showDepositTypeSelector(data, dashboardProvider, c),
            icon: const Icon(Icons.add),
            label: const Text('Deposit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: user.isFlagged
                ? null
                : () => _showWithdrawalTypeSelector(data, dashboardProvider, user, c),
            icon: const Icon(Icons.upload_outlined),
            label: const Text('Withdraw'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalAdminSimulation(DashboardProvider dash, AppColors c) {
    final deposits = dash.finance?.deposits ?? const <UserDeposit>[];
    final withdrawals = dash.finance?.withdrawals ?? const <UserWithdrawal>[];
    final pendingD = deposits.where((d) => d.status == 'pending').toList();
    final pendingW = withdrawals.where((w) => w.status == 'pending').toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF9800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Local demo — simulate admin (until admin app exists)',
            style: TextStyle(
              color: Color(0xFFFFB74D),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          if (pendingD.isEmpty && pendingW.isEmpty)
            Text('No pending items.', style: TextStyle(color: c.textSecondary, fontSize: 12))
          else ...[
            ...pendingD.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Deposit #${d.id} \$${d.amount.toStringAsFixed(2)} ${d.network}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await dash.devApproveDeposit(d.id);
                        if (context.mounted) {
                          Fluttertoast.showToast(msg: 'Deposit approved (demo)');
                        }
                      },
                      child: const Text('Approve', style: TextStyle(fontSize: 11)),
                    ),
                    TextButton(
                      onPressed: () async {
                        await dash.devRejectDeposit(d.id);
                        if (context.mounted) {
                          Fluttertoast.showToast(msg: 'Deposit rejected (demo)');
                        }
                      },
                      child: const Text('Reject', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
            ...pendingW.map(
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Withdraw #${w.id} \$${w.amount.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await dash.devApproveWithdrawal(w.id);
                        if (context.mounted) {
                          Fluttertoast.showToast(msg: 'Withdrawal approved (demo)');
                        }
                      },
                      child: const Text('Approve', style: TextStyle(fontSize: 11)),
                    ),
                    TextButton(
                      onPressed: () async {
                        await dash.devRejectWithdrawal(w.id);
                        if (context.mounted) {
                          Fluttertoast.showToast(msg: 'Withdrawal rejected — refunded (demo)');
                        }
                      },
                      child: const Text('Reject', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionHistory(DashboardProvider dash, AppColors c) {
    final deposits = dash.finance?.deposits ?? const <UserDeposit>[];
    final withdrawals = dash.finance?.withdrawals ?? const <UserWithdrawal>[];
    final combined = <Map<String, Object?>>[];
    for (final d in deposits) {
      combined.add({'type': 'deposit', 'obj': d, 'at': d.createdAt});
    }
    for (final w in withdrawals) {
      combined.add({'type': 'withdrawal', 'obj': w, 'at': w.createdAt});
    }
    combined.sort((a, b) => (b['at'] as DateTime).compareTo(a['at'] as DateTime));

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
            'Deposits & withdrawals',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (combined.isEmpty)
            Center(
              child: Text(
                'No deposit or withdrawal requests yet.',
                style: TextStyle(color: c.textSecondary),
              ),
            )
          else
            ...combined.map((row) {
              if (row['type'] == 'deposit') {
                final d = row['obj']! as UserDeposit;
                return _buildTransactionItem(
                  'Deposit',
                  '\$${d.amount.toStringAsFixed(2)}',
                  d.network,
                  d.status,
                  Colors.orange,
                  c,
                );
              }
              final w = row['obj']! as UserWithdrawal;
              return _buildTransactionItem(
                'Withdrawal',
                '\$${w.amount.toStringAsFixed(2)}',
                w.network,
                w.status,
                Colors.redAccent,
                c,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
    String type,
    String amount,
    String network,
    String status,
    Color color,
    AppColors c,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(
            type == 'Deposit' ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  network,
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              Text(
                status,
                style: TextStyle(
                  color: status == 'pending'
                      ? Colors.amber
                      : status == 'approved'
                      ? Colors.green
                      : Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDepositTypeSelector(DashboardData? data, DashboardProvider dash, AppColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select deposit method',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildDepositOption(
              icon: Icons.currency_bitcoin,
              title: 'Crypto',
              subtitle: 'USDT BEP-20, ERC-20, Solana, etc. — admin approval required',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showCryptoDepositModal(data, dash, c);
              },
              c: c,
            ),
            const SizedBox(height: 12),
            _buildDepositOption(
              icon: Icons.account_balance,
              title: 'Local (Paystack)',
              subtitle: 'Pay with card, bank transfer, USSD — auto-verified, no admin needed',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _showLocalPaystackDepositModal(data, dash, c);
              },
              c: c,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDepositOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required AppColors c,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.iconColor, size: 20),
          ],
        ),
      ),
    );
  }

  void _showCryptoDepositModal(DashboardData? data, DashboardProvider dash, AppColors c) {
    _amountController.text = data?.minDeposit.toStringAsFixed(0) ?? '7';
    final networks = _networksFor(dash);
    if (!networks.contains(_selectedNetwork)) {
      _selectedNetwork = networks.first;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.currency_bitcoin, color: Colors.orange, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Crypto Deposit',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Minimum \$${data?.minDeposit.toStringAsFixed(2) ?? '7.00'}. Pending admin approval required.',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Network',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: c.surfaceBg,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedNetwork,
                    dropdownColor: c.surfaceBg,
                    style: TextStyle(color: c.textPrimary),
                    items: networks
                        .map(
                          (n) => DropdownMenuItem(
                            value: n,
                            child: Text(n, style: TextStyle(color: c.textPrimary)),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => _selectedNetwork = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Amount (USDT)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: c.surfaceBg,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: dash.isSubmittingDeposit
                      ? null
                      : () async {
                          final amt = double.tryParse(_amountController.text) ?? 0;
                          if (amt < (data?.minDeposit ?? 7)) {
                            Fluttertoast.showToast(
                              msg: 'Minimum deposit is \$${data?.minDeposit.toStringAsFixed(0)}',
                            );
                            return;
                          }
                          final dep = await dash.submitDeposit(
                            amount: amt,
                            network: _selectedNetwork,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          if (dep != null) {
                            _showPendingDepositDialog(dep, dash, c);
                          } else {
                            Fluttertoast.showToast(
                              msg: dash.errorMessage ?? 'Deposit request failed',
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: dash.isSubmittingDeposit
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit crypto deposit'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocalPaystackDepositModal(DashboardData? data, DashboardProvider dash, AppColors c) {
    final emailController = TextEditingController();
    final amountController = TextEditingController(
      text: data?.minDeposit.toStringAsFixed(0) ?? '7',
    );
    final processingNotifier = ValueNotifier<bool>(false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isProcessing = processingNotifier.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance, color: Colors.green, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Local Deposit (Paystack)',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pay with Paystack — card, bank transfer, USSD. Auto-verified, no admin needed.',
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: c.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Amount (USDT equivalent)',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: c.surfaceBg,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: c.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Email (for payment receipt)',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: c.surfaceBg,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              final amt = double.tryParse(amountController.text) ?? 0;
                              if (amt < (data?.minDeposit ?? 7)) {
                                Fluttertoast.showToast(
                                  msg: 'Minimum deposit is \$${data?.minDeposit.toStringAsFixed(0)}',
                                );
                                return;
                              }
                              setModalState(() => processingNotifier.value = true);
                              final result = await dash.submitPaystackDeposit(
                                amount: amt,
                                email: emailController.text.trim(),
                              );
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              if (result['success'] == true) {
                                final reference = result['reference'] as String?;
                                if (reference != null) {
                                  await showDialog<void>(
                                    context: context,
                                    builder: (dialogCtx) => AlertDialog(
                                      backgroundColor: c.surfaceBg,
                                      title: Row(
                                        children: [
                                          const Icon(Icons.check_circle, color: Colors.green, size: 24),
                                          const SizedBox(width: 8),
                                          Text('Payment Submitted', style: TextStyle(color: c.textPrimary)),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Complete your payment in the browser, then tap Verify below.',
                                            style: TextStyle(color: Colors.white70),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Reference: $reference',
                                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                                          ),
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                final verified = await dash.verifyPaystackPayment(reference);
                                                if (!dialogCtx.mounted) return;
                                                Navigator.pop(dialogCtx);
                                                if (verified) {
                                                  if (!context.mounted) return;
                                                  await showDialog<void>(
                                                    context: context,
                                                    builder: (successCtx) => AlertDialog(
                                                      backgroundColor: c.surfaceBg,
                                                      title: Row(
                                                        children: [
                                                          const Icon(Icons.check_circle, color: Colors.green, size: 24),
                                                          const SizedBox(width: 8),
                                                          Text('Payment successful', style: TextStyle(color: c.textPrimary)),
                                                        ],
                                                      ),
                                                      content: Text(
                                                        'Your deposit of \$${amt.toStringAsFixed(2)} has been confirmed and credited to your tradable balance.',
                                                        style: const TextStyle(color: Colors.white70),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(successCtx),
                                                          child: const Text('OK'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                } else {
                                                  if (!context.mounted) return;
                                                  Fluttertoast.showToast(
                                                    msg: dash.errorMessage ?? 'Payment not yet confirmed. Try again.',
                                                    backgroundColor: Colors.orange,
                                                    textColor: Colors.white,
                                                  );
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF00BFA5),
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('Verify Payment'),
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dialogCtx),
                                          child: const Text('Cancel'),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  await showDialog<void>(
                                    context: context,
                                    builder: (dialogCtx) => AlertDialog(
                                      backgroundColor: c.surfaceBg,
                                      title: Row(
                                        children: [
                                          const Icon(Icons.check_circle, color: Colors.green, size: 24),
                                          const SizedBox(width: 8),
                                          Text('Payment successful', style: TextStyle(color: c.textPrimary)),
                                        ],
                                      ),
                                      content: Text(
                                        'Your deposit of \$${amt.toStringAsFixed(2)} has been confirmed and credited to your tradable balance.',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dialogCtx),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              } else {
                                Fluttertoast.showToast(
                                  msg: dash.errorMessage ?? 'Payment failed',
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFA5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isProcessing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                                SizedBox(width: 10),
                                Text('Processing...'),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payment, size: 20),
                                SizedBox(width: 8),
                                Text('Pay with Paystack'),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Secured by Paystack',
                      style: TextStyle(color: c.textSecondary, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showWithdrawalTypeSelector(DashboardData? data, DashboardProvider dash, User user, AppColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select withdrawal method',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Available: \$${data?.profile?.withdrawableBalance.toStringAsFixed(2) ?? '0.00'}',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _buildDepositOption(
              icon: Icons.currency_bitcoin,
              title: 'Crypto (USDT BEP-20)',
              subtitle: 'Withdraw to USDT BEP-20 address — admin processes payout',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showCryptoWithdrawalModal(data, dash, user, c);
              },
              c: c,
            ),
            const SizedBox(height: 12),
            _buildDepositOption(
              icon: Icons.account_balance,
              title: 'Bank Transfer',
              subtitle: 'Withdraw to your local bank account',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _showBankWithdrawalUnavailable(c);
              },
              c: c,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showCryptoWithdrawalModal(DashboardData? data, DashboardProvider dash, User user, AppColors c) {
    final amountController = TextEditingController(
      text: data?.minWithdrawal.toStringAsFixed(0) ?? '10',
    );
    final addressController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.currency_bitcoin, color: Colors.orange, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Crypto Withdrawal',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Minimum \$${data?.minWithdrawal.toStringAsFixed(2) ?? '10.00'}. '
                'Withdrawable debited now. Admin processes and marks complete.',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Amount (USDT)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: c.surfaceBg,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  labelText: 'USDT (BEP-20) Address',
                  hintText: '0x...',
                  hintStyle: const TextStyle(color: Color(0xFF505050)),
                  prefixIcon: const Icon(Icons.wallet),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: c.surfaceBg,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: dash.isSubmittingWithdrawal
                      ? null
                      : () async {
                          final amt = double.tryParse(amountController.text) ?? 0;
                          if (amt < (data?.minWithdrawal ?? 10)) {
                            Fluttertoast.showToast(
                              msg: 'Minimum withdrawal is \$${data?.minWithdrawal.toStringAsFixed(0)}',
                            );
                            return;
                          }
                          if (addressController.text.trim().isEmpty) {
                            Fluttertoast.showToast(
                              msg: 'Enter your USDT BEP-20 address',
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                            );
                            return;
                          }
                          final w = await dash.submitWithdrawal(
                            amount: amt,
                            network: 'USDT BEP20',
                            walletAddress: addressController.text.trim(),
                            userIsFlagged: user.isFlagged,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          if (w != null) {
                            Fluttertoast.showToast(
                              msg: 'Withdrawal pending. Admin will process payout to your USDT BEP-20 address.',
                              backgroundColor: Colors.green,
                              textColor: Colors.white,
                            );
                          } else {
                            Fluttertoast.showToast(
                              msg: dash.errorMessage ?? 'Withdrawal failed',
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: dash.isSubmittingWithdrawal
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit withdrawal'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showPendingDepositDialog(UserDeposit dep, DashboardProvider dash, AppColors c) {
    const fiveMin = Duration(minutes: 5);
    const pollInterval = Duration(seconds: 3);
    final walletExpiresAt = DateTime.now().add(fiveMin);
    final fixedExpiry = walletExpiresAt;
    ValueNotifier<DateTime> expiresAtNotifier = ValueNotifier(fixedExpiry);
    ValueNotifier<String> statusNotifier = ValueNotifier('pending');
    ValueNotifier<bool> approvedNotifier = ValueNotifier(false);
    Timer? countdownTimer;
    Timer? pollTimer;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          final remaining = fixedExpiry.difference(DateTime.now());
          if (remaining.isNegative) {
            timer.cancel();
            expiresAtNotifier.value = fixedExpiry;
          }
        });

        pollTimer = Timer.periodic(pollInterval, (_) async {
          final token = await AuthService.getToken();
          if (token == null) return;
          final apiService = ApiService(baseUrl: 'https://copybloomfx-mobile-app-backend.onrender.com', authToken: token);
          final res = await apiService.getDepositStatus(dep.id);
          if (res.success && res.data != null) {
            final status = res.data!['status']?.toString() ?? 'pending';
            statusNotifier.value = status;
            if (status == 'approved') {
              approvedNotifier.value = true;
              pollTimer?.cancel();
              countdownTimer?.cancel();
              NotificationService.instance.showDepositApproved(dep.amount);
            } else if (status == 'rejected' || status == 'expired') {
              pollTimer?.cancel();
              countdownTimer?.cancel();
            }
          }
        });

        return PopScope(
          canPop: approvedNotifier.value,
          child: ValueListenableBuilder<String>(
            valueListenable: statusNotifier,
            builder: (context, status, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: approvedNotifier,
                builder: (context, approved, _) {
                  if (approved) {
                    Future.delayed(const Duration(milliseconds: 2500), () {
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    });
                    return AlertDialog(
                      backgroundColor: c.surfaceBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 20),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 800),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 60,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Deposit Approved!',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$${dep.amount.toStringAsFixed(2)} credited to tradable balance.',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Closing automatically...',
                            style: TextStyle(color: c.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    );
                  }

                  return AlertDialog(
                    backgroundColor: c.surfaceBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Row(
                      children: [
                        Icon(
                          status == 'rejected' ? Icons.cancel : status == 'expired' ? Icons.timer_off : Icons.access_time,
                          color: status == 'rejected' ? Colors.red : status == 'expired' ? Colors.grey : Colors.orange,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status == 'rejected' ? 'Deposit Rejected' : status == 'expired' ? 'Deposit Expired' : 'Deposit Pending',
                          style: TextStyle(color: c.textPrimary, fontSize: 18),
                        ),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Send the exact amount to the address below:',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Amount: \$${dep.amount.toStringAsFixed(2)}',
                                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text('Network:', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                              Text(dep.network, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 8),
                              Text('Wallet Address:', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                              SelectableText(
                                dep.walletAddress ?? '',
                                style: TextStyle(color: c.accentBlue, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ValueListenableBuilder<DateTime>(
                          valueListenable: expiresAtNotifier,
                          builder: (context, expiresAt, _) {
                            final remaining = expiresAt.difference(DateTime.now());
                            final seconds = remaining.inSeconds.clamp(0, 300);
                            final minutes = seconds ~/ 60;
                            final secs = seconds % 60;
                            final isExpired = seconds <= 0;
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isExpired ? Colors.red.withValues(alpha: 0.1) : c.cardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isExpired ? Colors.red : c.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isExpired ? Icons.timer_off : Icons.timer,
                                    color: isExpired ? Colors.red : Colors.orange,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isExpired
                                        ? 'Wallet expired — create a new deposit'
                                        : 'Wallet expires in ${minutes}m ${secs}s',
                                    style: TextStyle(
                                      color: isExpired ? Colors.red : Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        if (status == 'expired')
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.timer_off, color: Colors.grey, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'This deposit has expired. Please create a new deposit.',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        else if (status == 'rejected')
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info, color: Colors.red, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'This deposit was rejected by admin.',
                                  style: TextStyle(color: Colors.red, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Checking for approval...',
                                style: TextStyle(color: c.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          countdownTimer?.cancel();
                          pollTimer?.cancel();
                          Navigator.of(ctx).pop();
                        },
                        child: Text(
                          (status == 'rejected' || status == 'expired') ? 'Close' : 'Close & check later',
                          style: TextStyle(color: c.accentBlue),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      countdownTimer?.cancel();
      pollTimer?.cancel();
    });
  }

  void _showBankWithdrawalUnavailable(AppColors c) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surfaceBg,
        title: Row(
          children: [
            Icon(Icons.info_outline, color: c.accentBlue, size: 22),
            const SizedBox(width: 8),
            Text('Bank withdrawal', style: TextStyle(color: c.textPrimary)),
          ],
        ),
        content: const Text(
          'Bank withdrawal is coming soon. Please use crypto withdrawal.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
