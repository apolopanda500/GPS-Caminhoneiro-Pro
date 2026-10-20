package com.gpscamioneiro.gps_camioneiro_pro

import android.app.PictureInPictureParams
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Rational
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Ponte entre o Flutter e o Android.
 *
 * - `servico/rastreio`: liga/desliga o servico em primeiro plano (o app
 *   continua rodando com a tela apagada, como os apps de video/musica).
 * - `pip`: mini janela (Picture-in-Picture) - a mesma tecnologia que o
 *   YouTube Premium usa para continuar em segundo plano: a janela fica
 *   flutuando sobre os outros apps, pode ser arrastada, redimensionada e
 *   minimizada.
 * - `energia/otimizacao`: abre a tela de otimizacao de bateria para o
 *   usuario liberar o app do "economizador".
 */
class MainActivity : FlutterActivity() {

    private val canal = "com.gpscamioneiro.gps_camioneiro_pro/nativo"

    /** O app esta em modo mini (Picture-in-Picture)? */
    private var emPip = false

    /** O rastreio esta ligado? (o app so entra no mini quando esta) */
    private var rastreando = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // A partir de agora, apertar HOME abre a mini janela flutuante
        // (o GPS continua rodando por tras).
        configurarAutoEntradaNoPip()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canal)
            .setMethodCallHandler { call, resp ->
                when (call.method) {
                    "servico/iniciar" -> {
                        val titulo = call.argument<String>("titulo")
                            ?: "GPS Caminhoneiro Pro"
                        val texto = call.argument<String>("texto") ?: "Rastreando sua viagem"
                        GpsTrackingService.iniciar(this, titulo, texto)
                        rastreando = true
                        // A partir de agora, apertar HOME abre a mini janela.
                        configurarAutoEntradaNoPip()
                        resp.success(true)
                    }
                    "servico/parar" -> {
                        GpsTrackingService.parar(this)
                        rastreando = false
                        resp.success(true)
                    }
                    "servico/ativo" -> {
                        resp.success(servicoRodando())
                    }
                    "pip/entrar" -> {
                        resp.success(entrarNoPip())
                    }
                    "pip/estado" -> {
                        resp.success(emPip)
                    }
                    "pip/permitido" -> {
                        resp.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    }
                    "tela/ligar" -> {
                        val ligada = call.argument<Boolean>("ligada") ?: false
                        manterTelaLigada(ligada)
                        resp.success(true)
                    }
                    "energia/otimizacao" -> {
                        resp.success(abrirOptimizacaoDeBateria())
                    }
                    else -> resp.notImplemented()
                }
            }
    }

    /**
     * Mantem a tela acesa durante a viagem (o motorista nao deve precisar
     * tocar na tela a cada parada) e solta o bloqueio quando o app para.
     */
    private fun manterTelaLigada(ligada: Boolean) {
        if (ligada) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    /** O servico esta rodando? (a notificacao persistente e a marca) */
    private fun servicoRodando(): Boolean {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE)
            as android.app.NotificationManager
        return manager.activeNotifications.any { it.id == 4711 }
    }

    /**
     * Entra na mini janela (Picture-in-Picture).
     *
     * E a mesma tecnologia do YouTube Premium: a janela fica sobre os outros
     * apps, o usuario arrasta para onde quiser, redimensiona e minimiza.
     */
    private fun entrarNoPip(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (emPip) return true
        return try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .setTitle("GPS Caminhoneiro Pro")
                .setSubtitle("Rastreando sua viagem")
                .build()
            enterPictureInPictureMode(params)
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Android 12+ (API 31): o proprio sistema entra na mini janela quando o
     * usuario aperta HOME. E o caminho mais confiável (funciona também ao
     * voltar do mini e sair de novo) e é o que apps como YouTube Premium
     * usam.
     */
    private fun configurarAutoEntradaNoPip() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .setTitle("GPS Caminhoneiro Pro")
                .setSubtitle("Rastreando sua viagem")
                .setAutoEnterEnabled(true)
                .setSeamlessResizeEnabled(true)
                .build()
            setPictureInPictureParams(params)
        } catch (_: Exception) {
        }
    }

    /**
     * Quando o usuario sai do app (botao home), o app vira a mini janela
     * automaticamente - igual ao YouTube Premium. So entra se o rastreio
     * estiver ligado, para nao atrapalhar quem so esta navegando.
     */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            if (!emPip) entrarNoPip()
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: android.content.res.Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        emPip = isInPictureInPictureMode
        // Avisa o Flutter para desenhar a interface compacta.
        val engine = flutterEngine ?: return
        MethodChannel(engine.dartExecutor.binaryMessenger, canal)
            .invokeMethod("pip/estado", isInPictureInPictureMode)
    }

    /**
     * Leva o usuario a tela de "otimizacao de bateria" para o app nao ser
     *  morto pelo Android. Devolve true se ja estava liberado.
     */
    private fun abrirOptimizacaoDeBateria(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (pm.isIgnoringBatteryOptimizations(packageName)) return true
        try {
            val intent = Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName"),
            )
            startActivity(intent)
        } catch (_: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (_: Exception) {
                return false
            }
        }
        return false
    }
}
