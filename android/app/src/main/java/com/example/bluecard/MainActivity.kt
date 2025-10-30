package com.example.bluecard

import android.Manifest
import android.content.*
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val HOST_CHANNEL = "bluecard.host.service"
    private val CLIENT_CHANNEL = "bluecard.client.service"
    
    private val PERMISSION_REQUEST_CODE = 1001
    private var hostMethodChannel: MethodChannel? = null
    private var clientMethodChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    
    // Service bindings
    private var hostService: BlueCardHostService? = null
    private var clientService: BlueCardClientService? = null
    private var isHostBound = false
    private var isClientBound = false
    
    companion object {
        private const val TAG = "MainActivity"
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        setupHostChannel(flutterEngine)
        setupClientChannel(flutterEngine)
    }
    
    private fun setupHostChannel(flutterEngine: FlutterEngine) {
        hostMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HOST_CHANNEL)
        
        hostMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startHostService" -> {
                    val deviceName = call.argument<String>("deviceName") ?: "BlueCard-Host"
                    
                    if (checkAndRequestPermissions()) {
                        startHostService(deviceName)
                        result.success(true)
                    } else {
                        result.error("PERMISSION_DENIED", "Bluetooth permissions zijn vereist", null)
                    }
                }
                "stopHostService" -> {
                    stopHostService()
                    result.success(true)
                }
                "sendData" -> {
                    val data = call.argument<ByteArray>("data")
                    if (data != null) {
                        val success = hostService?.sendDataToClients(data) ?: false
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Data is null", null)
                    }
                }
                "startGame" -> {
                    hostService?.startGame()
                    result.success(true)
                }
                "getConnectedClients" -> {
                    val count = hostService?.getConnectedClientCount() ?: 0
                    result.success(count)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun setupClientChannel(flutterEngine: FlutterEngine) {
        clientMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CLIENT_CHANNEL)
        
        clientMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startClientService" -> {
                    // Start service zonder device address - service zal zelf scannen
                    if (checkAndRequestPermissions()) {
                        startClientService()
                        result.success(true)
                    } else {
                        result.error("PERMISSION_DENIED", "Bluetooth permissions required", null)
                    }
                }
                "stopClientService" -> {
                    stopClientService()
                    result.success(true)
                }
                "sendDataToHost" -> {
                    val data = call.argument<ByteArray>("data")
                    if (data != null) {
                        val success = clientService?.sendData(data) ?: false
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Data is null", null)
                    }
                }
                "isConnected" -> {
                    val connected = clientService?.isConnectedToHost() ?: false
                    result.success(connected)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun checkAndRequestPermissions(): Boolean {
        val permissionsNeeded = mutableListOf<String>()
        
        // Permissions voor Android 12+ (API 31+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(Manifest.permission.BLUETOOTH_CONNECT)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_ADVERTISE) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(Manifest.permission.BLUETOOTH_ADVERTISE)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(Manifest.permission.BLUETOOTH_SCAN)
            }
        }
        
        // Location permission
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            permissionsNeeded.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        
        // Foreground service permission (Android 14+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE) != PackageManager.PERMISSION_GRANTED) {
                permissionsNeeded.add(Manifest.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE)
            }
        }
        
        if (permissionsNeeded.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissionsNeeded.toTypedArray(), PERMISSION_REQUEST_CODE)
            return false
        }
        
        return true
    }
    
    // Host Service Management
    private fun startHostService(deviceName: String) {
        Log.d(TAG, "🚀 Starting Host Service: $deviceName")
        
        val intent = Intent(this, BlueCardHostService::class.java).apply {
            action = BlueCardHostService.ACTION_START
            putExtra(BlueCardHostService.EXTRA_DEVICE_NAME, deviceName)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        
        // Bind to service
        bindService(intent, hostServiceConnection, Context.BIND_AUTO_CREATE)
    }
    
    private fun stopHostService() {
        Log.d(TAG, "🛑 Stopping Host Service")
        
        if (isHostBound) {
            unbindService(hostServiceConnection)
            isHostBound = false
        }
        
        val intent = Intent(this, BlueCardHostService::class.java).apply {
            action = BlueCardHostService.ACTION_STOP
        }
        startService(intent)
        hostService = null
    }
    
    private val hostServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            Log.d(TAG, "✅ Host Service connected")
            val binder = service as BlueCardHostService.LocalBinder
            hostService = binder.getService()
            isHostBound = true
            
            // Setup callbacks
            hostService?.onClientConnected = { deviceName, address ->
                mainHandler.post {
                    hostMethodChannel?.invokeMethod("onClientConnected", mapOf(
                        "name" to deviceName,
                        "address" to address
                    ))
                }
            }
            
            hostService?.onClientDisconnected = { deviceName, address ->
                mainHandler.post {
                    hostMethodChannel?.invokeMethod("onClientDisconnected", mapOf(
                        "name" to deviceName,
                        "address" to address
                    ))
                }
            }
            
            hostService?.onDataReceived = { address, data ->
                mainHandler.post {
                    hostMethodChannel?.invokeMethod("onDataReceived", mapOf(
                        "address" to address,
                        "data" to data
                    ))
                }
            }
        }
        
        override fun onServiceDisconnected(name: ComponentName?) {
            Log.d(TAG, "❌ Host Service disconnected")
            hostService = null
            isHostBound = false
        }
    }
    
    // Client Service Management
    private fun startClientService() {
        Log.d(TAG, "🚀 Starting Client Service (will scan for hosts)")
        
        val intent = Intent(this, BlueCardClientService::class.java).apply {
            action = BlueCardClientService.ACTION_START
            // Geen device address - service zal zelf scannen
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        
        // Bind to service
        bindService(intent, clientServiceConnection, Context.BIND_AUTO_CREATE)
    }
    
    private fun stopClientService() {
        Log.d(TAG, "🛑 Stopping Client Service")
        
        if (isClientBound) {
            unbindService(clientServiceConnection)
            isClientBound = false
        }
        
        val intent = Intent(this, BlueCardClientService::class.java).apply {
            action = BlueCardClientService.ACTION_STOP
        }
        startService(intent)
        clientService = null
    }
    
    private val clientServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            Log.d(TAG, "✅ Client Service connected")
            val binder = service as BlueCardClientService.LocalBinder
            clientService = binder.getService()
            isClientBound = true
            
            // Setup callbacks
            clientService?.onConnectionStateChanged = { connected ->
                mainHandler.post {
                    clientMethodChannel?.invokeMethod("onConnectionStateChanged", mapOf(
                        "connected" to connected
                    ))
                }
            }
            
            clientService?.onDataReceived = { data ->
                mainHandler.post {
                    clientMethodChannel?.invokeMethod("onDataReceived", mapOf(
                        "data" to data
                    ))
                }
            }
            
            clientService?.onGameMessage = { message ->
                mainHandler.post {
                    clientMethodChannel?.invokeMethod("onGameMessage", mapOf(
                        "message" to message
                    ))
                }
            }
        }
        
        override fun onServiceDisconnected(name: ComponentName?) {
            Log.d(TAG, "❌ Client Service disconnected")
            clientService = null
            isClientBound = false
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        
        if (isHostBound) {
            unbindService(hostServiceConnection)
        }
        if (isClientBound) {
            unbindService(clientServiceConnection)
        }
    }
}
