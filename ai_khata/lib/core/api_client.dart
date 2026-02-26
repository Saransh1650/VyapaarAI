import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;

  // Bare Dio used ONLY for the refresh call — no interceptors, no retry loop.
  late final Dio _refreshDio;

  // Guard: ensures only one refresh attempt is in-flight at a time.
  bool _isRefreshing = false;

  ApiClient._() {
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (err, handler) async {
          final statusCode = err.response?.statusCode;
          final path = err.requestOptions.path;

          // Skip refresh logic if:
          // - status is not 401
          // - the failing request IS the refresh endpoint (prevents recursion)
          // - a refresh is already in-flight
          if (statusCode != 401 ||
              path.contains('/auth/refresh') ||
              _isRefreshing) {
            return handler.next(err);
          }

          final prefs = await SharedPreferences.getInstance();
          final refreshToken = prefs.getString('refresh_token');

          if (refreshToken == null) {
            return handler.next(err);
          }

          _isRefreshing = true;
          try {
            // Use the bare _refreshDio — no interceptors, so 401 here won't loop.
            final res = await _refreshDio.post(
              '/auth/refresh',
              data: {'refreshToken': refreshToken},
            );
            final newToken = res.data['token'] as String;
            await prefs.setString('auth_token', newToken);

            // Retry the original request with the new token.
            err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            return handler.resolve(await _dio.fetch(err.requestOptions));
          } catch (_) {
            // Refresh failed — clear all stored credentials and force re-login.
            await prefs.remove('auth_token');
            await prefs.remove('refresh_token');
            await prefs.remove('user_id');
            await prefs.remove('user_name');
            await prefs.remove('store_id');
            await prefs.remove('store_type');
            await prefs.remove('onboarding_complete');
            handler.next(err);
          } finally {
            _isRefreshing = false;
          }
        },
      ),
    );
  }

  static ApiClient get instance => _instance ??= ApiClient._();
  Dio get dio => _dio;
}
