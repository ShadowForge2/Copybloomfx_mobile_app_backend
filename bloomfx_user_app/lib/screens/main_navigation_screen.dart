import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../services/news_generator.dart';
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

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final ValueNotifier<int> _activeIndex = ValueNotifier<int>(0);
  int _unreadNewsCount = 0;
  bool _permissionsRequested = false;
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
    _refreshUnreadCount();
    _unreadTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshUnreadCount());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.user?.id != null) {
        context.read<ThemeProvider>().setUserId(auth.user!.id);
      }
      context.read<NotificationProvider>().startPolling();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unreadTimer?.cancel();
    _activeIndex.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshUnreadCount();
    }
  }

  Future<void> _refreshUnreadCount() async {
    final count = await NewsStorage.unreadCount();
    if (!mounted) return;
    setState(() => _unreadNewsCount = count);
  }

  Future<void> _onTabSelected(int index) async {
    setState(() => _currentIndex = index);
    _activeIndex.value = index;
    if (index == 1) {
      await NewsStorage.markViewed();
      _refreshUnreadCount();
    }
  }

  Future<void> _requestPermissions() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;
    await [
      Permission.notification,
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
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  DashboardScreen(activeIndex: _activeIndex),
                  const NewsScreen(),
                  const FinanceScreen(),
                  const ProfileScreen(),
                  const ReferralScreen(),
                  const SettingsScreen(),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: c.cardBg,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabSelected,
              backgroundColor: c.cardBg,
              selectedItemColor: c.accentBlue,
              unselectedItemColor: c.textSecondary,
              type: BottomNavigationBarType.fixed,
              items: items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return BottomNavigationBarItem(
                  icon: idx == 1 && _unreadNewsCount > 0
                      ? Badge(
                          label: Text(_unreadNewsCount > 9 ? '9+' : '$_unreadNewsCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          child: Icon(item.icon),
                        )
                      : Icon(item.icon),
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
