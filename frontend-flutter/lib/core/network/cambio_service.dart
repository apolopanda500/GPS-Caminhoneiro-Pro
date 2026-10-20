import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cambio do dia para quem dirige fora do Brasil.
///
/// Usa a API publica do [open.er-api.com] (sem chave): base BRL e as
/// moedas dos paises de fronteira e principais destinos da rota.
///
/// O app mostra a taxa para o motorista saber quanto vale o que ele recebe
/// fora - a base para a integracao com remessas internacionais (Wise).
class CambioService {
  static const String _url = 'https://open.er-api.com/v6/latest/BRL';

  /// Moedas uteis para o caminhoneiro (fronteira e principais destinos).
  static const List<String> moedas = [
    'USD', // Dolar
    'EUR', // Euro
    'PYG', // Guarani (Paraguai)
    'ARS', // Peso (Argentina)
    'BOB', // Boliviano
    'UYU', // Peso (Uruguai)
    'CLP', // Peso (Chile)
  ];

  /// Como aparece o nome da moeda na tela.
  static const Map<String, String> nomes = {
    'USD': 'Dólar',
    'EUR': 'Euro',
    'PYG': 'Guarani',
    'ARS': 'Peso argentino',
    'BOB': 'Boliviano',
    'UYU': 'Peso uruguayo',
    'CLP': 'Peso chileno',
  };

  /// Taxas: 1 real vale X da moeda.
  Future<Map<String, double>> taxas() async {
    try {
      final resp = await http
          .get(Uri.parse(_url), headers: {'User-Agent': 'gps-camioneiro-pro/1.0'})
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return const {};
      final data =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final rates = data['rates'] as Map<String, dynamic>? ?? const {};
      final saida = <String, double>{};
      for (final m in moedas) {
        final v = rates[m];
        if (v is num) saida[m] = v.toDouble();
      }
      return saida;
    } catch (_) {
      return const {};
    }
  }

  /// Data da atualizacao da cotacao (texto do provedor).
  Future<String> atualizacao() async {
    try {
      final resp = await http
          .get(Uri.parse(_url), headers: {'User-Agent': 'gps-camioneiro-pro/1.0'})
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return '';
      final data =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      return (data['time_last_update_utc'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  /// Texto pronto: "1 USD = R\$ 5,05" (invertendo a taxa do provider).
  static String texto(String moeda, double taxaPorReal) {
    if (taxaPorReal <= 0) return '';
    final porReal = 1 / taxaPorReal;
    return '1 $moeda = R\$ ${porReal.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}
