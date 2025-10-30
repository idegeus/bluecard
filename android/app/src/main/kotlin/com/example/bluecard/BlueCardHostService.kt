package com.example.bluecard

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground Service voor BlueCard Host
 * Beheert GATT Server + interne ClientService instance voor unified ervaring
 */
class BlueCardHostService : Service() {
    
    companion object {
        private const val TAG = "BlueCardHost"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "bluecard_host_channel"
        
        const val ACTION_START = "com.example.bluecard.START_HOST"
        const val ACTION_STOP = "com.example.bluecard.STOP_HOST"
        
        const val EXTRA_DEVICE_NAME = "device_name"
    }
    
    private val binder = LocalBinder()
    private var gattServer: BlueCardGattServer? = null
    private val connectedClientAddresses = mutableSetOf<String>()
    private var deviceName = "BlueCard-Host"
    private var lastSyncTime = 0L
    private var isGameStarted = false
    
    // Callbacks voor Flutter
    var onClientConnected: ((String, String) -> Unit)? = null
    var onClientDisconnected: ((String, String) -> Unit)? = null
    var onDataReceived: ((String, ByteArray) -> Unit)? = null
    
    inner class LocalBinder : Binder() {
        fun getService(): BlueCardHostService = this@BlueCardHostService
    }
    
    override fun onBind(intent: Intent?): IBinder {
        return binder
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "🖥️ HostService created")
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                deviceName = intent.getStringExtra(EXTRA_DEVICE_NAME) ?: "BlueCard-Host"
                startForeground(NOTIFICATION_ID, createNotification("Starting...", 0))
                startGattServer()
            }
            ACTION_STOP -> {
                stopSelf()
            }
        }
        return START_STICKY
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "BlueCard Host Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "GATT Server and game hosting"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(status: String, playerCount: Int): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        val stopIntent = Intent(this, BlueCardHostService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        val syncStatus = if (lastSyncTime > 0) {
            val elapsed = (System.currentTimeMillis() - lastSyncTime) / 1000
            "${elapsed}s ago"
        } else {
            "Not synced"
        }
        
        val gameStatus = if (isGameStarted) "🎮 Game Active" else "⏳ Lobby"
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("BlueCard - Host")
            .setContentText("$gameStatus | $playerCount players | $status")
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("$gameStatus\n👥 Players: $playerCount\n📡 Sync: $syncStatus\n📱 $deviceName"))
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_delete, "Stop", stopPendingIntent)
            .setOngoing(true)
            .build()
    }
    
    private fun updateNotification(status: String) {
        val notification = createNotification(status, connectedClientAddresses.size)
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun startGattServer() {
        Log.d(TAG, "🚀 Starting GATT server...")
        
        if (gattServer == null) {
            gattServer = BlueCardGattServer(this)
        }
        
        // Setup callbacks
        gattServer?.onClientConnected = { name, address ->
            Log.d(TAG, "✅ Client connected: $name ($address)")
            val wasNew = connectedClientAddresses.add(address)
            if (wasNew) {
                Log.d(TAG, "📊 New unique client, total: ${connectedClientAddresses.size}")
                updateNotification("${connectedClientAddresses.size} clients connected")
                onClientConnected?.invoke(name, address)
            } else {
                Log.d(TAG, "⚠️ Client $address already in set (duplicate connection event)")
            }
        }
        
        gattServer?.onClientDisconnected = { name, address ->
            Log.d(TAG, "❌ Client disconnected: $name ($address)")
            val wasRemoved = connectedClientAddresses.remove(address)
            if (wasRemoved) {
                Log.d(TAG, "📊 Client removed, remaining: ${connectedClientAddresses.size}")
                updateNotification("${connectedClientAddresses.size} clients connected")
                onClientDisconnected?.invoke(name, address)
            } else {
                Log.d(TAG, "⚠️ Client $address not in set (already removed)")
            }
        }
        
        gattServer?.onDataReceived = { address, data ->
            Log.d(TAG, "📨 Data received from $address: ${data.size} bytes")
            lastSyncTime = System.currentTimeMillis()
            updateNotification("${connectedClientAddresses.size} clients connected")
            onDataReceived?.invoke(address, data)
        }
        
        val success = gattServer?.startServer(deviceName) ?: false
        
        if (success) {
            Log.d(TAG, "✅ GATT server started as: $deviceName")
            updateNotification("Waiting for players...")
        } else {
            Log.e(TAG, "❌ Failed to start GATT server")
            updateNotification("Failed to start")
        }
    }
    
    /**
     * Stuur data naar alle verbonden clients
     */
    fun sendDataToClients(data: ByteArray): Boolean {
        val success = gattServer?.sendDataToClients(data) ?: false
        if (success) {
            lastSyncTime = System.currentTimeMillis()
            updateNotification("${connectedClientAddresses.size} clients connected")
        }
        return success
    }
    
    /**
     * Start het spel - no new clients allowed
     */
    fun startGame() {
        isGameStarted = true
        updateNotification("Game started!")
    }
    
    fun getConnectedClientCount(): Int = connectedClientAddresses.size
    
    fun isGameStarted(): Boolean = isGameStarted
    
    fun getLastSyncTime(): Long = lastSyncTime
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🛑 HostService destroyed")
        
        gattServer?.stopServer()
        gattServer = null
        connectedClientAddresses.clear()
        isGameStarted = false
    }
}
