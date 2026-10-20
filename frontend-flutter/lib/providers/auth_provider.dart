import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gps_camioneiro_pro/data/models/driver_model.dart';
import 'package:gps_camioneiro_pro/core/network/socket_client.dart';
import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';

class AuthProvider extends ChangeNotifier {
  static const String _kSession = 'session.driver';
  static const String _kToken = 'session.token';

  DriverModel? _driver;
  bool _isLoading = false;
  String? _error;
  String? _pendingEmail;
  bool _requiresVerification = false;
  String? _token;
  final Completer<void> _pronto = Completer<void>();

  /// Completa quando a sessao salva foi lida do armazenamento.
  /// A splash AGUARDA isso antes de decidir para onde ir (evita pedir login
  /// toda vez que o app abre).
  Future<void> get pronto => _pronto.future;

  DriverModel? get driver => _driver;
  bool get isAuthenticated => _driver != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get pendingEmail => _pendingEmail;
  bool get requiresVerification => _requiresVerification;

  /// Token de sessao (Bearer) devolvido pelo back-end.
  String? get token => _token;

  /// Headers de autenticacao para as chamadas REST.
  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kToken);
      final raw = prefs.getString(_kSession);
      if (raw != null) {
        _driver = DriverModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        _connectSocket();
        notifyListeners();
      }
    } catch (_) {
      // Sessão corrompida: ignora e começa deslogado.
    } finally {
      if (!_pronto.isCompleted) _pronto.complete();
    }
  }

  /// Garante que a sessao salva foi lida (usado pela splash).
  /// Nunca bloqueia para sempre: se o armazenamento demorar, segue o fluxo.
  Future<void> ensureLoaded() async {
    if (_pronto.isCompleted) return;
    await Future.any<void>([
      _pronto.future,
      Future<void>.delayed(const Duration(seconds: 2)),
    ]);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final d = _driver;
      if (d == null) {
        await prefs.remove(_kSession);
        await prefs.remove(_kToken);
      } else {
        await prefs.setString(_kSession, jsonEncode(d.toJson()));
        if (_token != null) {
          await prefs.setString(_kToken, _token!);
        }
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
      token: _token,
    );
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final emailLimpo = email.trim().toLowerCase();

    // Tenta autenticar no back-end. Se o servidor não estiver configurado ou
    // falhar por rede, cria sessão local para permitir uso offline/avaliação.
    if (AppConstants.serverConfigured) {
      try {
        final resp = await http
            .post(
              Uri.parse('${AppConstants.baseUrl}/api/auth/login'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'email': emailLimpo, 'password': password}),
            )
            .timeout(const Duration(seconds: 8));

        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          _driver = DriverModel.fromJson(
              jsonDecode(resp.body) as Map<String, dynamic>);
          _token = body['token']?.toString() ?? _token;
          _isLoading = false;
          _connectSocket();
          await _persist();
          notifyListeners();
          return true;
        }
        if (resp.statusCode == 403) {
          _pendingEmail = emailLimpo;
          _requiresVerification = true;
          _error = 'Confirme sua conta com o código enviado por e-mail.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        // Erro do servidor (401/400/5xx): mostra a mensagem real.
        _error = _erroDaResposta(resp) ?? 'Não foi possível entrar. Tente novamente.';
        _isLoading = false;
        notifyListeners();
        return false;
      } catch (_) {
        // Sem conexão: segue para sessão local.
      }
    }

    _requiresVerification = false;
    _pendingEmail = null;
    _driver = DriverModel(
      driverId: 'drv_${DateTime.now().millisecondsSinceEpoch}',
      email: emailLimpo,
      name: emailLimpo.isNotEmpty ? emailLimpo.split('@').first : 'Motorista',
      isPremium: false,
    );
    _isLoading = false;
    _connectSocket();
    await _persist();
    notifyListeners();
    return true;
  }

  /// Extrai a mensagem de erro do corpo da resposta (campo "error").
  String? _erroDaResposta(http.Response resp) {
    try {
      final body = jsonDecode(resp.body);
      if (body is Map<String, dynamic>) {
        final erro = body['error'];
        if (erro is String && erro.isNotEmpty) return erro;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> register({
    required String email,
    required String password,
    String? name,
    String role = 'motorista',
    String? helpType,
    String? truckIcon,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final emailLimpo = email.trim().toLowerCase();

    if (AppConstants.serverConfigured) {
      try {
        final resp = await http
            .post(
              Uri.parse('${AppConstants.baseUrl}/api/auth/register'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': emailLimpo,
                'password': password,
                'name': name,
                'role': role,
                'helpType': helpType,
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (resp.statusCode == 201) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          if (body['requiresVerification'] == true) {
            _pendingEmail = emailLimpo;
            _requiresVerification = true;
            _error = null;
            _isLoading = false;
            notifyListeners();
            return true;
          }
          _driver = DriverModel(
            driverId: body['driverId'] ??
                'drv_${DateTime.now().millisecondsSinceEpoch}',
            email: emailLimpo,
            name: name ?? body['name'],
            isPremium: false,
            role: (body['role'] ?? role).toString(),
            helpType: body['helpType'] ?? helpType,
            truckIcon: truckIcon ?? '🚚',
          );
          _token = body['token']?.toString() ?? _token;
          _isLoading = false;
          _connectSocket();
          await _persist();
          notifyListeners();
          return true;
        }
        // Erro do servidor: mostra a mensagem real (não cria sessão local).
        _error = _erroDaResposta(resp) ??
            'Não foi possível criar a conta. Tente novamente.';
        _isLoading = false;
        notifyListeners();
        return false;
      } catch (_) {
        // Sem conexão: cria sessão local.
      }
    }

    _requiresVerification = false;
    _pendingEmail = null;
    _driver = DriverModel(
      driverId: 'drv_${DateTime.now().millisecondsSinceEpoch}',
      email: emailLimpo,
      name: (name != null && name.isNotEmpty)
          ? name
          : (emailLimpo.isNotEmpty ? emailLimpo.split('@').first : 'Motorista'),
      isPremium: false,
      role: role,
      helpType: helpType,
      truckIcon: truckIcon ?? '🚚',
    );
    _isLoading = false;
    _connectSocket();
    await _persist();
    notifyListeners();
    return true;
  }

  Future<bool> verifyCode({required String email, required String code}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    if (!AppConstants.serverConfigured) {
      _error = 'Servidor não configurado para validar o código.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
    try {
      final resp = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/auth/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'code': code,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        _driver = DriverModel.fromJson({...body, 'email': email});
        _token = body['token']?.toString() ?? _token;
        _requiresVerification = false;
        _pendingEmail = null;
        _isLoading = false;
        _connectSocket();
        await _persist();
        notifyListeners();
        return true;
      }
      _error = (jsonDecode(resp.body) as Map<String, dynamic>)['error'] ??
          'Código inválido ou expirado.';
    } catch (_) {
      _error = 'Sem conexão para validar o código.';
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> resendCode(String email) async {
    if (!AppConstants.serverConfigured) return false;
    try {
      final resp = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/auth/resend'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Pede o envio do codigo de redefinicao de senha.
  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    if (!AppConstants.serverConfigured) {
      _error = 'Servidor não configurado para recuperar a senha.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
    try {
      final resp = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/auth/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = _erroDaResposta(resp) ??
          'Não foi possível enviar o código de recuperação.';
    } catch (_) {
      _error = 'Sem conexão para solicitar a recuperação de senha.';
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Confirma o codigo e define a nova senha.
  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    if (!AppConstants.serverConfigured) {
      _error = 'Servidor não configurado para redefinir a senha.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
    try {
      final resp = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/auth/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'code': code.trim(),
              'password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = _erroDaResposta(resp) ?? 'Código inválido ou expirado.';
    } catch (_) {
      _error = 'Sem conexão para redefinir a senha.';
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Envia foto pessoal (avatar) ou foto do caminhao como dataURL base64.
  /// [dataUrl] já vem pronto (ex.: `data:image/jpeg;base64,...`).
  Future<bool> uploadPhotoUrl({
    required String dataUrl,
    String kind = 'avatar',
  }) async {
    final d = _driver;
    if (d == null) return false;
    _driver = DriverModel(
      driverId: d.driverId,
      email: d.email,
      name: d.name,
      isPremium: d.isPremium,
      truckHeight: d.truckHeight,
      truckWeight: d.truckWeight,
      axleCount: d.axleCount,
      hazmat: d.hazmat,
      avatarUrl: kind == 'truck' ? d.avatarUrl : dataUrl,
      truckPhotoUrl: kind == 'truck' ? dataUrl : d.truckPhotoUrl,
      truckModel: d.truckModel,
      cargoType: d.cargoType,
      truckIcon: d.truckIcon,
      role: d.role,
      helpType: d.helpType,
      companyName: d.companyName,
      companyLat: d.companyLat,
      companyLon: d.companyLon,
    );
    await _persist();
    notifyListeners();
    if (!AppConstants.serverConfigured) return true;
    try {
      final resp = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/auth/photo'),
            headers: authHeaders,
            body: jsonEncode({'data': dataUrl, 'kind': kind}),
          )
          .timeout(const Duration(seconds: 15));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Atualiza o perfil no servidor (empresa, modelo, foto, etc).
  /// Define o papel do usuario (motorista/ajudante) e o tipo de ajuda.
  Future<bool> definirPapel({
    required String role,
    String? helpType,
    String? truckIcon,
  }) async {
    final d = _driver;
    if (d == null) return false;
    _driver = DriverModel(
      driverId: d.driverId,
      email: d.email,
      name: d.name,
      isPremium: d.isPremium,
      truckHeight: d.truckHeight,
      truckWeight: d.truckWeight,
      axleCount: d.axleCount,
      hazmat: d.hazmat,
      avatarUrl: d.avatarUrl,
      truckPhotoUrl: d.truckPhotoUrl,
      truckModel: d.truckModel,
      cargoType: d.cargoType,
      truckIcon: truckIcon ?? d.truckIcon,
      role: role,
      helpType: helpType ?? d.helpType,
      companyName: d.companyName,
      companyLat: d.companyLat,
      companyLon: d.companyLon,
    );
    await _persist();
    notifyListeners();
    return true;
  }

  Future<bool> updateProfile({
    String? name,
    String? truckModel,
    String? cargoType,
    String? companyName,
    double? companyLat,
    double? companyLon,
  }) async {
    final d = _driver;
    if (d == null) return false;
    if (!AppConstants.serverConfigured) {
      _driver = DriverModel(
        driverId: d.driverId,
        email: d.email,
        name: name ?? d.name,
        isPremium: d.isPremium,
        truckHeight: d.truckHeight,
        truckWeight: d.truckWeight,
        axleCount: d.axleCount,
        hazmat: d.hazmat,
        avatarUrl: d.avatarUrl,
        truckPhotoUrl: d.truckPhotoUrl,
        truckModel: truckModel ?? d.truckModel,
        cargoType: cargoType ?? d.cargoType,
        truckIcon: d.truckIcon,
        role: d.role,
        helpType: d.helpType,
        companyName: companyName ?? d.companyName,
        companyLat: companyLat ?? d.companyLat,
        companyLon: companyLon ?? d.companyLon,
      );
      await _persist();
      notifyListeners();
      return true;
    }
    try {
      final resp = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/auth/profile'),
            headers: authHeaders,
            body: jsonEncode({
              'name': name,
              'truckModel': truckModel,
              'cargoType': cargoType,
              'companyName': companyName,
              'companyLat': companyLat,
              'companyLon': companyLon,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return false;
      _driver = DriverModel(
        driverId: d.driverId,
        email: d.email,
        name: name ?? d.name,
        isPremium: d.isPremium,
        truckHeight: d.truckHeight,
        truckWeight: d.truckWeight,
        axleCount: d.axleCount,
        hazmat: d.hazmat,
        avatarUrl: d.avatarUrl,
        truckPhotoUrl: d.truckPhotoUrl,
        truckModel: truckModel ?? d.truckModel,
        cargoType: cargoType ?? d.cargoType,
        truckIcon: d.truckIcon,
        role: d.role,
        helpType: d.helpType,
        companyName: companyName ?? d.companyName,
        companyLat: companyLat ?? d.companyLat,
        companyLon: companyLon ?? d.companyLon,
      );
      await _persist();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
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
