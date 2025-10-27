package com.example.bluecard

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "bluecard.gatt.server"
    private var gattServer: BlueCardGattServer? = null
    private val PERMISSION_REQUEST_CODE = 1001
    private var methodChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var callbacksSetup = false
    
    companion object {
        private const val TAG = "MainActivity"
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startServer" -> {
                    val deviceName = call.argument<String>("deviceName") ?: "BlueCard-Host"
                    
                    // Check en vraag permissions
                    if (checkAndRequestPermissions()) {
                        startGattServer(deviceName, result)
                    } else {
                        result.error("PERMISSION_DENIED", "Bluetooth permissions zijn vereist", null)
                    }
                }
                "stopServer" -> {
                    stopGattServer(result)
                }
                "sendData" -> {
                    val data = call.argument<ByteArray>("data")
                    if (data != null) {
                        sendData(data, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Data is null", null)
                    }
                }
                "getConnectedClients" -> {
                    val count = gattServer?.getConnectedClientCount() ?: 0
                    result.success(count)
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
        
        // Location permission (vereist voor Bluetooth op alle Android versies)
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            permissionsNeeded.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        
        if (permissionsNeeded.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissionsNeeded.toTypedArray(), PERMISSION_REQUEST_CODE)
            return false
        }
        
        return true
    }
    
    private fun startGattServer(deviceName: String, result: MethodChannel.Result) {
        Log.d(TAG, "📱 startGattServer called with deviceName: $deviceName")
        
        if (gattServer == null) {
            Log.d(TAG, "Creating new BlueCardGattServer instance")
            gattServer = BlueCardGattServer(this)
        }
        
        // BELANGRIJK: Setup callbacks VOOR het starten van de server
        // Anders missen we early connection events
        setupGattServerCallbacks()
        
        Log.d(TAG, "Starting GATT server...")
        val success = gattServer?.startServer(deviceName) ?: false
        Log.d(TAG, "GATT server start result: $success")
        result.success(success)
    }
    
    private fun setupGattServerCallbacks() {
        if (callbacksSetup) {
            Log.d(TAG, "⚠️ Callbacks already setup, skipping")
            return
        }
        
        Log.d(TAG, "Setting up GATT server callbacks")
        
        // Setup callbacks om client events naar Flutter te sturen
        // BELANGRIJK: Post naar main thread omdat MethodChannel alleen op UI thread werkt
        gattServer?.onClientConnected = { name, address ->
            Log.d(TAG, "🔔 Callback: Client connected - $name ($address)")
            mainHandler.post {
                Log.d(TAG, "📤 Invoking Flutter method: onClientConnected")
                methodChannel?.invokeMethod("onClientConnected", mapOf(
                    "name" to name,
                    "address" to address
                ))
            }
        }
        
        gattServer?.onClientDisconnected = { name, address ->
            Log.d(TAG, "🔔 Callback: Client disconnected - $name ($address)")
            mainHandler.post {
                Log.d(TAG, "📤 Invoking Flutter method: onClientDisconnected")
                methodChannel?.invokeMethod("onClientDisconnected", mapOf(
                    "name" to name,
                    "address" to address
                ))
            }
        }
        
        gattServer?.onDataReceived = { address, data ->
            Log.d(TAG, "🔔 Callback: Data received from $address - ${data.size} bytes")
            mainHandler.post {
                Log.d(TAG, "📤 Invoking Flutter method: onDataReceived")
                methodChannel?.invokeMethod("onDataReceived", mapOf(
                    "address" to address,
                    "data" to data
                ))
            }
        }
        
        callbacksSetup = true
        Log.d(TAG, "✅ GATT server callbacks configured")
    }
    
    private fun stopGattServer(result: MethodChannel.Result) {
        gattServer?.stopServer()
        result.success(true)
    }
    
    private fun sendData(data: ByteArray, result: MethodChannel.Result) {
        val success = gattServer?.sendDataToClients(data) ?: false
        result.success(success)
    }
}