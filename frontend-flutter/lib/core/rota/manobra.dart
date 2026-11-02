import 'package:latlong2/latlong.dart';

class FaixaRota {
  final bool eValida;
  final String indicacao;

  const FaixaRota({required this.eValida, required this.indicacao});
}

class Manobra {
  final LatLng posicao;
  final String tipo;
  final String texto;
  final double distancia;
  final List<LatLng> geometria;
  final List<FaixaRota> faixas;
  final double acumulado;

  const Manobra({
    required this.posicao,
    required this.tipo,
    required this.texto,
    this.distancia = 0,
    this.geometria = const [],
    this.faixas = const [],
    this.acumulado = 0,
  });
}

String normalizarManobra(String bruta) {
  final t = bruta.trim().toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
  if (t.contains('slight left')) return 'levemente_esquerda';
  if (t.contains('slight right')) return 'levemente_direita';
  if (t.contains('keep left')) return 'manter_esquerda';
  if (t.contains('keep right')) return 'manter_direita';
  if (t.contains('turn left') || t == 'left') return 'esquerda';
  if (t.contains('turn right') || t == 'right') return 'direita';
  if (t.contains('uturn')) return 'retorno';
  if (t.contains('roundabout left')) return 'rotatoria_esquerda';
  if (t.contains('roundabout right')) return 'rotatoria_direita';
  if (t.contains('roundabout')) return 'rotatoria';
  if (t.contains('exit left')) return 'saida_esquerda';
  if (t.contains('exit right')) return 'saida_direita';
  if (t.contains('fork left')) return 'garfo_esquerda';
  if (t.contains('fork right')) return 'garfo_direita';
  if (t.contains('merge')) return 'fusao';
  if (t.contains('ramp')) return 'rampa';
  if (t.contains('depart')) return 'partida';
  if (t.contains('arrive')) return 'chegada';
  if (t.contains('straight') || t.contains('name change') || t.contains('name_change') || t == 'continue' ||
      t.contains('notification')) {
    return 'reto';
  }
  if (t == 'esquerda' ||
      t == 'direita' ||
      t == 'reto' ||
      t == 'retorno' ||
      t == 'rotatoria' ||
      t == 'fusao' ||
      t == 'partida' ||
      t == 'chegada') {
    return t;
  }
  return 'reto';
}
