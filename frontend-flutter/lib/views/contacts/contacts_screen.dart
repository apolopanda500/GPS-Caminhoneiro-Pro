import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:gps_camioneiro_pro/providers/peer_provider.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final peers = context.watch<PeerProvider>().peers;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          'Contatos de Estrada',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: peers.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping_outlined,
                        color: Colors.white24, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Nenhum caminhão por perto agora.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Os contatos aparecem quando outros motoristas entram na rede V2X.',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: peers
                  .map((peer) => _buildContactCard(context, peer))
                  .toList(),
            ),
    );
  }

  Widget _buildContactCard(BuildContext context, Map<String, dynamic> peer) {
    final lat = (peer['lat'] as num?)?.toDouble();
    final lon = (peer['lon'] as num?)?.toDouble();
    final hasLocation = lat != null && lon != null && !(lat == 0 && lon == 0);
    final name = (peer['name'] ?? 'Caminhoneiro').toString();
    final model = (peer['truckModel'] ?? 'Modelo não informado').toString();
    final cargo = (peer['cargoType'] ?? 'Carga geral').toString();

    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: hasLocation ? const Color(0xFFA80000) : Colors.white12,
            width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Icon(Icons.local_shipping,
              color: hasLocation ? Colors.redAccent : Colors.grey),
        ),
        title: Text(name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(model,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Carga: $cargo',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              hasLocation
                  ? 'Online - ${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)}'
                  : 'Sem posição',
              style: TextStyle(
                color: hasLocation ? Colors.green : Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: hasLocation
            ? IconButton(
                icon: const Icon(Icons.my_location, color: Colors.redAccent),
                tooltip: 'Centralizar no mapa',
                onPressed: () => Navigator.pop(context, LatLng(lat, lon)),
              )
            : const Icon(Icons.location_off, color: Colors.white24),
      ),
    );
  }
}
