import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';
import 'package:gps_camioneiro_pro/core/utils/fotos_motorista.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _truckModel;
  late final TextEditingController _cargoType;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _axles;
  late String _icon;
  late bool _hazmat;
  bool _salvandoFoto = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final d = context.read<AuthProvider>().driver;
    _name = TextEditingController(text: d?.name ?? '');
    _truckModel = TextEditingController(text: d?.truckModel ?? '');
    _cargoType = TextEditingController(text: d?.cargoType ?? '');
    _height = TextEditingController(
        text: (d?.truckHeight ?? 4.40).toStringAsFixed(2));
    _weight = TextEditingController(
        text: (d?.truckWeight ?? 45.0).toStringAsFixed(2));
    _axles = TextEditingController(text: '${d?.axleCount ?? 2}');
    _icon = d?.truckIcon ?? AppConstants.truckIcons.first;
    _hazmat = d?.hazmat ?? false;
  }

  /// Abre seletor de foto (galeria ou câmera) e envia via dataURL.
  Future<void> _escolherFoto(String kind) async {
    if (_salvandoFoto) return;
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    setState(() => _salvandoFoto = true);
    try {
      final origem = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Escolher da galeria'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tirar foto'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
      if (origem == null || !mounted) return;
      final picker = ImagePicker();
      // Foto em boa qualidade: 1600 px de lado maior e 90% de compressao.
      final x = await picker.pickImage(
        source: origem,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (x == null || !mounted) return;
      final pronta = await _prepararFoto(File(x.path));
      if (pronta == null) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Não foi possível preparar essa foto. '
                'Tente outra imagem.')));
        return;
      }
      final dataUrl =
          'data:${pronta.mime};base64,${base64Encode(pronta.bytes)}';
      final ok = await auth.uploadPhotoUrl(dataUrl: dataUrl, kind: kind);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(
            ok ? 'Foto atualizada!' : 'Foto salva localmente (sem servidor).'),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível carregar a foto.')));
      }
    } finally {
      if (mounted) setState(() => _salvandoFoto = false);
    }
  }

  /// Prepara a foto para o perfil: aceita imagens grandes/pesadas da galeria e
  /// reduz automaticamente ate caber no limite (sem obrigar o usuario a
  /// escolher outra foto).
  Future<_FotoPronta?> _prepararFoto(File arquivo) async {
    const limite = 1800000;
    Uint8List bytes;
    try {
      bytes = await arquivo.readAsBytes();
    } catch (_) {
      return null;
    }
    if (bytes.length <= limite) return _FotoPronta(bytes, 'image/jpeg');
    var largura = 1280;
    var atual = bytes;
    while (largura >= 480) {
      try {
        final codec = await ui.instantiateImageCodec(atual, targetWidth: largura);
        final frame = await codec.getNextFrame();
        final dados = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        frame.image.dispose();
        if (dados == null) break;
        final png = dados.buffer.asUint8List();
        if (png.length <= limite) return _FotoPronta(png, 'image/png');
        atual = png;
      } catch (_) {
        break;
      }
      largura = largura ~/ 2;
    }
    return bytes.length <= limite ? _FotoPronta(bytes, 'image/jpeg') : null;
  }

  Widget _buildAvatarImage(String url) {
    final imagem = FotosMotorista.provider(url);
    if (imagem == null) {
      return Text(_icon, style: const TextStyle(fontSize: 46));
    }
    return Image(
      key: ValueKey(url),
      image: imagem,
      width: 92,
      height: 92,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          Text(_icon, style: const TextStyle(fontSize: 46)),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _truckModel.dispose();
    _cargoType.dispose();
    _height.dispose();
    _weight.dispose();
    _axles.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final auth = context.read<AuthProvider>();
    final current = auth.driver;
    if (current == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _salvando = true);

    final nome = _name.text.trim().isEmpty ? current.name : _name.text.trim();
    final modelo =
        _truckModel.text.trim().isEmpty ? null : _truckModel.text.trim();
    final carga =
        _cargoType.text.trim().isEmpty ? null : _cargoType.text.trim();

    final altura = double.tryParse(_height.text.replaceAll(',', '.'));
    final peso = double.tryParse(_weight.text.replaceAll(',', '.'));
    final eixos = int.tryParse(_axles.text.trim());

    // Grava no servidor (quando ha) e sempre no aparelho: o perfil nao pode
    // sumir ao trocar de celular ou reiniciar o app.
    final ok = await auth.updateProfile(
      name: nome,
      truckModel: modelo,
      cargoType: carga,
    );
    if (!mounted) return;

    // O icone do caminhao e local: a API ainda nao guarda esse campo.
    final atualizado = auth.driver;
    if (atualizado != null) {
      auth.setDriver(atualizado.copyWith(
        name: nome,
        truckModel: modelo,
        cargoType: carga,
        truckIcon: _icon,
        truckHeight: altura != null && altura > 0
            ? altura.clamp(1.0, 8.0)
            : atualizado.truckHeight,
        truckWeight: peso != null && peso > 0
            ? peso.clamp(0.5, 120.0)
            : atualizado.truckWeight,
        axleCount:
            eixos != null && eixos > 0 ? eixos.clamp(2, 12) : atualizado.axleCount,
        hazmat: _hazmat,
      ));
    }

    setState(() => _salvando = false);
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Perfil salvo. Ícone $_icon ativo no mapa.'
          : 'Perfil salvo só neste aparelho (sem servidor).'),
    ));
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final muted = ink.withValues(alpha: 0.55);
    final driver = context.watch<AuthProvider>().driver;
    final premium = driver?.isPremium ?? false;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Meu perfil'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: ink,
        actions: [
          TextButton(
            onPressed: _salvando ? null : _salvar,
            child: Text(
              _salvando ? 'SALVANDO...' : 'SALVAR',
              style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: premium
                          ? Colors.amber.shade700
                          : theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: (driver?.avatarUrl ?? '').isNotEmpty
                        ? _buildAvatarImage(driver!.avatarUrl!) //
                        : Text(_icon, style: const TextStyle(fontSize: 46)),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: _salvandoFoto ? null : () => _escolherFoto('avatar'),
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _salvandoFoto
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.photo_camera,
                              size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: _salvandoFoto ? null : () => _escolherFoto('truck'),
              icon: const Icon(Icons.add_a_photo_outlined, size: 16),
              label: const Text('Foto do caminhão'),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              premium ? 'PLANO PREMIUM' : 'PLANO FREE',
              style: TextStyle(
                color: premium ? Colors.amber.shade700 : muted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _Label('ÍCONE DO SEU CAMINHÃO NO MAPA'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AppConstants.truckIcons.map((icon) {
              final selected = icon == _icon;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _icon = icon),
                child: Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primary.withValues(alpha: 0.2)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : muted.withValues(alpha: 0.3),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Text(icon, style: const TextStyle(fontSize: 28)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          const _Label('DADOS DO MOTORISTA'),
          const SizedBox(height: 8),
          _Field(controller: _name, label: 'Nome do motorista'),
          const SizedBox(height: 12),
          _Field(controller: _truckModel, label: 'Modelo do caminhão'),
          const SizedBox(height: 12),
          _Field(controller: _cargoType, label: 'Tipo de carga'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: _height,
                  label: 'Altura (m)',
                  tecladoNumerico: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  controller: _weight,
                  label: 'Peso (t)',
                  tecladoNumerico: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  controller: _axles,
                  label: 'Eixos',
                  tecladoNumerico: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.warning_amber_rounded,
                color: _hazmat ? Colors.orange : muted),
            title: Text(
              'Transporte de carga perigosa (HAZMAT)',
              style: TextStyle(color: ink, fontSize: 14),
            ),
            subtitle: Text(
              'Usado nas rotas para evitar vias com restricao.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
            value: _hazmat,
            onChanged: (v) => setState(() => _hazmat = v),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.email, color: muted),
            title: Text(
              driver?.email ?? '',
              style: TextStyle(color: muted, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('SALVAR PERFIL'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto ja preparada (bytes + mime) para virar data URL.
class _FotoPronta {
  final Uint8List bytes;
  final String mime;
  const _FotoPronta(this.bytes, this.mime);
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool tecladoNumerico;
  const _Field({
    required this.controller,
    required this.label,
    this.tecladoNumerico = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType:
          tecladoNumerico ? TextInputType.numberWithOptions(decimal: true) : null,
      decoration: InputDecoration(labelText: label),
    );
  }
}
