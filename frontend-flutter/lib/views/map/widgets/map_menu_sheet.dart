import 'package:flutter/material.dart';

class MapMenuSheet extends StatelessWidget {
  final bool isPremium;
  final VoidCallback onProfile;
  final VoidCallback onTrips;
  final VoidCallback onEndTrip;
  final VoidCallback onContacts;
  final VoidCallback onSettings;
  final VoidCallback onPremium;
  final VoidCallback onClearSignals;
  final VoidCallback onLogout;

  const MapMenuSheet({
    super.key,
    required this.isPremium,
    required this.onProfile,
    required this.onTrips,
    required this.onEndTrip,
    required this.onContacts,
    required this.onSettings,
    required this.onPremium,
    required this.onClearSignals,
    required this.onLogout,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isPremium,
    required VoidCallback onProfile,
    required VoidCallback onTrips,
    required VoidCallback onEndTrip,
    required VoidCallback onContacts,
    required VoidCallback onSettings,
    required VoidCallback onPremium,
    required VoidCallback onClearSignals,
    required VoidCallback onLogout,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xF20E1216),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MapMenuSheet(
        isPremium: isPremium,
        onProfile: onProfile,
        onTrips: onTrips,
        onEndTrip: onEndTrip,
        onContacts: onContacts,
        onSettings: onSettings,
        onPremium: onPremium,
        onClearSignals: onClearSignals,
        onLogout: onLogout,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('Menu do mapa',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _tile(context,
                icon: Icons.person,
                title: 'Meu perfil e ícone',
                onTap: onProfile),
            const Divider(color: Colors.white12),
            _tile(context,
                icon: Icons.history,
                title: 'Histórico de viagens',
                onTap: onTrips),
            _tile(context,
                icon: Icons.flag,
                title: 'Encerrar viagem atual',
                onTap: onEndTrip),
            _tile(context,
                icon: Icons.people,
                title: 'Contatos de estrada',
                onTap: onContacts),
            const Divider(color: Colors.white12),
            _tile(context,
                icon: Icons.settings,
                title: 'Configurações',
                subtitle: 'Camada do mapa e visão 3D',
                onTap: onSettings),
            _tile(
              context,
              icon: Icons.cleaning_services,
              title: 'Limpar sinais do mapa',
              onTap: onClearSignals,
            ),
            const Divider(color: Colors.white12),
            _tile(
              context,
              icon: isPremium ? Icons.verified : Icons.payment,
              title: isPremium ? 'Plano Premium ativo' : 'Assinar Premium',
              subtitle: isPremium ? 'Obrigado por apoiar o app' : null,
              color: Colors.amber,
              onTap: onPremium,
            ),
            _tile(
              context,
              icon: Icons.logout,
              title: 'Sair da conta',
              color: Colors.redAccent,
              onTap: onLogout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? color,
    required VoidCallback onTap,
  }) {
    final c = color ?? Colors.white;
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.redAccent),
      title: Text(title, style: TextStyle(color: c)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}
