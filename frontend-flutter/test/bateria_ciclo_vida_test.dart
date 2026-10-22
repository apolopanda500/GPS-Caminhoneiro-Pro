import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gps_camioneiro_pro/core/audio/falas.dart';
import 'package:gps_camioneiro_pro/core/audio/som_da_parada.dart';
import 'package:gps_camioneiro_pro/core/audio/sons_provider.dart';
import 'package:gps_camioneiro_pro/providers/shared_routes_provider.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';

/// =============================================================================
/// BATERIA DO CICULO DE VIDA DO GPS (no app)
/// =============================================================================
/// Cobre o que o motorista vive: a voz que fala, os sons das paradas, a
/// escolha de quais rotas compartilhadas ver e o acompanhamento ao vivo.
/// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Ciclo de vida: a voz que fala (perfis)', () {
    test('Padrão: resumido, sem encher linguiça', () {
      final f = Falas.proximaParada(
        perfil: PerfilVoz.padrao,
        numero: 3,
        distanciaKm: 2.4,
      );
      expect(f, contains('3'));
      expect(f.length, lessThan(60), reason: 'fala longa demais: $f');
      expect(f.toLowerCase(), isNot(contains('quilometros')));
    });

    test('Waze: bem curto ("Próxima: 3")', () {
      final f = Falas.proximaParada(
        perfil: PerfilVoz.waze,
        numero: 3,
        distanciaKm: 2.4,
      );
      expect(f, 'Próxima: 3');
    });

    test('99: mínimo (numero e acao)', () {
      final f = Falas.proximaParada(
        perfil: PerfilVoz.noventa9,
        numero: 3,
        distanciaKm: 2.4,
      );
      expect(f, '3, 2 km');
    });

    test('Uber: objetivo com o numero da parada', () {
      final f = Falas.proximaParada(
        perfil: PerfilVoz.uber,
        numero: 3,
        distanciaKm: 2.4,
      );
      expect(f, contains('3'));
      expect(f.toLowerCase(), contains('próxima parada'));
    });

    test('perfil com nome do cliente fala o nome', () {
      final f = Falas.proximaParada(
        perfil: PerfilVoz.padrao,
        numero: 3,
        nome: 'Mercado Bom',
        porNome: true,
      );
      expect(f, contains('Mercado Bom'));
    });

    test('perfil Waze e 99 sao mais curtos que o Padrao', () {
      final padrao = Falas.chegada(
        perfil: PerfilVoz.padrao,
        numero: 2,
        total: 5,
        proximoNumero: 3,
        distanciaProximaKm: 1.2,
      );
      final waze = Falas.chegada(
        perfil: PerfilVoz.waze,
        numero: 2,
        total: 5,
        proximoNumero: 3,
        distanciaProximaKm: 1.2,
      );
      final noventa = Falas.chegada(
        perfil: PerfilVoz.noventa9,
        numero: 2,
        total: 5,
        proximoNumero: 3,
        distanciaProximaKm: 1.2,
      );
      expect(waze.length, lessThan(padrao.length));
      expect(noventa.length, lessThan(waze.length));
    });

    test('chegada na ultima parada manda voltar para a empresa', () {
      for (final p in PerfilVoz.values) {
        final f = Falas.chegada(perfil: p, numero: 5, total: 5);
        expect(f.toLowerCase(), contains('empresa'), reason: p.rotulo);
      }
    });

    test('inicio de rota e fim de viagem tem frase em todos os perfis', () {
      for (final p in PerfilVoz.values) {
        expect(
          Falas.rotaIniciada(perfil: p, totalParadas: 4, proximoNumero: 1),
          isNotEmpty,
        );
        expect(Falas.empresa(perfil: p), isNotEmpty);
        expect(Falas.viagemConcluida(perfil: p), isNotEmpty);
      }
    });
  });

  group('Ciclo de vida: sons sincronizados com as paradas', () {
    test('o sino toca SO na chegada (nunca na saida nem na entrega)', () {
      expect(SomDaParada.tocaSino(MomentoParada.chegada), isTrue);
      expect(SomDaParada.tocaSino(MomentoParada.saida), isFalse);
      expect(SomDaParada.tocaSino(MomentoParada.entrega), isFalse);
    });

    test('o sino de estacao toca junto com o de chegada', () {
      expect(SomDaParada.tocaSinoEstacao(MomentoParada.chegada), isTrue);
      expect(SomDaParada.tocaSinoEstacao(MomentoParada.saida), isFalse);
    });

    test('o som de saida toca SO na saida', () {
      expect(SomDaParada.tocaSomSaida(MomentoParada.saida), isTrue);
      expect(SomDaParada.tocaSomSaida(MomentoParada.chegada), isFalse);
    });

    test('a voz fala na chegada e na saida (anuncia a proxima)', () {
      expect(SomDaParada.fala(MomentoParada.chegada), isTrue);
      expect(SomDaParada.fala(MomentoParada.saida), isTrue);
      expect(SomDaParada.fala(MomentoParada.entrega), isFalse);
    });

    test('existem os slots de som: chegada, sino de estacao e saida', () {
      expect(SlotSom.entradaParada.titulo, isNotEmpty);
      expect(SlotSom.sinoEstacao.titulo, contains('estaç'));
      expect(SlotSom.saidaParada.titulo, contains('saída'));
      // Todo slot tem titulo e descricao (para a tela de configuracao).
      for (final s in SlotSom.values) {
        expect(s.titulo, isNotEmpty, reason: s.name);
        expect(s.descricao, isNotEmpty, reason: s.name);
      }
    });
  });

  group('Ciclo de vida: rotas compartilhadas do grupo', () {
    test('o motorista escolhe quais rotas ver (1 de 10, 9 de 10...)', () async {
      final p = SharedRoutesProvider();
      for (var i = 0; i < 10; i++) {
        p.adicionarDoSocket({
          'shareId': 's$i',
          'fromDriverId': 'outro',
          'fromName': 'Motorista $i',
          'stops': [],
        });
      }
      expect(p.total, 10);
      expect(p.totalVisiveis, 10);

      // Esconde 9: sobra 1 visivel.
      for (var i = 0; i < 9; i++) {
        p.alternarVisibilidade('s$i');
      }
      expect(p.totalVisiveis, 1);
      expect(p.isVisivel('s9'), isTrue);

      // Mostra tudo de novo.
      p.mostrarTodas();
      expect(p.totalVisiveis, 10);

      // Esconde todas.
      p.ocultarTodas();
      expect(p.totalVisiveis, 0);
    });

    test('a escolha fica salva (reinicio do app)', () async {
      final p = SharedRoutesProvider();
      p.adicionarDoSocket({'shareId': 's1', 'stops': []});
      p.alternarVisibilidade('s1');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final novo = SharedRoutesProvider();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(novo.ocultas.contains('s1'), isTrue);
    });

    test('o progresso ao vivo muda o status das paradas', () {
      final p = SharedRoutesProvider();
      p.adicionarDoSocket({
        'shareId': 's1',
        'fromDriverId': 'outro',
        'fromName': 'Joao',
        'stops': [
          {
            'lat': -22.9,
            'lon': -43.17,
            'label': 'Cliente 1',
            'customer': 'Cliente 1'
          },
          {
            'lat': -22.8,
            'lon': -43.16,
            'label': 'Cliente 2',
            'customer': 'Cliente 2'
          },
        ],
      });
      final r = p.todas.first;
      expect(r.totalParadas, 2);
      expect(r.statusDaParada(0), StatusParadaCompartilhada.pendente);

      p.registrarProgresso('s1', 0, StatusParadaCompartilhada.chegou);
      expect(p.todas.first.statusDaParada(0), StatusParadaCompartilhada.chegou);
      expect(p.todas.first.chegadas, 1);

      p.registrarProgresso('s1', 0, StatusParadaCompartilhada.entregue);
      expect(p.todas.first.entregues, 1);
      expect(p.todas.first.concluida, isFalse);

      p.registrarProgresso('s1', 1, StatusParadaCompartilhada.entregue);
      expect(p.todas.first.concluida, isTrue);
    });

    test('acompanhar e parar de acompanhar', () {
      final p = SharedRoutesProvider();
      p.adicionarDoSocket({'shareId': 's1', 'stops': []});
      p.marcarSeguindo('s1', true);
      expect(p.isSeguindo('s1'), isTrue);
      p.marcarSeguindo('s1', false);
      expect(p.isSeguindo('s1'), isFalse);
    });

    test('minhas rotas compartilhadas ficam registradas (progresso)', () {
      final p = SharedRoutesProvider();
      p.registrarMinhaShare('s9', 'g1');
      expect(p.minhasShares['s9'], 'g1');
    });

    test('remover rota tira da lista', () {
      final p = SharedRoutesProvider();
      p.adicionarDoSocket({'shareId': 's1', 'stops': []});
      p.remover('s1');
      expect(p.todas, isEmpty);
    });

    test('a rota compartilhada vira linha para desenhar no mapa', () {
      final p = SharedRoutesProvider();
      p.adicionarDoSocket({
        'shareId': 's1',
        'stops': [
          {'lat': -22.9, 'lon': -43.17, 'label': 'A', 'customer': 'A'},
          {'lat': -22.8, 'lon': -43.16, 'label': 'B', 'customer': 'B'},
        ],
      });
      final linha = p.todas.first.linha;
      expect(linha.length, 2);
      expect(linha.first.first, -43.17);
      expect(p.centroDaRota(p.todas.first)!.latitude, closeTo(-22.85, 0.01));
    });
  });

  group('Ciclo de vida: rota propria continua igual', () {
    test('a rota do motorista nao foi afetada pelas rotas compartilhadas', () {
      final r = RouteProvider();
      r.addStop(const RouteStopEntry(
        label: 'Cliente 1',
        customer: 'Cliente 1',
        point: LatLng(-22.9, -43.17),
      ));
      expect(r.totalStops, 1);
      expect(r.pendingCount, 1);
    });
  });
}
