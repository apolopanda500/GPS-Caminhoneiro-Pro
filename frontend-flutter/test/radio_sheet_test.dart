import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/radio_sheet.dart';

Map<String, dynamic> _estacao(String nome, {String uuid = 'u1'}) => {
      'name': nome,
      'url': 'https://exemplo.com/$nome.mp3',
      'url_resolved': 'https://exemplo.com/$nome.mp3',
      'stationuuid': uuid,
      'tags': 'pop',
      'bitrate': 128,
      'votes': 3,
      'clickcount': 9,
      'state': 'Sao Paulo',
    };

RadioService _servico(List<Map<String, dynamic>> itens, {int status = 200}) {
  return RadioService(
    cliente: MockClient((req) async {
      if (status != 200) return http.Response('erro', status);
      return http.Response(jsonEncode(itens), 200);
    }),
  );
}

Widget _app(AudioProvider audio, Widget child) {
  return ChangeNotifierProvider<AudioProvider>.value(
    value: audio,
    child: MaterialApp(
      theme: appTheme(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('mostra o cabecalho e o campo de busca', (tester) async {
    final audio = AudioProvider(servico: _servico([_estacao('Radio Nova')]));
    await tester.pumpWidget(_app(audio, const RadioSheet()));
    await tester.pump();

    expect(find.text('Radio do caminhoneiro'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('lista as estacoes retornadas pela API', (tester) async {
    final audio = AudioProvider(
      servico: _servico([_estacao('Radio Nova'), _estacao('Radio Old')]),
    );
    await tester.pumpWidget(_app(audio, const RadioSheet()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Radio Nova'), findsOneWidget);
    expect(find.text('Radio Old'), findsOneWidget);
  });

  testWidgets('filtra a lista pelo texto digitado', (tester) async {
    final audio = AudioProvider(
      servico: _servico([_estacao('Radio Nova'), _estacao('Radio Old')]),
    );
    await tester.pumpWidget(_app(audio, const RadioSheet()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField), 'nova');
    await tester.pump();

    expect(find.text('Radio Nova'), findsOneWidget);
    expect(find.text('Radio Old'), findsNothing);
  });

  testWidgets('mostra estado de erro quando a API falha', (tester) async {
    final audio = AudioProvider(servico: _servico([], status: 500));
    await tester.pumpWidget(_app(audio, const RadioSheet()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Sem conexao com o radio'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('mostra aviso quando nao ha estacoes', (tester) async {
    final audio = AudioProvider(servico: _servico([]));
    await tester.pumpWidget(_app(audio, const RadioSheet()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Nenhuma estacao encontrada'), findsOneWidget);
  });

  testWidgets('permite favoritar uma estacao da lista', (tester) async {
    final audio = AudioProvider(servico: _servico([_estacao('Radio Nova')]));
    await tester.pumpWidget(_app(audio, const RadioSheet()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byIcon(Icons.star_border), findsOneWidget);
    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pump();

    expect(audio.favoritos.length, 1);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });
}
