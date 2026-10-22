import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/alert_provider.dart';
import 'package:gps_camioneiro_pro/providers/navigation_provider.dart';
import 'package:gps_camioneiro_pro/data/models/alert_model.dart';
import 'package:gps_camioneiro_pro/data/models/driver_model.dart';
import 'package:gps_camioneiro_pro/data/models/truck_config.dart';

void main() {
  group('AuthProvider (modo offline)', () {
    test('estado inicial deslogado', () {
      final a = AuthProvider();
      expect(a.isAuthenticated, isFalse);
      expect(a.driver, isNull);
      expect(a.isLoading, isFalse);
      expect(a.error, isNull);
    });

    test('login offline autentica e cria driver local', () async {
      final a = AuthProvider();
      var notified = 0;
      a.addListener(() => notified++);

      final ok =
          await a.login(email: 'motorista@teste.com', password: '123456');

      expect(ok, isTrue);
      expect(a.isAuthenticated, isTrue);
      expect(a.driver, isNotNull);
      expect(a.driver!.email, 'motorista@teste.com');
      expect(a.driver!.name, 'motorista');
      expect(a.isLoading, isFalse);
      expect(notified, greaterThanOrEqualTo(2));
    });

    test('login sem email gera nome padrão "Motorista"', () async {
      final a = AuthProvider();
      await a.login(email: '', password: 'x');
      expect(a.driver!.name, 'Motorista');
    });

    test('setDriver define driver e notifica', () {
      final a = AuthProvider();
      var notified = 0;
      a.addListener(() => notified++);
      a.setDriver(DriverModel(driverId: 'z', email: 'z@z.com', name: 'Zé'));
      expect(a.isAuthenticated, isTrue);
      expect(a.driver!.name, 'Zé');
      expect(notified, 1);
    });

    test('logout limpa sessão', () async {
      final a = AuthProvider();
      await a.login(email: 'a@b.com', password: '1');
      a.logout();
      expect(a.isAuthenticated, isFalse);
      expect(a.driver, isNull);
    });

    test('register offline autentica e cria driver', () async {
      final a = AuthProvider();
      final ok = await a.register(
          email: 'novo@teste.com', password: 'abc', name: 'Novo Motorista');
      expect(ok, isTrue);
      expect(a.isAuthenticated, isTrue);
      expect(a.driver!.name, 'Novo Motorista');
    });

    test('register sem nome usa prefixo do e-mail', () async {
      final a = AuthProvider();
      await a.register(email: 'joao@teste.com', password: 'x');
      expect(a.driver!.name, 'joao');
    });

    test('login normaliza o e-mail (trim + minúsculas)', () async {
      final a = AuthProvider();
      await a.login(email: '  Motorista@Teste.COM ', password: '123456');
      expect(a.driver!.email, 'motorista@teste.com');
      expect(a.driver!.name, 'motorista');
    });

    test('register normaliza o e-mail', () async {
      final a = AuthProvider();
      await a.register(email: ' Novo@Teste.COM ', password: '123456');
      expect(a.driver!.email, 'novo@teste.com');
    });
  });

  group('AlertProvider', () {
    AlertModel sample(String id) => AlertModel(
          id: id,
          driverId: 'd',
          type: 'radar',
          latitude: 0,
          longitude: 0,
          createdAt: DateTime.now(),
        );

    test('addAlert insere no topo e notifica', () {
      final p = AlertProvider();
      var notified = 0;
      p.addListener(() => notified++);
      p.addAlert(sample('1'));
      p.addAlert(sample('2'));
      expect(p.alerts.first.id, '2');
      expect(p.alerts.length, 2);
      expect(notified, 2);
    });

    test('setAlerts substitui a lista', () {
      final p = AlertProvider();
      p.addAlert(sample('1'));
      p.setAlerts([sample('a'), sample('b')]);
      expect(p.alerts.map((e) => e.id), ['a', 'b']);
    });

    test('clearAlerts esvazia', () {
      final p = AlertProvider();
      p.addAlert(sample('1'));
      p.clearAlerts();
      expect(p.alerts, isEmpty);
    });

    test('alerts é imutável externamente', () {
      final p = AlertProvider();
      final list = p.alerts;
      expect(() => list.add(sample('x')), throwsUnsupportedError);
    });
  });

  group('NavigationProvider', () {
    test('inicia parado', () {
      final n = NavigationProvider();
      expect(n.isNavigating, isFalse);
      expect(n.truckConfig, isNull);
      expect(n.currentRoute, '');
    });

    test('setTruckConfig e navegação', () {
      final n = NavigationProvider();
      n.setTruckConfig(TruckConfig(
          driverId: 'd', height: 4, width: 2, length: 10, weight: 20));
      expect(n.truckConfig, isNotNull);
      n.startNavigation('SP-330 → Campinas');
      expect(n.isNavigating, isTrue);
      expect(n.currentRoute, 'SP-330 → Campinas');
      n.stopNavigation();
      expect(n.isNavigating, isFalse);
      expect(n.currentRoute, '');
    });
  });
}
