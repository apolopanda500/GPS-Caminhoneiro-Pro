import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/network/geocoding_service.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';

class RoutePlannerSheet extends StatefulWidget {
  final LatLng? origin;

  const RoutePlannerSheet({super.key, required this.origin});

  static Future<void> show(BuildContext context, {LatLng? origin}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF20A0A0A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RoutePlannerSheet(origin: origin),
    );
  }

  @override
  State<RoutePlannerSheet> createState() => _RoutePlannerSheetState();
}

class _RoutePlannerSheetState extends State<RoutePlannerSheet> {
  final _controller = TextEditingController();
  final _bairroController = TextEditingController();
  final _clienteController = TextEditingController();
  final _notaController = TextEditingController();
  final _service = GeocodingService();

  List<GeoResult> _results = const [];
  bool _searching = false;
  bool _highlighting = false;

  @override
  void dispose() {
    _controller.dispose();
    _bairroController.dispose();
    _clienteController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  Future<void> _buscar(String query) async {
    if (query.trim().length < 3) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _searching = true);
    final r = await _service.search(query);
    if (!mounted) return;
    setState(() {
      _results = r;
      _searching = false;
    });
  }

  void _adicionarDestino(GeoResult g) {
    final bairro = _bairroController.text.trim();
    context.read<RouteProvider>().addStop(
          RouteStopEntry(
            label: g.displayName,
            point: LatLng(g.latitude, g.longitude),
            neighborhood: bairro,
            customer: _clienteController.text.trim(),
            note: _notaController.text.trim(),
          ),
        );
    _controller.clear();
    _clienteController.clear();
    _notaController.clear();
    setState(() => _results = const []);
  }

  Future<void> _destacarArea() async {
    final bairro = _bairroController.text.trim();
    if (bairro.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Digite ou selecione um bairro para destacar.')),
      );
      return;
    }
    setState(() => _highlighting = true);
    final provider = context.read<RouteProvider>();
    var ring = await _service.searchPolygon(bairro);
    if (ring == null && provider.stops.isNotEmpty) {
      final ref = provider.stops.last.label;
      ring = await _service.searchPolygon('$bairro, $ref');
    }
    if (!mounted) return;
    setState(() => _highlighting = false);
    if (ring == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Área de "$bairro" não encontrada no mapa.')),
      );
      return;
    }
    provider.setHighlightedArea(ring, label: bairro);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bairro "$bairro" destacado no mapa.')),
    );
  }

  Future<bool> _confirmarConfiguracao() async {
    final provider = context.read<RouteProvider>();
    final stops = provider.stops;
    if (stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Adicione pelo menos uma entrega antes de calcular.')),
      );
      return false;
    }
    final semCliente = stops.where((s) => s.customer.isEmpty).length;
    final semNota = stops.where((s) => s.note.isEmpty).length;
    final porBairro = <String, int>{};
    for (final s in stops) {
      final key = s.neighborhood.isEmpty ? 'Sem bairro' : s.neighborhood;
      porBairro[key] = (porBairro[key] ?? 0) + 1;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        title: const Text('Finalizar configuração',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${stops.length} entrega(s) em ${porBairro.length} região(ões).',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              ...porBairro.entries.map(
                (e) => Text('• ${e.key}: ${e.value}',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13)),
              ),
              if (semCliente > 0 || semNota > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Pendências: $semCliente sem cliente, $semNota sem nota fiscal.',
                  style:
                      const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
              ],
              const SizedBox(height: 10),
              const Text(
                'Confira as paradas antes de desenhar a rota no mapa.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kEmergencyRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desenhar rota'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _calcular() async {
    final origin = widget.origin;
    if (origin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aguardando o sinal de GPS para calcular a rota.')),
      );
      return;
    }
    if (!await _confirmarConfiguracao()) return;
    if (!mounted) return;
    final provider = context.read<RouteProvider>();
    final driver = context.read<AuthProvider>().driver;
    final ok = await provider.plan(
      origin,
      truckHeight: driver?.truckHeight,
      truckWeight: driver?.truckWeight,
      axleCount: driver?.axleCount,
      hazmat: driver?.hazmat ?? false,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RouteProvider>();
    final stops = provider.stops;
    final media = MediaQuery.of(context);
    final maxHeight = (media.size.height - media.viewInsets.bottom) * 0.92;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: media.viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alt_route, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Rota de entregas',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (stops.isNotEmpty)
                      TextButton(
                        onPressed: () => context.read<RouteProvider>().clear(),
                        child: const Text('Limpar'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${stops.length} cliente(s) • ${stops.map((s) => s.neighborhood).where((n) => n.isNotEmpty).toSet().length} bairro(s)',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 10),
                _originRow(),
                const SizedBox(height: 12),
                _field(
                  controller: _controller,
                  hint: 'Buscar rua, número ou ponto do cliente',
                  icon: Icons.search,
                  onSubmitted: _buscar,
                  suffix: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.redAccent),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        controller: _bairroController,
                        hint: 'Bairro',
                        icon: Icons.location_city,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _field(
                        controller: _clienteController,
                        hint: 'Cliente',
                        icon: Icons.person_pin_circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: _field(
                        controller: _notaController,
                        hint: 'Nº nota',
                        icon: Icons.receipt_long,
                      ),
                    ),
                  ],
                ),
                if (_bairroController.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _highlighting ? null : _destacarArea,
                        icon: _highlighting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.gradient, size: 18),
                        label: Text(
                          _highlighting
                              ? 'Buscando área...'
                              : 'Destacar área do bairro',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                if (stops.any((s) => s.neighborhood.isNotEmpty)) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: stops
                          .map((s) => s.neighborhood)
                          .where((n) => n.isNotEmpty)
                          .toSet()
                          .length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final bairros = stops
                            .map((s) => s.neighborhood)
                            .where((n) => n.isNotEmpty)
                            .toSet()
                            .toList();
                        final bairro = bairros[i];
                        final active = _bairroController.text.trim() == bairro;
                        return ChoiceChip(
                          label: Text(bairro,
                              style: const TextStyle(fontSize: 11)),
                          selected: active,
                          onSelected: (_) =>
                              setState(() => _bairroController.text = bairro),
                          selectedColor: kEmergencyRed.withValues(alpha: 0.35),
                          labelStyle: TextStyle(
                              color: active ? Colors.white : Colors.white70),
                          backgroundColor: const Color(0xFF151515),
                          side: const BorderSide(color: Colors.white12),
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
                  ),
                ],
                if (_results.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final g = _results[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.add_location_alt,
                              color: Colors.redAccent),
                          title: Text(
                            g.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                          onTap: () => _adicionarDestino(g),
                        );
                      },
                    ),
                  ),
                if (stops.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                      'Clientes na ordem de entrega (arraste para reordenar)',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      buildDefaultDragHandles: true,
                      itemCount: stops.length,
                      onReorderItem: (a, b) =>
                          context.read<RouteProvider>().move(a, b),
                      itemBuilder: (context, i) {
                        final stop = stops[i];
                        final status = provider.statusOf(i);
                        final delivered = status == StopStatus.delivered;
                        final arrived = status == StopStatus.arrived;
                        return ListTile(
                          key: ValueKey('stop_$i'),
                          dense: true,
                          leading: CircleAvatar(
                            radius: 13,
                            backgroundColor: delivered
                                ? Colors.green
                                : arrived
                                    ? Colors.amber
                                    : kEmergencyRed,
                            child: delivered
                                ? const Icon(Icons.check,
                                    size: 14, color: Colors.white)
                                : Text('${i + 1}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11)),
                          ),
                          title: Text(
                            stop.customer.isEmpty ? stop.label : stop.customer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                          subtitle: Text(
                            [
                              if (stop.neighborhood.isNotEmpty)
                                stop.neighborhood,
                              if (stop.note.isNotEmpty) 'nota ${stop.note}',
                              if (stop.customer.isNotEmpty) stop.label,
                            ].join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: Colors.white54),
                            onPressed: () =>
                                context.read<RouteProvider>().removeStopAt(i),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (provider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      provider.error!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style:
                        FilledButton.styleFrom(backgroundColor: kEmergencyRed),
                    onPressed: provider.loading ? null : _calcular,
                    icon: provider.loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.directions),
                    label: Text(
                        provider.loading ? 'Calculando...' : 'Calcular rota'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      textInputAction:
          onSubmitted == null ? TextInputAction.next : TextInputAction.search,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.redAccent),
        suffixIcon: suffix,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFF151515),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _originRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: const Row(
        children: [
          Icon(Icons.my_location, color: Colors.lightBlueAccent, size: 18),
          SizedBox(width: 8),
          Text('Partida: minha posição atual',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}
