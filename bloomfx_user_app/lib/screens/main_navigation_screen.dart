import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import 'dashboard_screen.dart';
import 'finance_screen.dart';
import 'news_screen.dart';
import 'profile_screen.dart';
import 'referral_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _permissionsRequested = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.user?.id != null) {
        context.read<ThemeProvider>().setUserId(auth.user!.id);
      }
    });
  }

  Future<void> _requestPermissions() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;
    await [
      Permission.notification,
      Permission.camera,
    ].request();
  }

  List<NavigationItem> _navigationItems(BuildContext context) {
    final tr = context.read<LanguageProvider>();
    return [
      NavigationItem(icon: Icons.dashboard, label: tr.tr('nav.dashboard'), route: '/dashboard'),
      NavigationItem(icon: Icons.newspaper, label: tr.tr('nav.news'), route: '/news'),
      NavigationItem(icon: Icons.account_balance_wallet, label: tr.tr('nav.finance'), route: '/finance'),
      NavigationItem(icon: Icons.person, label: tr.tr('nav.profile'), route: '/profile'),
      NavigationItem(icon: Icons.share, label: tr.tr('nav.referrals'), route: '/referral'),
      NavigationItem(icon: Icons.settings, label: tr.tr('nav.settings'), route: '/settings'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _navigationItems(context);
    return Consumer2<AuthProvider, ThemeProvider>(
      builder: (context, authProvider, themeProvider, child) {
        final c = themeProvider.colors;
        if (authProvider.user == null) {
          return Scaffold(
            backgroundColor: c.scaffoldBg,
            body: const Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        return Scaffold(
          backgroundColor: c.scaffoldBg,
          body: IndexedStack(
            index: _currentIndex,
            children: const [
              DashboardScreen(),
              NewsScreen(),
              FinanceScreen(),
              ProfileScreen(),
              ReferralScreen(),
              SettingsScreen(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: c.cardBg,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: c.cardBg,
              selectedItemColor: c.accentBlue,
              unselectedItemColor: c.textSecondary,
              type: BottomNavigationBarType.fixed,
              items: items.map((item) {
                return BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  label: item.label,
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final String route;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
