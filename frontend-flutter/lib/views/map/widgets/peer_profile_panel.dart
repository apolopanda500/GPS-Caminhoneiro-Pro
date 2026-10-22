import 'package:flutter/material.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/utils/fotos_motorista.dart';

class PeerProfilePanel extends StatelessWidget {
  final Map<String, dynamic> peerTruck;
  final String currentDriverId;
  final void Function(String emoji) onSendReaction;
  final void Function() onOpenChat;
  final void Function() onMessage;
  final void Function() onSignal;
  final void Function() onVibration;
  final void Function() onCall;

  const PeerProfilePanel({
    super.key,
    required this.peerTruck,
    required this.currentDriverId,
    required this.onSendReaction,
    required this.onOpenChat,
    required this.onMessage,
    required this.onSignal,
    required this.onVibration,
    required this.onCall,
  });

  static const List<String> _emojis = [
    '👋', '👍', '🤝', '😄', '😂', '🙏', '❤️', '🔥', '😎', '🫡', '💯', '🎉', '🫶', '🚨',
    '🐂', '⛽', '✅', '👀',
  ];

  @override
  Widget build(BuildContext context) {
    final icon = (peerTruck['truckIcon'] ?? '🚚').toString();
    final photo = (peerTruck['truckPhotoUrl'] ?? '').toString();
    final avatar = (peerTruck['avatarUrl'] ?? '').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF1C0303),
                backgroundImage: FotosMotorista.provider(avatar),
                child: FotosMotorista.provider(avatar) == null
                    ? Text(icon, style: const TextStyle(fontSize: 28))
                    : null,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peerTruck['name'] ?? 'Caminhoneiro',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Puxando: ${peerTruck['cargoType'] ?? 'Carga Geral'}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Modelo: ${peerTruck['truckModel'] ?? 'Não informado'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _QuickAction(icon: Icons.chat_bubble_outline, label: 'Mensagem', onTap: onMessage),
              const SizedBox(width: 10),
              _QuickAction(icon: Icons.warning_amber, label: 'Sinal', onTap: onSignal),
              const SizedBox(width: 10),
              _QuickAction(icon: Icons.vibration, label: 'Vibrar', onTap: onVibration),
              const SizedBox(width: 10),
              _QuickAction(icon: Icons.call, label: 'Ligar', onTap: onCall),
            ],
          ),
          if (photo.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'FOTO DO BRUTO',
              style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 160,
                width: double.infinity,
                color: const Color(0xFF1C0303),
                child: FotosMotorista.imagem(
                  photo,
                  fit: BoxFit.cover,
                  fallback: const Center(
                    child: Icon(Icons.local_shipping, color: Colors.white24, size: 50),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          const Text(
            'ENVIAR SAUDAÇÃO RÁPIDA',
            style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _emojis.map((emoji) {
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSendReaction(emoji),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C0303),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA80000)),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: kEmergencyRed),
              ),
              onPressed: onOpenChat,
              child: const Text('ABRIR CHAT RÁDIO PX DA VIA'),
            ),
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3A0A0A)),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.redAccent, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
