import 'package:flutter/material.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/data/models/truck_config.dart';
import 'package:gps_camioneiro_pro/data/models/driver_model.dart';
import 'package:gps_camioneiro_pro/providers/navigation_provider.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/views/map/map_screen.dart';
import 'package:provider/provider.dart';

class TruckSetupScreen extends StatefulWidget {
  const TruckSetupScreen({super.key});

  @override
  State<TruckSetupScreen> createState() => _TruckSetupScreenState();
}

class _TruckSetupScreenState extends State<TruckSetupScreen> {
  final _heightController = TextEditingController(text: '4.40');
  final _widthController = TextEditingController(text: '2.50');
  final _lengthController = TextEditingController(text: '13.50');
  final _weightController = TextEditingController(text: '45.00');
  final _axleController = TextEditingController(text: '2');
  final _nameController = TextEditingController();
  final _modelController = TextEditingController();
  final _cargoController = TextEditingController();
  bool _hazmat = false;

  /// Palavras que indicam carga perigosa: ligam o HAZMAT sozinho.
  static const List<String> _cargasPerigosas = [
    'inflamavel',
    'inflamável',
    'toxica',
    'tóxica',
    'corrosiv',
    'explosiv',
    'radioativ',
    'radioativ',
    'perec',
    'quimic',
    'bateria',
    'gas',
    'combustivel',
    'combustível',
  ];

  /// O tipo de carga escolhido e perigoso?
  bool get _cargaPerigosa {
    final t = _cargoController.text.toLowerCase();
    return _cargasPerigosas.any((p) => t.contains(p));
  }

  /// Ao digitar o tipo de carga, o HAZMAT liga sozinho se for perigosa.
  void _aoMudarCarga(String valor) {
    setState(() {
      if (_cargaPerigosa) _hazmat = true;
    });
  }

  /// Cartao do HAZMAT: explica o que a opcao faz e liga/desliga.
  Widget _cartaoHazmat() {
    final perigo = _cargaPerigosa;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: (perigo ? kEmergencyRed : Colors.white).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              (perigo ? kEmergencyRed : Colors.white24).withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: perigo ? kEmergencyRed : Colors.white70, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Carga perigosa (HAZMAT)',
                  style: TextStyle(
                    color: perigo ? kEmergencyRed : kLightText,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Switch(
                value: _hazmat,
                onChanged: (val) => setState(() => _hazmat = val),
                activeThumbColor: kEmergencyRed,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            perigo
                ? 'Detectado pelo tipo de carga. A rota vai evitar túneis e '
                    'pontes com restrição, e os caminhoneiros perto recebem '
                    'um aviso na rede.'
                : 'Ative se a carga for inflamável, tóxica, corrosiva ou '
                    'explosiva. A rota evita túneis e pontes com restrição '
                    'de altura e avisa os caminhoneiros perto na rede.',
            style: TextStyle(
              color: kLightText.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Caminhão'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text('DADOS DO MOTORISTA',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildField('Nome do Motorista', _nameController),
            const SizedBox(height: 12),
            const Text('DIMENSÕES E CARGA',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildField('Altura (m)', _heightController),
            const SizedBox(height: 12),
            _buildField('Largura (m)', _widthController),
            const SizedBox(height: 12),
            _buildField('Comprimento (m)', _lengthController),
            const SizedBox(height: 12),
            _buildField('Peso total (ton)', _weightController),
            const SizedBox(height: 12),
            _buildField('Número de eixos', _axleController),
            const SizedBox(height: 12),
            _buildField('Modelo do Caminhão', _modelController),
            const SizedBox(height: 12),
            _buildField('Tipo de Carga', _cargoController,
                onChanged: _aoMudarCarga),
            const SizedBox(height: 14),
            _cartaoHazmat(),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  final auth = context.read<AuthProvider>();
                  final current = auth.driver;
                  final driverId = current?.driverId ??
                      'drv_${DateTime.now().millisecondsSinceEpoch}';

                  final config = TruckConfig(
                    driverId: driverId,
                    height: double.tryParse(_heightController.text) ?? 4.40,
                    width: double.tryParse(_widthController.text) ?? 2.50,
                    length: double.tryParse(_lengthController.text) ?? 13.50,
                    weight: double.tryParse(_weightController.text) ?? 45.00,
                    axleCount: int.tryParse(_axleController.text) ?? 2,
                    hazmat: _hazmat,
                  );
                  context.read<NavigationProvider>().setTruckConfig(config);

                  final name = _nameController.text.isNotEmpty
                      ? _nameController.text
                      : (current?.name ?? 'Motorista');

                  auth.setDriver(DriverModel(
                    driverId: driverId,
                    email: current?.email ?? '',
                    name: name,
                    isPremium: current?.isPremium ?? false,
                    truckHeight: config.height,
                    truckWeight: config.weight,
                    axleCount: config.axleCount,
                    hazmat: config.hazmat,
                    truckModel: _modelController.text.isNotEmpty
                        ? _modelController.text
                        : null,
                    cargoType: _cargoController.text.isNotEmpty
                        ? _cargoController.text
                        : null,
                  ));

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            MapScreen(driverId: driverId, driverName: name)),
                  );
                },
                child: const Text('Salvar e Iniciar Navegação V2X'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.text,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kLightText),
      ),
    );
  }
}
