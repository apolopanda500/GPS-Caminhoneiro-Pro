import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gps_camioneiro_pro/data/models/trip_model.dart';
import 'package:gps_camioneiro_pro/providers/trip_provider.dart';

class TravelHistoryScreen extends StatelessWidget {
  const TravelHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();
    final trips = tripProvider.trips;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Histórico de Viagens', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (trips.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Limpar histórico',
              onPressed: () => _confirmarLimpeza(context),
            ),
        ],
      ),
      body: trips.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.route, color: Colors.white24, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Nenhuma viagem registrada ainda.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Suas viagens são salvas automaticamente ao encerrar a navegação.',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: trips.map((t) => _buildHistoryCard(context, t)).toList(),
            ),
    );
  }

  Future<void> _confirmarLimpeza(BuildContext context) async {
    final provider = context.read<TripProvider>();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Limpar histórico?'),
        content: const Text(
          'Todas as viagens registradas serão apagadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LIMPAR'),
          ),
        ],
      ),
    );
    if (confirmar == true) await provider.clear();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }

  String _formatDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _buildHistoryCard(BuildContext context, TripModel trip) {
    final surface = Theme.of(context).colorScheme.surface;
    final outline = Theme.of(context).colorScheme.outline;
    return Card(
      color: surface,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDate(trip.startedAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text('${trip.distanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Text('�??� Início: ${trip.startLat.toStringAsFixed(4)}, ${trip.startLon.toStringAsFixed(4)}',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 4),
            Text('�?�� Fim: ${trip.endLat.toStringAsFixed(4)}, ${trip.endLon.toStringAsFixed(4)}',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            const Divider(color: Colors.white12, height: 20),
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.grey, size: 16),
                const SizedBox(width: 6),
                Text('Duração: ${_formatDuration(trip.duration)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const Spacer(),
                const Icon(Icons.speed, color: Colors.grey, size: 16),
                const SizedBox(width: 6),
                Text('Máx ${trip.maxSpeedKmh.toStringAsFixed(0)} km/h',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
