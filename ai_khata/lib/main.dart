import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/onboarding/onboarding_screens.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/bills/bills_screens.dart';
import 'features/ledger/ledger_screen.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/insights/insights_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const AiKhataApp());
}

class AiKhataApp extends StatelessWidget {
  const AiKhataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService()..loadFromPrefs(),
      child: Consumer<AuthService>(
        builder: (_, auth, __) => MaterialApp.router(
          title: 'AI Khata',
          theme: AppTheme.dark,
          debugShowCheckedModeBanner: false,
          routerConfig: _buildRouter(auth),
        ),
      ),
    );
  }
}

GoRouter _buildRouter(AuthService auth) => GoRouter(
  initialLocation: AppConstants.routeLogin,
  redirect: (context, state) {
    final loggedIn = auth.isLoggedIn;
    final onboarded = auth.onboardingComplete;
    final loc = state.matchedLocation;

    if (!loggedIn && loc != AppConstants.routeLogin)
      return AppConstants.routeLogin;
    if (loggedIn && !onboarded && !loc.startsWith('/onboarding'))
      return AppConstants.routeOnboardingType;
    if (loggedIn && onboarded && loc == AppConstants.routeLogin)
      return AppConstants.routeDashboard;
    return null;
  },
  routes: [
    // Auth
    GoRoute(
      path: AppConstants.routeLogin,
      builder: (_, __) => const LoginScreen(),
    ),

    // Onboarding
    GoRoute(
      path: AppConstants.routeOnboardingType,
      builder: (_, __) => const StoreTypeScreen(),
    ),
    GoRoute(
      path: AppConstants.routeOnboardingDetails,
      builder: (_, state) =>
          StoreDetailsScreen(storeType: state.extra as String? ?? 'general'),
    ),
    GoRoute(
      path: AppConstants.routeOnboardingDone,
      builder: (_, __) => const OnboardingDoneScreen(),
    ),

    // Standalone screens (outside shell)
    GoRoute(
      path: AppConstants.routeBillScanner,
      builder: (_, __) => const BillScannerScreen(),
    ),
    GoRoute(
      path: AppConstants.routeBillManual,
      builder: (_, __) => const BillManualEntryScreen(),
    ),

    // Dashboard shell with nested tabs
    ShellRoute(
      builder: (_, __, child) => DashboardScreen(child: child),
      routes: [
        GoRoute(
          path: AppConstants.routeDashboard,
          builder: (_, __) => const SizedBox(),
        ),
        GoRoute(
          path: '/dashboard/bills',
          builder: (_, __) => const BillsScreen(),
        ),
        GoRoute(
          path: '/dashboard/ledger',
          builder: (_, __) => const LedgerScreen(),
        ),
        GoRoute(
          path: '/dashboard/analytics',
          builder: (_, __) => const AnalyticsScreen(),
        ),
        GoRoute(
          path: '/dashboard/insights',
          builder: (_, __) => const InsightsScreen(),
        ),
      ],
    ),
  ],
);
