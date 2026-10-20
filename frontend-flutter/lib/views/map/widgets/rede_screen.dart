import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/network/socket_client.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/providers/peer_provider.dart';
import 'package:gps_camioneiro_pro/providers/weather_provider.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/chat_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/groups_sheet.dart';

/// Tela **Rede**: tudo que o motorista compartilha com os outros
/// caminhoneiros em um lugar so.
///
/// Abas: Chat da via, Grupos e comboios, Contatos de estrada e Empresa.
/// (Cada aba e um atalho para a acao real - nao ha comando duplicado.)
class RedeScreen extends StatefulWidget {
  final String driverId;
  final String driverName;
  final Map<String, String> authHeaders;

  /// Abre a tela de contatos de estrada.
  final VoidCallback? onContatos;

  /// Marca a empresa no mapa.
  final VoidCallback? onEmpresa;

  /// Sinaliza na via.
  final VoidCallback? onSinalizar;

  const RedeScreen({
    super.key,
    required this.driverId,
    required this.driverName,
    required this.authHeaders,
    this.onContatos,
    this.onEmpresa,
    this.onSinalizar,
  });

  static Future<void> show(
    BuildContext context, {
    required String driverId,
    required String driverName,
    required Map<String, String> authHeaders,
    VoidCallback? onContatos,
    VoidCallback? onEmpresa,
    VoidCallback? onSinalizar,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RedeScreen(
          driverId: driverId,
          driverName: driverName,
          authHeaders: authHeaders,
          onContatos: onContatos,
          onEmpresa: onEmpresa,
          onSinalizar: onSinalizar,
        ),
      ),
    );
  }

  @override
  State<RedeScreen> createState() => _RedeScreenState();
}

class _RedeScreenState extends State<RedeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ink = tema.colorScheme.onSurface;
    final clima = context.read<WeatherProvider>();

    return Scaffold(
      backgroundColor: tema.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Rede de caminhoneiros'),
        backgroundColor: tema.colorScheme.surface,
        foregroundColor: ink,
        bottom: TabBar(
          controller: _tabs,
          labelColor: tema.colorScheme.primary,
          unselectedLabelColor: ink.withValues(alpha: 0.6),
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
            Tab(icon: Icon(Icons.group), text: 'Grupos'),
            Tab(icon: Icon(Icons.people), text: 'Contatos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          ChatPanel(
            driverId: widget.driverId,
            driverName: widget.driverName,
            messages: const [],
            onSend: (message) {
              SocketClient().sendChatMessage(
                driverId: widget.driverId,
                driverName: widget.driverName,
                message: message,
                lat: clima.lastLatitude ?? 0,
                lon: clima.lastLongitude ?? 0,
              );
            },
          ),
          GroupsSheet(
            driverId: widget.driverId,
            authHeaders: widget.authHeaders,
          ),
          _contatos(context, ink),
        ],
      ),
    );
  }

  /// Aba de contatos: mostra os caminhoneiros por perto e da acesso as
  /// acoes principais (empresa, sinalizar, conversa).
  Widget _contatos(BuildContext context, Color ink) {
    final peers = context.watch<PeerProvider>().peers;
    if (peers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline, size: 48, color: Colors.white24),
              const SizedBox(height: 12),
              Text(
                'Nenhum caminhoneiro por perto agora.\n'
                'Assim que aparecer, ele entra aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: peers.length,
      itemBuilder: (context, i) {
        final p = peers[i];
        final nome = (p['name'] ?? 'Caminhoneiro').toString();
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: kEmergencyRed.withValues(alpha: 0.2),
            child: Text(
              nome.isNotEmpty ? nome[0].toUpperCase() : '?',
              style: const TextStyle(color: kEmergencyRed),
            ),
          ),
          title: Text(nome, style: TextStyle(color: ink)),
          subtitle: Text('Caminhoneiro na rede', style: TextStyle(fontSize: 12, color: ink.withValues(alpha: 0.6))),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Conversar',
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () {
                  _tabs.animateTo(0);
                },
              ),
              IconButton(
                tooltip: 'Empresa',
                icon: const Icon(Icons.factory_outlined),
                onPressed: widget.onEmpresa,
              ),
              IconButton(
                tooltip: 'Sinalizar aqui',
                icon: const Icon(Icons.add_location_alt_outlined),
                onPressed: widget.onSinalizar,
              ),
            ],
          ),
          onTap: widget.onContatos,
        );
      },
    );
  }
}
