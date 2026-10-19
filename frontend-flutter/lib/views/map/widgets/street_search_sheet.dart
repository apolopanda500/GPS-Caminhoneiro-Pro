import 'package:flutter/material.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/network/geocoding_service.dart';

/// Folha de busca de rua/cidade. Retorna um [GeoResult] escolhido.
class StreetSearchSheet extends StatefulWidget {
  const StreetSearchSheet({super.key});

  static Future<GeoResult?> show(BuildContext context) {
    return showModalBottomSheet<GeoResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kDarkRedTransition,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const StreetSearchSheet(),
    );
  }

  @override
  State<StreetSearchSheet> createState() => _StreetSearchSheetState();
}

class _StreetSearchSheetState extends State<StreetSearchSheet> {
  final _controller = TextEditingController();
  final _service = GeocodingService();
  List<GeoResult> _results = [];
  bool _loading = false;
  String? _error;

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final r = await _service.search(q);
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
              hintText: 'Ex.: Av. Anhanguera, São Paulo',
              hintStyle: const TextStyle(color: Colors.grey),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.redAccent),
                onPressed: _search,
              ),
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
                  title: Text(r.displayName, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  onTap: () => Navigator.pop(context, r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
