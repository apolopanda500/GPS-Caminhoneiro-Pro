import 'package:flutter/material.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';

class ReportDialog extends StatefulWidget {
  final void Function(String type, String message, double lat, double lon) onSubmit;
  final double latitude;
  final double longitude;

  const ReportDialog({
    super.key,
    required this.onSubmit,
    this.latitude = -23.55052,
    this.longitude = -46.633308,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final _textController = TextEditingController();
  String _selectedType = 'texto_livre';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kDarkRedTransition,
      title: const Text(
        'Escrever Aviso no Mapa',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            dropdownColor: kDarkBlack,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Tipo de aviso',
              labelStyle: TextStyle(color: kLightText),
            ),
            items: const [
              DropdownMenuItem(value: 'texto_livre', child: Text('Texto livre')),
              DropdownMenuItem(value: 'radar', child: Text('Radar / velocidade')),
              DropdownMenuItem(value: 'ponte_baixa', child: Text('Ponte baixa')),
              DropdownMenuItem(value: 'policia', child: Text('Polícia / blitz')),
              DropdownMenuItem(value: 'balanca', child: Text('Balança obrigatória')),
              DropdownMenuItem(value: 'perigo', child: Text('Perigo na pista')),
              DropdownMenuItem(value: 'pedagio', child: Text('Pedágio')),
              DropdownMenuItem(value: 'acidente', child: Text('Acidente')),
              DropdownMenuItem(value: 'obstrucao', child: Text('Obra / obstrução')),
              DropdownMenuItem(value: 'zmrc', child: Text('Zona restrita (ZMRC)')),
              DropdownMenuItem(value: 'descanso', child: Text('Área de descanso')),
              DropdownMenuItem(value: 'estacionamento', child: Text('Estacionamento')),
              DropdownMenuItem(value: 'combustivel', child: Text('Posto de combustível')),
              DropdownMenuItem(value: 'restaurante', child: Text('Restaurante')),
              DropdownMenuItem(value: 'borracharia', child: Text('Borracharia')),
              DropdownMenuItem(value: 'ponto_apoio', child: Text('Ponto de apoio')),
              DropdownMenuItem(value: 'serra', child: Text('Serra / descida forte')),
              DropdownMenuItem(value: 'curva', child: Text('Curva perigosa')),
              DropdownMenuItem(value: 'fiscalizacao', child: Text('Fiscalização')),
            ],
            onChanged: (val) => setState(() => _selectedType = val ?? 'texto_livre'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ex: Fio elétrico baixo na pista direita...',
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSubmit(
              _selectedType,
              _textController.text,
              widget.latitude,
              widget.longitude,
            );
            Navigator.pop(context);
          },
          child: const Text('Publicar no Mapa', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
