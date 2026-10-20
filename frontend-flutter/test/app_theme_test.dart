import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('tema escuro usa superficies escuras e vermelho', () {
      expect(appTheme.brightness, Brightness.dark);
      expect(appTheme.scaffoldBackgroundColor, kDarkBlack);
      expect(appTheme.colorScheme.primary, kEmergencyRed);
      expect(appTheme.snackBarTheme.backgroundColor, kDarkRedTransition);
    });

    test('tema claro usa superficies claras e mesmo vermelho', () {
      expect(appLightTheme.brightness, Brightness.light);
      expect(appLightTheme.scaffoldBackgroundColor, kLightBackground);
      expect(appLightTheme.colorScheme.primary, kEmergencyRed);
      expect(appLightTheme.textButtonTheme.style, isNotNull);
    });

    testWidgets('overlaySurface adapta ao brilho', (tester) async {
      const Color branco = Color(0xF2FFFFFF);
      const Color escuro = Color(0xE6101418);

      await tester.pumpWidget(
        MaterialApp(
          theme: appLightTheme,
          home: Builder(
            builder: (context) => Container(color: overlaySurface(context)),
          ),
        ),
      );
      var container = tester.widget<Container>(find.byType(Container));
      expect((container.color!.toARGB32() & 0x00FFFFFF).toDouble(),
          closeTo(branco.computeLuminance(), 0.001));

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Builder(
            builder: (context) => Container(color: overlaySurface(context)),
          ),
        ),
      );
      container = tester.widget<Container>(find.byType(Container));
      expect((container.color!.toARGB32() & 0x00FFFFFF).toDouble(),
          closeTo(escuro.computeLuminance(), 0.001));
    });

    testWidgets('overlayText/overlayTextMuted mudam com tema', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appLightTheme,
          home: Builder(
            builder: (context) {
              expect(overlayText(context), kLightInk);
              expect(overlayTextMuted(context), kLightInk);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Builder(
            builder: (context) {
              expect(overlayText(context), Colors.white);
              expect(overlayTextMuted(context), Colors.white70);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });
}
