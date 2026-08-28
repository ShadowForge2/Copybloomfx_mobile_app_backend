import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_deposit_provider.dart';
import '../models/admin_models.dart';

class AdminDepositsScreen extends StatefulWidget {
  const AdminDepositsScreen({super.key});

  @override
  State<AdminDepositsScreen> createState() => _AdminDepositsScreenState();
}

class _AdminDepositsScreenState extends State<AdminDepositsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminDepositProvider>(context, listen: false).loadDeposits();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminDepositProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF1A1F2E),
              child: Row(
                children: [
                  _StatusChip(label: 'All', selected: provider.statusFilter == 'all', onTap: () => provider.setStatusFilter('all')),
                  const SizedBox(width: 8),
                  _StatusChip(label: 'Pending', selected: provider.statusFilter == 'pending', onTap: () => provider.setStatusFilter('pending')),
                  const SizedBox(width: 8),
                  _StatusChip(label: 'Approved', selected: provider.statusFilter == 'approved', onTap: () => provider.setStatusFilter('approved')),
                  const SizedBox(width: 8),
                  _StatusChip(label: 'Rejected', selected: provider.statusFilter == 'rejected', onTap: () => provider.setStatusFilter('rejected')),
                  const SizedBox(width: 8),
                  _StatusChip(label: 'Expired', selected: provider.statusFilter == 'expired', onTap: () => provider.setStatusFilter('expired')),
                ],
              ),
            ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.deposits.isEmpty
                      ? const Center(child: Text('No deposits found', style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          itemCount: provider.deposits.length,
                          itemBuilder: (_, i) => _DepositCard(deposit: provider.deposits[i], provider: provider),
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD4AF37) : const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFFD4AF37) : Colors.white24),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _DepositCard extends StatelessWidget {
  final AdminDeposit deposit;
  final AdminDepositProvider provider;

  const _DepositCard({required this.deposit, required this.provider});

  @override
  Widget build(BuildContext context) {
    final statusColor = deposit.status == 'approved'
        ? Colors.green
        : deposit.status == 'rejected' || deposit.status == 'expired'
            ? Colors.red
            : Colors.orange;
    final statusLabel = deposit.status == 'expired' ? 'PAYMENT TIMEOUT' : deposit.status.toUpperCase();

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deposit.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(deposit.userEmail, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor)),
                  child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                if (deposit.isFlagged || deposit.isBanned) ...[
                  const SizedBox(width: 4),
                  Icon(deposit.isBanned ? Icons.gpp_bad : Icons.warning, color: deposit.isBanned ? Colors.red : Colors.orange, size: 16),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('\$', style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 18)),
                Text(deposit.amount.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                _InfoBadge(label: deposit.network),
                const SizedBox(width: 6),
                _InfoBadge(label: deposit.walletAddress ?? '---'),
              ],
            ),
            if (deposit.walletExpiresAt != null) ...[
              const SizedBox(height: 4),
              Text('Wallet expires: ${_formatDate(deposit.walletExpiresAt!)}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
            if (deposit.expiresAt != null) ...[
              const SizedBox(height: 4),
              Text('Lock expires: ${_formatDate(deposit.expiresAt!)}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
            Text('Created: ${_formatDate(deposit.createdAt)}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            if (deposit.isPaymentTimeout) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_off, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment timeout — the user did not pay into the wallet address before it expired. Auto-expired: user\u2019s fault, no action needed.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (deposit.status == 'pending') ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _confirmAction(context, 'Approve \$${deposit.amount.toStringAsFixed(0)} deposit?', () => provider.approveDeposit(deposit.id)),
                    icon: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    label: const Text('Approve', style: TextStyle(color: Colors.green, fontSize: 12)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _confirmAction(context, 'Reject \$${deposit.amount.toStringAsFixed(0)} deposit?', () => provider.rejectDeposit(deposit.id)),
                    icon: const Icon(Icons.cancel, size: 16, color: Colors.red),
                    label: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 12)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                  ),
                ],
              ),
            ],
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

  String _formatDate(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _InfoBadge extends StatelessWidget {
  final String label;
  const _InfoBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    );
  }
}
