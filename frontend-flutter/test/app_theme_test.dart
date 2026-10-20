import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';

int rgb(Color c) => c.toARGB32() & 0xFFFFFF;

const _key = Key('surfaceBox');

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

    testWidgets('overlaySurface claro e branca translúcida', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appLightTheme,
          home: Builder(
            builder: (context) => Container(
              key: _key,
              color: overlaySurface(context),
            ),
          ),
        ),
      );
      await tester.pump();
      final container = tester.widget<Container>(find.byKey(_key));
      expect(rgb(container.color!), 0xFFFFFF);
    });

    testWidgets('overlaySurface escura e preta translúcida', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Builder(
            builder: (context) => Container(
              key: _key,
              color: overlaySurface(context),
            ),
          ),
        ),
      );
      await tester.pump();
      final container = tester.widget<Container>(find.byKey(_key));
      expect(rgb(container.color!), 0x101418);
    });

    testWidgets('overlayText claro usa tinta escura', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appLightTheme,
          home: Builder(
            builder: (context) {
              expect(rgb(overlayText(context)), rgb(kLightInk));
              expect(rgb(overlayTextMuted(context)), rgb(kLightInk));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
    });

    testWidgets('overlayText escuro usa branco', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Builder(
            builder: (context) {
              expect(rgb(overlayText(context)), 0xFFFFFF);
              expect(rgb(overlayTextMuted(context)), rgb(Colors.white70));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
    });
  });
}
