import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/admin_withdrawal_provider.dart';
import '../models/admin_models.dart';

class AdminWithdrawalsScreen extends StatefulWidget {
  const AdminWithdrawalsScreen({super.key});

  @override
  State<AdminWithdrawalsScreen> createState() => _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends State<AdminWithdrawalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminWithdrawalProvider>(context, listen: false).loadWithdrawals();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminWithdrawalProvider>(
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
                ],
              ),
            ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.withdrawals.isEmpty
                      ? const Center(child: Text('No withdrawals found', style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          itemCount: provider.withdrawals.length,
                          itemBuilder: (_, i) => _WithdrawalCard(withdrawal: provider.withdrawals[i], provider: provider),
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
          color: selected ? const Color(0xFF1E3A8A) : const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF1E3A8A) : Colors.white24),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  final AdminWithdrawal withdrawal;
  final AdminWithdrawalProvider provider;

  const _WithdrawalCard({required this.withdrawal, required this.provider});

  Future<void> _copyAddress(BuildContext context, String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet address copied'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = withdrawal.status == 'approved' ? Colors.green : withdrawal.status == 'rejected' ? Colors.red : Colors.orange;
    final address = withdrawal.walletAddress.trim();

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
                      Text(withdrawal.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(withdrawal.userEmail, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor)),
                  child: Text(withdrawal.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                if (withdrawal.isFlagged || withdrawal.isBanned) ...[
                  const SizedBox(width: 4),
                  Icon(withdrawal.isBanned ? Icons.gpp_bad : Icons.warning, color: withdrawal.isBanned ? Colors.red : Colors.orange, size: 16),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('\$', style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 18)),
                Text(withdrawal.amount.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                _Badge(label: withdrawal.network),
              ],
            ),
            const SizedBox(height: 12),
            Text('Payout wallet address', style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    address.isEmpty ? '(no address provided)' : address,
                    style: TextStyle(
                      color: address.isEmpty ? Colors.red[300] : const Color(0xFF58A6FF),
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _copyAddress(context, address),
                        icon: const Icon(Icons.copy, size: 16, color: Color(0xFF58A6FF)),
                        label: const Text('Copy address', style: TextStyle(color: Color(0xFF58A6FF), fontSize: 12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text('Created: ${_formatDate(withdrawal.createdAt)}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            if (withdrawal.processedAt != null)
              Text('Processed: ${_formatDate(withdrawal.processedAt!)}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            if (withdrawal.status == 'pending') ...[
              const SizedBox(height: 8),
              if (withdrawal.isFlagged || withdrawal.isBanned)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                  child: const Text('Cannot approve — user is flagged or banned', style: TextStyle(color: Colors.orange, fontSize: 11)),
                )
              else if (address.isEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Missing wallet address — reject or contact user', style: TextStyle(color: Colors.red, fontSize: 11)),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _confirmAction(
                        context,
                        'Mark \$${withdrawal.amount.toStringAsFixed(2)} as delivered to this wallet?',
                        () => provider.approveWithdrawal(withdrawal.id),
                      ),
                      icon: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      label: const Text('Mark delivered', style: TextStyle(color: Colors.green, fontSize: 12)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _confirmAction(
                        context,
                        'Reject \$${withdrawal.amount.toStringAsFixed(2)} withdrawal? (refunds balance)',
                        () => provider.rejectWithdrawal(withdrawal.id),
                      ),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    );
  }
}
