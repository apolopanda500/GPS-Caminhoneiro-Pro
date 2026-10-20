import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/premium/premium_policy.dart';
import 'package:gps_camioneiro_pro/data/models/driver_model.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';

void main() {
  group('PremiumPolicy plano Free', () {
    test('mapa e rotas ficam liberados no Free', () {
      expect(PremiumPolicy.freeHasMap, isTrue);
      expect(PremiumPolicy.freeHasRoutes, isTrue);
    });

    test('promo ativa (antes de 29/11/2026) libera recursos no Free', () {
      final antes = DateTime(2026, 10, 19);
      expect(PremiumPolicy.promoActive(antes), isTrue);
      for (final feature in PremiumPolicy.features) {
        expect(PremiumPolicy.isLocked(feature, isPremium: false, now: antes),
            isFalse,
            reason: feature.name);
        expect(
            PremiumPolicy.canUse(feature, isPremium: false, now: antes),
            isTrue,
            reason: feature.name);
      }
    });

    test('após 29/11/2026 recursos ficam bloqueados no Free', () {
      final depois = DateTime(2026, 11, 30);
      expect(PremiumPolicy.promoActive(depois), isFalse);
      for (final feature in PremiumPolicy.features) {
        expect(
            PremiumPolicy.isLocked(feature, isPremium: false, now: depois),
            isTrue,
            reason: feature.name);
        expect(
            PremiumPolicy.canUse(feature, isPremium: false, now: depois),
            isFalse,
            reason: feature.name);
      }
    });

    test('todos os recursos ficam liberados no Premium', () {
      for (final feature in PremiumPolicy.features) {
        expect(PremiumPolicy.isLocked(feature, isPremium: true), isFalse,
            reason: feature.name);
        expect(PremiumPolicy.canUse(feature, isPremium: true), isTrue,
            reason: feature.name);
      }
      expect(PremiumPolicy.lockedFor(isPremium: true), isEmpty);
    });

    test('rótulos dos recursos não ficam vazios', () {
      for (final feature in PremiumPolicy.features) {
        expect(feature.label.trim(), isNotEmpty);
      }
    });
  });

  group('DriverModel plano Premium', () {
    test('isPremium sobrevive ao round-trip de JSON', () {
      final driver = DriverModel(
        driverId: 'drv_premium',
        email: 'premium@teste.com',
        name: 'Premium',
        isPremium: true,
      );
      final restored = DriverModel.fromJson(driver.toJson());
      expect(restored.isPremium, isTrue);
      expect(restored.driverId, 'drv_premium');
    });

    test('novo motorista começa no plano Free', () {
      final driver = DriverModel(driverId: 'drv_free', email: 'free@teste.com');
      expect(driver.isPremium, isFalse);
    });
  });

  group('AuthProvider verificação por código', () {
    test('verifyCode sem servidor retorna false e explica o motivo', () async {
      final auth = AuthProvider();
      final ok =
          await auth.verifyCode(email: 'teste@teste.com', code: '123456');
      expect(ok, isFalse);
      expect(auth.error, contains('Servidor'));
      expect(auth.isLoading, isFalse);
    });

    test('resendCode sem servidor retorna false', () async {
      final auth = AuthProvider();
      expect(await auth.resendCode('teste@teste.com'), isFalse);
    });

    test('estado inicial não pede verificação', () {
      final auth = AuthProvider();
      expect(auth.requiresVerification, isFalse);
      expect(auth.pendingEmail, isNull);
    });
  });

  group('SettingsProvider camada detalhada', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('camada detalhada (3D) persiste entre sessões', () async {
      final s = SettingsProvider();
      await s.setLayer(MapLayerMode.detailed);
      expect(s.layer, MapLayerMode.detailed);

      final s2 = SettingsProvider();
      await s2.load();
      expect(s2.layer, MapLayerMode.detailed);
    });

    test('alterna satélite, ruas e detalhada sem perder o valor', () async {
      final s = SettingsProvider();
      for (final mode in MapLayerMode.values) {
        await s.setLayer(mode);
        expect(s.layer, mode);
      }
    });
  });
}
