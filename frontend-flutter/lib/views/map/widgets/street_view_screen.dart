import 'package:flutter/material.dart';
import 'package:gps_camioneiro_pro/core/network/street_view_service.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';

/// Visualizador de imagens de rua: permite zoom, arrastar, trocar de foto e
/// abrir a mesma posicao no Google Maps (Street View).
class StreetViewScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? token;

  const StreetViewScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.token,
  });

  static Future<void> show(
    BuildContext context, {
    required double latitude,
    required double longitude,
    String? token,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StreetViewScreen(
          latitude: latitude,
          longitude: longitude,
          token: token,
        ),
      ),
    );
  }

  @override
  State<StreetViewScreen> createState() => _StreetViewScreenState();
}

class _StreetViewScreenState extends State<StreetViewScreen> {
  final _service = StreetViewService();
  List<StreetPhoto> _photos = [];
  int _index = 0;
  bool _loading = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final photos = await _service.photosNear(
      lat: widget.latitude,
      lon: widget.longitude,
      token: widget.token,
    );
    if (!mounted) return;
    setState(() {
      _photos = photos;
      _loading = false;
      _erro = photos.isEmpty
          ? 'Nenhuma imagem de rua encontrada aqui (ou token Mapillary ausente).'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final foto = _photos.isEmpty ? null : _photos[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Ver a rua'),
        backgroundColor: kDarkBlack,
        actions: [
          IconButton(
            tooltip: 'Abrir no Google Maps',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _abrirGoogle(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : foto == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.streetview, size: 56, color: Colors.white24),
                              const SizedBox(height: 12),
                              Text(
                                _erro ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _abrirGoogle,
                                child: const Text('VER NO GOOGLE MAPS'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : InteractiveViewer(
                        minScale: 1,
                        maxScale: 5,
                        child: Center(
                          child: Image.network(
                            foto.thumbUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) => progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('Não foi possível carregar a imagem',
                                  style: TextStyle(color: Colors.white70)),
                            ),
                          ),
                        ),
                      ),
          ),
          if (foto != null) _barraInfo(foto),
        ],
      ),
    );
  }

  Widget _barraInfo(StreetPhoto foto) {
    final data = foto.capturedDate;
    return SafeArea(
      child: Container(
        width: double.infinity,
        color: const Color(0xEE0A0A0A),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Imagem ${_index + 1} de ${_photos.length}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data == null
                        ? 'Data da captura desconhecida'
                        : 'Capturada em ${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: _index > 0
                  ? () => setState(() => _index--)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: _index < _photos.length - 1
                  ? () => setState(() => _index++)
                  : null,
            ),
            IconButton(
              tooltip: 'Atualizar imagens',
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _carregar,
            ),
          ],
        ),
      ),
    );
  }

  void _abrirGoogle() {
    final url = StreetViewService.googleStreetViewLink(
      widget.latitude,
      widget.longitude,
    );
    final uri = Uri.parse(url);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abrir fora do app'),
        content: Text(url),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _abrirExterno(uri);
            },
            child: const Text('ABRIR'),
          ),
        ],
      ),
    );
  }

  void _abrirExterno(Uri uri) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Abrindo: ${uri.host}')),
    );
  }
}
