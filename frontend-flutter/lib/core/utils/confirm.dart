import 'package:flutter/material.dart';

/// Resultado de uma acao com confirmacao.
enum Confirmacao {
  /// O usuario confirmou e a acao pode ser executada.
  confirmado,

  /// O usuario cancelou.
  cancelado,
}

/// Pede confirmacao antes de executar uma acao importante.
///
/// Retorna [Confirmacao.confirmado] somente quando o usuario confirmar.
Future<Confirmacao> confirmarAcao(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String textoConfirmar = 'CONFIRMAR',
  String textoCancelar = 'CANCELAR',
  bool destrutivo = false,
  IconData? icone,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final escuro = Theme.of(ctx).brightness == Brightness.dark;
      final cor = destrutivo
          ? const Color(0xFFE53935)
          : Theme.of(ctx).colorScheme.primary;
      return AlertDialog(
        backgroundColor: escuro ? const Color(0xFF14181D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            if (icone != null) ...[
              Icon(icone, color: cor, size: 22),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(titulo)),
          ],
        ),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(textoCancelar),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(textoConfirmar),
          ),
        ],
      );
    },
  );
  return ok == true ? Confirmacao.confirmado : Confirmacao.cancelado;
}

/// Confirma e executa a acao em um unico passo.
Future<void> confirmarEExecutar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required Future<void> Function() acao,
  String textoConfirmar = 'CONFIRMAR',
  bool destrutivo = false,
  IconData? icone,
}) async {
  final resposta = await confirmarAcao(
    context,
    titulo: titulo,
    mensagem: mensagem,
    textoConfirmar: textoConfirmar,
    destrutivo: destrutivo,
    icone: icone,
  );
  if (resposta == Confirmacao.confirmado) {
    await acao();
  }
}
