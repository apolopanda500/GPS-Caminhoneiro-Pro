import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/database/local_cache.dart';
import 'package:gps_camioneiro_pro/core/premium/premium_policy.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/views/history/travel_history_screen.dart';
import 'package:gps_camioneiro_pro/views/premium/payment_gate.dart';
import 'package:gps_camioneiro_pro/views/profile/profile_screen.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/map_controls_panel.dart';
import 'package:gps_camioneiro_pro/views/settings/appearance_screen.dart';
import 'package:gps_camioneiro_pro/views/settings/permissions_screen.dart';
import 'package:gps_camioneiro_pro/views/settings/sons_screen.dart';

/// Configuracoes do app: **poucos botoes, cada um abrindo um grupo
/// completo**. Tudo que o motorista usa no dia a dia (rede, chat, radio,
/// clima, empresa, sinalizar) fica direto no mapa.
class SettingsScreen extends StatelessWidget {
  /// Acoes do mapa chamadas a partir das configuracoes.
  final VoidCallback? onLimparSinais;
  final VoidCallback? onSairDaConta;

  const SettingsScreen({
    super.key,
    this.onLimparSinais,
    this.onSairDaConta,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onLimparSinais,
    VoidCallback? onSairDaConta,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          onLimparSinais: onLimparSinais,
          onSairDaConta: onSairDaConta,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ink = tema.colorScheme.onSurface;
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final premium = PremiumPolicy.hasPremiumAccess(
        isPremium: auth.driver?.isPremium ?? false, now: DateTime.now());

    return Scaffold(
      backgroundColor: tema.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: tema.colorScheme.surface,
        foregroundColor: ink,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ---------------------------------------------- perfil e plano
          _item(
            context,
            icone: Icons.person,
            titulo: auth.driver?.name ?? 'Motorista',
            subtitulo: auth.driver?.email ?? '',
            trailing: premium
                ? const Text('PREMIUM',
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold))
                : const Text('FREE',
                    style: TextStyle(
                        color: Colors.amber, fontWeight: FontWeight.bold)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          _item(
            context,
            icone: Icons.workspace_premium,
            titulo: 'Meu plano',
            subtitulo: premium
                ? 'Premium ativo: tudo liberado'
                : 'Assinar o Premium e liberar tudo',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PaymentGateScreen(driverId: auth.driver?.driverId ?? ''),
              ),
            ),
          ),
          const Divider(height: 26),

          // ---------------------------------------------- GPS
          _item(
            context,
            icone: Icons.gps_fixed,
            titulo: 'GPS e rota',
            subtitulo:
                '${settings.trackingEnabled ? 'Rastreando' : 'Pausado'} • '
                '${settings.gpsIntervalSeconds}s entre posições'
                '${settings.batterySaver ? ' • economia ligada' : ''}',
            onTap: () => _abrirGps(context, settings),
          ),

          // ---------------------------------------------- mapa
          _item(
            context,
            icone: Icons.tune,
            titulo: 'Mapa e gráficos',
            subtitulo:
                'Camada, trânsito ao vivo, 3D, chuva, nuvens, relevo, '
                'qualidade, FPS, cor da linha e aparência dos painéis',
            onTap: () => _abrirMapa(context, settings),
          ),

          // ---------------------------------------------- sons
          _item(
            context,
            icone: Icons.record_voice_over,
            titulo: 'Sons e voz',
            subtitulo:
                'Voz das paradas, voz do aparelho, rádio, alarms e sons '
                'personalizados',
            onTap: () => SonsScreen.show(context),
          ),

          // ---------------------------------------------- aparencia
          _item(
            context,
            icone: Icons.palette_outlined,
            titulo: 'Aparência',
            subtitulo: 'Transparência e cor dos painéis do mapa',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppearanceScreen()),
            ),
          ),

          // ---------------------------------------------- permissoes
          _item(
            context,
            icone: Icons.shield,
            titulo: 'Permissões e energia',
            subtitulo:
                'Confirmar tudo de uma vez e manter o app vivo 24/7',
            onTap: () => PermissionsScreen.show(context),
          ),
          const Divider(height: 26),

          // ---------------------------------------------- dados
          _item(
            context,
            icone: Icons.history,
            titulo: 'Histórico de viagens',
            subtitulo: 'Km rodados e viagens concluídas',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TravelHistoryScreen()),
            ),
          ),
          _item(
            context,
            icone: Icons.cleaning_services,
            titulo: 'Limpar sinais do mapa',
            subtitulo: 'Apaga os sinais que você marcou no mapa',
            onTap: () {
              onLimparSinais?.call();
              Navigator.of(context).pop();
            },
          ),
          _item(
            context,
            icone: Icons.delete_sweep,
            titulo: 'Limpar cache offline',
            subtitulo: 'Apaga alertas e mensagens salvos no aparelho',
            onTap: () => _limparCache(context),
          ),
          _item(
            context,
            icone: Icons.logout,
            titulo: 'Sair da conta',
            cor: Colors.redAccent,
            onTap: () {
              onSairDaConta?.call();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  /// GPS: um grupo so com o que importa para a estrada.
  void _abrirGps(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final tema = Theme.of(ctx);
        final ink = tema.colorScheme.onSurface;
        final muted = ink.withValues(alpha: 0.6);
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setState) => ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                Text('GPS e rota',
                    style: TextStyle(
                        color: ink, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(Icons.power_settings_new, color: ink),
                  title: Text('Expediente e GPS', style: TextStyle(color: ink)),
                  subtitle: Text(
                    settings.trackingEnabled
                        ? 'Ligado • ${settings.dayStartedLabel}'
                        : 'Desligado • GPS pausado',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  value: settings.trackingEnabled,
                  onChanged: (v) async {
                    if (v) {
                      await settings.startDay();
                    } else {
                      await settings.endDay();
                    }
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(Icons.location_on, color: ink),
                  title:
                      Text('Localização em segundo plano', style: TextStyle(color: ink)),
                  subtitle: Text('Continua navegando com a tela bloqueada',
                      style: TextStyle(color: muted, fontSize: 12)),
                  value: settings.backgroundLocation,
                  onChanged: settings.setBackgroundLocation,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(Icons.battery_saver, color: ink),
                  title: Text('Economia de bateria', style: TextStyle(color: ink)),
                  subtitle: Text(
                    settings.batterySaver
                        ? 'Ligada: pede posição a cada ${settings.intervaloGpsReal}s'
                        : 'Desligada: GPS sempre no máximo',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  value: settings.batterySaver,
                  onChanged: (v) async {
                    await settings.setBatterySaver(v);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                Text('Intervalo de atualização',
                    style: TextStyle(color: ink, fontWeight: FontWeight.bold)),
                Text(
                  settings.batterySaver
                      ? 'Com a economia ligada o app usa ${settings.intervaloGpsReal}s.'
                      : '${settings.gpsIntervalSeconds}s entre posições',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                Slider(
                  value: settings.gpsIntervalSeconds.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '${settings.gpsIntervalSeconds}s',
                  onChanged: (v) {
                    settings.setGpsInterval(v.round());
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Mapa e graficos: TUDO em um painel so.
  void _abrirMapa(BuildContext context, SettingsProvider settings) {
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

  Future<void> _limparCache(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await LocalCache.clearAll();
      messenger.showSnackBar(const SnackBar(content: Text('Cache offline limpo.')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível limpar o cache.')),
      );
    }
  }

  Widget _item(
    BuildContext context, {
    required IconData icone,
    required String titulo,
    String? subtitulo,
    Widget? trailing,
    Color? cor,
    required VoidCallback onTap,
  }) {
    final tema = Theme.of(context);
    final ink = tema.colorScheme.onSurface;
    final muted = ink.withValues(alpha: 0.6);
    return ListTile(
      leading: Icon(icone, color: cor ?? kEmergencyRed),
      title: Text(titulo, style: TextStyle(color: cor ?? ink)),
      subtitle: subtitulo == null
          ? null
          : Text(subtitulo, style: TextStyle(color: muted, fontSize: 12)),
      trailing: trailing ?? Icon(Icons.chevron_right, color: muted),
      onTap: onTap,
    );
  }
}
