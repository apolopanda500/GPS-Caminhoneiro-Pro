import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/network/geocoding_service.dart';

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
      backgroundColor: kDarkRedTransition,
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

  /// Regiao em uso (pode ser trocada pelos atalhos).
  late String _regiao = widget.stateName ?? 'RJ';

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
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
        _error = r.isEmpty ? 'Nenhum resultado encontrado.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Falha na busca. Verifique a conexão.';
      });
    }
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
              const Icon(Icons.search, color: Colors.redAccent),
              const SizedBox(width: 8),
              const Text('Buscar rua/cidade', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: widget.near != null
                  ? 'Ex.: Av. Brasil, proximo a mim'
                  : 'Ex.: Av. Anhanguera, Rio de Janeiro',
              hintStyle: const TextStyle(color: Colors.grey),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.redAccent),
                onPressed: _search,
              ),
            ),
          ),
          if (widget.near != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.near_me, size: 13, color: Colors.white54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Buscando perto de voce e dentro de $_regiao',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
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
                      color: ativo ? Colors.white : Colors.white70,
                      fontSize: 12,
                    ),
                    selectedColor: kEmergencyRed,
                    backgroundColor: Colors.white10,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: kEmergencyRed)),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final r = _results[i];
                return ListTile(
                  leading: const Icon(Icons.place, color: Colors.redAccent),
                  title: Text(r.displayName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13)),
                  subtitle: r.distanceKm != null
                      ? Text(
                          '${_distanciaTexto(r.distanceKm!)} de voce',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        )
                      : null,
                  trailing: r.distanceKm != null
                      ? Icon(Icons.near_me,
                          size: 14, color: Colors.white.withValues(alpha: 0.5))
                      : null,
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
