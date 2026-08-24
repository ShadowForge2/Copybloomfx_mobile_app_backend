import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bloomfx_shared/bloomfx_shared.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/support_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/register_screen.dart';
import 'screens/username_setup_screen.dart';
import 'screens/support_chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize(supabaseUrl, supabaseAnonKey);

  final authProvider = AuthProvider(baseUrl: apiBaseUrl);
  await authProvider.checkAuthStatus();

  final themeProvider = ThemeProvider();
  final languageProvider = LanguageProvider();
  await Future.wait([
    themeProvider.initialize(),
    languageProvider.initialize(),
  ]);

  await NotificationService.instance.init();
  await BackgroundService.register();

  runApp(
    MyApp(
      authProvider: authProvider,
      themeProvider: themeProvider,
      languageProvider: languageProvider,
    ),
  );
}

const String apiBaseUrl = 'https://copybloomfx-mobile-app-backend-nb7f.onrender.com';
const String supabaseUrl = 'https://mefbzfgwogvmsgttlffp.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1lZmJ6Zmd3b2d2bXNndHRsZmZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3MTU4NTksImV4cCI6MjA5NDI5MTg1OX0.az5I7mJLSxASIvmqRquvXqLF2fBZC9sCm2SOmkQCCwI';

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  final ThemeProvider themeProvider;
  final LanguageProvider languageProvider;

  const MyApp({
    super.key,
    required this.authProvider,
    required this.themeProvider,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/username-setup',
          builder: (context, state) {
            final data = state.extra as Map<String, dynamic>?;
            return UsernameSetupScreen(
              firstName: data?['firstName'] ?? '',
              lastName: data?['lastName'] ?? '',
              email: data?['email'] ?? '',
              password: data?['password'] ?? '',
              referralCode: data?['referralCode'] ?? '',
            );
          },
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const MainNavigationScreen(),
        ),
        GoRoute(
          path: '/support-chat',
          builder: (context, state) => const SupportChatScreen(),
        ),
      ],
      redirect: (context, state) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final loggedIn = auth.isAuthenticated;
        final onAuthPages =
            state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/username-setup';

        if (!loggedIn && !onAuthPages && state.matchedLocation != '/') {
          return '/login';
        }
        if (loggedIn && onAuthPages) {
          return '/dashboard';
        }
        return null;
      },
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider(
          create: (context) =>
              DashboardProvider(ApiService(baseUrl: apiBaseUrl)),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              NotificationProvider(ApiService(baseUrl: apiBaseUrl)),
        ),
        ChangeNotifierProvider(
          create: (context) => SupportProvider(baseUrl: apiBaseUrl),
        ),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, langProvider, _) {
          return MaterialApp.router(
            title: 'CPBloomFX',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            locale: langProvider.locale,
            supportedLocales: const [
              Locale('en'),
              Locale('pt'),
              Locale('zh'),
              Locale('ja'),
              Locale('hi'),
            ],
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            localeResolutionCallback: (locale, supportedLocales) {
              if (locale == null) return const Locale('en');
              for (final supported in supportedLocales) {
                if (supported.languageCode == locale.languageCode) {
                  return supported;
                }
              }
              return const Locale('en');
            },
            routerConfig: router,
          );
        },
      ),
    );
  }
}
