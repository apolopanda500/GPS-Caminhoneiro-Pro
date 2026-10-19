import 'package:flutter/foundation.dart';

/// Guarda os caminhões próximos recebidos da rede V2X (radar).
/// Alimenta a tela de Contatos de Estrada e o balão do mapa.
class PeerProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _peers = [];

  List<Map<String, dynamic>> get peers => List.unmodifiable(_peers);
  int get count => _peers.length;
  bool get isEmpty => _peers.isEmpty;

  void setPeers(List<Map<String, dynamic>> peers) {
    _peers
      ..clear()
      ..addAll(peers);
    notifyListeners();
  }

  void clear() {
    _peers.clear();
    notifyListeners();
  }
}
