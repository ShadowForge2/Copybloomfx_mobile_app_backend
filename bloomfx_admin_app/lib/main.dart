import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';
import 'providers/admin_auth_provider.dart';
import 'providers/admin_user_provider.dart';
import 'providers/admin_deposit_provider.dart';
import 'providers/admin_withdrawal_provider.dart';
import 'providers/admin_promo_provider.dart';
import 'providers/admin_notification_provider.dart';
import 'providers/admin_dashboard_provider.dart';
import 'providers/admin_support_provider.dart';
import 'services/admin_notification_service.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize(supabaseUrl, supabaseAnonKey);

  final adminAuthProvider = AdminAuthProvider(baseUrl: apiBaseUrl);
  await adminAuthProvider.checkAuthStatus();

  await AdminNotificationService.instance.init();
  runApp(MyApp(adminAuthProvider: adminAuthProvider));
}

const String apiBaseUrl = 'https://copybloomfx-mobile-app-backend-dmgy.onrender.com';
const String supabaseUrl = 'https://mefbzfgwogvmsgttlffp.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1lZmJ6Zmd3b2d2bXNndHRsZmZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3MTU4NTksImV4cCI6MjA5NDI5MTg1OX0.az5I7mJLSxASIvmqRquvXqLF2fBZC9sCm2SOmkQCCwI';

class MyApp extends StatelessWidget {
  final AdminAuthProvider adminAuthProvider;

  const MyApp({super.key, required this.adminAuthProvider});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/admin/login',
      refreshListenable: adminAuthProvider,
      routes: [
        GoRoute(
          path: '/admin/login',
          builder: (context, state) => const AdminLoginScreen(),
        ),
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
      ],
      redirect: (context, state) {
        final auth = Provider.of<AdminAuthProvider>(context, listen: false);
        final loggedIn = auth.isAuthenticated;
        final onLogin = state.matchedLocation == '/admin/login';

        if (!loggedIn && !onLogin) {
          return '/admin/login';
        }
        if (loggedIn && onLogin) {
          return '/admin/dashboard';
        }
        return null;
      },
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AdminAuthProvider>.value(
          value: adminAuthProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => AdminUserProvider(baseUrl: apiBaseUrl),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminDepositProvider(baseUrl: apiBaseUrl),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminWithdrawalProvider(baseUrl: apiBaseUrl),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminPromoProvider(baseUrl: apiBaseUrl),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminNotificationProvider(baseUrl: apiBaseUrl),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminDashboardProvider(baseUrl: apiBaseUrl),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminSupportProvider(baseUrl: apiBaseUrl),
        ),
      ],
      child: MaterialApp.router(
        title: 'BloomFX Admin App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E3A8A),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0D1117),
          navigationBarTheme: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith(
              (_) => const TextStyle(color: Colors.white, fontSize: 11),
            ),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected))
                return const IconThemeData(color: Colors.white);
              return const IconThemeData(color: Colors.white54);
            }),
          ),
        ),
        routerConfig: router,
      ),
    );
  }
}
