import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/notification_ui.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
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

        return SafeArea(
          child: Column(
            children: [
              _buildHeader(context, user),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildReferralBonusInfo(),
                      const SizedBox(height: 16),
                      _buildReferralCodeSection(user, dashboardProvider.data?.profile?.referralCode ?? ''),
                      const SizedBox(height: 16),
                      _buildReferralStats(dashboardProvider.data),
                      const SizedBox(height: 16),
                      _buildReferralListPlaceholder(),
                    ],
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
          const Icon(Icons.people, color: Color(0xFF58A6FF), size: 24),
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
          const Icon(Icons.monetization_on, color: Color(0xFF58A6FF), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Earn 8% on Every Referral Deposit', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('When someone you refer deposits or tops up, you get 8% credited to your tradable balance instantly.', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCodeSection(User user, String referralCode) {
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
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.copy, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _shareReferralLink('telegram', referralCode),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.share, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferralStats(DashboardData? dashboardData) {
    final stats = dashboardData?.profile;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          _statTile('Total Referrals', '${stats?.totalReferrals ?? 0}'),
          const SizedBox(width: 24),
          _statTile('Valid Referrals', '${stats?.validReferrals ?? 0}'),
          const SizedBox(width: 24),
          _statTile('Earnings', '\$${(stats?.referralEarnings ?? 0).toStringAsFixed(2)}'),
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

  Widget _buildReferralListPlaceholder() {
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
          _buildReferralListItem('user_crypto_king', 'Valid', '2023-10-15', Colors.green),
          _buildReferralListItem('trading_expert', 'Pending', '2023-11-02', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildReferralListItem(String username, String status, String date, Color statusColor) {
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
                Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(date, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
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
            child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _copyReferralCode(String code) {
    Fluttertoast.showToast(msg: "Referral code $code copied!");
  }

  void _shareReferralLink(String platform, String code) {
    Fluttertoast.showToast(msg: "Sharing referral link for $code via $platform...");
  }
}
