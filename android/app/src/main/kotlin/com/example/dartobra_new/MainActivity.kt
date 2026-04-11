package com.maodeobraoficial.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            val expirationChannel = NotificationChannel(
                "expiration_alerts",
                "Alertas de Expiração",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notificações sobre perfis próximos da expiração"
                enableLights(true)
                lightColor = Color.parseColor("#EA580C")
                enableVibration(true)
            }

            val chatChannel = NotificationChannel(
                "chat_messages",
                "Mensagens e Solicitações",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notificações de mensagens e solicitações de chat"
                enableLights(true)
                lightColor = Color.BLUE
                enableVibration(true)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(expirationChannel)
            notificationManager?.createNotificationChannel(chatChannel)
        }
    }
}