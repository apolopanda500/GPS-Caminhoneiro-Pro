import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';
import 'package:gps_camioneiro_pro/core/audio/sons_provider.dart';
import 'package:gps_camioneiro_pro/core/audio/voice_service.dart';
import 'package:gps_camioneiro_pro/core/database/local_cache.dart';
import 'package:gps_camioneiro_pro/core/premium/premium_policy.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/views/premium/payment_gate.dart';
import 'package:gps_camioneiro_pro/views/profile/profile_screen.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/radio_sheet.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/weather_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/map_controls_panel.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/assistant_sheet.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/chat_panel.dart';
import 'package:gps_camioneiro_pro/core/network/socket_client.dart';
import 'package:gps_camioneiro_pro/providers/weather_provider.dart';
import 'package:gps_camioneiro_pro/views/settings/appearance_screen.dart';
import 'package:gps_camioneiro_pro/views/settings/permissions_screen.dart';

class SettingsScreen extends StatelessWidget {
  /// Acoes que vivem no mapa e foram reunidas aqui para deixar o acesso
  /// mais simples (o grupo "Reconstruir").
  final VoidCallback? onCompany;
  final VoidCallback? onGrupos;
  final VoidCallback? onContatos;
  final VoidCallback? onSinalizar;
  final VoidCallback? onHistorico;
  final VoidCallback? onSairDaConta;
  final VoidCallback? onLimparSinais;

  const SettingsScreen({
    super.key,
    this.onCompany,
    this.onGrupos,
    this.onContatos,
    this.onSinalizar,
    this.onHistorico,
    this.onSairDaConta,
    this.onLimparSinais,
  });

  /// Abre o painel de clima (as coordenadas vem da ultima leitura do GPS).
  void _abrirClima(BuildContext context) {
    final clima = context.read<WeatherProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => WeatherPanel(
        latitude: clima.lastLatitude,
        longitude: clima.lastLongitude,
      ),
    );
  }

  /// Abre o painel de camadas do mapa (chuva, nuvens, relevo, 3D, cor da rota).
  void _abrirCamadas(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MapControlsPanel(
        onCamada: (modo) => settings.setLayer(modo),
        onMostrarUi: (_) {},
        uiVisivel: true,
      ),
    );
  }

  /// Abre o chat da rede.
  void _abrirChat(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final clima = context.read<WeatherProvider>();
    final driver = auth.driver;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChatPanel(
        driverId: driver?.driverId ?? '',
        driverName: driver?.name ?? 'Motorista',
        messages: const [],
        onSend: (message) {
          SocketClient().sendChatMessage(
            driverId: driver?.driverId ?? '',
            driverName: driver?.name ?? 'Motorista',
            message: message,
            lat: clima.lastLatitude ?? 0,
            lon: clima.lastLongitude ?? 0,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final premium = PremiumPolicy.hasPremiumAccess(
        isPremium: auth.driver?.isPremium ?? false,
        now: DateTime.now());
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
            subtitle: s.trackingEnabled
                ? 'Ligado • ${s.dayStartedLabel}'
                : 'Desligado • GPS pausado',
            icon: Icons.power_settings_new,
            value: s.trackingEnabled,
            onChanged: (on) => _toggleExpediente(context, s, on),
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
          // AGENTE B: camada do mapa, predios 3D, qualidade grafica e FPS
          // ficaram em UM lugar so (painel "Mapa e graficos" no mapa).
          ListTile(
            leading: const Icon(Icons.tune, color: Colors.redAccent),
            title: Text('Mapa e gráficos', style: TextStyle(color: ink)),
            subtitle: Text(
              'Camada, trânsito ao vivo, prédios 3D, chuva, nuvens, relevo, '
              'qualidade (leve/médio/pesado), FPS e cor da linha da rota.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () => _abrirCamadas(context),
          ),
          _Switch(
            title: 'Mostrar outros caminhões',
            subtitle: 'Exibe motoristas próximos no mapa',
            icon: Icons.local_shipping,
            value: s.showTrucks,
            onChanged: (on) {
              if (on && !premium) {
                _premiumLock(context, 'Comunidade de caminhoneiros');
                return;
              }
              s.setShowTrucks(on);
            },
          ),
          _Switch(
            title: 'Modo noturno',
            subtitle:
                'Escurece apenas barras e botões — o mapa continua claro para enxergar a via',
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
          const _SonsPersonalizados(),
          const _AudioSwitchMusica(),
          const _AudioSwitchEstacao(),
          const _AudioSwitchVoz(),
          const _RadioTile(),
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
          const _Section('ACESSIBILIDADE E LEITURA'),
          _Switch(
            title: 'Modo de leitura',
            subtitle: s.modoLeitura
                ? 'Ativo: textos maiores e toques mais fáceis'
                : 'Textos maiores, contraste e alvos de toque (WCAG)',
            icon: Icons.accessibility_new,
            value: s.modoLeitura,
            onChanged: s.setModoLeitura,
          ),
          const _Section('DESEMPENHO'),
          // AGENTE B: qualidade grafica, FPS alvo e FPS sao do painel do mapa
          // (um lugar so). Aqui fica so a informacao de leitura.
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: Colors.redAccent),
            title: Text('Qualidade gráfica', style: TextStyle(color: ink)),
            subtitle: Text(
              'Perfil atual: ${switch (s.renderQuality) { RenderQuality.economy => 'leve', RenderQuality.balanced => 'médio', RenderQuality.ultra => 'pesado' }} '
              '• alvo ${s.targetFps} FPS. Toque para trocar agora.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () => _abrirCamadas(context),
          ),
          const _Section('MAPA E FERRAMENTAS'),
          // AGENTE B: o mapa ficou com 5 elementos (km/h, centralizar, rota,
          // buscar, sinais). Tudo o mais mora aqui.
          ListTile(
            leading: const Icon(Icons.cloud_outlined, color: Colors.redAccent),
            title: Text('Clima e previsão', style: TextStyle(color: ink)),
            subtitle: Text(
              'Tempo real, próximas horas, 5 dias, sol e lua',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () => _abrirClima(context),
          ),
          ListTile(
            leading: const Icon(Icons.tune, color: Colors.redAccent),
            title: Text('Camadas do mapa', style: TextStyle(color: ink)),
            subtitle: Text(
              'Chuva, nuvens, relevo, prédios 3D e cor da linha da rota',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () => _abrirCamadas(context),
          ),
          ListTile(
            leading: const Icon(Icons.radio_outlined, color: Colors.redAccent),
            title: Text('Rádio da estrada', style: TextStyle(color: ink)),
            subtitle: Text(
              'Estações FM ao vivo (abre o player)',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () => RadioSheet.open(context),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: Colors.redAccent),
            title: Text('Assistente (IA)', style: TextStyle(color: ink)),
            subtitle: Text(
              'Pergunte sobre rota, sinais, limite de velocidade e clima',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () => AssistantSheet.show(context),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline, color: Colors.redAccent),
            title: Text('Chat da via', style: TextStyle(color: ink)),
            subtitle: Text(
              'Conversa com os caminhoneiros da rede',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () => _abrirChat(context),
          ),
          const _Section('APARÊNCIA DO MAPA'),
          ListTile(
            leading: const Icon(Icons.palette_outlined, color: Colors.redAccent),
            title: Text('Aparência do mapa', style: TextStyle(color: ink)),
            subtitle: Text(
              'Transparência e cor dos painéis, botão flutuante do rádio',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AppearanceScreen(),
              ),
            ),
          ),
          const _Section('RECONSTRUIR'),
          ListTile(
            leading: const Icon(Icons.factory, color: Colors.redAccent),
            title: Text('Empresa', style: TextStyle(color: ink)),
            subtitle: Text(
              'Marcar o local exato da empresa',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () {
              Navigator.of(context).pop();
              onCompany?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.group, color: Colors.redAccent),
            title: Text('Grupos e comboios', style: TextStyle(color: ink)),
            subtitle: Text(
              'Rotas compartilhadas e companhia',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () {
              Navigator.of(context).pop();
              onGrupos?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.people, color: Colors.redAccent),
            title: Text('Contatos de estrada', style: TextStyle(color: ink)),
            subtitle: Text(
              'Motoristas de confiança por perto',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () {
              Navigator.of(context).pop();
              onContatos?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_location_alt, color: Colors.redAccent),
            title: Text('Sinalizar na via', style: TextStyle(color: ink)),
            subtitle: Text(
              'Avisos, radares, pontes baixas e perigos',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () {
              Navigator.of(context).pop();
              onSinalizar?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.redAccent),
            title: Text('Histórico de viagens', style: TextStyle(color: ink)),
            subtitle: Text(
              'Km rodados e viagens concluídas',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () {
              Navigator.of(context).pop();
              onHistorico?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.redAccent),
            title: Text('Limpar sinais do mapa', style: TextStyle(color: ink)),
            subtitle: Text(
              'Apaga os sinais que voce placed no mapa',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () {
              Navigator.of(context).pop();
              onLimparSinais?.call();
            },
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
          const _Section('CONTA'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: Text('Sair da conta', style: TextStyle(color: ink)),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () {
              Navigator.of(context).pop();
              onSairDaConta?.call();
            },
          ),
        ],
      ),
    );
  }

  void _revisarPermissoes(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PermissionsScreen(),
      ),
    );
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

  Future<void> _toggleExpediente(
      BuildContext context, SettingsProvider s, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      await s.startDay();
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Bom trabalho! GPS e expediente iniciados.')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar o dia?'),
        content: const Text(
          'O GPS e o compartilhamento de posição serão pausados. A rota e os alertas continuam salvos para o próximo expediente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar rodando'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kEmergencyRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Encerrar dia'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await s.endDay();
    messenger.showSnackBar(
      const SnackBar(content: Text('Expediente encerrado. GPS pausado.')),
    );
  }

  void _premiumLock(BuildContext context, String feature) {
    final auth = context.read<AuthProvider>();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recurso Premium'),
        content: Text(
          '$feature está disponível apenas no Premium.\n\n'
          'No Free você navega com o mapa e as rotas. '
          'Assine para liberar alertas, sinais, rádio, comunidade, ruas 3D e histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Agora não'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kEmergencyRed),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PaymentGateScreen(driverId: auth.driver?.driverId ?? ''),
                ),
              );
            },
            child: const Text('Ver Premium'),
          ),
        ],
      ),
    );
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
class _AudioSwitchMusica extends StatelessWidget {
  const _AudioSwitchMusica();

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    return SwitchListTile(
      secondary: Icon(Icons.music_note, color: ink.withValues(alpha: 0.7)),
      title: Text('Música de fundo', style: TextStyle(color: ink)),
      subtitle: Text(
        'Toca desde o início do app (usa assets/audio/musica_custom.mp3 se existir)',
        style: TextStyle(color: ink.withValues(alpha: 0.55), fontSize: 12),
      ),
      value: audio.musicaLigada,
      onChanged: audio.alternarMusica,
      activeThumbColor: kEmergencyRed,
      activeTrackColor: kEmergencyRed.withValues(alpha: 0.5),
    );
  }
}

class _AudioSwitchEstacao extends StatelessWidget {
  const _AudioSwitchEstacao();

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    return SwitchListTile(
      secondary: Icon(Icons.terminal_sharp, color: ink.withValues(alpha: 0.7)),
      title: Text('Sino de estação na parada', style: TextStyle(color: ink)),
      subtitle: Text(
        'Toca um sininho de estação de trem em cada entrega concluída',
        style: TextStyle(color: ink.withValues(alpha: 0.55), fontSize: 12),
      ),
      value: audio.estacaoLigada,
      onChanged: audio.alternarEstacao,
      activeThumbColor: kEmergencyRed,
      activeTrackColor: kEmergencyRed.withValues(alpha: 0.5),
    );
  }
}

class _RadioTile extends StatelessWidget {
  const _RadioTile();

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final muted = ink.withValues(alpha: 0.55);
    return ListTile(
      leading: Icon(
        audio.radioTocando ? Icons.radio : Icons.radio_outlined,
        color: audio.radioTocando ? kEmergencyRed : muted,
      ),
      title: Text(
        audio.radioTocando
            ? 'Rádio FM: ${audio.radioEstacao}'
            : 'Rádio FM ao vivo',
        style: TextStyle(color: ink),
      ),
      subtitle: Text(
        audio.radioTocando ? 'Tocando agora • toque para parar' : 'Buscar e ouvir estações reais do Brasil',
        style: TextStyle(color: muted, fontSize: 12),
      ),
      trailing: Icon(
        audio.radioTocando ? Icons.stop : Icons.chevron_right,
        color: muted,
      ),
      onTap: () => audio.radioTocando
          ? audio.pararRadio()
          : _abrirRadio(context, audio),
    );
  }

  void _abrirRadio(BuildContext context, AudioProvider audio) {
    RadioSheet.open(context);
  }
}

class _AudioSwitchVoz extends StatelessWidget {
  const _AudioSwitchVoz();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    return StatefulBuilder(
      builder: (context, setState) => SwitchListTile(
        secondary: Icon(Icons.record_voice_over, color: ink.withValues(alpha: 0.7)),
        title: Text('Voz das paradas', style: TextStyle(color: ink)),
        subtitle: Text(
          'Fala "Chegou no ponto X de Y" ao chegar em cada cliente e avisa rota e viagem concluída',
          style: TextStyle(color: ink.withValues(alpha: 0.55), fontSize: 12),
        ),
        value: VoiceService.instance.ligada,
        onChanged: (v) async {
          await VoiceService.instance.alternar(v);
          setState(() {});
        },
        activeThumbColor: kEmergencyRed,
        activeTrackColor: kEmergencyRed.withValues(alpha: 0.5),
      ),
    );
  }
}

/// Secao de sons personalizados: importar do aparelho e atribuir por evento.
class _SonsPersonalizados extends StatelessWidget {
  const _SonsPersonalizados();

  @override
  Widget build(BuildContext context) {
    final sons = context.watch<SonsProvider>();
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final muted = ink.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            'Importe um som do celular e escolha quando ele toca.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ),
        for (final slot in SlotSom.values)
          _SlotSomTile(slot: slot, sons: sons),
      ],
    );
  }
}

class _SlotSomTile extends StatelessWidget {
  final SlotSom slot;
  final SonsProvider sons;

  const _SlotSomTile({required this.slot, required this.sons});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final muted = ink.withValues(alpha: 0.55);
    final atual = sons.som(slot);

    return ListTile(
      leading: Icon(
        atual != null ? Icons.library_music : Icons.music_off_outlined,
        color: atual != null ? kEmergencyRed : muted,
      ),
      title: Text(slot.titulo, style: TextStyle(color: ink)),
      subtitle: Text(
        atual != null
            ? '${atual.nome} • ${slot.descricao}'
            : slot.descricao,
        style: TextStyle(color: muted, fontSize: 12),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (atual != null)
            IconButton(
              tooltip: 'Ouvir',
              onPressed: () => sons.tocar(slot),
              icon: const Icon(Icons.play_arrow, color: kEmergencyRed),
            ),
          IconButton(
            tooltip: atual != null ? 'Trocar som' : 'Importar som',
            onPressed: () => _importar(context),
            icon: Icon(
              atual != null ? Icons.swap_horiz : Icons.add,
              color: muted,
            ),
          ),
          if (atual != null)
            IconButton(
              tooltip: 'Remover',
              onPressed: () => sons.remover(slot),
              icon: Icon(Icons.delete_outline, color: muted),
            ),
        ],
      ),
      onTap: atual != null ? () => sons.tocar(slot) : () => _importar(context),
    );
  }

  Future<void> _importar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await sons.importar(slot);
    if (ok) {
      await sons.tocar(slot);
      messenger.showSnackBar(
        SnackBar(content: Text('Som de ${slot.titulo} importado.')),
      );
    }
  }
}
