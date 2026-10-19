import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class _PermissaoItem {
  final String titulo;
  final String descricao;
  final Permission permissao;
  final bool sistema;

  const _PermissaoItem({
    required this.titulo,
    required this.descricao,
    required this.permissao,
    this.sistema = false,
  });
}

/// Tela de confirmacao individual de cada permissao do Android.
/// Cada item e confirmado pelo usuario (um por vez) e mostra o estado atual.
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

  static const List<_PermissaoItem> _itens = [
    _PermissaoItem(
      titulo: 'Localização (em uso)',
      descricao: 'Necessária para posicionar o caminhão no mapa e na rota.',
      permissao: Permission.locationWhenInUse,
    ),
    _PermissaoItem(
      titulo: 'Localização em segundo plano',
      descricao: 'Mantém o GPS ativo com a tela bloqueada durante a viagem.',
      permissao: Permission.locationAlways,
    ),
    _PermissaoItem(
      titulo: 'Notificações',
      descricao: 'Avisos de alertas, chegadas e conclusão de viagem.',
      permissao: Permission.notification,
    ),
    _PermissaoItem(
      titulo: 'Câmera',
      descricao: 'Foto do caminhão e do perfil do motorista.',
      permissao: Permission.camera,
    ),
    _PermissaoItem(
      titulo: 'Microfone',
      descricao: 'Gravação de voz no rádio PX da estrada.',
      permissao: Permission.microphone,
    ),
    _PermissaoItem(
      titulo: 'Arquivos/fotos',
      descricao: 'Salvar e escolher fotos de perfil e do veículo.',
      permissao: Permission.photos,
    ),
    _PermissaoItem(
      titulo: 'Ignorar otimização de bateria',
      descricao: 'Impede o Android de desligar o GPS durante a rodagem.',
      permissao: Permission.ignoreBatteryOptimizations,
      sistema: true,
    ),
    _PermissaoItem(
      titulo: 'Sobreposição na tela',
      descricao: 'Exibe o HUD de velocidade sobre outros aplicativos.',
      permissao: Permission.systemAlertWindow,
      sistema: true,
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
    if (!mounted) return;
    setState(() => _carregando = false);
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
        const SnackBar(content: Text('Não foi possível abrir a permissão agora.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final concedidas =
        _status.values.where((s) => s.isGranted).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissões do app'),
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
                Text(
                  '$concedidas de ${_itens.length} permissões confirmadas.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Confirme uma por uma. O app continua funcionando mesmo com '
                  'permissões negadas — apenas os recursos correspondentes '
                  'ficam desativados.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                ..._itens.map(_tile),
              ],
            ),
    );
  }

  Widget _tile(_PermissaoItem item) {
    final status = _status[item.permissao];
    final ok = status?.isGranted ?? false;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          color: ok ? Colors.green : Colors.orange,
        ),
        title: Text(item.titulo),
        subtitle: Text(item.descricao),
        trailing: ok
            ? const Text('OK',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
            : TextButton(
                onPressed: () => _solicitar(item),
                child: Text(item.sistema ? 'ABRIR' : 'PERMITIR'),
              ),
        isThreeLine: true,
      ),
    );
  }
}
