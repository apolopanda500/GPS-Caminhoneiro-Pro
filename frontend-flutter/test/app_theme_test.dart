import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';

int rgb(Color c) => c.toARGB32() & 0xFFFFFF;

const _key = Key('surfaceBox');

void main() {
  group('AppTheme', () {
    test('tema escuro usa superficies escuras e a cor escolhida', () {
      final tema = appTheme();
      expect(tema.brightness, Brightness.dark);
      expect(tema.scaffoldBackgroundColor, kDarkBlack);
      expect(tema.colorScheme.primary, kEmergencyRed);
      expect(tema.snackBarTheme.backgroundColor, isNotNull);
    });

    test('tema claro usa superficies claras e a cor escolhida', () {
      final tema = appLightTheme();
      expect(tema.brightness, Brightness.light);
      expect(tema.scaffoldBackgroundColor, kLightBackground);
      expect(tema.colorScheme.primary, kEmergencyRed);
      expect(tema.textButtonTheme.style, isNotNull);
    });

    test('a cor do usuario vale para todo o tema', () {
      const azul = Color(0xFF1D4ED8);
      final escuro = appTheme(accent: azul);
      final claro = appLightTheme(accent: azul);
      expect(escuro.colorScheme.primary, azul);
      expect(claro.colorScheme.primary, azul);
      expect(escuro.floatingActionButtonTheme.backgroundColor, azul);
      expect(claro.floatingActionButtonTheme.backgroundColor, azul);
      expect(
        escuro.elevatedButtonTheme.style?.backgroundColor?.resolve({}),
        azul,
      );
    });

    testWidgets('overlaySurface claro e branca translúcida', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appLightTheme(),
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
      // No tema claro a superficie e um branco quente (nao branco puro):
      // o branco puro brigava com o fundo do app.
      expect(rgb(container.color!), rgb(kLightSurface));
      expect(container.color!.a, greaterThan(0));
    });

    testWidgets('overlaySurface escura e preta translúcida', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
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
      expect(rgb(container.color!), 0x1F0808);
    });

    testWidgets('overlayText claro usa tinta escura', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appLightTheme(),
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
          theme: appTheme(),
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
