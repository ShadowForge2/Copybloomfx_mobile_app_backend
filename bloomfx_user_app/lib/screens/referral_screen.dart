import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/notification_ui.dart';

class _ReferralListEntry {
  final String username;
  final String status;
  final String joinedAt;
  final double totalCommission;

  const _ReferralListEntry({
    required this.username,
    required this.status,
    required this.joinedAt,
    required this.totalCommission,
  });
}

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  bool _loadingReferrals = true;
  String? _referralLoadError;
  List<_ReferralListEntry> _referrals = [];
  int _totalReferrals = 0;
  int _validReferrals = 0;
  double _referralEarnings = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReferrals());
  }

  Future<void> _loadReferrals() async {
    if (!mounted) return;
    setState(() {
      _loadingReferrals = true;
      _referralLoadError = null;
    });

    try {
      final token = await AuthService.getToken();
      final baseUrl = context.read<DashboardProvider>().apiBaseUrl;
      final api = ApiService(baseUrl: baseUrl, authToken: token);
      final res = await api.getUserReferrals();

      if (!mounted) return;

      if (res.success && res.data != null) {
        final data = res.data!;
        final list = (data['referrals'] as List<dynamic>? ?? [])
            .map((raw) {
              final m = Map<String, dynamic>.from(raw as Map);
              final joined = m['joinedAt']?.toString() ?? '';
              return _ReferralListEntry(
                username: m['username']?.toString() ?? 'Unknown',
                status: (m['status']?.toString() ?? 'PENDING').toUpperCase(),
                joinedAt: joined.isNotEmpty ? _formatDate(joined) : '—',
                totalCommission: (m['totalCommissionEarned'] as num?)?.toDouble() ?? 0,
              );
            })
            .toList();

        setState(() {
          _referrals = list;
          _totalReferrals = (data['totalReferrals'] as num?)?.toInt() ?? list.length;
          _validReferrals = (data['validReferrals'] as num?)?.toInt() ?? 0;
          _referralEarnings = (data['referralEarnings'] as num?)?.toDouble() ?? 0;
          _loadingReferrals = false;
        });
        return;
      }

      setState(() {
        _referralLoadError = res.message.isNotEmpty ? res.message : 'Could not load referrals';
        _loadingReferrals = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _referralLoadError = 'Could not load referrals';
        _loadingReferrals = false;
      });
    }
  }

  String _formatDate(String iso) {
    try {
      return DateFormat.yMMMd().format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, DashboardProvider>(
      builder: (context, authProvider, dashboardProvider, child) {
        if (authProvider.user == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final user = authProvider.user!;
        final referralCode = dashboardProvider.data?.profile?.referralCode ?? '';

        return SafeArea(
          child: Column(
            children: [
              _buildHeader(context, user),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadReferrals,
                  color: const Color(0xFFD4AF37),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildReferralBonusInfo(),
                        const SizedBox(height: 16),
                        _buildReferralCodeSection(referralCode),
                        const SizedBox(height: 16),
                        _buildReferralStats(),
                        const SizedBox(height: 16),
                        _buildReferralList(),
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

  Widget _buildHeader(BuildContext context, User user) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          const Icon(Icons.people, color: Color(0xFFD4AF37), size: 24),
          const SizedBox(width: 12),
          const Text('Referrals', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: NotificationBell(onTap: () => showNotificationSheet(context)),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF7D8590), size: 20),
                const SizedBox(width: 8),
                Text(user.username, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralBonusInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, color: Color(0xFFD4AF37), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Earn 8% on Every Referral Deposit', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(
                  'When someone you refer makes a deposit, you earn 8% credited to your locked balance (same 30-day lock as deposits).',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCodeSection(String referralCode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Referral Code', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Text(
                    referralCode.isNotEmpty ? referralCode : 'N/A',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _copyReferralCode(referralCode),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C7A28),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.copy, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferralStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          _statTile('Total Referrals', '$_totalReferrals'),
          const SizedBox(width: 24),
          _statTile('Valid Referrals', '$_validReferrals'),
          const SizedBox(width: 24),
          _statTile('Earnings', '\$${_referralEarnings.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF7D8590), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildReferralList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Referrals', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_loadingReferrals)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: Color(0xFFD4AF37))))
          else if (_referralLoadError != null)
            Text(_referralLoadError!, style: const TextStyle(color: Colors.orange, fontSize: 12))
          else if (_referrals.isEmpty)
            const Text('No referrals yet. Share your code to invite traders.', style: TextStyle(color: Color(0xFF7D8590), fontSize: 12))
          else
            ..._referrals.map(_buildReferralListItem),
        ],
      ),
    );
  }

  Widget _buildReferralListItem(_ReferralListEntry entry) {
    final isValid = entry.status == 'VALID';
    final statusColor = isValid ? Colors.green : Colors.orange;
    final statusLabel = isValid ? 'Valid' : 'Pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(entry.joinedAt, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                if (entry.totalCommission > 0)
                  Text(
                    'Earned: \$${entry.totalCommission.toStringAsFixed(2)}',
                    style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 10),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor),
            ),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _copyReferralCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      Fluttertoast.showToast(msg: 'Referral code not available yet');
      return;
    }
    await Clipboard.setData(ClipboardData(text: trimmed));
    if (!mounted) return;
    Fluttertoast.showToast(msg: 'Referral code copied: $trimmed');
  }
}
