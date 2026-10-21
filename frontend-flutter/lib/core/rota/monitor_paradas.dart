/// Como o monitor avisa o app.
class EventoParada {
  /// A parada onde o caminhao acabou de chegar.
  final int indice;

  /// 'chegou' ou 'saiu'.
  final String tipo;

  const EventoParada(this.indice, this.tipo);

  bool get chegou => tipo == 'chegou';
  bool get saiu => tipo == 'saiu';
}

/// Monitora chegada e saida das paradas pelo GPS, em tempo real.
///
/// Regras:
/// - **Chegada**: o caminhao entra no raio da parada (100-200 m). Acontece
///   uma vez por parada.
/// - **Saida**: o caminhao passa do raio de saida **e** ja esta andando
///   (velocidade acima do piso). A proxima parada e anunciada uma vez.
///
/// Fica separado do widget para poder ser testado com milhares de
/// simulacoes de estrada.
class MonitorDeParadas {
  /// Velocidade minima (km/h) para considerar que o caminhao saiu de fato.
  final double velocidadeParaSair;

  /// Distancia extra alem do raio de saida (evita disparar no vaivem do
  /// portao de descarga).
  final double margemExtra;

  MonitorDeParadas({
    this.velocidadeParaSair = 5,
    this.margemExtra = 20,
  });

  final Map<int, bool> _dentro = {};
  final Set<int> _saiu = {};
  final Set<int> _anunciouChegada = {};
  int? _paradaParada;

  /// A parada em que o caminhao esta (a que ele acabou de parar).
  int? get paradaParada => _paradaParada;

  /// Zera o monitor (rota limpa ou nova rota).
  void resetar() {
    _dentro.clear();
    _saiu.clear();
    _anunciouChegada.clear();
    _paradaParada = null;
  }

  /// Processa uma posicao do GPS.
  ///
  /// [dentroDe] diz se o caminhao esta dentro do raio da parada;
  /// [saiuDe] diz se ja passou do raio de saida. Os dois vem do
  /// [RouteProvider] (que conhece o raio de cada parada).
  ///
  /// Devolve os eventos do ciclo: chegada (uma vez) e saida (uma vez).
  List<EventoParada> processar({
    required int totalParadas,
    required bool Function(int indice) dentroDe,
    required bool Function(int indice) saiuDe,
    required double velocidadeKmh,
  }) {
    final eventos = <EventoParada>[];

    for (var i = 0; i < totalParadas; i++) {
      final dentro = dentroDe(i);
      final antes = _dentro[i] ?? false;
      if (dentro && !antes) {
        _dentro[i] = true;
        // A chegada e anunciada UMA vez por parada: com ruido de GPS o
        // caminhao pode sair e voltar do raio, e o motorista nao pode
        // ouvir "chegou" duas vezes.
        if (!_anunciouChegada.contains(i)) {
          _anunciouChegada.add(i);
          _saiu.remove(i);
          _paradaParada = i;
          eventos.add(EventoParada(i, 'chegou'));
        }
      } else if (!dentro && antes) {
        _dentro[i] = false;
      }
    }

    // A saida so e anunciada para a parada da ULTIMA chegada anunciada,
    // e apenas uma vez. Sem isso, uma segunda visita a mesma parada geraria
    // mais saidas que chegadas.
    final parada = _paradaParada;
    if (parada != null &&
        !_saiu.contains(parada) &&
        velocidadeKmh >= velocidadeParaSair &&
        saiuDe(parada)) {
      _saiu.add(parada);
      eventos.add(EventoParada(parada, 'saiu'));
    }

    return eventos;
  }
}
