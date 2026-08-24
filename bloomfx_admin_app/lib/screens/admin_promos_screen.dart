import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/admin_promo_provider.dart';
import '../models/admin_models.dart';

class AdminPromosScreen extends StatefulWidget {
  const AdminPromosScreen({super.key});

  @override
  State<AdminPromosScreen> createState() => _AdminPromosScreenState();
}

class _AdminPromosScreenState extends State<AdminPromosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminPromoProvider>(context, listen: false).loadPromos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminPromoProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF1A1F2E),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showCreatePromoDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Promo Code'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.promos.isEmpty
                      ? const Center(child: Text('No promo codes', style: TextStyle(color: Colors.white54)))
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            ...provider.promos.map((p) => _PromoCard(promo: p, provider: provider)),
                            if (provider.redemptions.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('Redemption History', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              ...provider.redemptions.map((r) => _RedemptionCard(redemption: r)),
                            ],
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }

  void _showCreatePromoDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final minDepCtrl = TextEditingController();
    final maxBonusCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '100');
    DateTime? expires;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text('Create Promo Code', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Code', 'e.g. BONUS50'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minDepCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Min Deposit (\$)', 'e.g. 100'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: maxBonusCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Max Bonus (\$)', 'e.g. 50'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limitCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Usage Limit', 'e.g. 100'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(expires == null ? 'No expiry' : 'Expires: ${expires!.toLocal()}'.split(' ')[0], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 30)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (picked != null) setDialogState(() => expires = picked);
                  },
                  child: const Text('Pick Date'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (codeCtrl.text.trim().isEmpty) return;
              Provider.of<AdminPromoProvider>(context, listen: false).createPromo(
                codeCtrl.text.trim(),
                double.tryParse(minDepCtrl.text) ?? 0,
                double.tryParse(maxBonusCtrl.text) ?? 0,
                int.tryParse(limitCtrl.text) ?? 100,
                expires,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ));
  }

  InputDecoration _inputDeco(String label, String hint) {
    return InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true, fillColor: const Color(0xFF0D1117),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final PromoCode promo;
  final AdminPromoProvider provider;

  const _PromoCard({required this.promo, required this.provider});

  @override
  Widget build(BuildContext context) {
    final expired = promo.expiresAt != null && promo.expiresAt!.isBefore(DateTime.now());

    return Card(
      color: const Color(0xFF1A1F2E),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (promo.isActive && !expired) ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: (promo.isActive && !expired) ? Colors.green : Colors.red),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(promo.code, style: TextStyle(
                        color: (promo.isActive && !expired) ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1,
                      )),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: promo.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied ${promo.code}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: (promo.isActive && !expired) ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (expired)
                  const Text('EXPIRED', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))
                else
                  Text(promo.isActive ? 'ACTIVE' : 'DISABLED', style: TextStyle(color: promo.isActive ? Colors.green : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _PromoInfo(label: 'Min: \$${promo.minDeposit.toStringAsFixed(0)}'),
                const SizedBox(width: 12),
                _PromoInfo(label: 'Max Bonus: \$${promo.maxBonus.toStringAsFixed(0)}'),
                const SizedBox(width: 12),
                _PromoInfo(label: 'Used: ${promo.usedCount}/${promo.usageLimit}'),
              ],
            ),
            if (promo.expiresAt != null) ...[
              const SizedBox(height: 4),
              Text('Expires: ${promo.expiresAt!.toLocal()}'.split(' ')[0], style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Switch(
                value: promo.isActive && !expired,
                activeColor: Colors.green,
                onChanged: expired ? null : (v) => provider.togglePromo(promo.id, v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoInfo extends StatelessWidget {
  final String label;
  const _PromoInfo({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    );
  }
}

class _RedemptionCard extends StatelessWidget {
  final PromoRedemption redemption;
  const _RedemptionCard({required this.redemption});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1F2E),
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(radius: 14, backgroundColor: const Color(0xFFD4AF37), child: Text(redemption.userName.isNotEmpty ? redemption.userName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 12))),
        title: Text(redemption.userName, style: const TextStyle(color: Colors.white, fontSize: 13)),
        subtitle: Text('Code: ${redemption.promoCode}', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('+\$${redemption.bonusAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${redemption.createdAt.toLocal()}'.split(' ')[0], style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
