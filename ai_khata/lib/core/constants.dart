import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

  // Route names
  static const String routeLogin = '/login';
  static const String routeOnboardingType = '/onboarding/type';
  static const String routeOnboardingDetails = '/onboarding/details';
  static const String routeOnboardingDone = '/onboarding/done';
  static const String routeDashboard = '/dashboard';
  static const String routeBillScanner = '/dashboard/bills/scan';
  static const String routeBillManual = '/dashboard/bills/manual';
  static const String routeAdvice = '/dashboard/advice';
  static const String routeInventory = '/dashboard/inventory';
  static const String routeBills = '/dashboard/bills';
  static const String routeRecords = '/dashboard/records';
}
