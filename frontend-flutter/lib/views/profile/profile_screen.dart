import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';
import 'package:gps_camioneiro_pro/data/models/driver_model.dart';
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
  late String _icon;
  bool _salvandoFoto = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final d = context.read<AuthProvider>().driver;
    _name = TextEditingController(text: d?.name ?? '');
    _truckModel = TextEditingController(text: d?.truckModel ?? '');
    _cargoType = TextEditingController(text: d?.cargoType ?? '');
    _icon = d?.truckIcon ?? AppConstants.truckIcons.first;
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
      // Foto em boa qualidade: 1600 px de lado maior e 92% de compressao
      // (antes 512 px e 70%, o que deixava a imagem borrada).
      final x = await picker.pickImage(
        source: origem,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
        requestFullMetadata: false,
      );
      if (x == null || !mounted) return;
      final bytes = await File(x.path).readAsBytes();
      if (bytes.length > 2200000) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Foto grande demais. Escolha uma menor.')));
        return;
      }
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
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

  @override
  void dispose() {
    _name.dispose();
    _truckModel.dispose();
    _cargoType.dispose();
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
    final carga = _cargoType.text.trim().isEmpty ? null : _cargoType.text.trim();

    // Grava no servidor (quando ha) e sempre no aparelho: o perfil nao pode
    // sumir ao trocar de celular ou reiniciar o app.
    final ok = await auth.updateProfile(
      name: nome,
      truckModel: modelo,
      cargoType: carga,
    );
    if (!mounted) return;

    // O icone do caminhao e local: a API ainda nao guarda esse campo.
    auth.setDriver(DriverModel(
      driverId: current.driverId,
      email: current.email,
      name: nome,
      isPremium: current.isPremium,
      truckHeight: current.truckHeight,
      truckWeight: current.truckWeight,
      axleCount: current.axleCount,
      hazmat: current.hazmat,
      avatarUrl: current.avatarUrl,
      truckPhotoUrl: current.truckPhotoUrl,
      truckModel: modelo,
      cargoType: carga,
      truckIcon: _icon,
      role: current.role,
      helpType: current.helpType,
      companyName: current.companyName,
      companyLat: current.companyLat,
      companyLon: current.companyLon,
    ));

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
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
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
                        ? Image.network(
                            driver!.avatarUrl!,
                            width: 92,
                            height: 92,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Text(_icon, style: const TextStyle(fontSize: 46)),
                          )
                        : Text(_icon, style: const TextStyle(fontSize: 46)),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: _salvandoFoto
                        ? null
                        : () => _escolherFoto('avatar'),
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
              onPressed:
                  _salvandoFoto ? null : () => _escolherFoto('truck'),
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
                      color: selected ? theme.colorScheme.primary : muted.withValues(alpha: 0.3),
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
  const _Field({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    );
  }
}
