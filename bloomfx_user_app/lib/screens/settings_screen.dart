import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/support_provider.dart';
import '../services/theme_colors.dart';
import '../widgets/notification_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer4<
      AuthProvider,
      ThemeProvider,
      LanguageProvider,
      SupportProvider
    >(
      builder: (context, authProvider, themeProvider, lang, support, _) {
        final c = themeProvider.colors;
        if (authProvider.user == null) {
          return Center(child: CircularProgressIndicator(color: c.accentBlue));
        }

        final user = authProvider.user!;
        return SafeArea(
          child: Column(
            children: [
              _buildHeader(context, user, c),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAccountSettings(themeProvider, lang, c),
                      const SizedBox(height: 24),
                      _buildSecuritySection(context, themeProvider, c),
                      const SizedBox(height: 24),
                      _buildSecurityInfoSection(user, c, lang),
                      const SizedBox(height: 24),
                      _buildSupportSection(c, lang),
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

  Widget _buildHeader(BuildContext context, User user, AppColors c) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: c.cardBg,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.settings, color: c.accentBlue, size: 24),
          const SizedBox(width: 12),
          Text(
            'Settings',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: NotificationBell(
              onTap: () => showNotificationSheet(context),
            ),
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

  Widget _buildAccountSettings(
    ThemeProvider themeProvider,
    LanguageProvider lang,
    AppColors c,
  ) {
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
            'Account Settings',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingsItem('Notifications', Icons.notifications, () {}, c),
          const SizedBox(height: 8),
          _buildSettingsItem('Privacy', Icons.lock, () {}, c),
          const SizedBox(height: 8),
          _buildSettingsItem(
            'Language',
            Icons.language,
            () => _showLanguagePicker(lang, themeProvider, c),
            c,
          ),
          const SizedBox(height: 8),
          _buildSettingsItem(
            'Theme',
            Icons.palette,
            () => _showThemePicker(themeProvider, c),
            c,
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(
    BuildContext context,
    ThemeProvider themeProvider,
    AppColors c,
  ) {
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
            'Security',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingsItem('Change Password', Icons.password, () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: c.cardBg,
                title: const Text(
                  'Change Password',
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  'To change your password, please contact us on Telegram.',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      launchUrl(Uri.parse('https://t.me/CPBloomFX'));
                    },
                    child: Text(
                      'Open Telegram',
                      style: TextStyle(color: c.accentBlue),
                    ),
                  ),
                ],
              ),
            );
          }, c),
          const SizedBox(height: 8),
          _buildSettingsItem('Two-Factor Authentication', Icons.security, () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: c.cardBg,
                title: const Text(
                  'Two-Factor Authentication',
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  'Feature coming soon.',
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
          }, c),
          const SizedBox(height: 8),
          _buildSettingsItem('Login History', Icons.history, () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: c.cardBg,
                title: const Text(
                  'Login History',
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  'Coming soon.',
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
          }, c),
          const SizedBox(height: 8),
          _buildSettingsItem(
            'Logout',
            Icons.logout,
            () => _showLogoutDialog(context, themeProvider),
            c,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    String title,
    IconData icon,
    VoidCallback onTap,
    AppColors c,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surfaceBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: c.iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: TextStyle(color: c.textPrimary)),
            ),
            Icon(Icons.arrow_forward_ios, color: c.iconColor, size: 16),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(
    LanguageProvider lang,
    ThemeProvider themeProvider,
    AppColors c,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        title: Text('Select Language', style: TextStyle(color: c.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['en', 'pt', 'zh', 'ja', 'hi'].map((code) {
            final selected = lang.currentCode == code;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GestureDetector(
                onTap: () {
                  lang.setLanguage(code);
                  Navigator.pop(ctx);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? c.accentBlue.withValues(alpha: 0.2)
                        : c.surfaceBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? c.accentBlue : c.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        lang.tr('language.$code'),
                        style: TextStyle(
                          color: selected ? c.accentBlue : c.textSecondary,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (selected) ...[
                        const Spacer(),
                        Icon(Icons.check, color: c.accentBlue, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF58A6FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(ThemeProvider themeProvider, AppColors c) {
    final themes = AppThemeType.values;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        title: Text('Select Theme', style: TextStyle(color: c.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: themes.map((t) {
            final selected = themeProvider.type == t;
            final color = _themeColor(t);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GestureDetector(
                onTap: () {
                  themeProvider.setTheme(t);
                  Navigator.pop(ctx);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.2)
                        : c.surfaceBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? color : c.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(_themeIcon(t), color: color, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        _themeLabel(t),
                        style: TextStyle(
                          color: selected ? color : c.textSecondary,
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (selected) ...[
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(Icons.check, color: color, size: 20),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF58A6FF)),
            ),
          ),
        ],
      ),
    );
  }

  Color _themeColor(AppThemeType t) {
    switch (t) {
      case AppThemeType.black:
        return const Color(0xFF0D1117);
      case AppThemeType.white:
        return Colors.grey;
      case AppThemeType.skyBlue:
        return const Color(0xFF42A5F5);
    }
  }

  IconData _themeIcon(AppThemeType t) {
    switch (t) {
      case AppThemeType.black:
        return Icons.dark_mode;
      case AppThemeType.white:
        return Icons.light_mode;
      case AppThemeType.skyBlue:
        return Icons.wb_sunny;
    }
  }

  String _themeLabel(AppThemeType t) {
    switch (t) {
      case AppThemeType.black:
        return 'Black';
      case AppThemeType.white:
        return 'White';
      case AppThemeType.skyBlue:
        return 'Sky Blue';
    }
  }

  void _showLogoutDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (ctx) {
        final c = context.read<ThemeProvider>().colors;
        return AlertDialog(
          backgroundColor: c.cardBg,
          title: Text('Logout', style: TextStyle(color: c.textPrimary)),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: c.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: c.accentBlue)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Clear dashboard data to prevent data bleed when switching users
                context.read<DashboardProvider>().clearData();
                context.read<AuthProvider>().logout();
                context.go('/login');
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSecurityInfoSection(
    User user,
    AppColors c,
    LanguageProvider lang,
  ) {
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
            lang.tr('settings.security'),
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoItem('Last Login IP', '192.168.1.1', c),
          _buildInfoItem('Account Status', user.status.name.toUpperCase(), c),
          _buildInfoItem('Banned', user.isBanned ? 'YES' : 'NO', c),
          _buildInfoItem('Flagged', user.isFlagged ? 'YES' : 'NO', c),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: c.textSecondary, fontSize: 14)),
          Text(value, style: TextStyle(color: c.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSupportSection(AppColors c, LanguageProvider lang) {
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
            lang.tr('settings.support'),
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSupportItem(
            'Chat with Support',
            Icons.chat_outlined,
            () => _openSupportChat(),
            c,
          ),
          _buildSupportItem(
            'Contact Support',
            Icons.headset_mic_outlined,
            () => _showContactSupport(),
            c,
          ),
          _buildSupportItem(
            'Terms of Service',
            Icons.description_outlined,
            () => _showTermsOfService(),
            c,
          ),
          _buildSupportItem(
            'Privacy Policy',
            Icons.privacy_tip_outlined,
            () => _showPrivacyPolicy(),
            c,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportItem(
    String title,
    IconData icon,
    VoidCallback onTap,
    AppColors c,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: c.iconColor, size: 20),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(color: c.textPrimary)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: c.iconColor, size: 14),
          ],
        ),
      ),
    );
  }

  void _openSupportChat() {
    context.push('/support-chat');
  }

  void _showContactSupport() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        content: const Text(
          'For support, please contact us on Telegram.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF7D8590)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              launchUrl(
                Uri.parse('https://t.me/CPBloomFX'),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text(
              'Open Telegram',
              style: TextStyle(color: Color(0xFF58A6FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        content: SingleChildScrollView(
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  '# Privacy Policy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text('## 1. Introduction'),
                SizedBox(height: 4),
                Text(
                  'CP Bloom FX ("Company", "we", "our", or "us") respects your privacy and is committed to protecting your personal information.',
                ),
                SizedBox(height: 4),
                Text(
                  'This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our website, mobile application, copy trading services, and related platforms ("Services").',
                ),
                SizedBox(height: 4),
                Text(
                  'By accessing or using our Services, you agree to the collection and use of information in accordance with this Privacy Policy.',
                ),
                SizedBox(height: 12),
                Text('## 2. Information We Collect'),
                SizedBox(height: 4),
                Text('We may collect the following categories of information:'),
                SizedBox(height: 8),
                Text('### Personal Information'),
                Text('• Full name'),
                Text('• Email address'),
                Text('• Phone number'),
                Text('• Date of birth'),
                Text('• Residential address'),
                Text('• Government-issued identification'),
                Text('• Payment information'),
                SizedBox(height: 8),
                Text('### Account Information'),
                Text('• Username'),
                Text('• Password credentials'),
                Text('• Trading preferences'),
                Text('• Referral information'),
                Text('• Wallet balances'),
                Text('• Transaction history'),
                SizedBox(height: 8),
                Text('### Technical Information'),
                Text('• IP address'),
                Text('• Device information'),
                Text('• Browser type'),
                Text('• Operating system'),
                Text('• App version'),
                Text('• Login activity'),
                Text('• Cookies and tracking data'),
                SizedBox(height: 8),
                Text('### Financial Information'),
                Text('• Deposit records'),
                Text('• Withdrawal history'),
                Text('• Payment method details'),
                Text('• Trading activity'),
                SizedBox(height: 12),
                Text('## 3. How We Use Your Information'),
                SizedBox(height: 4),
                Text('We use collected information to:'),
                Text('• create and manage user accounts;'),
                Text('• process deposits and withdrawals;'),
                Text('• provide copy trading services;'),
                Text('• improve platform functionality;'),
                Text('• monitor fraud and suspicious activities;'),
                Text('• comply with legal and regulatory obligations;'),
                Text(
                  '• communicate updates, notifications, and support messages;',
                ),
                Text('• personalize user experience.'),
                SizedBox(height: 12),
                Text('## 4. KYC and Identity Verification'),
                SizedBox(height: 4),
                Text(
                  'To comply with applicable regulations and security requirements, users may be required to complete identity verification procedures ("KYC").',
                ),
                SizedBox(height: 4),
                Text('Verification documents may include:'),
                Text('• passport;'),
                Text('• national ID;'),
                Text('• driver\'s license;'),
                Text('• proof of address.'),
                SizedBox(height: 4),
                Text(
                  'Failure to complete verification may result in account limitations or suspension.',
                ),
                SizedBox(height: 12),
                Text('## 5. Cookies and Tracking Technologies'),
                SizedBox(height: 4),
                Text(
                  'We may use cookies, analytics tools, and similar technologies to:',
                ),
                Text('• improve platform performance;'),
                Text('• remember user preferences;'),
                Text('• analyze user activity;'),
                Text('• enhance security.'),
                SizedBox(height: 4),
                Text(
                  'Users may disable cookies through browser settings, though some features may not function properly.',
                ),
                SizedBox(height: 12),
                Text('## 6. Data Sharing and Disclosure'),
                SizedBox(height: 4),
                Text('We do not sell personal information to third parties.'),
                SizedBox(height: 4),
                Text('However, we may share information with:'),
                Text('• payment processors;'),
                Text('• cloud hosting providers;'),
                Text('• analytics providers;'),
                Text('• fraud prevention services;'),
                Text('• legal authorities where required by law;'),
                Text('• professional advisers and compliance partners.'),
                SizedBox(height: 4),
                Text(
                  'All third-party providers are required to maintain confidentiality and security standards.',
                ),
                SizedBox(height: 12),
                Text('## 7. Data Security'),
                SizedBox(height: 4),
                Text(
                  'We implement reasonable administrative, technical, and organizational measures to protect user information, including:',
                ),
                Text('• encryption;'),
                Text('• secure servers;'),
                Text('• access controls;'),
                Text('• authentication systems;'),
                Text('• monitoring tools.'),
                SizedBox(height: 4),
                Text(
                  'However, no online platform or electronic storage method can be guaranteed to be completely secure.',
                ),
                SizedBox(height: 12),
                Text('## 8. Data Retention'),
                SizedBox(height: 4),
                Text(
                  'We retain personal information for as long as necessary to:',
                ),
                Text('• provide Services;'),
                Text('• comply with legal obligations;'),
                Text('• resolve disputes;'),
                Text('• enforce agreements;'),
                Text('• maintain financial records.'),
                SizedBox(height: 4),
                Text(
                  'Retention periods may vary depending on regulatory requirements.',
                ),
                SizedBox(height: 12),
                Text('## 9. User Rights'),
                SizedBox(height: 4),
                Text(
                  'Depending on applicable laws, users may have the right to:',
                ),
                Text('• access personal information;'),
                Text('• request correction of inaccurate data;'),
                Text('• request deletion of personal data;'),
                Text('• object to processing;'),
                Text('• request data portability;'),
                Text('• withdraw consent where applicable.'),
                SizedBox(height: 4),
                Text('Requests may be submitted through our support channels.'),
                SizedBox(height: 12),
                Text('## 10. International Transfers'),
                SizedBox(height: 4),
                Text(
                  'User information may be transferred to and processed in countries outside the user\'s jurisdiction where our servers, providers, or partners operate.',
                ),
                SizedBox(height: 4),
                Text('By using the Services, users consent to such transfers.'),
                SizedBox(height: 12),
                Text('## 11. Third-Party Services'),
                SizedBox(height: 4),
                Text(
                  'Our platform may contain links or integrations with third-party services, including payment gateways and analytics providers.',
                ),
                SizedBox(height: 4),
                Text(
                  'We are not responsible for the privacy practices of external services or websites.',
                ),
                SizedBox(height: 4),
                Text(
                  'Users should review third-party privacy policies separately.',
                ),
                SizedBox(height: 12),
                Text('## 12. Children\'s Privacy'),
                SizedBox(height: 4),
                Text(
                  'Our Services are not intended for individuals under the age of 18.',
                ),
                SizedBox(height: 4),
                Text(
                  'We do not knowingly collect personal information from minors.',
                ),
                SizedBox(height: 4),
                Text(
                  'If we become aware of such collection, we will take appropriate steps to remove the information.',
                ),
                SizedBox(height: 12),
                Text('## 13. Fraud Prevention and Monitoring'),
                SizedBox(height: 4),
                Text('To protect users and the platform, we may monitor:'),
                Text('• login activity;'),
                Text('• IP addresses;'),
                Text('• device identifiers;'),
                Text('• transaction patterns;'),
                Text('• referral activities.'),
                SizedBox(height: 4),
                Text(
                  'Accounts suspected of fraud, abuse, or unauthorized activity may be restricted or suspended.',
                ),
                SizedBox(height: 12),
                Text('## 14. Changes to This Privacy Policy'),
                SizedBox(height: 4),
                Text(
                  'We reserve the right to update or modify this Privacy Policy at any time.',
                ),
                SizedBox(height: 4),
                Text(
                  'Changes become effective immediately upon posting on the Platform.',
                ),
                SizedBox(height: 4),
                Text(
                  'Continued use of the Services constitutes acceptance of the updated Privacy Policy.',
                ),
                SizedBox(height: 12),
                Text('## 15. Contact Information'),
                SizedBox(height: 4),
                Text('For privacy-related inquiries or requests, contact:'),
                Text('Support Email: support@cpbloomfx.com'),
                Text('Official Website: www.cpbloomfx.com'),
                SizedBox(height: 12),
                Text('## 16. Consent'),
                SizedBox(height: 4),
                Text(
                  'By creating an account or using our Services, you acknowledge that you have read, understood, and agreed to this Privacy Policy.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF58A6FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        content: SingleChildScrollView(
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  '# Terms of Service',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text('## 1. Acceptance of Terms'),
                SizedBox(height: 4),
                Text(
                  'By accessing or using the CP Bloom FX platform, mobile application, website, or related services ("Platform"), you agree to comply with and be legally bound by these Terms of Service ("Terms"). If you do not agree to these Terms, you must not use the Platform.',
                ),
                SizedBox(height: 12),
                Text('## 2. Eligibility'),
                SizedBox(height: 4),
                Text(
                  'You must be at least 18 years old and legally capable of entering into binding agreements in your jurisdiction to use the Platform.',
                ),
                SizedBox(height: 4),
                Text('By using the Platform, you represent and warrant that:'),
                SizedBox(height: 4),
                Text('• all information provided is accurate and complete;'),
                Text(
                  '• you are not prohibited from using financial or investment-related services under applicable laws;',
                ),
                Text('• you will use the Platform only for lawful purposes.'),
                SizedBox(height: 12),
                Text('## 3. Nature of Service'),
                SizedBox(height: 4),
                Text(
                  'CP Bloom FX provides a copy trading and automated trading technology platform that allows users to follow or copy trading strategies and activities from selected traders or automated systems.',
                ),
                SizedBox(height: 4),
                Text(
                  'The Platform does not guarantee profits, investment returns, or protection against losses.',
                ),
                SizedBox(height: 4),
                Text(
                  'Trading in financial markets involves significant risk, and users may lose part or all of their deposited funds.',
                ),
                SizedBox(height: 12),
                Text('## 4. No Financial Advice'),
                SizedBox(height: 4),
                Text('The Platform does not provide:'),
                Text('• financial advice;'),
                Text('• investment recommendations;'),
                Text('• tax advice;'),
                Text('• legal advice.'),
                SizedBox(height: 4),
                Text(
                  'All trading decisions are made solely at the user\'s own discretion and risk.',
                ),
                Text(
                  'Past performance of traders, strategies, or automated systems does not guarantee future results.',
                ),
                SizedBox(height: 12),
                Text('## 5. User Accounts'),
                SizedBox(height: 4),
                Text('Users are responsible for:'),
                Text(
                  '• maintaining the confidentiality of account credentials;',
                ),
                Text('• all activities conducted under their account;'),
                Text('• providing accurate registration information.'),
                SizedBox(height: 4),
                Text(
                  'The Platform reserves the right to suspend or terminate accounts suspected of:',
                ),
                Text('• fraud;'),
                Text('• abusive behavior;'),
                Text('• multiple account abuse;'),
                Text('• unauthorized access;'),
                Text('• money laundering activities;'),
                Text('• violation of these Terms.'),
                SizedBox(height: 12),
                Text('## 6. Deposits and Withdrawals'),
                SizedBox(height: 4),
                Text(
                  'Users may deposit and withdraw funds through approved payment methods available on the Platform.',
                ),
                SizedBox(height: 4),
                Text('The Platform reserves the right to:'),
                Text('• verify user identity before processing withdrawals;'),
                Text('• delay or reject suspicious transactions;'),
                Text(
                  '• impose withdrawal limits or security reviews where necessary.',
                ),
                SizedBox(height: 4),
                Text(
                  'Users are solely responsible for ensuring that payment information provided is correct.',
                ),
                SizedBox(height: 12),
                Text('## 7. Copy Trading Risks'),
                SizedBox(height: 4),
                Text(
                  'By participating in copy trading, users acknowledge and accept that:',
                ),
                Text('• copied trades may result in losses;'),
                Text('• market conditions can change rapidly;'),
                Text('• delays, slippage, or technical failures may occur;'),
                Text(
                  '• traders being copied may change strategies without notice.',
                ),
                SizedBox(height: 4),
                Text(
                  'The Platform is not responsible for financial losses arising from copied trades or automated trading activities.',
                ),
                SizedBox(height: 12),
                Text('## 8. Automated Trading Features'),
                SizedBox(height: 4),
                Text(
                  'Automated trading tools and AI-assisted systems are provided on an "as available" basis.',
                ),
                SizedBox(height: 4),
                Text('The Platform does not guarantee:'),
                Text('• uninterrupted service;'),
                Text('• profitable performance;'),
                Text('• continuous market availability;'),
                Text('• execution accuracy under all market conditions.'),
                SizedBox(height: 4),
                Text(
                  'Users understand that system interruptions, internet outages, market volatility, and technical errors may impact trading performance.',
                ),
                SizedBox(height: 12),
                Text('## 9. Referral and Reward Programs'),
                SizedBox(height: 4),
                Text(
                  'Referral commissions, bonuses, and rewards are subject to eligibility requirements and internal fraud prevention checks.',
                ),
                SizedBox(height: 4),
                Text('The Platform reserves the right to:'),
                Text('• modify reward structures;'),
                Text('• revoke fraudulent rewards;'),
                Text('• suspend accounts involved in abuse or manipulation.'),
                SizedBox(height: 12),
                Text('## 10. Prohibited Activities'),
                SizedBox(height: 4),
                Text('Users may not:'),
                Text('• engage in fraudulent activity;'),
                Text('• manipulate the Platform;'),
                Text('• exploit system vulnerabilities;'),
                Text('• create multiple unauthorized accounts;'),
                Text('• use stolen payment methods;'),
                Text('• interfere with platform operations;'),
                Text('• attempt unauthorized access to servers or databases.'),
                SizedBox(height: 4),
                Text(
                  'Violation may result in immediate account suspension or permanent termination.',
                ),
                SizedBox(height: 12),
                Text('## 11. Intellectual Property'),
                SizedBox(height: 4),
                Text(
                  'All Platform content, branding, software, graphics, trademarks, and systems are the exclusive property of CP Bloom FX and may not be copied, reproduced, or redistributed without written permission.',
                ),
                SizedBox(height: 12),
                Text('## 12. Limitation of Liability'),
                SizedBox(height: 4),
                Text(
                  'To the maximum extent permitted by law, CP Bloom FX and its operators shall not be liable for:',
                ),
                Text('• trading losses;'),
                Text('• indirect damages;'),
                Text('• loss of profits;'),
                Text('• loss of data;'),
                Text('• system downtime;'),
                Text('• delays or interruptions;'),
                Text('• third-party service failures.'),
                SizedBox(height: 4),
                Text('Users use the Platform entirely at their own risk.'),
                SizedBox(height: 12),
                Text('## 13. Account Suspension and Termination'),
                SizedBox(height: 4),
                Text(
                  'The Platform reserves the right to suspend, restrict, or terminate accounts at its sole discretion for:',
                ),
                Text('• Terms violations;'),
                Text('• suspicious activity;'),
                Text('• compliance obligations;'),
                Text('• security concerns.'),
                SizedBox(height: 12),
                Text('## 14. Privacy'),
                SizedBox(height: 4),
                Text(
                  'User information is collected and processed in accordance with the Platform\'s Privacy Policy.',
                ),
                SizedBox(height: 4),
                Text(
                  'By using the Platform, users consent to such collection and processing.',
                ),
                SizedBox(height: 12),
                Text('## 15. Changes to Terms'),
                SizedBox(height: 4),
                Text(
                  'The Platform may update or modify these Terms at any time without prior notice.',
                ),
                SizedBox(height: 4),
                Text(
                  'Continued use of the Platform after changes become effective constitutes acceptance of the updated Terms.',
                ),
                SizedBox(height: 12),
                Text('## 16. Governing Law'),
                SizedBox(height: 4),
                Text(
                  'These Terms shall be governed by and interpreted in accordance with applicable laws and regulations in the jurisdiction where the Platform operates.',
                ),
                SizedBox(height: 12),
                Text('## 17. Contact Information'),
                SizedBox(height: 4),
                Text('For support or legal inquiries, users may contact:'),
                Text('Support Email: support@cpbloomfx.com'),
                Text('Official Platform: www.cpbloomfx.com'),
                SizedBox(height: 12),
                Text('## 18. Risk Disclosure'),
                SizedBox(height: 4),
                Text(
                  'Trading foreign exchange, cryptocurrencies, CFDs, and other financial instruments carries a high level of risk and may not be suitable for all users.',
                ),
                SizedBox(height: 4),
                Text(
                  'Users should carefully consider their financial situation and risk tolerance before participating in trading activities.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF58A6FF)),
            ),
          ),
        ],
      ),
    );
  }
}
