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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Caminhão'),
        backgroundColor: kDarkRedTransition,
        foregroundColor: Colors.white,
      ),
      backgroundColor: kDarkBlack,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text('DADOS DO MOTORISTA', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildField('Nome do Motorista', _nameController),
            const SizedBox(height: 12),
            const Text('DIMENSÕES E CARGA', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
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
            _buildField('Tipo de Carga', _cargoController),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text(
                'Carga perigosa (HAZMAT)',
                style: TextStyle(color: kLightText),
              ),
              value: _hazmat,
              onChanged: (val) => setState(() => _hazmat = val),
              activeThumbColor: kEmergencyRed,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  final auth = context.read<AuthProvider>();
                  final current = auth.driver;
                  final driverId = current?.driverId ?? 'drv_${DateTime.now().millisecondsSinceEpoch}';

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
                    truckModel: _modelController.text.isNotEmpty ? _modelController.text : null,
                    cargoType: _cargoController.text.isNotEmpty ? _cargoController.text : null,
                  ));

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => MapScreen(driverId: driverId, driverName: name)),
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

  Widget _buildField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kLightText),
      ),
    );
  }
}
