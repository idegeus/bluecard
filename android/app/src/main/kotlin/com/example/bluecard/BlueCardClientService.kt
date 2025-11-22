package com.example.bluecard

import android.app.*
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import java.util.*

/**
 * Foreground Service voor BlueCard Clients
 * Beheert BLE connectie en game state synchronisatie in achtergrond
 */
class BlueCardClientService : Service() {
    
    companion object {
        private const val TAG = "BlueCardClient"
        private const val NOTIFICATION_ID = 1002
        private const val CHANNEL_ID = "bluecard_client_channel"
        
        const val ACTION_START = "com.example.bluecard.START_CLIENT"
        const val ACTION_STOP = "com.example.bluecard.STOP_CLIENT"
        
        const val EXTRA_DEVICE_ADDRESS = "device_address"
        const val EXTRA_DEVICE_NAME = "device_name"
        
        // Service en Characteristic UUIDs
        val SERVICE_UUID: UUID = UUID.fromString("0000fff0-0000-1000-8000-00805f9b34fb")
        val CHARACTERISTIC_UUID: UUID = UUID.fromString("0000fff1-0000-1000-8000-00805f9b34fb")
    }
    
    private val binder = LocalBinder()
    private var bluetoothGatt: BluetoothGatt? = null
    private var gameCharacteristic: BluetoothGattCharacteristic? = null
    private var isConnected = false
    private var isScanning = false
    private var hostDeviceName = "Unknown"
    private var lastSyncTime = 0L
    private var currentMtu = 23  // Standaard MTU
    
    // Data buffering voor multi-packet berichten
    private val dataBuffer = StringBuilder()
    
    // BLE Scanner
    private var bluetoothLeScanner: BluetoothLeScanner? = null
    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            result?.let { scanResult ->
                val deviceName = scanResult.device.name
                if (deviceName != null && deviceName.contains("-Host-", ignoreCase = true)) {
                    Log.d(TAG, "✅ Found BlueCard host: $deviceName")
                    stopScanning()
                    hostDeviceName = deviceName
                    connectToHost(scanResult.device.address)
                }
            }
        }
        
        override fun onScanFailed(errorCode: Int) {
            Log.e(TAG, "❌ BLE Scan failed: $errorCode")
            isScanning = false
            updateNotification("Scan failed", 0)
        }
    }
    
    // Callbacks voor Flutter (via MethodChannel in MainActivity)
    var onConnectionStateChanged: ((Boolean) -> Unit)? = null
    var onDataReceived: ((ByteArray) -> Unit)? = null
    var onGameMessage: ((String) -> Unit)? = null
    
    inner class LocalBinder : Binder() {
        fun getService(): BlueCardClientService = this@BlueCardClientService
    }
    
    override fun onBind(intent: Intent?): IBinder {
        return binder
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "📱 ClientService created")
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                startForeground(NOTIFICATION_ID, createNotification("Starting...", 0))
                
                val deviceAddress = intent.getStringExtra(EXTRA_DEVICE_ADDRESS)
                
                if (deviceAddress != null) {
                    // Direct verbinden met opgegeven device
                    val deviceName = intent.getStringExtra(EXTRA_DEVICE_NAME) ?: "BlueCard Host"
                    hostDeviceName = deviceName
                    updateNotification("Connecting...", 0)
                    connectToHost(deviceAddress)
                } else {
                    // Geen device address - start scanning
                    Log.d(TAG, "🔍 No device address provided, starting scan...")
                    updateNotification("Scanning...", 0)
                    startScanning()
                }
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
                "BlueCard Client Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Game state synchronization"
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
        
        val stopIntent = Intent(this, BlueCardClientService::class.java).apply {
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
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("BlueCard - Client")
            .setContentText("$status | Sync: $syncStatus")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_delete, "Stop", stopPendingIntent)
            .setOngoing(true)
            .build()
    }
    
    private fun updateNotification(status: String, playerCount: Int = 0) {
        val notification = createNotification(status, playerCount)
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun connectToHost(deviceAddress: String) {
        Log.d(TAG, "🔌 Connecting to host: $deviceAddress")
        
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val bluetoothAdapter = bluetoothManager.adapter
        
        if (bluetoothAdapter == null) {
            Log.e(TAG, "❌ Bluetooth adapter not available")
            onConnectionStateChanged?.invoke(false)
            return
        }
        
        try {
            val device = bluetoothAdapter.getRemoteDevice(deviceAddress)
            bluetoothGatt = device.connectGatt(this, false, gattCallback)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Connection error: ${e.message}")
            onConnectionStateChanged?.invoke(false)
        }
    }
    
    private fun startScanning() {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val bluetoothAdapter = bluetoothManager.adapter
        
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            Log.e(TAG, "❌ Bluetooth not available or not enabled")
            return
        }
        
        bluetoothLeScanner = bluetoothAdapter.bluetoothLeScanner
        
        if (bluetoothLeScanner == null) {
            Log.e(TAG, "❌ BLE Scanner not available")
            return
        }
        
        isScanning = true
        Log.d(TAG, "🔍 Starting BLE scan for hosts...")
        
        try {
            // Scan zonder filters - we filteren handmatig op naam
            bluetoothLeScanner?.startScan(scanCallback)
            
            // Stop scan na 30 seconden als niets gevonden
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                if (isScanning) {
                    Log.d(TAG, "⏱️ Scan timeout - no host found")
                    stopScanning()
                    updateNotification("No host found", 0)
                }
            }, 30000)
            
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Permission denied for BLE scan: ${e.message}")
            isScanning = false
        }
    }
    
    private fun stopScanning() {
        if (isScanning) {
            Log.d(TAG, "🛑 Stopping BLE scan")
            try {
                bluetoothLeScanner?.stopScan(scanCallback)
            } catch (e: SecurityException) {
                Log.e(TAG, "❌ Permission denied for stopping scan: ${e.message}")
            }
            isScanning = false
        }
    }
    
    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    Log.d(TAG, "✅ Connected to GATT server")
                    isConnected = true
                    updateNotification("Connected to $hostDeviceName")
                    onConnectionStateChanged?.invoke(true)
                    
                    // Request grotere MTU voor betere performance
                    try {
                        val requestedMtu = 512  // Max supported MTU
                        Log.d(TAG, "📏 Requesting MTU: $requestedMtu")
                        gatt?.requestMtu(requestedMtu)
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ MTU request failed: ${e.message}")
                        gatt?.discoverServices()
                    }
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    Log.d(TAG, "❌ Disconnected from GATT server")
                    isConnected = false
                    currentMtu = 23  // Reset naar standaard
                    dataBuffer.clear() // Clear buffer bij disconnect
                    updateNotification("Disconnected")
                    onConnectionStateChanged?.invoke(false)
                }
            }
        }
        
        override fun onMtuChanged(gatt: BluetoothGatt?, mtu: Int, status: Int) {
            super.onMtuChanged(gatt, mtu, status)
            if (status == BluetoothGatt.GATT_SUCCESS) {
                currentMtu = mtu
                Log.d(TAG, "✅ MTU changed to $mtu bytes (payload: ${mtu - 3} bytes)")
            } else {
                Log.e(TAG, "❌ MTU change failed, status=$status")
            }
            // Na MTU change, discover services
            gatt?.discoverServices()
        }
        
        override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                Log.d(TAG, "📋 Services discovered")
                
                val service = gatt?.getService(SERVICE_UUID)
                if (service != null) {
                    gameCharacteristic = service.getCharacteristic(CHARACTERISTIC_UUID)
                    
                    if (gameCharacteristic != null) {
                        Log.d(TAG, "✅ Game characteristic found")
                        
                        // Enable notifications
                        gatt.setCharacteristicNotification(gameCharacteristic, true)
                        
                        // Write descriptor to enable notifications
                        val descriptor = gameCharacteristic?.getDescriptor(
                            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
                        )
                        descriptor?.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        gatt.writeDescriptor(descriptor)
                        
                        updateNotification("Ready - Connected to $hostDeviceName")
                    } else {
                        Log.e(TAG, "❌ Game characteristic not found")
                    }
                } else {
                    Log.e(TAG, "❌ Game service not found")
                }
            }
        }
        
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt?,
            characteristic: BluetoothGattCharacteristic?
        ) {
            characteristic?.value?.let { data ->
                Log.d(TAG, "📨 Data chunk received: ${data.size} bytes")
                lastSyncTime = System.currentTimeMillis()
                
                // Voeg data toe aan buffer
                val chunk = String(data)
                dataBuffer.append(chunk)
                Log.d(TAG, "🔄 Buffer size: ${dataBuffer.length} chars")
                
                // Probeer JSON berichten te parsen en verwerken
                var bufferContent = dataBuffer.toString().trim()
                
                // Blijf JSON objecten verwerken zolang er complete objecten in de buffer zitten
                while (bufferContent.isNotEmpty()) {
                    // Zoek naar het eerste complete JSON object
                    val firstBraceIndex = bufferContent.indexOf('{')
                    if (firstBraceIndex == -1) {
                        // Geen opening brace, clear buffer
                        dataBuffer.clear()
                        break
                    }
                    
                    // Tel braces om het einde van het JSON object te vinden
                    var braceCount = 0
                    var endIndex = -1
                    
                    for (i in firstBraceIndex until bufferContent.length) {
                        when (bufferContent[i]) {
                            '{' -> braceCount++
                            '}' -> {
                                braceCount--
                                if (braceCount == 0) {
                                    endIndex = i
                                    break
                                }
                            }
                        }
                    }
                    
                    if (endIndex == -1) {
                        // Geen compleet JSON object gevonden, wacht op meer data
                        Log.d(TAG, "⏳ Incomplete JSON, waiting for more chunks...")
                        break
                    }
                    
                    // Extract het complete JSON object
                    val jsonMessage = bufferContent.substring(firstBraceIndex, endIndex + 1)
                    Log.d(TAG, "✅ Complete message received: $jsonMessage")
                    
                    // Verwerk het bericht
                    onDataReceived?.invoke(jsonMessage.toByteArray())
                    onGameMessage?.invoke(jsonMessage)
                    updateNotification("Synced with $hostDeviceName")
                    
                    // Verwijder verwerkt bericht uit buffer
                    bufferContent = bufferContent.substring(endIndex + 1).trim()
                    dataBuffer.clear()
                    dataBuffer.append(bufferContent)
                }
            }
        }
    }
    
    /**
     * Stuur data naar de host (gebruikt MTU voor optimale packet size)
     */
    fun sendData(data: ByteArray): Boolean {
        if (!isConnected || gameCharacteristic == null) {
            Log.w(TAG, "⚠️ Not connected or characteristic not found")
            return false
        }
        
        try {
            // Gebruik current MTU voor optimale chunk size
            val payloadSize = currentMtu - 3  // ATT overhead is 3 bytes
            val totalChunks = (data.size + payloadSize - 1) / payloadSize
            
            Log.d(TAG, "📦 Sending ${data.size} bytes (MTU=$currentMtu, payload=$payloadSize, chunks=$totalChunks)")
            
            // Verstuur elke chunk
            for (i in 0 until totalChunks) {
                val start = i * payloadSize
                val end = minOf(start + payloadSize, data.size)
                val chunk = data.copyOfRange(start, end)
                
                gameCharacteristic?.value = chunk
                val success = bluetoothGatt?.writeCharacteristic(gameCharacteristic) ?: false
                
                if (success) {
                    Log.d(TAG, "📤 Chunk ${i + 1}/$totalChunks (${chunk.size} bytes) sent to host")
                    
                    // Kleine delay alleen bij meerdere chunks
                    if (totalChunks > 1 && i < totalChunks - 1) {
                        Thread.sleep(5) // 5ms delay
                    }
                } else {
                    Log.e(TAG, "❌ Failed to send chunk ${i + 1}")
                    return false
                }
            }
            
            Log.d(TAG, "✅ All chunks sent successfully")
            return true
            
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Permission denied: ${e.message}")
            return false
        } catch (e: InterruptedException) {
            Log.e(TAG, "❌ Interrupted while sending chunks: ${e.message}")
            return false
        }
    }
    
    fun isConnectedToHost(): Boolean = isConnected
    
    fun getLastSyncTime(): Long = lastSyncTime
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🛑 ClientService destroyed")
        
        stopScanning()
        bluetoothGatt?.disconnect()
        bluetoothGatt?.close()
        bluetoothGatt = null
        gameCharacteristic = null
        isConnected = false
    }
}
