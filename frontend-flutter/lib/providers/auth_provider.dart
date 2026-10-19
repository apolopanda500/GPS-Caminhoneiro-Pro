import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gps_camioneiro_pro/data/models/driver_model.dart';
import 'package:gps_camioneiro_pro/core/network/socket_client.dart';
import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';

class AuthProvider extends ChangeNotifier {
  static const String _kSession = 'session.driver';

  DriverModel? _driver;
  bool _isLoading = false;
  String? _error;

  DriverModel? get driver => _driver;
  bool get isAuthenticated => _driver != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSession);
      if (raw == null) return;
      _driver = DriverModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _connectSocket();
      notifyListeners();
    } catch (_) {
      // Sessão corrompida: ignora e começa deslogado.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final d = _driver;
      if (d == null) {
        await prefs.remove(_kSession);
      } else {
        await prefs.setString(_kSession, jsonEncode(d.toJson()));
      }
    } catch (_) {}
  }

  void _connectSocket() {
    if (!AppConstants.serverConfigured) return;
    final d = _driver;
    if (d == null) return;
    SocketClient().connectToServer(
      driverId: d.driverId,
      isPremium: d.isPremium,
      name: d.name ?? 'Motorista',
      truckIcon: d.truckIcon,
    );
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Tenta autenticar no back-end. Se o servidor não estiver configurado ou
    // falhar por rede, cria sessão local para permitir uso offline/avaliação.
    if (AppConstants.serverConfigured) {
      try {
        final resp = await http
            .post(
              Uri.parse('${AppConstants.baseUrl}/api/auth/login'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'email': email, 'password': password}),
            )
            .timeout(const Duration(seconds: 8));

        if (resp.statusCode == 200) {
          _driver = DriverModel.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
          _isLoading = false;
          _connectSocket();
          await _persist();
          notifyListeners();
          return true;
        }
        if (resp.statusCode == 401) {
          _error = 'E-mail ou senha inválidos.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } catch (_) {
        // Sem conexão: segue para sessão local.
      }
    }

    _driver = DriverModel(
      driverId: 'drv_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: email.isNotEmpty ? email.split('@').first : 'Motorista',
      isPremium: false,
    );
    _isLoading = false;
    _connectSocket();
    await _persist();
    notifyListeners();
    return true;
  }

  Future<bool> register({
    required String email,
    required String password,
    String? name,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (AppConstants.serverConfigured) {
      try {
        final resp = await http
            .post(
              Uri.parse('${AppConstants.baseUrl}/api/auth/register'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'email': email, 'password': password, 'name': name}),
            )
            .timeout(const Duration(seconds: 8));

        if (resp.statusCode == 201) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          _driver = DriverModel(
            driverId: body['driverId'] ?? 'drv_${DateTime.now().millisecondsSinceEpoch}',
            email: email,
            name: name ?? body['name'],
            isPremium: false,
          );
          _isLoading = false;
          _connectSocket();
          await _persist();
          notifyListeners();
          return true;
        }
        if (resp.statusCode == 400) {
          _error = 'E-mail já cadastrado.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } catch (_) {
        // Sem conexão: cria sessão local.
      }
    }

    _driver = DriverModel(
      driverId: 'drv_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: (name != null && name.isNotEmpty)
          ? name
          : (email.isNotEmpty ? email.split('@').first : 'Motorista'),
      isPremium: false,
    );
    _isLoading = false;
    _connectSocket();
    await _persist();
    notifyListeners();
    return true;
  }

  void setDriver(DriverModel driver) {
    _driver = driver;
    _connectSocket();
    _persist();
    notifyListeners();
  }

  void logout() {
    _driver = null;
    SocketClient().disconnect();
    _persist();
    notifyListeners();
  }
}
