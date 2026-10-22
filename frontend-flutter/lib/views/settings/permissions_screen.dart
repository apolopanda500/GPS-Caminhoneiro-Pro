import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:gps_camioneiro_pro/core/native/servico_rastreio.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';

class _PermissaoItem {
  final String titulo;
  final String descricao;
  final Permission permissao;
  final bool sistema;
  final IconData icone;

  const _PermissaoItem({
    required this.titulo,
    required this.descricao,
    required this.permissao,
    this.sistema = false,
    this.icone = Icons.shield_outlined,
  });
}

/// Tela de confirmacao das permissões do Android e dos **acessos
/// especiais** (economizador de bateria, servico em primeiro plano,
/// sobreposicao, alarme exato, etc.).
///
/// O motorista pode confirmar tudo de uma vez ("PERMITIR TUDO") ou item a
/// item. O app explica o porque de cada acesso: localizacao, camara,
/// microfone, bluetooth, wifi e sensores.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PermissionsScreen()),
    );
  }

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final Map<Permission, PermissionStatus> _status = {};
  bool _carregando = true;
  bool _servicoRodando = false;
  bool _pedindo = false;

  static const List<_PermissaoItem> _itens = [
    _PermissaoItem(
      titulo: 'Localização (em uso)',
      descricao:
          'Posiciona o caminhão no mapa, na rota e nos sinais da estrada.',
      permissao: Permission.locationWhenInUse,
      icone: Icons.my_location,
    ),
    _PermissaoItem(
      titulo: 'Localização em segundo plano',
      descricao:
          'Mantém o GPS ativo com a tela bloqueada durante toda a viagem.',
      permissao: Permission.locationAlways,
      icone: Icons.gps_fixed,
    ),
    _PermissaoItem(
      titulo: 'Notificações',
      descricao: 'Avisos de alertas, chegadas, alarmes e o aviso de que o app '
          'está rodando em segundo plano.',
      permissao: Permission.notification,
      icone: Icons.notifications_active,
    ),
    _PermissaoItem(
      titulo: 'Câmera',
      descricao: 'Foto do caminhão e do perfil do motorista.',
      permissao: Permission.camera,
      icone: Icons.photo_camera,
    ),
    _PermissaoItem(
      titulo: 'Microfone',
      descricao: 'Gravação de voz no rádio PX da estrada.',
      permissao: Permission.microphone,
      icone: Icons.mic,
    ),
    _PermissaoItem(
      titulo: 'Arquivos/fotos',
      descricao: 'Escolher e salvar as fotos de perfil e do veículo.',
      permissao: Permission.photos,
      icone: Icons.photo_library,
    ),
    _PermissaoItem(
      titulo: 'Bluetooth',
      descricao: 'Comunicação por proximidade e sensores sem fio do veículo '
          '(telemetria, Tags e beacons na estrada).',
      permissao: Permission.bluetooth,
      icone: Icons.bluetooth,
    ),
    _PermissaoItem(
      titulo: 'Wi-Fi e rede móvel',
      descricao: 'Ler a qualidade da rede para escolher a melhor conexão e '
          'continuar mandando a posição na estrada.',
      permissao: Permission.nearbyWifiDevices,
      icone: Icons.wifi,
    ),
    _PermissaoItem(
      titulo: 'Sensores do veículo',
      descricao:
          'Acelerômetro e sensores do caminhão para economizar bateria sem perder o rastreio.',
      permissao: Permission.sensors,
      icone: Icons.vibration,
    ),
    _PermissaoItem(
      titulo: 'Sensores de movimento',
      descricao:
          'Detecta que o caminhao parou para economizar bateria sem perder o '
          'rastreio.',
      permissao: Permission.activityRecognition,
      icone: Icons.directions_car,
    ),
    _PermissaoItem(
      titulo: 'Alarme exato',
      descricao: 'Dispara o aviso de chegada no horário certo, mesmo em Doze.',
      permissao: Permission.scheduleExactAlarm,
      sistema: true,
      icone: Icons.alarm,
    ),
    _PermissaoItem(
      titulo: 'Ignorar otimização de bateria',
      descricao:
          'Impede o Android de desligar o GPS e a rede durante a rodagem.',
      permissao: Permission.ignoreBatteryOptimizations,
      sistema: true,
      icone: Icons.battery_saver,
    ),
    _PermissaoItem(
      titulo: 'Sobreposição na tela',
      descricao: 'Exibe o HUD de velocidade sobre outros aplicativos.',
      permissao: Permission.systemAlertWindow,
      sistema: true,
      icone: Icons.picture_in_picture_alt,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _atualizar();
  }

  Future<void> _atualizar() async {
    for (final item in _itens) {
      try {
        _status[item.permissao] = await item.permissao.status;
      } catch (_) {
        _status[item.permissao] = PermissionStatus.denied;
      }
    }
    final servico = await ServicoRastreio.instancia.ativo();
    if (!mounted) return;
    setState(() {
      _servicoRodando = servico;
      _carregando = false;
    });
  }

  Future<void> _solicitar(_PermissaoItem item) async {
    try {
      final resultado = await item.permissao.request();
      if (!mounted) return;
      setState(() => _status[item.permissao] = resultado);
      if (resultado.isPermanentlyDenied || resultado.isRestricted) {
        await openAppSettings();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não foi possível abrir a permissão agora.')),
      );
    }
  }

  /// Pede todas as permissões de uma vez (o Android vai mostrando uma a uma).
  Future<void> _permitirTudo() async {
    setState(() => _pedindo = true);
    for (final item in _itens) {
      if (!mounted) break;
      final status = _status[item.permissao];
      if (status?.isGranted == true) continue;
      try {
        final resultado = await item.permissao.request();
        if (mounted) setState(() => _status[item.permissao] = resultado);
      } catch (_) {
        // Segue para a proxima: uma permissao negada nao trava as outras.
      }
    }
    // Liga o rastreio em segundo plano depois das permissoes.
    await ServicoRastreio.instancia.iniciar(
      titulo: 'GPS Caminhoneiro Pro',
      texto: 'Rastreando sua viagem - GPS e rede ativos',
    );
    await ServicoRastreio.instancia.pedirIsencaoDeBateria();
    await _atualizar();
    if (!mounted) return;
    setState(() => _pedindo = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Permissões revisadas. App pronto para a estrada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ink = tema.colorScheme.onSurface;
    final muted = ink.withValues(alpha: 0.6);
    final concedidas = _status.values.where((s) => s.isGranted).length;
    final pendentes = _itens.length - concedidas;

    return Scaffold(
      backgroundColor: tema.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Permissões e acessos'),
        backgroundColor: tema.colorScheme.surface,
        foregroundColor: ink,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _atualizar,
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: tema.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$concedidas de ${_itens.length} acessos confirmados',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pendentes == 0
                              ? 'Tudo pronto: o app roda 24/7 com a tela apagada.'
                              : '$pendentes ainda faltam. Sem eles o app funciona, '
                                  'mas some o GPS em segundo plano, os alarmes '
                                  'ou os avisos.',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: _pedindo ? null : _permitirTudo,
                            icon: _pedindo
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.verified_user),
                            label:
                                Text(_pedindo ? 'PEDINDO...' : 'PERMITIR TUDO'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _cartao(
                  context,
                  icone: Icons.bolt,
                  titulo: 'Rodar 24/7 em segundo plano',
                  texto: _servicoRodando
                      ? 'Ligado: o app continua na estrada com a tela apagada.'
                      : 'Desligado: ligue o expediente para o GPS e a rede '
                          'continuarem working.',
                  ok: _servicoRodando,
                  acao: _servicoRodando
                      ? null
                      : () async {
                          await ServicoRastreio.instancia.iniciar(
                            titulo: 'GPS Caminhoneiro Pro',
                            texto: 'Rastreando sua viagem - GPS e rede ativos',
                          );
                          await _atualizar();
                        },
                ),
                const SizedBox(height: 12),
                ..._itens.map(_tile),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _cartao(
    BuildContext context, {
    required IconData icone,
    required String titulo,
    required String texto,
    required bool ok,
    VoidCallback? acao,
  }) {
    final tema = Theme.of(context);
    final ink = tema.colorScheme.onSurface;
    return Card(
      color: tema.colorScheme.surface,
      child: ListTile(
        leading: Icon(icone, color: ok ? Colors.green : kEmergencyRed),
        title: Text(titulo, style: TextStyle(color: ink)),
        subtitle: Text(texto, style: const TextStyle(fontSize: 12)),
        trailing: acao == null
            ? const Icon(Icons.check_circle, color: Colors.green)
            : TextButton(onPressed: acao, child: const Text('LIGAR')),
      ),
    );
  }

  Widget _tile(_PermissaoItem item) {
    final status = _status[item.permissao];
    final ok = status?.isGranted ?? false;
    final tema = Theme.of(context);
    final ink = tema.colorScheme.onSurface;
    return Card(
      color: tema.colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          item.icone,
          color: ok ? Colors.green : kEmergencyRed,
        ),
        title: Text(item.titulo, style: TextStyle(color: ink)),
        subtitle: Text(
          item.descricao,
          style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 12),
        ),
        trailing: ok
            ? const Text('OK',
                style:
                    TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
            : TextButton(
                onPressed: () => _solicitar(item),
                child: Text(item.sistema ? 'ABRIR' : 'PERMITIR'),
              ),
        isThreeLine: true,
      ),
    );
  }
}
