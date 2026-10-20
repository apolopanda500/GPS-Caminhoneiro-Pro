import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/network/geocoding_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Historico de buscas do motorista (as ultimas 8).
class BuscaHistorico {
  BuscaHistorico._();
  static const _chave = 'busca.historico';

  static Future<List<String>> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_chave) ?? const [];
  }

  static Future<void> registrar(String termo) async {
    final t = termo.trim();
    if (t.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final lista = [...await carregar(), t];
    final unicos = <String>[];
    for (final x in lista.reversed) {
      if (!unicos.contains(x)) unicos.add(x);
      if (unicos.length >= 8) break;
    }
    await prefs.setStringList(_chave, unicos.reversed.toList());
  }

  static Future<void> limpar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chave);
  }
}

/// Folha de busca de rua/cidade. Retorna um [GeoResult] escolhido.
///
/// A busca usa a sua posicao como referencia: os resultados vem por
/// distancia, priorizando a sua cidade e os bairros vizinhos.
class StreetSearchSheet extends StatefulWidget {
  final LatLng? near;
  final String? cityName;
  final String? stateName;

  const StreetSearchSheet({
    super.key,
    this.near,
    this.cityName,
    this.stateName,
  });

  static Future<GeoResult?> show(
    BuildContext context, {
    LatLng? near,
    String? cityName,
    String? stateName,
  }) {
    return showModalBottomSheet<GeoResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBackground(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StreetSearchSheet(
        near: near,
        cityName: cityName,
        stateName: stateName,
      ),
    );
  }

  @override
  State<StreetSearchSheet> createState() => _StreetSearchSheetState();
}

/// Regioesoffertecidas para o motorista trocar a "casa" da busca.
const List<String> kRegioesRapidas = [
  'RJ',
  'SP',
  'MG',
  'PR',
  'SC',
  'RS',
  'BA',
  'PE',
  'CE',
  'GO',
];

class _StreetSearchSheetState extends State<StreetSearchSheet> {
  final _controller = TextEditingController();
  final _service = GeocodingService();
  List<GeoResult> _results = [];
  bool _loading = false;
  String? _error;
  List<String> _historico = const [];

  /// Regiao em uso (pode ser trocada pelos atalhos). Vem do GPS: a busca
  /// nunca sai do estado onde o caminhao esta.
  late String _regiao = widget.stateName ?? 'RJ';

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  Future<void> _carregarHistorico() async {
    final h = await BuscaHistorico.carregar();
    if (!mounted) return;
    setState(() => _historico = h);
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final r = await _service.search(
        q,
        near: widget.near,
        cityName: widget.cityName,
        stateName: _regiao,
      );
      await BuscaHistorico.registrar(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
        _error = r.isEmpty
            ? 'Nenhum resultado em $_regiao. Troque a regiao ou tente outro termo.'
            : null;
      });
      await _carregarHistorico();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Falha na busca. Verifique a conexão.';
      });
    }
  }

  /// Copia o texto do resultado (endereco) para a area de transferencia.
  Future<void> _copiar(String texto) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copiado: $texto')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: sheetAccent(context)),
              const SizedBox(width: 8),
              Text('Buscar rua/cidade',
                  style: TextStyle(
                      color: sheetText(context),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: sheetMuted(context)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          // Campo grande: facil de digitar e de acertar com o dedo na estrada.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: fieldFill(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sheetAccent(context).withValues(alpha: 0.45),
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: sheetAccent(context), size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(
                      color: sheetText(context),
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: widget.near != null
                          ? 'Av. Brasil, proximo a mim'
                          : 'Av. Anhanguera, Rio de Janeiro',
                      hintStyle: TextStyle(
                        color: sheetMuted(context),
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: sheetAccent(context),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _search,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.arrow_forward, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (widget.near != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.near_me,
                      size: 13, color: sheetMuted(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Buscando perto de voce e dentro de $_regiao',
                      style: TextStyle(
                        color: sheetMuted(context),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: kRegioesRapidas.map((r) {
                final ativo = r == _regiao;
                final destaque = sheetAccent(context);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(r),
                    selected: ativo,
                    onSelected: (_) {
                      setState(() => _regiao = r);
                      if (_controller.text.trim().isNotEmpty) _search();
                    },
                    labelStyle: TextStyle(
                      color: ativo
                          ? Colors.white
                          : sheetText(context),
                      fontSize: 12,
                    ),
                    selectedColor: destaque,
                    backgroundColor:
                        sheetDivider(context).withValues(alpha: 0.5),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          if (_historico.isNotEmpty && _results.isEmpty) ...[
            Row(
              children: [
                Icon(Icons.history, size: 15, color: sheetMuted(context)),
                const SizedBox(width: 6),
                Text('Buscas recentes',
                    style: TextStyle(
                        color: sheetMuted(context), fontSize: 12)),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    await BuscaHistorico.limpar();
                    await _carregarHistorico();
                  },
                  child: Text('limpar',
                      style: TextStyle(
                          color: sheetAccent(context), fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _historico.map((t) {
                return ActionChip(
                  avatar: Icon(Icons.search, size: 14, color: sheetMuted(context)),
                  label: Text(t,
                      style: TextStyle(color: sheetText(context), fontSize: 12)),
                  backgroundColor: sheetDivider(context).withValues(alpha: 0.4),
                  onPressed: () {
                    _controller.text = t;
                    _search();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
          if (_loading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(color: sheetAccent(context)),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.orangeAccent)),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final r = _results[i];
                return ListTile(
                  leading: Icon(Icons.place, color: sheetAccent(context)),
                  title: Text(r.displayName,
                      style: TextStyle(
                          color: sheetText(context), fontSize: 13)),
                  subtitle: r.distanceKm != null
                      ? Text(
                          '${_distanciaTexto(r.distanceKm!)} de voce',
                          style: TextStyle(
                              color: sheetMuted(context), fontSize: 11),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Copiar',
                        iconSize: 18,
                        onPressed: () => _copiar(r.displayName),
                        icon: Icon(Icons.copy, color: sheetMuted(context)),
                      ),
                      if (r.distanceKm != null)
                        Icon(Icons.near_me,
                            size: 14, color: sheetMuted(context)),
                    ],
                  ),
                  onTap: () => Navigator.pop(context, r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Formata a distancia em km/m para exibir no resultado da busca.
  String _distanciaTexto(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }
}
