package com.gpscamioneiro.gps_camioneiro_pro

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Servico em primeiro plano que mantem o GPS Caminhoneiro Pro vivo com a
 * tela apagada: mesma tecnica dos apps de musica/video que continuam
 * tocando em segundo plano.
 *
 * O servico:
 *  - mostra uma notificacao permanente (exigida pelo Android) com o estado
 *    da viagem e acoes rapidas (abrir o app / encerrar viagem);
 *  - segura um WakeLock parcial para o CPU nao dormir durante a rota;
 *  - nao faz o trabalho pesado: o Flutter cuida do GPS e do socket.
 */
class GpsTrackingService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        criarCanal()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val acao = intent?.action
        if (acao == ACAO_PARAR) {
            pararTudo()
            return START_NOT_STICKY
        }

        val titulo = intent?.getStringExtra(EXTRA_TITULO) ?: "GPS Caminhoneiro Pro"
        val texto = intent?.getStringExtra(EXTRA_TEXTO) ?: "Rastreando sua viagem"

        iniciarNotificacao(titulo, texto)
        segurarWakeLock()

        // START_STICKY: se o Android matar o app por falta de memoria, o
        // servico volta sozinho e o rastreio continua.
        return START_STICKY
    }

    private fun iniciarNotificacao(titulo: String, texto: String) {
        abrirApp = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val parar = PendingIntent.getService(
            this,
            1,
            Intent(this, GpsTrackingService::class.java).setAction(ACAO_PARAR),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val notificacao: Notification = NotificationCompat.Builder(this, CANAL_ID)
            .setContentTitle(titulo)
            .setContentText(texto)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(abrirApp)
            .addAction(0, "Encerrar viagem", parar)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICACAO_ID,
                notificacao,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
            )
        } else {
            startForeground(NOTIFICACAO_ID, notificacao)
        }
    }

    private fun segurarWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "GPSCamioneiro::rastreio",
        ).apply {
            setReferenceCounted(false)
            acquire(24 * 60 * 60 * 1000L)
        }
    }

    private fun soltarWakeLock() {
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
        }
        wakeLock = null
    }

    private fun pararTudo() {
        soltarWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        soltarWakeLock()
        super.onDestroy()
    }

    private fun criarCanal() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CANAL_ID) != null) return
        val canal = NotificationChannel(
            CANAL_ID,
            "Rastreamento da viagem",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Mostra o app rodando em segundo plano durante a viagem"
            setShowBadge(false)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(canal)
    }

    companion object {
        const val ACAO_INICIAR = "com.gpscamioneiro.gps_camioneiro_pro.INICIAR"
        const val ACAO_PARAR = "com.gpscamioneiro.gps_camioneiro_pro.PARAR"
        const val EXTRA_TITULO = "titulo"
        const val EXTRA_TEXTO = "texto"

        private const val CANAL_ID = "gps_rastreio"
        private const val NOTIFICACAO_ID = 4711

        /** Liga o servico em primeiro plano. */
        fun iniciar(context: Context, titulo: String, texto: String) {
            val intent = Intent(context, GpsTrackingService::class.java).apply {
                action = ACAO_INICIAR
                putExtra(EXTRA_TITULO, titulo)
                putExtra(EXTRA_TEXTO, texto)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Desliga o servico em primeiro plano. */
        fun parar(context: Context) {
            val intent = Intent(context, GpsTrackingService::class.java).apply {
                action = ACAO_PARAR
            }
            context.startService(intent)
        }
    }
}
