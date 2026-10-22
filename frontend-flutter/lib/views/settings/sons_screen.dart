import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/audio/audio_provider.dart';
import 'package:gps_camioneiro_pro/providers/alert_notifier.dart';
import 'package:gps_camioneiro_pro/core/audio/sons_provider.dart';
import 'package:gps_camioneiro_pro/core/audio/voice_service.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/views/map/widgets/radio_sheet.dart';

/// Tela **Sons e voz**: tudo que o app fala ou toca em um lugar so.
///
/// - Liga/desliga os sons do app
/// - Voz das paradas: escolhe se a voz fala o **numero** da parada ou o
///   **nome do cliente**
/// - Voz do aparelho: pode trocar a voz, a velocidade e o tom
/// - Radio da estrada
/// - Sons personalizados (importados do celular) por momento
/// - Alarme de radar, vibracao e notificacoes
class SonsScreen extends StatefulWidget {
  const SonsScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SonsScreen()),
    );
  }

  @override
  State<SonsScreen> createState() => _SonsScreenState();
}

class _SonsScreenState extends State<SonsScreen> {
  List<VozDisponivel> _vozes = const [];
  bool _carregandoVozes = true;

  @override
  void initState() {
    super.initState();
    _carregarVozes();
  }

  Future<void> _carregarVozes() async {
    final v = await VoiceService.instance.listarVozes();
    if (!mounted) return;
    setState(() {
      _vozes = v;
      _carregandoVozes = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ink = tema.colorScheme.onSurface;
    final muted = ink.withValues(alpha: 0.6);
    final settings = context.watch<SettingsProvider>();
    final audio = context.watch<AudioProvider>();
    final voz = VoiceService.instance;

    return Scaffold(
      backgroundColor: tema.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Sons e voz'),
        backgroundColor: tema.colorScheme.surface,
        foregroundColor: ink,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _titulo(context, 'GERAL'),
          SwitchListTile(
            secondary: Icon(Icons.volume_up, color: ink.withValues(alpha: 0.7)),
            title: Text('Sons do app', style: TextStyle(color: ink)),
            subtitle: Text('Desliga todos os avisos sonoros',
                style: TextStyle(color: muted, fontSize: 12)),
            value: settings.soundEnabled,
            onChanged: settings.setSoundEnabled,
            activeThumbColor: kEmergencyRed,
            activeTrackColor: kEmergencyRed.withValues(alpha: 0.5),
          ),
          SwitchListTile(
            secondary:
                Icon(Icons.notifications, color: ink.withValues(alpha: 0.7)),
            title: Text('Notificações', style: TextStyle(color: ink)),
            subtitle: Text('Avisos de alertas e mensagens',
                style: TextStyle(color: muted, fontSize: 12)),
            value: settings.pushNotifications,
            onChanged: settings.setPushNotifications,
            activeThumbColor: kEmergencyRed,
            activeTrackColor: kEmergencyRed.withValues(alpha: 0.5),
          ),
          SwitchListTile(
            secondary: Icon(Icons.warning, color: ink.withValues(alpha: 0.7)),
            title: Text('Alarme de radar', style: TextStyle(color: ink)),
            subtitle: Text('Bipe ao se aproximar de um radar',
                style: TextStyle(color: muted, fontSize: 12)),
            value: settings.radarSound,
            onChanged: settings.setRadarSound,
            activeThumbColor: kEmergencyRed,
            activeTrackColor: kEmergencyRed.withValues(alpha: 0.5),
          ),
          // Testes: o motorista confere o som e a vibracao sem sair da
          // estrada.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await context.read<AudioProvider>().tocarChegada();
                    HapticFeedback.mediumImpact();
                  },
                  icon: const Icon(Icons.notifications_active, size: 16),
                  label: const Text('SINo DE CHEGADA'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    AlertNotifier.triggerRadarWarning();
                    HapticFeedback.mediumImpact();
                  },
                  icon: const Icon(Icons.warning, size: 16),
                  label: const Text('ALARME DE RADAR'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    HapticFeedback.vibrate();
                  },
                  icon: const Icon(Icons.vibration, size: 16),
                  label: const Text('VIBRACAO'),
                ),
              ],
            ),
          ),
          SwitchListTile(
            secondary: Icon(Icons.vibration, color: ink.withValues(alpha: 0.7)),
            title: Text('Vibração de emergência', style: TextStyle(color: ink)),
            subtitle: Text('Vibra em perigo, ponte baixa e blitz',
                style: TextStyle(color: muted, fontSize: 12)),
            value: settings.vibration,
            onChanged: settings.setVibration,
            activeThumbColor: kEmergencyRed,
            activeTrackColor: kEmergencyRed.withValues(alpha: 0.5),
          ),
          const Divider(height: 28),
          _titulo(context, 'VOZ DAS PARADAS'),
          SwitchListTile(
            secondary: Icon(Icons.notifications_active,
                color: ink.withValues(alpha: 0.7)),
            title: Text('Só o sino (sem falar as ruas)',
                style: TextStyle(color: ink)),
            subtitle: Text(
              'Toca apenas o sino de chegada e de estação. A voz fica muda.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            value: voz.somenteSino,
            onChanged: (v) async {
              await voz.definirSomenteSino(v);
              setState(() {});
            },
            activeThumbColor: kEmergencyRed,
            activeTrackColor: kEmergencyRed.withValues(alpha: 0.5),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Como a voz fala (perfil)',
              style: TextStyle(color: ink, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in PerfilVoz.values)
                  ChoiceChip(
                    label: Text(p.rotulo),
                    selected: voz.perfil == p,
                    onSelected: (_) async {
                      await voz.definirPerfil(p);
                      setState(() {});
                    },
                    selectedColor: kEmergencyRed.withValues(alpha: 0.35),
                    labelStyle: TextStyle(
                      color: ink,
                      fontSize: 12,
                      fontWeight:
                          voz.perfil == p ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: Text(
              voz.perfil.descricao,
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _botaoTeste(
                  context,
                  icone: Icons.notifications,
                  rotulo: 'OUVIR O SINO DE CHEGADA',
                  onTap: () async {
                    final audio = context.read<AudioProvider>();
                    final sons = context.read<SonsProvider>();
                    await audio.tocarChegada();
                    await sons.tocar(SlotSom.sinoEstacao);
                  },
                ),
                _botaoTeste(
                  context,
                  icone: Icons.train,
                  rotulo: 'OUVIR O SINO DE ESTAÇÃO',
                  onTap: () {
                    final sons = context.read<SonsProvider>();
                    return sons.tocar(SlotSom.sinoEstacao);
                  },
                ),
                _botaoTeste(
                  context,
                  icone: Icons.exit_to_app,
                  rotulo: 'OUVIR O SOM DE SAÍDA',
                  onTap: () {
                    final sons = context.read<SonsProvider>();
                    return sons.tocar(SlotSom.saidaParada);
                  },
                ),
              ],
            ),
          ),
          SwitchListTile(
            secondary: Icon(Icons.record_voice_over,
                color: ink.withValues(alpha: 0.7)),
            title: Text('Voz das paradas', style: TextStyle(color: ink)),
            subtitle: Text(
              'Fala a chegada em cada cliente e a próxima parada',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            value: voz.ligada,
            onChanged: (v) async {
              await voz.alternar(v);
              setState(() {});
            },
            activeThumbColor: kEmergencyRed,
            activeTrackColor: kEmergencyRed.withValues(alpha: 0.5),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Como a voz anuncia as paradas',
              style: TextStyle(color: ink, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ModoFalaParada>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
              ),
              segments: const [
                ButtonSegment(
                  value: ModoFalaParada.numero,
                  label: Text('Números'),
                  icon: Icon(Icons.pin_outlined, size: 14),
                ),
                ButtonSegment(
                  value: ModoFalaParada.nomeCliente,
                  label: Text('Nome do cliente'),
                  icon: Icon(Icons.person_outline, size: 14),
                ),
              ],
              selected: {voz.modoFalaParada},
              onSelectionChanged: (v) async {
                await voz.definirModoFala(v.first);
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 14),
          _titulo(context, 'VOZ DO APPARELHO'),
          ListTile(
            leading: Icon(Icons.record_voice_over,
                color: ink.withValues(alpha: 0.7)),
            title: Text('Voz', style: TextStyle(color: ink)),
            subtitle: Text(
              voz.vozEscolhida ?? 'Padrão do aparelho',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _escolherVoz,
          ),
          _slider(
            context,
            'Velocidade da fala',
            voz.velocidade,
            0.2,
            1.0,
            (v) => voz.definirVozAjustes(velocidade: v),
            (v) => '${(v * 100).round()}%',
          ),
          _slider(
            context,
            'Tom da voz',
            voz.tom,
            0.5,
            2.0,
            (v) => voz.definirVozAjustes(tom: v),
            (v) => v.toStringAsFixed(1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: OutlinedButton.icon(
              onPressed: () => voz.falar(
                'Chegou na parada numero dois de cinco. Proxima parada, numero tres, a duzentos metros.',
              ),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('TESTAR A VOZ'),
            ),
          ),
          const Divider(height: 28),
          _titulo(context, 'RÁDIO DA ESTRADA'),
          ListTile(
            leading: Icon(
              audio.radioTocando ? Icons.radio : Icons.radio_outlined,
              color: audio.radioTocando
                  ? kEmergencyRed
                  : ink.withValues(alpha: 0.7),
            ),
            title: Text(
              audio.radioTocando
                  ? 'Tocando: ${audio.radioEstacao}'
                  : 'Rádio FM ao vivo',
              style: TextStyle(color: ink),
            ),
            subtitle: Text(
              audio.radioTocando
                  ? 'Toque para parar'
                  : 'Estações reais do Brasil',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: Icon(
              audio.radioTocando ? Icons.stop : Icons.chevron_right,
              color: muted,
            ),
            onTap: () => setState(() {
              if (audio.radioTocando) {
                audio.pararRadio();
              } else {
                RadioSheet.open(context);
              }
            }),
          ),
          const Divider(height: 28),
          _titulo(context, 'SONS PERSONALIZADOS'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Importe um som do celular e escolha quando ele toca.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
          for (final slot in SlotSom.values) _SlotSomTile(slot: slot),
        ],
      ),
    );
  }

  /// Botao de teste de som (ouvir o sino, o som de saida, etc).
  Widget _botaoTeste(
    BuildContext context, {
    required IconData icone,
    required String rotulo,
    required Future<void> Function() onTap,
  }) {
    final tema = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: () async {
        await onTap();
      },
      icon: Icon(icone, size: 16),
      label: Text(rotulo, style: const TextStyle(fontSize: 11)),
      style: OutlinedButton.styleFrom(
        foregroundColor: tema.colorScheme.onSurface,
        side: BorderSide(
            color: tema.colorScheme.onSurface.withValues(alpha: 0.3)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _titulo(BuildContext context, String texto) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        texto,
        style: TextStyle(
          color: tema.colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _slider(
    BuildContext context,
    String titulo,
    double valor,
    double min,
    double max,
    Future<void> Function(double) onChanged,
    String Function(double) rotulo,
  ) {
    final tema = Theme.of(context);
    final ink = tema.colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(titulo, style: TextStyle(color: ink)),
              ),
              Text(rotulo(valor),
                  style: TextStyle(
                      color: ink.withValues(alpha: 0.6), fontSize: 12)),
            ],
          ),
        ),
        Slider(
          value: valor.clamp(min, max),
          min: min,
          max: max,
          divisions: 20,
          label: rotulo(valor),
          onChanged: (v) {
            onChanged(v);
            setState(() {});
          },
        ),
      ],
    );
  }

  /// Escolhe a voz do aparelho (lista as vozes em portugues).
  Future<void> _escolherVoz() async {
    if (_carregandoVozes) {
      await _carregarVozes();
    }
    if (!mounted) return;
    final tema = Theme.of(context);
    final ink = tema.colorScheme.onSurface;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: tema.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Voz do app',
                  style: TextStyle(
                      color: ink, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.settings_voice),
              title: Text('Padrão do aparelho', style: TextStyle(color: ink)),
              onTap: () async {
                await VoiceService.instance.definirVoz(null);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              },
            ),
            for (final v in _vozes)
              ListTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: Text(v.rotulo, style: TextStyle(color: ink)),
                subtitle: Text(v.local,
                    style: TextStyle(
                        color: ink.withValues(alpha: 0.6), fontSize: 11)),
                onTap: () async {
                  await VoiceService.instance
                      .definirVoz(v.nome, local: v.local);
                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() {});
                },
              ),
            if (_vozes.isEmpty && !_carregandoVozes)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Nenhuma voz em portugues encontrada no aparelho. '
                  'Instale o pacote de voz do Google em Configuracoes > Idioma.',
                  style: TextStyle(
                      color: ink.withValues(alpha: 0.6), fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Item de um som personalizado (importado do celular).
class _SlotSomTile extends StatelessWidget {
  final SlotSom slot;

  const _SlotSomTile({required this.slot});

  @override
  Widget build(BuildContext context) {
    final sons = context.watch<SonsProvider>();
    final tema = Theme.of(context);
    final ink = tema.colorScheme.onSurface;
    final muted = ink.withValues(alpha: 0.6);
    final atual = sons.som(slot);

    return ListTile(
      leading: Icon(
        atual != null ? Icons.library_music : Icons.music_off_outlined,
        color: atual != null ? kEmergencyRed : muted,
      ),
      title: Text(slot.titulo, style: TextStyle(color: ink)),
      subtitle: Text(
        atual != null ? '${atual.nome} • ${slot.descricao}' : slot.descricao,
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
    final sons = context.read<SonsProvider>();
    final ok = await sons.importar(slot);
    if (ok) {
      await sons.tocar(slot);
      messenger.showSnackBar(
        SnackBar(content: Text('Som de ${slot.titulo} importado.')),
      );
    }
  }
}
