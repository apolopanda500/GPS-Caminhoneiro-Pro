package com.gpscamioneiro.gps_camioneiro_pro

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Ponte entre o Flutter e o Android.
 *
 * - `servico/rastreio`: liga/desliga o servico em primeiro plano (o app
 *   continua rodando com a tela apagada, como os apps de video/musica).
 * - `energia/otimizacao`: abre a tela de otimizacao de bateria para o
 *   usuario liberar o app do "economizador".
 */
class MainActivity : FlutterActivity() {

    private val canal = "com.gpscamioneiro.gps_camioneiro_pro/nativo"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canal)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "servico/iniciar" -> {
                        val titulo = call.argument<String>("titulo")
                            ?: "GPS Caminhoneiro Pro"
                        val texto = call.argument<String>("texto") ?: "Rastreando sua viagem"
                        GpsTrackingService.iniciar(this, titulo, texto)
                        result.success(true)
                    }
                    "servico/parar" -> {
                        GpsTrackingService.parar(this)
                        result.success(true)
                    }
                    "servico/ativo" -> {
                        result.success(servicoRodando())
                    }
                    "energia/otimizacao" -> {
                        result.success(abrirOptimizacaoDeBateria())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** O servico esta rodando? (a notificacao persistente e a marca) */
    private fun servicoRodando(): Boolean {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE)
            as android.app.NotificationManager
        return manager.activeNotifications.any {
            it.id == 4711
        }
    }

    /** Leva o usuario a tela de "otimizacao de bateria" para o app nao ser
     *  morto pelo Android. Devolve true se ja estava liberado. */
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
