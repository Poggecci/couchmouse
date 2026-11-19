package com.example.couchmouse

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Runs while a host is connected. Android unregisters a HID device app as soon
 * as it is no longer visible (screen off, app switch), and some phones then let
 * their audio profiles throttle the shared Bluetooth link for the rest of the
 * connection. A foreground service keeps the app important enough to stay
 * registered.
 */
class HidConnectionService : Service() {
    companion object {
        private const val TAG = "RemoteMouseHID"
        private const val CHANNEL_ID = "hid_connection"
        private const val NOTIFICATION_ID = 1
        private const val EXTRA_HOST_NAME = "hostName"

        // Main thread only. Stopping a service before it calls startForeground
        // crashes the app, so a stop that arrives first is left to onStartCommand.
        private var wanted = false
        private var inForeground = false

        fun start(context: Context, hostName: String) {
            val intent = Intent(context, HidConnectionService::class.java)
                .putExtra(EXTRA_HOST_NAME, hostName)
            wanted = true
            try {
                context.startForegroundService(intent)
            } catch (e: IllegalStateException) {
                // Android 12+ refuses to start one from the background.
                wanted = false
                Log.w(TAG, "Could not start the connection service: ${e.message}")
            }
        }

        fun stop(context: Context) {
            wanted = false
            if (inForeground) context.stopService(Intent(context, HidConnectionService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        inForeground = false
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val hostName = intent?.getStringExtra(EXTRA_HOST_NAME) ?: "host"
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification(hostName),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification(hostName))
            }
            inForeground = true
        } catch (e: Exception) {
            Log.e(TAG, "Could not enter the foreground: ${e.message}")
            stopSelf()
        }
        if (!wanted) stopSelf()
        return START_NOT_STICKY
    }

    private fun notification(hostName: String): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Connection", NotificationManager.IMPORTANCE_LOW)
        )
        val openApp = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE)
        }
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentTitle("Connected to $hostName")
            .setContentText("Stays connected while the screen is off")
            .setContentIntent(openApp)
            .setOngoing(true)
            .build()
    }
}
