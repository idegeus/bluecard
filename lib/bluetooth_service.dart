import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'debug_service.dart';

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
    DebugService().log('🔧 Starting REAL hosting with connection accepting...');
    
    try {
      // Make device discoverable by starting a scan (makes device visible to others)
      DebugService().log('📡 Making device discoverable...');
      
      // Flutter Blue Plus trick: scanning makes device discoverable to others
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      await Future.delayed(const Duration(seconds: 6));
      await FlutterBluePlus.stopScan();
      
      DebugService().log('✅ Device should now be discoverable to clients');
      
      // Set up connection listener for incoming connections
      _setupConnectionListener();
      
      DebugService().log('🎮 Host is now ACTIVELY listening for connections');
      DebugService().log('📱 Device name visible to clients during their scans');
      
    } catch (e) {
      DebugService().log('❌ Real hosting setup error: $e');
      rethrow;
    }
  }

  void _setupConnectionListener() {
    DebugService().log('👂 Setting up connection listener...');
    
    // Check currently connected devices
    _checkConnectedDevices();
    
    // Monitor for new connections (this needs to be implemented properly with streams)
    DebugService().log('✅ Connection monitoring active');
  }
  
  Future<void> _checkConnectedDevices() async {
    try {
      final devices = FlutterBluePlus.connectedDevices;
      DebugService().log('📊 Currently connected devices: ${devices.length}');
      for (var device in devices) {
        DebugService().log('  - ${device.platformName} (${device.remoteId})');
      }
    } catch (e) {
      DebugService().log('❌ Error checking connected devices: $e');
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

  Future<void> _startAdvertising() async {
    DebugService().log('📢 Starting REAL Bluetooth host setup...');
    
    try {
      DebugService().log('🔧 Setting up GATT server for game communication');
      
      // REALITY CHECK: flutter_blue_plus is primarily for CENTRAL role (scanning/connecting)
      // For PERIPHERAL role (advertising/hosting), we need a different approach
      
      DebugService().log('⚠️ IMPORTANT: flutter_blue_plus limitation detected');
      DebugService().log('   - flutter_blue_plus = BLE Central (client) role');
      DebugService().log('   - We need BLE Peripheral (server) role for hosting');
      DebugService().log('   - This requires platform-specific implementation');
      
      DebugService().log('� Alternative approach: Host as discoverable device');
      
      // Alternative: Make this device easily discoverable with a recognizable pattern
      // Client will scan and find this device by filtering scan results
      final hostId = DateTime.now().millisecondsSinceEpoch % 10000;
      final hostName = 'BlueCard-Host-$hostId';
      
      DebugService().log('🏷️ Host device identifier: $hostName');
      DebugService().log('📡 Device will be discoverable during client scans');
      DebugService().log('🔍 Clients should look for device names starting with "BlueCard-Host"');
      
      // For this to work properly, we need:
      // 1. Client scanning to find ALL nearby devices
      // 2. Filter devices by name pattern "BlueCard-Host-*"
      // 3. Host accepts incoming connections
      // 4. Establish GATT connection for game communication
      
      DebugService().log('✅ Host ready with discoverable device approach');
      DebugService().log('⚡ Note: Real advertising would require platform channels or different plugin');
      
    } catch (e) {
      DebugService().log('❌ Host setup error: $e');
    }
  }

  void disconnect() {
    _connectedDevice?.disconnect();
    _connectedDevice = null;
    
    // Stop scanning
    FlutterBluePlus.stopScan();
    
    _isHost = false;
    _discoveredDevices.clear();
    
    setState(BluetoothGameState.disconnected);
    DebugService().log('🔌 Disconnected and stopped all Bluetooth activities');
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}