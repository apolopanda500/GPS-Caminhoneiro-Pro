import 'package:flutter/material.dart';

/// Posicoes iniciais dos paineis flutuantes conforme a orientacao da tela.
///
/// Corrige o problema historico: posicoes salvas no modo retrato ficavam fora
/// da tela ao girar para paisagem (e vice-versa). Este utilitario oferece
/// posicoes sensatas por orientacao e limites seguros de tela.
class OrientacaoLayout {
  const OrientacaoLayout._();

  /// True quando a tela esta mais larga que alta (paisagem).
  static bool ehPaisagem(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height;
  }

  /// Margem lateral usada pelos paineis (maior na paisagem).
  static double margem(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height ? 24.0 : 16.0;
  }

  /// Posicao inicial de um painel pela sua funcao e orientacao atual.
  ///
  /// Os [ids] suportados sao os mesmos usados no FloatingPanel da tela do
  /// mapa ('clima', 'camadas', 'chat', 'route', 'alerts', 'radio',
  /// 'assistant', 'speed_hud', 'peers', 'toolbar', 'groups', 'traffic').
  static Offset inicial(BuildContext context, String id, Size tamanho) {
    final w = tamanho.width;
    final h = tamanho.height;
    final paisagem = w > h;
    switch (id) {
      case 'clima':
        return paisagem ? Offset(16, h - 300) : Offset(16, h - 430);
      case 'camadas':
        return Offset(w - 320, 96);
      case 'chat':
        return paisagem ? Offset(w - 340, h - 380) : Offset(w - 340, h - 520);
      case 'route':
        return Offset(w - 340, 96);
      case 'alerts':
        return const Offset(16, 96);
      case 'alerts_badge':
        return const Offset(16, 96);
      case 'radio':
        return Offset(w - 70, h - 300);
      case 'assistant':
        return Offset(w - 70, h - 380);
      case 'speed_hud':
        return paisagem ? Offset(w - 220, h - 130) : Offset(w - 220, h - 230);
      case 'peers':
        return Offset(w - 220, h - 390);
      case 'toolbar':
        return paisagem ? const Offset(12, 96) : const Offset(12, 120);
      case 'groups':
        return Offset(16, h - 240);
      case 'traffic':
        return paisagem ? Offset(16, h - 220) : Offset(16, h - 300);
      default:
        return const Offset(16, 96);
    }
  }

  /// Garante que uma posicao salva caiba na tela atual (apos giro).
  ///
  /// Retorna a posicao ajustada para dentro dos limites visiveis, levando em
  /// conta o tamanho do painel e os recortes do sistema (notch, gestos).
  static Offset limitarTela(
    BuildContext context,
    Offset salvo, {
    required double larguraPainel,
    required double alturaPainel,
  }) {
    final size = MediaQuery.of(context).size;
    final recorte = MediaQuery.of(context).padding;
    final minX = recorte.left + 4.0;
    final minY = recorte.top + 4.0;
    final maxX = (size.width - larguraPainel - recorte.right - 4.0)
        .clamp(minX, size.width);
    final maxY = (size.height - alturaPainel - recorte.bottom - 4.0)
        .clamp(minY, size.height);
    return Offset(
      salvo.dx.clamp(minX, maxX),
      salvo.dy.clamp(minY, maxY),
    );
  }
}

/// Modo de leitura acessivel do app (contraste, textos e toques maiores).
///
/// Segue o padrao de leitura dos grandes apps de GPS (Waze/Maps/Uber): texto
/// legivel a distancia, alvos de toque maiores e rotulos falados pelo
/// leitor de tela. O Dynamic Type do sistema continua respeitado — este modo
/// apenas garante um piso minimo de legibilidade.
class ModoLeitura {
  const ModoLeitura._();

  /// Escala minima de texto garantida no modo de leitura.
  static const double escalaMinima = 1.2;

  /// Tamanho minimo de alvo de toque no modo de leitura (WCAG).
  static const double alvoMinimo = 48.0;

  /// Aplica o modo de leitura a uma subarvore de widgets.
  static Widget aplicar(BuildContext context, Widget filho,
      {required bool ativo}) {
    if (!ativo) return filho;
    final base = MediaQuery.of(context).textScaler;
    final escala = base.scale(1.0) < escalaMinima
        ? const TextScaler.linear(escalaMinima)
        : base;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: escala),
      child: DefaultTextStyle.merge(
        style: const TextStyle(height: 1.5),
        child: filho,
      ),
    );
  }
}
