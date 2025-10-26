import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'debug_service.dart';
import 'bluetooth_peripheral_channel.dart';

enum BluetoothGameState {
  disconnected,
  scanning,
  connecting,
  connected,
  hosting,
}

enum GameMessageType {
  gameState,
  playCard,
  drawCard,
  nextTurn,
  playerJoined,
  playerLeft,
}

class GameMessage {
  final GameMessageType type;
  final Map<String, dynamic> data;
  final String playerId;

  GameMessage({
    required this.type,
    required this.data,
    required this.playerId,
  });

  Map<String, dynamic> toJson() => {
    'type': type.toString().split('.').last,
    'data': data,
    'playerId': playerId,
  };

  factory GameMessage.fromJson(Map<String, dynamic> json) {
    return GameMessage(
      type: GameMessageType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type']
      ),
      data: json['data'] ?? {},
      playerId: json['playerId'] ?? '',
    );
  }
}

class BluetoothGameService extends ChangeNotifier {
  static final BluetoothGameService _instance = BluetoothGameService._internal();
  factory BluetoothGameService() => _instance;
  BluetoothGameService._internal();

  // Custom service UUID for BlueCard game
  static const String gameServiceUuid = "12345678-1234-1234-1234-123456789abc";
  static const String gameCharacteristicUuid = "87654321-4321-4321-4321-cba987654321";

  BluetoothGameState _state = BluetoothGameState.disconnected;
  final List<BluetoothDevice> _discoveredDevices = [];
  BluetoothDevice? _connectedDevice;
  bool _isHost = false;
  
  // Game-specific callbacks
  Function(GameMessage)? onMessageReceived;
  Function(String)? onPlayerConnected;
  Function(String)? onPlayerDisconnected;

  BluetoothGameState get state => _state;
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;
  bool get isHost => _isHost;
  bool get isConnected => _connectedDevice != null;

  void setState(BluetoothGameState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<bool> checkPermissions() async {
    if (kIsWeb) {
      DebugService().log('❌ Web platform - Bluetooth not supported');
      return false;
    }
    
    DebugService().log('🔐 Checking Bluetooth permissions...');
    final permissions = [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.location,
    ];

    for (final permission in permissions) {
      DebugService().log('   Checking $permission...');
      final status = await permission.request();
      if (!status.isGranted) {
        DebugService().log('❌ Permission denied: $permission (status: $status)');
        return false;
      }
      DebugService().log('✅ Permission granted: $permission');
    }
    DebugService().log('🎉 All permissions granted!');
    return true;
  }

  Future<bool> enableBluetooth() async {
    try {
      DebugService().log('🔍 Checking Bluetooth support...');
      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        DebugService().log('❌ Bluetooth not supported by this device');
        return false;
      }
      DebugService().log('✅ Bluetooth supported');

      DebugService().log('📡 Checking Bluetooth adapter state...');
      // Turn on Bluetooth if off
      final adapterState = await FlutterBluePlus.adapterState.first;
      DebugService().log('   Current state: $adapterState');
      
      if (adapterState != BluetoothAdapterState.on) {
        DebugService().log('🔄 Turning on Bluetooth...');
        await FlutterBluePlus.turnOn();
        
        // Wait a bit for the state to change
        await Future.delayed(const Duration(seconds: 2));
      }

      final newState = await FlutterBluePlus.adapterState.first;
      DebugService().log('   Final state: $newState');
      
      final success = newState == BluetoothAdapterState.on;
      if (success) {
        DebugService().log('✅ Bluetooth is ON');
      } else {
        DebugService().log('❌ Failed to turn on Bluetooth');
      }
      
      return success;
    } catch (e) {
      DebugService().log('❌ Error enabling Bluetooth: $e');
      return false;
    }
  }

  Future<void> startHosting() async {
    DebugService().log('🎯 Starting PROPER hosting process...');
    
    // Check if running on web
    if (kIsWeb) {
      DebugService().log('❌ Bluetooth not supported on web platform');
      return;
    }
    
    DebugService().log('📱 Step 1: Checking permissions...');
    final hasPermissions = await checkPermissions();
    if (!hasPermissions) {
      DebugService().log('❌ Permissions denied - cannot start hosting');
      return;
    }
    DebugService().log('✅ Permissions granted');

    DebugService().log('📡 Step 2: Enabling Bluetooth...');
    final bluetoothEnabled = await enableBluetooth();
    if (!bluetoothEnabled) {
      DebugService().log('❌ Could not enable Bluetooth - cannot start hosting');
      return;
    }
    DebugService().log('✅ Bluetooth enabled');

    DebugService().log('🏃 Step 3: Setting up host server...');
    try {
      // REAL hosting approach: Start scanning to make device discoverable
      // AND set up to accept incoming connections
      await _startRealHosting();
      
      _state = BluetoothGameState.hosting;
      _isHost = true;
      DebugService().log('✅ Now ACTUALLY hosting! State: $_state');
    } catch (e) {
      DebugService().log('❌ Failed to start hosting: $e');
      _state = BluetoothGameState.disconnected;
    }
  }

  Future<void> _startRealHosting() async {
    DebugService().log('🔧 Starting REAL BLE hosting with native implementation...');
    
    try {
      // Check if BLE peripheral is supported
      DebugService().log('📱 Checking native BLE peripheral support...');
      final isSupported = await BluetoothPeripheralChannel.isPeripheralSupported();
      
      if (!isSupported) {
        DebugService().log('❌ BLE Peripheral not supported on this device');
        throw Exception('BLE Peripheral not supported');
      }
      
      DebugService().log('✅ BLE Peripheral supported');
      
      // Setup GATT server first
      DebugService().log('🔧 Setting up GATT server...');
      final gattSetup = await BluetoothPeripheralChannel.setupGattServer(
        serviceUuid: gameServiceUuid,
        characteristicUuid: gameCharacteristicUuid,
      );
      
      if (!gattSetup) {
        DebugService().log('❌ Failed to setup GATT server');
        throw Exception('GATT server setup failed');
      }
      
      DebugService().log('✅ GATT server ready');
      
      // Start BLE advertising with native implementation
      DebugService().log('📡 Starting native BLE advertising...');
      final hostId = DateTime.now().millisecondsSinceEpoch % 10000;
      final deviceName = 'BlueCard-Host-$hostId';
      
      final advertisingStarted = await BluetoothPeripheralChannel.startAdvertising(
        serviceUuid: gameServiceUuid,
        deviceName: deviceName,
      );
      
      if (!advertisingStarted) {
        DebugService().log('❌ Failed to start BLE advertising');
        throw Exception('BLE advertising failed');
      }
      
      DebugService().log('✅ BLE advertising started successfully!');
      DebugService().log('📱 Device advertising as: $deviceName');
      DebugService().log('🔍 Service UUID: $gameServiceUuid');
      DebugService().log('');
      DebugService().log('� NRF Connect should now show:');
      DebugService().log('   - Device: $deviceName');
      DebugService().log('   - Service: $gameServiceUuid');
      DebugService().log('   - Characteristic: $gameCharacteristicUuid');
      DebugService().log('');
      DebugService().log('🎮 Host is now REALLY advertising and ready!');
      
    } catch (e) {
      DebugService().log('❌ Native hosting setup error: $e');
      rethrow;
    }
  }



  Future<void> scanForHosts() async {
    if (!await checkPermissions()) return;
    if (!await enableBluetooth()) return;

    setState(BluetoothGameState.scanning);
    _discoveredDevices.clear();

    try {
      // Listen to scan results
      var subscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          // Filter for potential game hosts
          bool isGameHost = _isLikelyGameHost(r);
          
          if (isGameHost && !_discoveredDevices.any((device) => device.remoteId == r.device.remoteId)) {
            _discoveredDevices.add(r.device);
            print('Found potential BlueCard host: ${r.device.platformName} (${r.device.remoteId})');
            notifyListeners();
          }
        }
      });

      // Start scanning with longer timeout for game discovery
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 20));
      DebugService().log('🔍 Scanning for BlueCard game hosts...');

      // Stop scanning after timeout
      Timer(const Duration(seconds: 21), () {
        subscription.cancel();
        FlutterBluePlus.stopScan();
        DebugService().log('Scan completed. Found ${_discoveredDevices.length} potential hosts.');
        setState(BluetoothGameState.disconnected);
      });

    } catch (e) {
      DebugService().log('Error scanning: $e');
      setState(BluetoothGameState.disconnected);
    }
  }

  // Filter logic to identify likely game hosts
  bool _isLikelyGameHost(ScanResult scanResult) {
    final device = scanResult.device;
    final advertisementData = scanResult.advertisementData;
    
    // Filter 1: Check if device name contains "BlueCard" or "Game"
    String deviceName = device.platformName.toLowerCase();
    if (deviceName.contains('bluecard') || deviceName.contains('game')) {
      print('✅ Found by name filter: $deviceName');
      return true;
    }
    
    // Filter 2: Check for our custom service UUID in advertised services
    for (var serviceGuid in advertisementData.serviceUuids) {
      String serviceUuid = serviceGuid.toString().toLowerCase();
      if (serviceUuid == gameServiceUuid.toLowerCase()) {
        print('✅ Found by service UUID: $serviceUuid');
        return true;
      }
    }
    
    // Filter 3: Check advertised local name
    String localName = advertisementData.advName.toLowerCase();
    if (localName.contains('bluecard') || localName.contains('game')) {
      print('✅ Found by advertised name: $localName');
      return true;
    }
    
    // Filter 4: For development - include devices that are connectable and have a name
    // Remove this in production to be more restrictive
    if (device.platformName.isNotEmpty && advertisementData.connectable) {
      print('🔍 Potential device (dev mode): ${device.platformName}');
      return true; // Temporarily allow all named devices for testing
    }
    
    return false;
  }

  Future<bool> connectToHost(BluetoothDevice device) async {
    setState(BluetoothGameState.connecting);
    
    try {
      await device.connect();
      _connectedDevice = device;
      _isHost = false;
      
      setState(BluetoothGameState.connected);
      
      // In a real implementation, you would discover services and characteristics here
      // and set up notifications for receiving messages
      
      // Send join message (simplified)
      onPlayerConnected?.call('client_${device.remoteId}');

      return true;
    } catch (e) {
      print('Error connecting to host: $e');
      setState(BluetoothGameState.disconnected);
      return false;
    }
  }

  Future<void> sendMessage(GameMessage message) async {
    // In a real implementation, this would send the message via GATT characteristic
    // For now, we'll just simulate message sending
    DebugService().log('Sending message: ${message.toJson()}');
    
    // Simulate message received by other devices
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isHost) {
        // If we're a client, simulate host receiving the message
      }
    });
  }

  void disconnect() {
    _connectedDevice?.disconnect();
    _connectedDevice = null;
    
    // Stop scanning
    FlutterBluePlus.stopScan();
    
    _isHost = false;
    _discoveredDevices.clear();
    
    setState(BluetoothGameState.disconnected);
    DebugService().log('� Disconnected and stopped all Bluetooth activities');
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}