import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camioneiro_pro/data/models/alert_model.dart';
import 'package:gps_camioneiro_pro/data/models/driver_model.dart';
import 'package:gps_camioneiro_pro/data/models/truck_config.dart';

void main() {
  group('AlertModel', () {
    test('fromJson mapeia campos canônicos', () {
      final now = DateTime.now();
      final a = AlertModel.fromJson({
        'id': 'a1',
        'driverId': 'd1',
        'type': 'radar',
        'message': 'Radar 60km/h',
        'maxHeight': 4.2,
        'maxWeight': 30.0,
        'latitude': -23.5,
        'longitude': -46.6,
        'timestamp': now.millisecondsSinceEpoch,
      });

      expect(a.id, 'a1');
      expect(a.driverId, 'd1');
      expect(a.type, 'radar');
      expect(a.message, 'Radar 60km/h');
      expect(a.maxHeight, 4.2);
      expect(a.maxWeight, 30.0);
      expect(a.latitude, -23.5);
      expect(a.longitude, -46.6);
      expect(a.createdAt.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });

    test('fromJson aceita aliases lat/lon e driver_id', () {
      final a = AlertModel.fromJson({
        'id': 'a2',
        'driver_id': 'd2',
        'lat': -10,
        'lon': -20,
      });

      expect(a.driverId, 'd2');
      expect(a.latitude, -10);
      expect(a.longitude, -20);
      expect(a.type, 'texto_livre');
    });

    test('fromJson tolera ausência de campos (defaults)', () {
      final a = AlertModel.fromJson({});
      expect(a.id, '');
      expect(a.driverId, '');
      expect(a.latitude, 0);
      expect(a.longitude, 0);
    });

    test('toJson/fromJson é round-trip estável', () {
      final a = AlertModel(
        id: 'x',
        driverId: 'y',
        type: 'perigo',
        message: 'buracos',
        latitude: 1.23,
        longitude: 4.56,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );
      final b = AlertModel.fromJson(a.toJson());
      expect(b.id, a.id);
      expect(b.driverId, a.driverId);
      expect(b.type, a.type);
      expect(b.message, a.message);
      expect(b.latitude, a.latitude);
      expect(b.longitude, a.longitude);
      expect(b.createdAt.millisecondsSinceEpoch,
          a.createdAt.millisecondsSinceEpoch);
    });

    test('fromJson le created_at em ISO da varredura SQL', () {
      final a = AlertModel.fromJson({
        'id': 's1',
        'alert_type': 'radar',
        'lat': -23.5,
        'lon': -46.6,
        'created_at': '2026-10-20T02:00:00.000Z',
      });
      expect(a.id, 's1');
      expect(a.type, 'radar');
      expect(a.createdAt.year, 2026);
      expect(a.createdAt.month, 10);
    });

    test('fromJson le created_at como epoch em string', () {
      final a = AlertModel.fromJson({
        'id': 's2',
        'created_at': '1000',
      });
      expect(a.createdAt.millisecondsSinceEpoch, 1000);
    });
  });

  group('TruckConfig', () {
    test('defaults corretos', () {
      final t = TruckConfig(
          driverId: 'd', height: 4.4, width: 2.5, length: 13.5, weight: 45);
      expect(t.axleCount, 2);
      expect(t.hazmat, false);
    });

    test('fromJson aplica defaults quando vazio', () {
      final t = TruckConfig.fromJson({'driverId': 'd'});
      expect(t.height, 4.40);
      expect(t.width, 2.50);
      expect(t.length, 13.50);
      expect(t.weight, 45.00);
      expect(t.axleCount, 2);
      expect(t.hazmat, false);
    });

    test('toJson/fromJson round-trip', () {
      final t = TruckConfig(
        driverId: 'd',
        height: 4.1,
        width: 2.4,
        length: 12.0,
        weight: 40,
        axleCount: 5,
        hazmat: true,
      );
      final r = TruckConfig.fromJson(t.toJson());
      expect(r.axleCount, 5);
      expect(r.hazmat, true);
      expect(r.height, 4.1);
    });
  });

  group('DriverModel', () {
    test('defaults aplicados', () {
      final d = DriverModel(driverId: 'd', email: 'e@e.com');
      expect(d.isPremium, false);
      expect(d.truckHeight, 4.40);
      expect(d.truckWeight, 45.00);
      expect(d.axleCount, 2);
      expect(d.hazmat, false);
    });

    test('fromJson aceita snake_case', () {
      final d = DriverModel.fromJson({
        'driver_id': 'abc',
        'email': 'x@y.com',
        'is_premium': true,
        'truck_height': 4.0,
        'axle_count': 3,
      });
      expect(d.driverId, 'abc');
      expect(d.isPremium, true);
      expect(d.truckHeight, 4.0);
      expect(d.axleCount, 3);
    });

    test('toJson/fromJson round-trip', () {
      final d = DriverModel(
        driverId: 'id1',
        email: 'motorista@teste.com',
        name: 'João',
        isPremium: true,
        truckHeight: 4.2,
        axleCount: 6,
        hazmat: true,
        truckModel: 'Volvo FH',
        cargoType: 'Grãos',
      );
      final r = DriverModel.fromJson(d.toJson());
      expect(r.email, d.email);
      expect(r.name, d.name);
      expect(r.truckModel, d.truckModel);
      expect(r.cargoType, d.cargoType);
      expect(r.axleCount, 6);
    });
  });
}
