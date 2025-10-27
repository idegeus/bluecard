package com.example.bluecard

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "bluecard.ble.peripheral"
    private lateinit var blePeripheralManager: BlePeripheralManager
    private lateinit var methodChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        blePeripheralManager = BlePeripheralManager(this)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
                // Set up connection callback
        blePeripheralManager.connectionCallback = object : BlePeripheralManager.ConnectionCallback {
            override fun onClientConnected(deviceName: String, deviceAddress: String) {
                Log.i("MainActivity", "Client connected: $deviceName ($deviceAddress)")
                runOnUiThread {
                    methodChannel.invokeMethod("onClientConnected", mapOf(
                        "name" to deviceName,
                        "address" to deviceAddress
                    ))
                }
            }
            
            override fun onClientDisconnected(deviceName: String, deviceAddress: String) {
                Log.i("MainActivity", "Client disconnected: $deviceName ($deviceAddress)")
                runOnUiThread {
                    methodChannel.invokeMethod("onClientDisconnected", mapOf(
                        "name" to deviceName,
                        "address" to deviceAddress
                    ))
                }
            }
            
            override fun onDataReceived(deviceAddress: String, data: String) {
                Log.i("MainActivity", "Data received from $deviceAddress: $data")
                runOnUiThread {
                    methodChannel.invokeMethod("onDataReceived", mapOf(
                        "address" to deviceAddress,
                        "data" to data
                    ))
                }
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAdvertising" -> {
                    val serviceUuid = call.argument<String>("serviceUuid")
                    val deviceName = call.argument<String>("deviceName")
                    
                    if (serviceUuid != null && deviceName != null) {
                        blePeripheralManager.startAdvertising(serviceUuid, deviceName) { success ->
                            result.success(success)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Missing serviceUuid or deviceName", null)
                    }
                }
                
                "stopAdvertising" -> {
                    blePeripheralManager.stopAdvertising { success ->
                        result.success(success)
                    }
                }
                
                "isPeripheralSupported" -> {
                    result.success(blePeripheralManager.isPeripheralSupported())
                }
                
                "setupGattServer" -> {
                    val serviceUuid = call.argument<String>("serviceUuid")
                    val characteristicUuid = call.argument<String>("characteristicUuid")
                    
                    if (serviceUuid != null && characteristicUuid != null) {
                        blePeripheralManager.setupGattServer(serviceUuid, characteristicUuid) { success ->
                            result.success(success)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Missing UUIDs", null)
                    }
                }
                
                "sendData" -> {
                    val data = call.argument<String>("data")
                    if (data != null) {
                        blePeripheralManager.sendData(data) { success ->
                            result.success(success)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Missing data", null)
                    }
                }
                
                "getConnectedClients" -> {
                    result.success(blePeripheralManager.getConnectedClients())
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
