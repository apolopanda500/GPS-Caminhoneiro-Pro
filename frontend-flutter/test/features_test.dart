import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

import 'package:gps_camioneiro_pro/data/models/map_marker_model.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/providers/marker_provider.dart';
import 'package:gps_camioneiro_pro/core/network/geocoding_service.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/fps_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapMarkerModel', () {
    test('toJson/fromJson round-trip', () {
      final m = MapMarkerModel(
        id: 'm1',
        emoji: '🚧',
        type: 'obra',
        label: 'Obra na pista',
        latitude: -23.55,
        longitude: -46.63,
        driverId: 'drv1',
      );
      final restored = MapMarkerModel.fromJson(m.toJson());
      expect(restored.id, 'm1');
      expect(restored.emoji, '🚧');
      expect(restored.type, 'obra');
      expect(restored.label, 'Obra na pista');
      expect(restored.latitude, closeTo(-23.55, 1e-9));
      expect(restored.longitude, closeTo(-46.63, 1e-9));
      expect(restored.driverId, 'drv1');
    });

    test('fromJson aplica defaults', () {
      final m = MapMarkerModel.fromJson({'id': 'x'});
      expect(m.emoji, '📍');
      expect(m.type, 'sinal');
      expect(m.latitude, 0);
      expect(m.createdAt, isA<DateTime>());
    });

    test('isExpired respeita o TTL', () {
      final novo = MapMarkerModel(
          id: 'a', emoji: '👋', type: 'sinal', latitude: 0, longitude: 0);
      expect(novo.isExpired(const Duration(hours: 1)), false);
      final antigo = MapMarkerModel(
        id: 'b',
        emoji: '👋',
        type: 'sinal',
        latitude: 0,
        longitude: 0,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      expect(antigo.isExpired(const Duration(hours: 1)), true);
    });

    test('copyWith altera apenas campos informados', () {
      final m = MapMarkerModel(
          id: 'a', emoji: '👋', type: 'sinal', latitude: 1, longitude: 2);
      final c = m.copyWith(emoji: '⚠️');
      expect(c.emoji, '⚠️');
      expect(c.id, 'a');
      expect(c.latitude, 1);
    });
  });

  group('MarkerProvider', () {
    test('place cria e adiciona marcador', () {
      final p = MarkerProvider(idGenerator: () => 'fixed', autoCleanup: false);
      final m = p.place(emoji: '☕', type: 'sinal', latitude: 10, longitude: 20);
      expect(p.markers.length, 1);
      expect(m.id, 'fixed');
      expect(p.markers.first.emoji, '☕');
    });

    test('purgeExpired remove sinais velhos', () {
      final p =
          MarkerProvider(autoCleanup: false, ttl: const Duration(hours: 1));
      p.addMarker(MapMarkerModel(
        id: 'velho',
        emoji: 'a',
        type: 'sinal',
        latitude: 0,
        longitude: 0,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ));
      p.addMarker(MapMarkerModel(
          id: 'novo', emoji: 'b', type: 'sinal', latitude: 0, longitude: 0));
      final removidos = p.purgeExpired();
      expect(removidos, 1);
      expect(p.markers.length, 1);
      expect(p.markers.first.id, 'novo');
    });

    test('addMarker insere no topo e notifica', () {
      final p = MarkerProvider(autoCleanup: false);
      var notified = 0;
      p.addListener(() => notified++);
      p.addMarker(MapMarkerModel(
          id: '1', emoji: 'a', type: 'sinal', latitude: 0, longitude: 0));
      p.addMarker(MapMarkerModel(
          id: '2', emoji: 'b', type: 'sinal', latitude: 0, longitude: 0));
      expect(p.markers.first.id, '2');
      expect(notified, 2);
    });

    test('removeMarker remove pelo id', () {
      final p = MarkerProvider(autoCleanup: false);
      p.addMarker(MapMarkerModel(
          id: '1', emoji: 'a', type: 'sinal', latitude: 0, longitude: 0));
      p.removeMarker('1');
      expect(p.markers, isEmpty);
    });

    test('withinRadius filtra por distância', () {
      final p = MarkerProvider(autoCleanup: false);
      p.addMarker(MapMarkerModel(
          id: 'perto', emoji: 'a', type: 'sinal', latitude: 0, longitude: 0));
      p.addMarker(MapMarkerModel(
          id: 'longe', emoji: 'b', type: 'sinal', latitude: 1, longitude: 1));
      final near = p.withinRadius(const LatLng(0, 0), 500);
      expect(near.map((m) => m.id), contains('perto'));
      expect(near.map((m) => m.id), isNot(contains('longe')));
    });

    test('metersBetween e bearing calculam valores plausíveis', () {
      final d =
          MarkerProvider.metersBetween(const LatLng(0, 0), const LatLng(0, 1));
      expect(d, greaterThan(110000));
      expect(d, lessThan(112000));
      final b = MarkerProvider.bearing(const LatLng(0, 0), const LatLng(0, 1));
      expect(b, closeTo(90, 1));
    });
  });

  group('SettingsProvider', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults corretos', () {
      final s = SettingsProvider();
      expect(s.showFps, false);
      expect(s.targetFps, 60);
      expect(s.layer, MapLayerMode.satellite);
      expect(s.gpsIntervalSeconds, 1);
      expect(s.highAccuracy, true);
      expect(s.isLoaded, false);
    });

    test('load lê valores persistidos', () async {
      SharedPreferences.setMockInitialValues({
        'settings.showFps': true,
        'settings.targetFps': 120,
        'settings.layer': 1,
        'settings.gpsInterval': 5,
        'settings.highAccuracy': false,
      });
      final s = SettingsProvider();
      await s.load();
      expect(s.showFps, true);
      expect(s.targetFps, 120);
      expect(s.layer, MapLayerMode.streets);
      expect(s.gpsIntervalSeconds, 5);
      expect(s.highAccuracy, false);
      expect(s.isLoaded, true);
    });

    test('setters persistem e notificam', () async {
      final s = SettingsProvider();
      await s.load();
      var notified = 0;
      s.addListener(() => notified++);
      await s.setShowFps(true);
      await s.setTargetFps(120);
      await s.setLayer(MapLayerMode.streets);
      await s.setGpsInterval(10);
      await s.setHighAccuracy(false);
      expect(notified, 5);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings.showFps'), true);
      expect(prefs.getInt('settings.targetFps'), 120);
      expect(prefs.getInt('settings.gpsInterval'), 10);
    });

    test('setTargetFps ignora valores não suportados', () async {
      final s = SettingsProvider();
      await s.setTargetFps(999);
      expect(s.targetFps, 60);
    });

    test('setGpsInterval valida faixa', () async {
      final s = SettingsProvider();
      await s.setGpsInterval(0);
      expect(s.gpsIntervalSeconds, 1);
      await s.setGpsInterval(999);
      expect(s.gpsIntervalSeconds, 1);
    });
  });

  group('GeoResult', () {
    test('fromJson parseia lat/lon string', () {
      final g = GeoResult.fromJson(
          {'display_name': 'Av. Paulista', 'lat': '-23.56', 'lon': '-46.65'});
      expect(g.displayName, 'Av. Paulista');
      expect(g.latitude, closeTo(-23.56, 1e-9));
      expect(g.longitude, closeTo(-46.65, 1e-9));
    });
  });

  group('FpsOverlay', () {
    testWidgets('renderiza sem erro', (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: FpsOverlay(targetFps: 60))));
      await tester.pump();
      expect(find.byType(FpsOverlay), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
