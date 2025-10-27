package com.example.bluecard

import android.bluetooth.*
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import java.util.*

/**
 * Native Bluetooth GATT Server voor BlueCard
 * Dit maakt het mogelijk om als Host te fungeren en clients te accepteren
 */
class BlueCardGattServer(private val context: Context) {
    
    companion object {
        private const val TAG = "BlueCardGATT"
        
        // Service en Characteristic UUIDs (moet matchen met Dart code)
        val SERVICE_UUID: UUID = UUID.fromString("0000fff0-0000-1000-8000-00805f9b34fb")
        val CHARACTERISTIC_UUID: UUID = UUID.fromString("0000fff1-0000-1000-8000-00805f9b34fb")
    }
    
    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var androidGattServer: android.bluetooth.BluetoothGattServer? = null
    
    private val connectedDevices = mutableSetOf<BluetoothDevice>()
    private var gameCharacteristic: BluetoothGattCharacteristic? = null
    
    // Callbacks voor Flutter
    var onClientConnected: ((String, String) -> Unit)? = null
    var onClientDisconnected: ((String, String) -> Unit)? = null
    var onDataReceived: ((String, ByteArray) -> Unit)? = null
    
    /**
     * Start de GATT Server en begin met advertisen
     */
    fun startServer(deviceName: String): Boolean {
        Log.d(TAG, "🚀 Starting GATT Server as: $deviceName")
        
        // Initialiseer Bluetooth
        bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter
        
        if (bluetoothAdapter == null) {
            Log.e(TAG, "❌ Bluetooth adapter not available")
            return false
        }
        
        // Check of Bluetooth aan staat
        try {
            if (bluetoothAdapter?.isEnabled == false) {
                Log.e(TAG, "❌ Bluetooth is uitgeschakeld. Zet Bluetooth aan in de instellingen.")
                return false
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Permission denied when checking Bluetooth state: ${e.message}")
            return false
        }
        
        // Stel device naam in
        try {
            bluetoothAdapter?.name = deviceName
            Log.d(TAG, "✅ Device name set to: $deviceName")
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Permission denied for setting device name: ${e.message}")
        }
        
        // Setup GATT Server
        if (!setupGattServer()) {
            Log.e(TAG, "❌ Failed to setup GATT Server")
            return false
        }
        
        // Start Advertising
        if (!startAdvertising(deviceName)) {
            Log.e(TAG, "❌ Failed to start advertising")
            return false
        }
        
        Log.d(TAG, "✅ GATT Server started successfully!")
        Log.d(TAG, "📱 Device should be visible as: $deviceName")
        Log.d(TAG, "📡 Service UUID: $SERVICE_UUID")
        return true
    }
    
    /**
     * Setup de GATT Server met onze service en characteristic
     */
    private fun setupGattServer(): Boolean {
        Log.d(TAG, "🔧 Setting up GATT Server...")
        
        // Maak de characteristic aan
        gameCharacteristic = BluetoothGattCharacteristic(
            CHARACTERISTIC_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or
            BluetoothGattCharacteristic.PROPERTY_WRITE or
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ or
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        
        // Voeg descriptor toe voor notificaties
        val descriptor = BluetoothGattDescriptor(
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"),
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        gameCharacteristic?.addDescriptor(descriptor)
        
        // Maak de service aan
        val service = BluetoothGattService(
            SERVICE_UUID,
            BluetoothGattService.SERVICE_TYPE_PRIMARY
        )
        service.addCharacteristic(gameCharacteristic)
        
        // Open de GATT Server
        try {
            androidGattServer = bluetoothManager?.openGattServer(context, gattServerCallback)
            androidGattServer?.addService(service)
            
            Log.d(TAG, "✅ GATT Server configured with service: $SERVICE_UUID")
            return true
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Permission denied for opening GATT Server: ${e.message}")
            return false
        }
    }
    
    /**
     * Start BLE Advertising zodat clients ons kunnen vinden
     */
    private fun startAdvertising(deviceName: String): Boolean {
        Log.d(TAG, "📡 Starting BLE advertising...")
        
        bluetoothLeAdvertiser = bluetoothAdapter?.bluetoothLeAdvertiser
        if (bluetoothLeAdvertiser == null) {
            Log.e(TAG, "❌ BLE Advertising not supported on this device")
            return false
        }
        
        // Advertising settings
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setConnectable(true)
            .setTimeout(0)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .build()
        
        // Advertising data
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()
        
        try {
            bluetoothLeAdvertiser?.startAdvertising(settings, data, advertiseCallback)
            Log.d(TAG, "✅ Advertising started as: $deviceName")
            return true
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Permission denied for advertising: ${e.message}")
            return false
        }
    }
    
    /**
     * Stop de GATT Server en advertising
     */
    fun stopServer() {
        Log.d(TAG, "🛑 Stopping GATT Server...")
        
        try {
            bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback)
            androidGattServer?.close()
            connectedDevices.clear()
            
            Log.d(TAG, "✅ GATT Server stopped")
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Permission denied while stopping: ${e.message}")
        }
    }
    
    /**
     * Get aantal verbonden clients
     */
    fun getConnectedClientCount(): Int {
        val count = connectedDevices.size
        Log.d(TAG, "📊 Connected clients: $count")
        return count
    }
    
    /**
     * Verstuur data naar alle verbonden clients
     */
    fun sendDataToClients(data: ByteArray): Boolean {
        if (connectedDevices.isEmpty()) {
            Log.w(TAG, "⚠️ No clients connected")
            return false
        }
        
        gameCharacteristic?.value = data
        
        var successCount = 0
        connectedDevices.forEach { device ->
            try {
                val success = androidGattServer?.notifyCharacteristicChanged(
                    device,
                    gameCharacteristic,
                    false
                )
                if (success == true) {
                    successCount++
                    Log.d(TAG, "📤 Sent data to ${device.address}")
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "❌ Permission denied sending to ${device.address}: ${e.message}")
            }
        }
        
        Log.d(TAG, "✅ Data sent to $successCount/${connectedDevices.size} clients")
        return successCount > 0
    }
    
    /**
     * GATT Server Callback - handelt client events af
     */
    private val gattServerCallback = object : BluetoothGattServerCallback() {
        
        override fun onConnectionStateChange(device: BluetoothDevice?, status: Int, newState: Int) {
            super.onConnectionStateChange(device, status, newState)
            
            Log.d(TAG, "🔄 Connection state change: device=${device?.address}, status=$status, newState=$newState")
            device ?: return
            
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    connectedDevices.add(device)
                    Log.d(TAG, "✅ Client connected: ${device.name} (${device.address})")
                    Log.d(TAG, "📊 Total clients: ${connectedDevices.size}")
                    
                    // Check of callback is gezet
                    if (onClientConnected != null) {
                        Log.d(TAG, "🔔 Calling onClientConnected callback")
                        onClientConnected?.invoke(device.name ?: "Unknown", device.address)
                    } else {
                        Log.e(TAG, "❌ onClientConnected callback is NULL!")
                    }
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    connectedDevices.remove(device)
                    Log.d(TAG, "❌ Client disconnected: ${device.name} (${device.address})")
                    Log.d(TAG, "📊 Total clients: ${connectedDevices.size}")
                    onClientDisconnected?.invoke(device.name ?: "Unknown", device.address)
                }
                else -> {
                    Log.d(TAG, "⚠️ Unknown connection state: $newState")
                }
            }
        }
        
        override fun onServiceAdded(status: Int, service: BluetoothGattService?) {
            super.onServiceAdded(status, service)
            Log.d(TAG, "📝 Service added: status=$status, service=${service?.uuid}")
        }
        
        override fun onCharacteristicReadRequest(
            device: BluetoothDevice?,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic?
        ) {
            super.onCharacteristicReadRequest(device, requestId, offset, characteristic)
            Log.d(TAG, "📖 Read request from ${device?.address} for characteristic ${characteristic?.uuid}")
            
            try {
                androidGattServer?.sendResponse(
                    device,
                    requestId,
                    BluetoothGatt.GATT_SUCCESS,
                    0,
                    characteristic?.value
                )
            } catch (e: SecurityException) {
                Log.e(TAG, "❌ Permission denied on read response: ${e.message}")
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
            Log.d(TAG, "✍️ Write request from ${device?.address} for characteristic ${characteristic?.uuid}")
            
            value?.let {
                Log.d(TAG, "📨 Received ${it.size} bytes from ${device?.address}")
                
                // Check of callback is gezet
                if (onDataReceived != null) {
                    Log.d(TAG, "🔔 Calling onDataReceived callback")
                    onDataReceived?.invoke(device?.address ?: "unknown", it)
                } else {
                    Log.e(TAG, "❌ onDataReceived callback is NULL!")
                }
            }
            
            if (responseNeeded) {
                try {
                    androidGattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        0,
                        null
                    )
                } catch (e: SecurityException) {
                    Log.e(TAG, "❌ Permission denied on write response: ${e.message}")
                }
            }
        }
        
        override fun onDescriptorReadRequest(
            device: BluetoothDevice?,
            requestId: Int,
            offset: Int,
            descriptor: BluetoothGattDescriptor?
        ) {
            super.onDescriptorReadRequest(device, requestId, offset, descriptor)
            Log.d(TAG, "📖 Descriptor read request from ${device?.address}")
            
            try {
                androidGattServer?.sendResponse(
                    device,
                    requestId,
                    BluetoothGatt.GATT_SUCCESS,
                    0,
                    descriptor?.value
                )
            } catch (e: SecurityException) {
                Log.e(TAG, "❌ Permission denied on descriptor read response: ${e.message}")
            }
        }
        
        override fun onDescriptorWriteRequest(
            device: BluetoothDevice?,
            requestId: Int,
            descriptor: BluetoothGattDescriptor?,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            super.onDescriptorWriteRequest(device, requestId, descriptor, preparedWrite, responseNeeded, offset, value)
            Log.d(TAG, "🔔 Descriptor write request from ${device?.address} for descriptor ${descriptor?.uuid}")
            
            if (responseNeeded) {
                try {
                    androidGattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        0,
                        null
                    )
                } catch (e: SecurityException) {
                    Log.e(TAG, "❌ Permission denied on descriptor response: ${e.message}")
                }
            }
        }
        
        override fun onExecuteWrite(device: BluetoothDevice?, requestId: Int, execute: Boolean) {
            super.onExecuteWrite(device, requestId, execute)
            Log.d(TAG, "📝 Execute write from ${device?.address}, execute=$execute")
        }
        
        override fun onNotificationSent(device: BluetoothDevice?, status: Int) {
            super.onNotificationSent(device, status)
            Log.d(TAG, "📬 Notification sent to ${device?.address}, status=$status")
        }
        
        override fun onMtuChanged(device: BluetoothDevice?, mtu: Int) {
            super.onMtuChanged(device, mtu)
            Log.d(TAG, "📏 MTU changed for ${device?.address}, new MTU=$mtu")
        }
        
        override fun onPhyUpdate(device: BluetoothDevice?, txPhy: Int, rxPhy: Int, status: Int) {
            super.onPhyUpdate(device, txPhy, rxPhy, status)
            Log.d(TAG, "📡 PHY update for ${device?.address}, tx=$txPhy, rx=$rxPhy, status=$status")
        }
        
        override fun onPhyRead(device: BluetoothDevice?, txPhy: Int, rxPhy: Int, status: Int) {
            super.onPhyRead(device, txPhy, rxPhy, status)
            Log.d(TAG, "📡 PHY read for ${device?.address}, tx=$txPhy, rx=$rxPhy, status=$status")
        }
    }
    
    /**
     * Advertising Callback
     */
    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            Log.d(TAG, "✅ Advertising started successfully")
        }
        
        override fun onStartFailure(errorCode: Int) {
            Log.e(TAG, "❌ Advertising failed with error code: $errorCode")
        }
    }
}
