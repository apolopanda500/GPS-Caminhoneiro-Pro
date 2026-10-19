import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/database/local_cache.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/views/premium/payment_gate.dart';
import 'package:gps_camioneiro_pro/views/profile/profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final premium = auth.driver?.isPremium ?? false;
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: ink,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _Section('CONTA E PLANO'),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.redAccent),
            title: Text(
              auth.driver?.name ?? 'Motorista',
              style: TextStyle(color: ink, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              auth.driver?.email ?? '',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: _PlanBadge(premium: premium),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          ListTile(
            leading: Icon(
              premium ? Icons.verified : Icons.workspace_premium,
              color: premium ? Colors.green : Colors.amber.shade700,
            ),
            title: Text(
              premium ? 'Plano Premium ativo' : 'Plano Free',
              style: TextStyle(color: ink),
            ),
            subtitle: Text(
              premium
                  ? 'Todos os recursos liberados'
                  : 'Toque para ver os recursos do Premium',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PaymentGateScreen(driverId: auth.driver?.driverId ?? ''),
              ),
            ),
          ),
          const _Section('GPS E LOCALIZAÇÃO'),
          _Switch(
            title: 'Expediente e GPS',
            subtitle: s.dayStartedLabel,
            icon: Icons.power_settings_new,
            value: s.trackingEnabled,
            onChanged: (on) => on ? s.startDay() : s.endDay(),
          ),
          _Switch(
            title: 'Alta precisão',
            subtitle: 'Usa GPS + rede (mais preciso, gasta mais bateria)',
            icon: Icons.gps_fixed,
            value: s.highAccuracy,
            onChanged: s.setHighAccuracy,
          ),
          _Switch(
            title: 'Localização em segundo plano',
            subtitle: 'Continua navegando com a tela bloqueada',
            icon: Icons.location_on,
            value: s.backgroundLocation,
            onChanged: s.setBackgroundLocation,
          ),
          _Switch(
            title: 'Economia de bateria',
            subtitle: 'Reduz a frequência de atualização em viagens longas',
            icon: Icons.battery_saver,
            value: s.batterySaver,
            onChanged: s.setBatterySaver,
          ),
          ListTile(
            leading: const Icon(Icons.timer, color: Colors.redAccent),
            title:
                Text('Intervalo de atualização', style: TextStyle(color: ink)),
            subtitle: Text(
              '${s.gpsIntervalSeconds}s entre posições',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: s.gpsIntervalSeconds.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              activeColor: kEmergencyRed,
              label: '${s.gpsIntervalSeconds}s',
              onChanged: (v) => s.setGpsInterval(v.round()),
            ),
          ),
          const _Section('MAPA E VISUALIZAÇÃO'),
          _Switch(
            title: 'Abrir em satélite',
            subtitle: 'Desligado abre no mapa de ruas',
            icon: Icons.satellite,
            value: s.layer == MapLayerMode.satellite,
            onChanged: (v) =>
                s.setLayer(v ? MapLayerMode.satellite : MapLayerMode.streets),
          ),
          _Switch(
            title: 'Prédios em 3D',
            subtitle: 'Relevo urbano ao inclinar o mapa',
            icon: Icons.apartment,
            value: s.buildings3d,
            onChanged: s.setBuildings3d,
          ),
          _Switch(
            title: 'Mostrar outros caminhões',
            subtitle: 'Exibe motoristas próximos no mapa',
            icon: Icons.local_shipping,
            value: s.showTrucks,
            onChanged: s.setShowTrucks,
          ),
          _Switch(
            title: 'Modo noturno',
            subtitle: 'Cores suaves para dirigir à noite',
            icon: Icons.brightness_4,
            value: s.nightMode,
            onChanged: s.setNightMode,
          ),
          ListTile(
            leading: const Icon(Icons.update, color: Colors.redAccent),
            title: Text('Atualizar mapa', style: TextStyle(color: ink)),
            subtitle: Text(
              'Automático a cada 12 h • último: ${s.lastMapUpdateLabel}',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.refresh, color: muted),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await s.markMapUpdated();
              messenger.showSnackBar(
                const SnackBar(content: Text('Mapa e vias atualizados.')),
              );
            },
          ),
          const _Section('SONS E NOTIFICAÇÕES'),
          _Switch(
            title: 'Sons do app',
            subtitle: 'Desliga todos os avisos sonoros',
            icon: Icons.volume_up,
            value: s.soundEnabled,
            onChanged: s.setSoundEnabled,
          ),
          _Switch(
            title: 'Alarme de radar',
            subtitle: 'Bipe ao se aproximar de um radar',
            icon: Icons.warning,
            value: s.radarSound,
            onChanged: s.setRadarSound,
          ),
          _Switch(
            title: 'Vibração de emergência',
            subtitle: 'Vibra em perigo, ponte baixa e blitz',
            icon: Icons.vibration,
            value: s.vibration,
            onChanged: s.setVibration,
          ),
          _Switch(
            title: 'Notificações',
            subtitle: 'Avisos de alertas e mensagens',
            icon: Icons.notifications,
            value: s.pushNotifications,
            onChanged: s.setPushNotifications,
          ),
          const _Section('DESEMPENHO'),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: Colors.redAccent),
            title: Text('Qualidade gráfica', style: TextStyle(color: ink)),
            subtitle: Text(
              'Perfil de GPU/CPU. A tela usa a resolução nativa do aparelho.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: SegmentedButton<RenderQuality>(
              segments: const [
                ButtonSegment(value: RenderQuality.economy, label: Text('Eco')),
                ButtonSegment(
                    value: RenderQuality.balanced, label: Text('Equil.')),
                ButtonSegment(value: RenderQuality.ultra, label: Text('Ultra')),
              ],
              selected: {s.renderQuality},
              onSelectionChanged: (v) => s.setRenderQuality(v.first),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          _Switch(
            title: 'Mostrar FPS',
            subtitle: 'Mede o FPS real do render do app',
            icon: Icons.speed,
            value: s.showFps,
            onChanged: s.setShowFps,
          ),
          ListTile(
            leading: const Icon(Icons.memory, color: Colors.redAccent),
            title: Text('FPS alvo', style: TextStyle(color: ink)),
            subtitle:
                Text('${s.targetFps} FPS', style: TextStyle(color: muted)),
            trailing: SegmentedButton<int>(
              segments: SettingsProvider.supportedFps
                  .map((f) => ButtonSegment<int>(value: f, label: Text('$f')))
                  .toList(),
              selected: {s.targetFps},
              onSelectionChanged: (v) => s.setTargetFps(v.first),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          const _Section('PERMISSÕES DO ANDROID'),
          ListTile(
            leading: const Icon(Icons.shield, color: Colors.redAccent),
            title: Text('Revisar permissões', style: TextStyle(color: ink)),
            subtitle: Text(
              'Localização, notificações, câmera, microfone, bateria e sobreposição',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () => _revisarPermissoes(context),
          ),
          const _Section('ARMAZENAMENTO'),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            title: Text('Limpar cache offline', style: TextStyle(color: ink)),
            subtitle: Text(
              'Apaga alertas e mensagens salvos no aparelho',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () => _limparCache(context),
          ),
        ],
      ),
    );
  }

  Future<void> _revisarPermissoes(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await <Permission>[
      Permission.locationWhenInUse,
      Permission.locationAlways,
      Permission.notification,
      Permission.camera,
      Permission.microphone,
      Permission.ignoreBatteryOptimizations,
      Permission.systemAlertWindow,
    ].request();

    if (!context.mounted) return;
    final status = await openAppSettings();
    if (status) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Ajuste as permissões especiais e volte ao app.')),
      );
    }
  }

  Future<void> _limparCache(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await LocalCache.clearAll();
      messenger
          .showSnackBar(const SnackBar(content: Text('Cache offline limpo.')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Não foi possível limpar o cache.')));
    }
  }
}

class _PlanBadge extends StatelessWidget {
  final bool premium;
  const _PlanBadge({required this.premium});

  @override
  Widget build(BuildContext context) {
    final badgeColor =
        premium ? Colors.green : Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        premium ? 'PREMIUM' : 'FREE',
        style: TextStyle(
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Switch({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    return SwitchListTile(
      secondary: Icon(icon, color: ink.withValues(alpha: 0.7)),
      title: Text(title, style: TextStyle(color: ink)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: ink.withValues(alpha: 0.55), fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: kEmergencyRed,
      activeTrackColor: kEmergencyRed.withValues(alpha: 0.5),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
