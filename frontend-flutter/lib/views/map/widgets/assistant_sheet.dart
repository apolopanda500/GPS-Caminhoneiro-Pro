import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:gps_camioneiro_pro/core/ai/assistant_engine.dart';
import 'package:gps_camioneiro_pro/core/audio/voice_service.dart';
import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';
import 'package:gps_camioneiro_pro/core/theme/app_theme.dart';
import 'package:gps_camioneiro_pro/providers/auth_provider.dart';
import 'package:gps_camioneiro_pro/providers/route_provider.dart';
import 'package:gps_camioneiro_pro/providers/settings_provider.dart';

/// Assistente da estrada: conversa com o motorista usando o estado real do
/// app (rota, paradas, sinais, limite de velocidade e clima).
class AssistantSheet extends StatefulWidget {
  const AssistantSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AssistantSheet(),
    );
  }

  @override
  State<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<AssistantSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<({String pergunta, String resposta})> _historico = [];
  bool _pensando = false;

  static const _atalhos = [
    'Como esta minha rota?',
    'Tem algum sinal perto?',
    'Qual o limite de velocidade?',
    'Preciso de ajuda na estrada',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _perguntar(String pergunta) async {
    if (pergunta.trim().isEmpty) return;
    _controller.clear();
    setState(() => _pensando = true);

    final route = context.read<RouteProvider>();
    final resposta = await _responder(pergunta, route);

    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() {
      _historico.add((pergunta: pergunta, resposta: resposta));
      _pensando = false;
    });
    _scroll.animateTo(_scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    VoiceService.instance.falar(resposta);
  }

  /// Tenta o backend (que pode usar LLM); se falhar, responde localmente.
  Future<String> _responder(String pergunta, RouteProvider route) async {
    final local = AssistantEngine.responder(
      pergunta: pergunta,
      totalParadas: route.totalStops,
      entregasFeitas: route.deliveredCount,
      alertas: const [],
      sugestoes: _atalhos,
    );
    if (!AppConstants.serverConfigured) return local;
    try {
      final auth = context.read<AuthProvider>();
      final resp = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/assistant/ask'),
            headers: auth.authHeaders,
            body: jsonEncode({
              'pergunta': pergunta,
              'contexto': {
                'totalParadas': route.totalStops,
                'entregasFeitas': route.deliveredCount,
              },
            }),
          )
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final texto = data['resposta']?.toString();
        if (texto != null && texto.trim().isNotEmpty) return texto;
      }
    } catch (_) {
      // Sem rede: segue com a resposta local.
    }
    return local;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cor = settings.overlayColor;
    final texto = overlayText(context);
    final muted = overlayTextMuted(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.auto_awesome, color: cor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Assistente da estrada',
                  style: TextStyle(
                    color: texto,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_historico.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pergunte sobre a rota, os sinais, o limite ou o clima.',
                      style: TextStyle(color: muted, fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _atalhos
                        .map((a) => ActionChip(
                              label: Text(a),
                              onPressed: () => _perguntar(a),
                            ))
                        .toList(),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView(
                controller: _scroll,
                shrinkWrap: true,
                children: _historico
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: cor.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(f.pergunta,
                                      style: TextStyle(color: texto, fontSize: 13)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.auto_awesome,
                                      color: cor, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(f.resposta,
                                        style: TextStyle(
                                            color: texto, fontSize: 13)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          if (_pensando)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cor),
                  ),
                  const SizedBox(width: 10),
                  Text('Consultando o estado da estrada...',
                      style: TextStyle(color: muted, fontSize: 12)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _perguntar,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Pergunte sobre a estrada...',
                    prefixIcon: const Icon(Icons.chat_bubble_outline, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: cor),
                onPressed: () => _perguntar(_controller.text),
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
