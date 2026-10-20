import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';

class ConvoyGroup {
  final String id;
  final String name;
  final String ownerDriverId;
  final bool isPublic;
  final String myRole;

  const ConvoyGroup({
    required this.id,
    required this.name,
    required this.ownerDriverId,
    required this.isPublic,
    this.myRole = 'member',
  });

  bool get isOwner => myRole == 'owner';

  factory ConvoyGroup.fromJson(Map<String, dynamic> json, String myId) {
    final roles = (json['my_role'] ?? json['myRole'] ?? '').toString();
    return ConvoyGroup(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Grupo').toString(),
      ownerDriverId: (json['owner_driver_id'] ?? json['ownerDriverId'] ?? '')
          .toString(),
      isPublic: (json['is_public'] ?? json['isPublic'] ?? true) == true,
      myRole: roles.isNotEmpty
          ? roles
          : (json['owner_driver_id'] == myId ? 'owner' : 'member'),
    );
  }
}

class GroupMember {
  final String driverId;
  final String name;
  final String role;
  final String truckIcon;

  const GroupMember({
    required this.driverId,
    required this.name,
    this.role = 'member',
    this.truckIcon = '🚚',
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        driverId: (json['driverId'] ?? json['driver_id'] ?? '').toString(),
        name: (json['name'] ?? 'Motorista').toString(),
        role: (json['role'] ?? 'member').toString(),
        truckIcon: (json['truckIcon'] ?? json['truck_icon'] ?? '🚚').toString(),
      );
}

/// Grupos (comboios) via REST /api/groups com token de sessão.
/// Modo estrito: ver apenas os caminhões dos grupos a que pertenco.
class GroupProvider extends ChangeNotifier {
  final List<ConvoyGroup> _mine = [];
  final List<ConvoyGroup> _public = [];
  final Map<String, List<GroupMember>> _members = {};
  bool _estricto = false;
  bool _loading = false;
  String? _error;

  List<ConvoyGroup> get mine => List.unmodifiable(_mine);
  List<ConvoyGroup> get public => List.unmodifiable(_public);
  List<GroupMember> membersOf(String groupId) =>
      List.unmodifiable(_members[groupId] ?? const []);
  Set<String> get memberIds => {
        for (final list in _members.values) ...list.map((m) => m.driverId),
      };
  bool get estrito => _estricto;
  bool get loading => _loading;
  String? get error => _error;

  bool get temGrupos => _mine.isNotEmpty;

  GroupProvider() {
    _loadEstrito();
  }

  Future<SharedPreferences?> _prefsSeguro() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadEstrito() async {
    final prefs = await _prefsSeguro();
    if (prefs == null) return;
    _estricto = prefs.getBool('groups.estrito.v1') ?? false;
    notifyListeners();
  }

  Future<void> setEstrito(bool v) async {
    _estricto = v;
    notifyListeners();
    final prefs = await _prefsSeguro();
    await prefs?.setBool('groups.estrito.v1', v);
  }

  Uri _url(String path) => Uri.parse('${AppConstants.baseUrl}/api/groups$path');

  Map<String, String> _headers(Map<String, String> auth) => auth;

  /// Lista meus grupos e os públicos (visíveis para pedir entrada).
  Future<void> load({
    required String driverId,
    required Map<String, String> auth,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final resp = await http
          .get(_url('/'), headers: _headers(auth))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final list = jsonDecode(resp.body);
      _mine.clear();
      _public.clear();
      if (list is List) {
        for (final g in list) {
          if (g is! Map<String, dynamic>) continue;
          final grupo = ConvoyGroup.fromJson(g, driverId);
          _mine.add(grupo);
          _public.add(grupo);
        }
      }
      _error = null;
    } catch (_) {
      _error = 'Não foi possível carregar grupos (offline?).';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Cria grupo e entra como dono.
  Future<bool> create({
    required String name,
    required String driverId,
    required Map<String, String> auth,
  }) async {
    try {
      final resp = await http.post(
        _url('/'),
        headers: _headers(auth),
        body: jsonEncode({'name': name, 'driverId': driverId}),
      ).timeout(const Duration(seconds: 10));
      final ok = resp.statusCode == 201 || resp.statusCode == 200;
      if (ok) await load(driverId: driverId, auth: auth);
      return ok;
    } catch (_) {
      _error = 'Falha ao criar grupo (offline?).';
      notifyListeners();
      return false;
    }
  }

  Future<bool> join({
    required String groupId,
    required String driverId,
    required Map<String, String> auth,
  }) async {
    try {
      final resp = await http.post(
        _url('/$groupId/join'),
        headers: _headers(auth),
        body: jsonEncode({'driverId': driverId}),
      ).timeout(const Duration(seconds: 10));
      final ok = resp.statusCode == 200 || resp.statusCode == 201;
      if (ok) await load(driverId: driverId, auth: auth);
      return ok;
    } catch (_) {
      _error = 'Falha ao entrar no grupo (offline?).';
      notifyListeners();
      return false;
    }
  }

  Future<bool> leave({
    required String groupId,
    required String driverId,
    required Map<String, String> auth,
  }) async {
    try {
      final resp = await http.post(
        _url('/$groupId/leave'),
        headers: _headers(auth),
        body: jsonEncode({'driverId': driverId}),
      ).timeout(const Duration(seconds: 10));
      final ok = resp.statusCode == 200 || resp.statusCode == 201;
      if (ok) {
        _members.remove(groupId);
        await load(driverId: driverId, auth: auth);
      }
      return ok;
    } catch (_) {
      _error = 'Falha ao sair do grupo (offline?).';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadMembers({
    required String groupId,
    required Map<String, String> auth,
  }) async {
    try {
      final resp = await http
          .get(_url('/$groupId/members'), headers: _headers(auth))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;
      final body = jsonDecode(resp.body);
      final list = body is List ? body : (body['members'] as List?);
      _members[groupId] = [
        if (list != null)
          for (final m in list)
            if (m is Map<String, dynamic>) GroupMember.fromJson(m),
      ];
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _error = null;
    super.dispose();
  }
}
