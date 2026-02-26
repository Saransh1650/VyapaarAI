import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;

  ApiClient._() {
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
          if (err.response?.statusCode == 401) {
            // Try refresh
            final prefs = await SharedPreferences.getInstance();
            final refreshToken = prefs.getString('refresh_token');
            if (refreshToken != null) {
              try {
                final res = await _dio.post(
                  '/auth/refresh',
                  data: {'refreshToken': refreshToken},
                );
                final newToken = res.data['token'];
                await prefs.setString('auth_token', newToken);
                err.requestOptions.headers['Authorization'] =
                    'Bearer $newToken';
                return handler.resolve(await _dio.fetch(err.requestOptions));
              } catch (_) {}
            }
          }
          handler.next(err);
        },
      ),
    );
  }

  static ApiClient get instance => _instance ??= ApiClient._();
  Dio get dio => _dio;
}
