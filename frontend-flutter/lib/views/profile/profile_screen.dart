import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    final d = context.read<AuthProvider>().driver;
    _name = TextEditingController(text: d?.name ?? '');
    _truckModel = TextEditingController(text: d?.truckModel ?? '');
    _cargoType = TextEditingController(text: d?.cargoType ?? '');
    _icon = d?.truckIcon ?? AppConstants.truckIcons.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _truckModel.dispose();
    _cargoType.dispose();
    super.dispose();
  }

  void _salvar() {
    final auth = context.read<AuthProvider>();
    final current = auth.driver;
    if (current == null) return;

    auth.setDriver(DriverModel(
      driverId: current.driverId,
      email: current.email,
      name: _name.text.trim().isEmpty ? current.name : _name.text.trim(),
      isPremium: current.isPremium,
      truckHeight: current.truckHeight,
      truckWeight: current.truckWeight,
      axleCount: current.axleCount,
      hazmat: current.hazmat,
      avatarUrl: current.avatarUrl,
      truckPhotoUrl: current.truckPhotoUrl,
      truckModel: _truckModel.text.trim().isEmpty ? null : _truckModel.text.trim(),
      cargoType: _cargoType.text.trim().isEmpty ? null : _cargoType.text.trim(),
      truckIcon: _icon,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Perfil salvo. Ícone $_icon ativo no mapa.')),
    );
    Navigator.pop(context);
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
            onPressed: _salvar,
            child: Text(
              'SALVAR',
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: premium ? Colors.amber.shade700 : theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              child: Text(_icon, style: const TextStyle(fontSize: 46)),
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
              onPressed: _salvar,
              child: const Text('SALVAR PERFIL'),
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
