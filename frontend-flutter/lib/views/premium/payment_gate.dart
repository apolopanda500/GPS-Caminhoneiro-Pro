import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';

class PaymentGateScreen extends StatefulWidget {
  const PaymentGateScreen({super.key, this.driverId = ''});

  final String driverId;

  @override
  State<PaymentGateScreen> createState() => _PaymentGateScreenState();
}

class _PaymentGateScreenState extends State<PaymentGateScreen> {
  bool _loading = false;

  Future<void> _ativarAssinatura() async {
    setState(() => _loading = true);
    try {
      final resp = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/payment/pix'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'driverId': widget.driverId, 'email': ''}),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _showPixDialog(data['copyAndPastePix'] ?? '', data['paymentId'] ?? '');
      } else {
        _showErro('Falha ao gerar o pagamento (${resp.statusCode}).');
      }
    } catch (_) {
      _showErro('Sem conexão com o servidor de pagamento.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPixDialog(String pixCode, String paymentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Pagamento via PIX', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Escaneie o QR Code ou use o PIX copia-e-cola:',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                pixCode.isEmpty ? 'PIX indisponível no momento.' : pixCode,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text('ID: $paymentId', style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFA80000)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Plano Premium Pro', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'DESBLOQUEIE O PODER MÁXIMO',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            const Text(
              'Navegue com infraestrutura militar por apenas R\$ 29,90/mês',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),

            _buildBenefitRow(Icons.satellite_alt, 'Visão de Satélite 3D Hiper-Realista'),
            _buildBenefitRow(Icons.cloud_download, 'Mapas Offline Completos para Zonas sem Sinal'),
            _buildBenefitRow(Icons.calculate, 'Cálculo Automático de Custo de Pedágio por Eixo'),
            _buildBenefitRow(Icons.support_agent, 'Suporte e Monitoramento de Rotas Compartilhadas'),

            const SizedBox(height: 40),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber, width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plano Mensal Logística', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 4),
                      Text('Cancele quando quiser', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  Text('R\$ 29,90', style: TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA80000),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _loading ? null : _ativarAssinatura,
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'ATIVAR ASSINATURA PREMIUM',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.redAccent, size: 24),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
