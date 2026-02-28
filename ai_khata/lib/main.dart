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
import 'features/insights/insights_screen.dart';
import 'features/stocks/stock_screen.dart';
import 'features/stocks/order_list_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const AiKhataApp());
}

class AiKhataApp extends StatelessWidget {
  const AiKhataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..loadFromPrefs()),
        // OrderListProvider gets its storeId from AuthService so the list
        // loads from the backend as soon as the user is authenticated.
        ChangeNotifierProxyProvider<AuthService, OrderListProvider>(
          create: (_) => OrderListProvider(),
          update: (_, auth, previous) {
            previous!.setStoreId(auth.storeId);
            return previous;
          },
        ),
      ],
      child: Consumer<AuthService>(
        builder: (_, auth, __) => MaterialApp.router(
          title: 'VyapaarAI',
          theme: AppTheme.light,
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

    if (!loggedIn && loc != AppConstants.routeLogin) {
      return AppConstants.routeLogin;
    }
    if (loggedIn && !onboarded && !loc.startsWith('/onboarding')) {
      return AppConstants.routeOnboardingType;
    }
    if (loggedIn && onboarded && loc == AppConstants.routeLogin) {
      return AppConstants.routeDashboard;
    }
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

    // Dashboard shell — 3 tabs: Home | Smart Advice | Inventory
    ShellRoute(
      builder: (_, __, child) => DashboardScreen(child: child),
      routes: [
        // Home tab (index 0) — rendered inside DashboardScreen._buildHomeContent()
        GoRoute(
          path: AppConstants.routeDashboard,
          builder: (_, __) => const SizedBox.shrink(),
        ),

        // Smart Advice tab (index 1)
        GoRoute(
          path: '/dashboard/advice',
          builder: (_, __) => const InsightsScreen(),
        ),

        // Inventory tab (index 2)
        GoRoute(
          path: '/dashboard/inventory',
          builder: (_, __) => const StockScreen(),
        ),

        // Bills — secondary screen (no nav tab, accessible from Home FAB)
        GoRoute(
          path: '/dashboard/bills',
          builder: (_, __) => const BillsScreen(),
        ),

        // Records — secondary screen (accessible from Home quick action)
        GoRoute(
          path: '/dashboard/records',
          builder: (_, __) => const LedgerScreen(),
        ),

        // Scanner — inside shell so nav bar stays
        GoRoute(
          path: AppConstants.routeBillScanner,
          builder: (_, __) => const BillScannerScreen(),
        ),

        // Manual entry — inside shell so nav bar stays
        GoRoute(
          path: AppConstants.routeBillManual,
          builder: (_, __) => const BillManualEntryScreen(),
        ),
      ],
    ),
  ],
);
