package com.example.bluecard

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.pm.PackageManager
import android.os.ParcelUuid
import android.util.Log
import java.util.*

class BlePeripheralManager(private val context: Context) {
    
    private val TAG = "BlePeripheralManager"
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var bluetoothGattServer: BluetoothGattServer? = null
    private var bluetoothManager: BluetoothManager? = null
    
    private var isAdvertising = false
    private var gameService: BluetoothGattService? = null
    private var gameCharacteristic: BluetoothGattCharacteristic? = null
    private var connectedDevices = mutableSetOf<BluetoothDevice>()
    
    init {
        bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter
        bluetoothLeAdvertiser = bluetoothAdapter?.bluetoothLeAdvertiser
    }
    
    fun isPeripheralSupported(): Boolean {
        return context.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE) &&
               bluetoothAdapter?.isMultipleAdvertisementSupported == true
    }
    
    fun startAdvertising(serviceUuid: String, deviceName: String, callback: (Boolean) -> Unit) {
        if (!isPeripheralSupported()) {
            Log.e(TAG, "BLE Peripheral not supported")
            callback(false)
            return
        }
        
        if (isAdvertising) {
            Log.w(TAG, "Already advertising")
            callback(true)
            return
        }
        
        try {
            // Set the Bluetooth adapter name to our custom device name
            bluetoothAdapter?.name = deviceName
            
            Log.i(TAG, "🔧 Setting up BLE advertising...")
            Log.i(TAG, "   Device name: $deviceName")
            Log.i(TAG, "   Service UUID: $serviceUuid")
            
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
                .setConnectable(true)
                .setTimeout(0) // Advertise indefinitely
                .build()
            
            val data = AdvertiseData.Builder()
                .setIncludeDeviceName(false)  // Don't include in main data
                .setIncludeTxPowerLevel(false)
                .addServiceUuid(ParcelUuid.fromString(serviceUuid))
                .build()
            
            val scanResponse = AdvertiseData.Builder()
                .setIncludeDeviceName(true)   // Include device name in scan response
                .build()
            
            Log.i(TAG, "📊 Advertising data size optimization:")
            Log.i(TAG, "   Device name: $deviceName (${deviceName.length} chars)")
            Log.i(TAG, "   Service UUID: $serviceUuid")
            Log.i(TAG, "   Using scan response for device name to save space")
            
            bluetoothLeAdvertiser?.startAdvertising(settings, data, scanResponse, advertiseCallback)
            
            Log.i(TAG, "Started advertising as '$deviceName' with service UUID: $serviceUuid")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error starting advertising", e)
            callback(false)
        }
    }
    
    fun stopAdvertising(callback: (Boolean) -> Unit) {
        try {
            if (isAdvertising) {
                bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback)
                isAdvertising = false
                Log.i(TAG, "Stopped advertising")
            }
            callback(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping advertising", e)
            callback(false)
        }
    }
    
    fun setupGattServer(serviceUuid: String, characteristicUuid: String, callback: (Boolean) -> Unit) {
        try {
            bluetoothGattServer = bluetoothManager?.openGattServer(context, gattServerCallback)
            
            // Create game service
            gameService = BluetoothGattService(
                UUID.fromString(serviceUuid),
                BluetoothGattService.SERVICE_TYPE_PRIMARY
            )
            
            // Create game characteristic for data exchange
            gameCharacteristic = BluetoothGattCharacteristic(
                UUID.fromString(characteristicUuid),
                BluetoothGattCharacteristic.PROPERTY_READ or 
                BluetoothGattCharacteristic.PROPERTY_WRITE or
                BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                BluetoothGattCharacteristic.PERMISSION_READ or 
                BluetoothGattCharacteristic.PERMISSION_WRITE
            )
            
            gameService?.addCharacteristic(gameCharacteristic)
            
            val success = bluetoothGattServer?.addService(gameService) == true
            
            Log.i(TAG, "GATT server setup: $success")
            callback(success)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up GATT server", e)
            callback(false)
        }
    }
    
    fun sendData(data: String, callback: (Boolean) -> Unit) {
        try {
            if (gameCharacteristic != null && connectedDevices.isNotEmpty()) {
                gameCharacteristic?.value = data.toByteArray()
                
                var successCount = 0
                for (device in connectedDevices) {
                    val success = bluetoothGattServer?.notifyCharacteristicChanged(
                        device, 
                        gameCharacteristic, 
                        false
                    ) == true
                    
                    if (success) successCount++
                }
                
                val allSuccess = successCount == connectedDevices.size
                Log.i(TAG, "Sent data to $successCount/${connectedDevices.size} devices")
                callback(allSuccess)
            } else {
                Log.w(TAG, "No connected devices or characteristic not set")
                callback(false)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending data", e)
            callback(false)
        }
    }
    
    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            super.onStartSuccess(settingsInEffect)
            isAdvertising = true
            Log.i(TAG, "✅ BLE Advertising started successfully")
            Log.i(TAG, "📱 Device name: ${bluetoothAdapter?.name}")
            Log.i(TAG, "🔍 Now visible in NRF Connect scanner!")
        }
        
        override fun onStartFailure(errorCode: Int) {
            super.onStartFailure(errorCode)
            isAdvertising = false
            val errorMsg = when (errorCode) {
                ADVERTISE_FAILED_ALREADY_STARTED -> "Already started"
                ADVERTISE_FAILED_DATA_TOO_LARGE -> "Data too large"
                ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "Feature unsupported"
                ADVERTISE_FAILED_INTERNAL_ERROR -> "Internal error"
                ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "Too many advertisers"
                else -> "Unknown error: $errorCode"
            }
            Log.e(TAG, "❌ BLE Advertising failed: $errorMsg")
        }
    }
    
    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice?, status: Int, newState: Int) {
            super.onConnectionStateChange(device, status, newState)
            
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    device?.let {
                        connectedDevices.add(it)
                        Log.i(TAG, "✅ Client connected: ${it.name ?: it.address}")
                    }
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    device?.let {
                        connectedDevices.remove(it)
                        Log.i(TAG, "❌ Client disconnected: ${it.name ?: it.address}")
                    }
                }
            }
        }
        
        override fun onServiceAdded(status: Int, service: BluetoothGattService?) {
            super.onServiceAdded(status, service)
            Log.i(TAG, "Service added with status: $status")
        }
        
        override fun onCharacteristicReadRequest(
            device: BluetoothDevice?,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic?
        ) {
            super.onCharacteristicReadRequest(device, requestId, offset, characteristic)
            
            if (characteristic?.uuid == gameCharacteristic?.uuid) {
                bluetoothGattServer?.sendResponse(
                    device,
                    requestId,
                    BluetoothGatt.GATT_SUCCESS,
                    0,
                    characteristic?.value ?: byteArrayOf()
                )
                Log.d(TAG, "Characteristic read request from ${device?.address}")
            }
        }
        
        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice?,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic?,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value)
            
            if (characteristic?.uuid == gameCharacteristic?.uuid) {
                value?.let {
                    val data = String(it)
                    Log.i(TAG, "📨 Received data from ${device?.address}: $data")
                    // Here you could notify Flutter about received data
                }
                
                if (responseNeeded) {
                    bluetoothGattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        0,
                        null
                    )
                }
            }
        }
    }
}