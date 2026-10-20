import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _plano = 'mensal';
  double _valor = 4.99;

  Future<void> _ativarAssinatura() async {
    if (!AppConstants.serverConfigured) {
      _showErro('Servidor não configurado. Não é possível gerar o PIX agora.');
      return;
    }
    setState(() => _loading = true);
    try {
      final resp = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/payment/pix'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driverId': widget.driverId,
          'plan': _plano,
          'amount': _valor,
        }),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _showPixDialog(
          data['copyAndPastePix']?.toString() ?? '',
          data['paymentId']?.toString() ?? '',
          data['receiver']?.toString() ?? 'HENRIQUE DE CARVALHO',
          (data['value'] as num?)?.toDouble() ?? 29.90,
        );
      } else {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _showErro(data['error']?.toString() ??
            'Falha ao gerar o pagamento (${resp.statusCode}).');
      }
    } catch (_) {
      _showErro('Sem conexão com o servidor de pagamento.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPixDialog(
      String pixCode, String paymentId, String receiver, double value) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C0303),
        title: const Text('Pagamento via PIX',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Titular: $receiver\nValor: R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text('Use o PIX copia-e-cola abaixo no app do seu banco:',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 10),
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
              const SizedBox(height: 10),
              Text('ID: $paymentId',
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 14),
              const Text(
                'Depois de pagar, envie o comprovante no WhatsApp '
                '+55 21 98315-8911 para liberarmos o Premium.',
                style: TextStyle(color: Colors.amber, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: pixCode));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código PIX copiado.')),
              );
            },
            child: const Text('COPIAR PIX'),
          ),
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
        title: const Text('Plano Premium Pro',
            style: TextStyle(color: Colors.white)),
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
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            const Text(
              'Preço popular: R\$ 4,99/mês.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.amber,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const Text(
              'Promoção: Premium liberado para todos até 29/11/2026.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 32),
            _buildBenefitRow(Icons.campaign, 'Alertas e sinais da comunidade'),
            _buildBenefitRow(
                Icons.radio, 'Rádio e conversas entre caminhoneiros'),
            _buildBenefitRow(
                Icons.local_shipping, 'Ver outros caminhões no mapa'),
            _buildBenefitRow(
                Icons.layers, 'Ruas 3D detalhadas e prédios em 3D'),
            _buildBenefitRow(Icons.history, 'Histórico de viagens'),
            _buildBenefitRow(Icons.search, 'Busca de ruas e endereços'),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C0303),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber, width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _planCard('Mensal', 'R\$ 4,99', 'mensal', 4.99),
                      _planCard(
                          'Anual', 'R\$ 29,99', 'anual', 29.99,
                          badge: 'economize 50%'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Escolha o plano e gere o PIX abaixo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _loading ? null : _ativarAssinatura,
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'GERAR PIX ${_plano.toUpperCase()} ${_valor.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCard(String nome, String preco, String plano, double valor,
      {String? badge}) {
    final ativo = _plano == plano;
    return GestureDetector(
      onTap: () => setState(() {
        _plano = plano;
        _valor = valor;
      }),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ativo ? const Color(0xFF2A0505) : const Color(0xFF1C0303),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ativo ? Colors.red : Colors.white12,
            width: ativo ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              nome,
              style: TextStyle(
                color: ativo ? Colors.red : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (badge != null)
              Text(
                badge,
                style: const TextStyle(
                    color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 6),
            Text(
              preco,
              style: const TextStyle(
                  color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold),
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
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
