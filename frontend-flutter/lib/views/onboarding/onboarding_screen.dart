import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/core/utils/confirm.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';
import 'package:gps_camioneiro_pro/views/map/map_screen.dart';

/// Configuracao inicial do perfil (feita uma vez por conta).
///
/// O motorista escolhe se e **motorista** ou **ajudante** e termina o perfil
/// na mesma tela. Depois disso o app vai direto para o mapa.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nome = TextEditingController();
  String _papel = 'motorista';
  String _tipoAjuda = AppConstants.helperTypes.first;
  String _icone = AppConstants.helperIcons.first;

  double _altura = 4.40;
  double _peso = 45;
  double _largura = 2.50;
  double _comprimento = 13.50;
  int _eixos = 2;
  bool _cargaPerigosa = false;

  @override
  void initState() {
    super.initState();
    final driver = context.read<AuthProvider>().driver;
    _nome.text = driver?.name ?? '';
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _concluir() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe seu nome para continuar.')),
      );
      return;
    }

    await confirmarEExecutar(
      context,
      titulo: 'Concluir perfil',
      mensagem: _papel == 'ajudante'
          ? 'Voce vai entrar como AJUDANTE: acompanha a rede, ve as rotas dos '
              'motoristas, envia sinais e pode ajudar. Nao monta nem inicia rota.'
          : 'Voce vai entrar como MOTORISTA: monta suas rotas, envia sinais e '
              'acompanha a rede. As dimensoes do caminhao sao usadas para '
              'evitar pontes baixas e balancas.',
      textoConfirmar: 'ENTRAR NO APP',
      icone: Icons.check_circle_outline,
      acao: () async {
        final auth = context.read<AuthProvider>();
        final settings = context.read<SettingsProvider>();
        await auth.updateProfile(
          name: nome,
          truckModel: _papel == 'motorista' ? 'Caminhão configurado' : null,
          cargoType: _papel == 'ajudante' ? _tipoAjuda : null,
        );
        await auth.definirPapel(
          role: _papel,
          helpType: _papel == 'ajudante' ? _tipoAjuda : null,
          truckIcon: _icone,
        );
        await settings.setPerfilConfigurado(true);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MapScreen(
              driverId: auth.driver?.driverId ?? '',
              driverName: auth.driver?.name ?? nome,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final texto = overlayText(context);
    final muted = overlayTextMuted(context);
    final isAjudante = _papel == 'ajudante';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seu perfil'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('Como voce vai usar o app?',
              style: TextStyle(
                  color: texto, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Configuramos uma vez so e voce ja entra direto no mapa.',
              style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 14),
          _cartaoPapel(
            context,
            icone: Icons.local_shipping,
            titulo: 'Motorista',
            descricao: 'Monta rotas, entrega, envia sinais e acompanha a rede.',
            selecionado: !isAjudante,
            onTap: () => setState(() => _papel = 'motorista'),
          ),
          const SizedBox(height: 10),
          _cartaoPapel(
            context,
            icone: Icons.handshake,
            titulo: 'Ajudante',
            descricao:
                'Acompanha a rede, ve as rotas dos motoristas, envia sinais e ajuda.',
            selecionado: isAjudante,
            onTap: () => setState(() => _papel = 'ajudante'),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _nome,
            style: TextStyle(color: texto),
            decoration: InputDecoration(
              labelText: 'Seu nome',
              labelStyle: TextStyle(color: muted),
            ),
          ),
          if (isAjudante) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _tipoAjuda,
              items: AppConstants.helperTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _tipoAjuda = v ?? _tipoAjuda),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: AppConstants.helperIcons.map((e) {
                  final sel = e == _icone;
                  return GestureDetector(
                    onTap: () => setState(() => _icone = e),
                    child: Container(
                      width: 48,
                      margin: const EdgeInsets.only(right: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sel
                            ? kEmergencyRed.withValues(alpha: 0.25)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: sel ? kEmergencyRed : Colors.white24),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Text('Dimensoes do caminhao (evita ponte baixa e balanca)',
                style: TextStyle(
                    color: muted, fontSize: 12, fontWeight: FontWeight.bold)),
            _slider('Altura (m)', _altura, 2, 6, (v) => _altura = v),
            _slider('Peso (t)', _peso, 1, 60, (v) => _peso = v),
            _slider('Largura (m)', _largura, 1.5, 3.5, (v) => _largura = v),
            _slider('Comprimento (m)', _comprimento, 5, 25, (v) => _comprimento = v),
            _slider('Eixos', _eixos.toDouble(), 2, 12,
                (v) => _eixos = v.round()),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _cargaPerigosa,
              onChanged: (v) => setState(() => _cargaPerigosa = v),
              title: Text('Carga perigosa (HAZMAT)', style: TextStyle(color: texto)),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _concluir,
              child: const Text('CONCLUIR E ENTRAR'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartaoPapel(
    BuildContext context, {
    required IconData icone,
    required String titulo,
    required String descricao,
    required bool selecionado,
    required VoidCallback onTap,
  }) {
    final texto = overlayText(context);
    final muted = overlayTextMuted(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selecionado
              ? kEmergencyRed.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selecionado ? kEmergencyRed : Colors.white24,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Icon(icone, color: selecionado ? kEmergencyRed : muted, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: TextStyle(
                          color: texto,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(descricao,
                      style: TextStyle(color: muted, fontSize: 11)),
                ],
              ),
            ),
            Icon(
              selecionado
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selecionado ? kEmergencyRed : muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(String titulo, double valor, double min, double max,
      ValueChanged<double> onChanged) {
    final texto = overlayText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$titulo: ${valor.toStringAsFixed(valor % 1 == 0 ? 0 : 2)}',
            style: TextStyle(color: texto, fontSize: 13)),
        Slider(
          value: valor.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) => setState(() => onChanged(v)),
        ),
      ],
    );
  }
}
