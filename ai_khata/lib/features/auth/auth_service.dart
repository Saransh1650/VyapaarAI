import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';

class AuthService extends ChangeNotifier {
  String? _token;
  String? _userName;
  String? _storeId;
  String? _storeType;
  bool _onboardingComplete = false;

  bool get isLoggedIn => _token != null;
  bool get onboardingComplete => _onboardingComplete;
  String? get storeId => _storeId;
  String? get storeType => _storeType;
  String? get userName => _userName;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _userName = prefs.getString('user_name');
    _storeId = prefs.getString('store_id');
    _storeType = prefs.getString('store_type');
    _onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    notifyListeners();
  }

  Future<void> register(String name, String password) async {
    final dio = ApiClient.instance.dio;
    await dio.post(
      '/auth/register',
      data: {'name': name, 'password': password},
    );
  }

  Future<void> login(String name, String password) async {
    final dio = ApiClient.instance.dio;
    final res = await dio.post(
      '/auth/login',
      data: {'name': name, 'password': password},
    );
    final data = res.data;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', data['token']);
    await prefs.setString('refresh_token', data['refreshToken']);
    await prefs.setString('user_id', data['user']['id']);
    await prefs.setString('user_name', data['user']['name']);
    _token = data['token'];
    _userName = data['user']['name'];
    notifyListeners();
  }

  Future<void> completeOnboarding(Map<String, dynamic> store) async {
    final prefs = await SharedPreferences.getInstance();
    final dio = ApiClient.instance.dio;
    final res = await dio.post('/stores/setup', data: store);
    final storeData = res.data['store'];
    await prefs.setString('store_id', storeData['id']);
    await prefs.setString('store_type', storeData['type']);
    await prefs.setBool('onboarding_complete', true);
    _storeId = storeData['id'];
    _storeType = storeData['type'];
    _onboardingComplete = true;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _token = null;
    _userName = null;
    _storeId = null;
    _storeType = null;
    _onboardingComplete = false;
    notifyListeners();
  }
}
