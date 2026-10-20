import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gps_camioneiro_pro/views/premium/payment_gate.dart';

void main() {
  group('PaymentGateScreen', () {
    Future<void> bombear(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PaymentGateScreen(driverId: 't1')),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renderiza beneficios e planos mensal e anual', (tester) async {
      await bombear(tester);
      expect(find.text('Plano Premium Pro'), findsOneWidget);
      expect(find.text('DESBLOQUEIE O PODER MÁXIMO'), findsOneWidget);
      expect(find.byIcon(Icons.campaign), findsOneWidget);
      expect(find.text('Anual'), findsOneWidget);
      expect(find.text('Mensal'), findsOneWidget);
      expect(find.textContaining('R\$ 4,99'), findsWidgets);
      expect(find.textContaining('R\$ 29,99'), findsWidgets);
    });

    testWidgets('seleciona plano anual e muda destaque', (tester) async {
      await bombear(tester);
      await tester.ensureVisible(find.text('Anual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anual'));
      await tester.pumpAndSettle();
      final botao = find.textContaining('GERAR PIX');
      expect(botao, findsOneWidget);
      final texto = tester.widget<Text>(botao).data ?? '';
      expect(texto, contains('ANUAL'));
      expect(texto, contains('29,99'));
    });

    testWidgets('sem servidor mostra erro ao gerar PIX', (tester) async {
      await bombear(tester);
      await tester.ensureVisible(find.textContaining('GERAR PIX'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('GERAR PIX'));
      await tester.pumpAndSettle();
      expect(find.textContaining('não configurado'), findsWidgets);
    });
  });
}
