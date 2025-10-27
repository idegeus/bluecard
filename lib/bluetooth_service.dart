import 'dart:async';
import 'dart:convert';
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
  startingHost,
  hosting,
}

enum GameMessageType {
  gameState,
  playCard,
  drawCard,
  nextTurn,
  playerJoined,
  playerLeft,
  ping,
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
  
  // Connected clients list for host
  final List<Map<String, String>> _connectedClients = [];
  
  // Ping timer for keeping connection alive
  Timer? _pingTimer;
  Timer? _hostPingTimer;
  
  // Ping history for UI display
  final List<Map<String, dynamic>> _pingHistory = [];
  
  // Game-specific callbacks
  Function(GameMessage)? onMessageReceived;
  Function(String)? onPlayerConnected;
  Function(String)? onPlayerDisconnected;

  BluetoothGameState get state => _state;
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;
  List<Map<String, String>> get connectedClients => _connectedClients;
  List<Map<String, dynamic>> get pingHistory => _pingHistory;
  
  // Handle received messages
  void _handleReceivedMessage(String address, String data) {
    try {
      final messageJson = json.decode(data);
      final message = GameMessage.fromJson(messageJson);
      
      DebugService().log('📨 Parsed message from $address: ${message.type} - ${message.data}');
      
      // Handle ping messages specially
      if (message.type == GameMessageType.ping) {
        final timestamp = DateTime.now();
        final timestampString = timestamp.toIso8601String();
        DebugService().log('🏓 PING received from ${message.playerId} at $timestampString');
        
        // Store ping in history for UI display
        _pingHistory.add({
          'timestamp': timestamp,
          'playerId': message.playerId,
          'address': address,
          'direction': 'received',
          'message': message.data['message'] ?? 'ping',
        });
        
        // Keep only last 20 pings to avoid memory issues
        if (_pingHistory.length > 20) {
          _pingHistory.removeAt(0);
        }
        
        // Notify UI to update
        notifyListeners();
      }
      
      // Notify listeners about the received message
      onMessageReceived?.call(message);
    } catch (e) {
      DebugService().log('❌ Error parsing received message: $e');
    }
  }
  
  // Start ping timer for clients to keep connection alive
  void _startPingTimer() {
    if (_isHost) return; // Only clients send pings
    
    _stopPingTimer(); // Stop existing timer if any
    
    DebugService().log('🏓 Starting ping timer (every 15 seconds)');
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_state == BluetoothGameState.connected && _gameCharacteristic != null && _connectedDevice != null) {
        // Send ping - errors are handled in sendMessage method
        DebugService().log('🏓 Sending keep-alive ping to host...');
        _sendPingMessage('keep-alive ping from client');
      } else {
        DebugService().log('⚠️ Stopping ping timer - not connected or no device');
        _stopPingTimer();
      }
    });
  }
  
  // Stop ping timer
  void _stopPingTimer() {
    if (_pingTimer != null) {
      DebugService().log('🛑 Stopping ping timer');
      _pingTimer?.cancel();
      _pingTimer = null;
    }
  }
  
  // Stop host ping timer
  void _stopHostPingTimer() {
    if (_hostPingTimer != null) {
      DebugService().log('🛑 Stopping host ping timer');
      _hostPingTimer?.cancel();
      _hostPingTimer = null;
    }
  }
  
  // Handle unexpected connection loss
  Timer? _reconnectionTimer;
  int _reconnectionAttempts = 0;
  static const int _maxReconnectionAttempts = 3;

  Future<void> _handleConnectionLost() async {
    DebugService().log('💥 Handling connection loss...');
    
    try {
      // Stop all timers
      _stopPingTimer();
      _stopHostPingTimer();
      _reconnectionTimer?.cancel();
      _reconnectionTimer = null;
      
      // Store last connected device for potential reconnection
      final lastDevice = _connectedDevice;
      
      // Cancel connection monitoring
      await _connectionStateSubscription?.cancel();
      _connectionStateSubscription = null;
      
      // Clear connection data
      _connectedDevice = null;
      _gameCharacteristic = null;
      
      // Update state safely
      setState(BluetoothGameState.disconnected);
      
      // Notify user about disconnection
      if (onPlayerDisconnected != null) {
        onPlayerDisconnected!('Connection lost');
      }
      
      // Attempt automatic reconnection for clients only
      if (!_isHost && lastDevice != null && _reconnectionAttempts < _maxReconnectionAttempts) {
        _reconnectionAttempts++;
        final delay = Duration(seconds: 2 * _reconnectionAttempts); // Exponential backoff
        
        DebugService().log('🔄 Scheduling reconnection attempt $_reconnectionAttempts/$_maxReconnectionAttempts in ${delay.inSeconds}s...');
        
        _reconnectionTimer = Timer(delay, () {
          _attemptReconnection(lastDevice);
        });
      } else if (_reconnectionAttempts >= _maxReconnectionAttempts) {
        DebugService().log('❌ Max reconnection attempts reached, giving up');
        _reconnectionAttempts = 0;
      }
      
      DebugService().log('🔌 Connection loss handled successfully');
      
    } catch (e) {
      DebugService().log('❌ Error during connection loss handling: $e');
      // Force cleanup
      _connectedDevice = null;
      _gameCharacteristic = null;
      setState(BluetoothGameState.disconnected);
    }
  }
  
  // Attempt to reconnect to the last known device
  Future<void> _attemptReconnection(BluetoothDevice device) async {
    try {
      DebugService().log('🔄 Trying to reconnect to ${device.platformName}...');
      
      // Check if device is still available and not connected
      final connectionState = await device.connectionState.first;
      if (connectionState == BluetoothConnectionState.connected) {
        DebugService().log('✅ Device is already connected, re-establishing service');
        await connectToHost(device);
        return;
      }
      
      // Try to connect
      await connectToHost(device);
      DebugService().log('✅ Automatic reconnection successful!');
      
    } catch (e) {
      DebugService().log('❌ Automatic reconnection failed: $e');
      // Could implement retry logic here with exponential backoff
    }
  }
  
  // Start host ping timer (host sends pings to clients)
  void _startHostPingTimer() {
    if (!_isHost) return; // Only hosts send pings to clients
    
    _stopHostPingTimer(); // Stop existing timer if any
    
    DebugService().log('🏓 Starting host ping timer (every 10 seconds)');
    _hostPingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_state == BluetoothGameState.hosting && _connectedClients.isNotEmpty) {
        DebugService().log('🏓 Sending ping to ${_connectedClients.length} clients...');
        _sendPingMessage('keep-alive ping from host');
      } else if (_connectedClients.isEmpty) {
        DebugService().log('⚠️ No clients connected, continuing host ping timer');
      } else {
        DebugService().log('⚠️ Stopping host ping timer - not hosting');
        _stopHostPingTimer();
      }
    });
  }
  
  // Start the game (called when host presses START GAME)
  Future<void> startGame() async {
    if (!_isHost) {
      DebugService().log('❌ Only host can start the game');
      return;
    }
    
    DebugService().log('🎮 Starting game! Sending start message to all clients...');
    
    // Send game start message to all clients
    final startMessage = GameMessage(
      type: GameMessageType.gameState,
      data: {
        'action': 'game_started',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'message': 'Game has started!'
      },
      playerId: 'host',
    );
    
    await sendMessage(startMessage);
    
    // Start host ping timer to keep connections alive during game
    _startHostPingTimer();
    
    DebugService().log('✅ Game started and host ping timer activated!');
  }
  
  // Send ping and store in history
  Future<void> _sendPingMessage(String message) async {
    try {
      final timestamp = DateTime.now();
      final playerId = _isHost ? 'host' : 'client_${_connectedDevice?.remoteId.str ?? 'unknown'}';
      
      final pingMessage = GameMessage(
        type: GameMessageType.ping,
        data: {
          'timestamp': timestamp.millisecondsSinceEpoch,
          'message': message
        },
        playerId: playerId,
      );
      
      // Store in history before sending
      _pingHistory.add({
        'timestamp': timestamp,
        'playerId': playerId,
        'address': 'local',
        'direction': 'sent',
        'message': message,
      });
      
      // Keep only last 20 pings
      if (_pingHistory.length > 20) {
        _pingHistory.removeAt(0);
      }
      
      // Send the ping
      await sendMessage(pingMessage);
      
      // Notify UI to update
      notifyListeners();
    } catch (e) {
      DebugService().log('❌ Failed to send ping: $e');
      // If ping fails, it might indicate connection issues
      if (!_isHost && _connectedDevice != null) {
        DebugService().log('⚠️ Ping failure detected, checking connection...');
        final connectionState = await _connectedDevice!.connectionState.first;
        if (connectionState != BluetoothConnectionState.connected) {
          DebugService().log('💥 Connection is not active, handling connection loss');
          _handleConnectionLost();
        }
      }
    }
  }
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
    
    try {
      // Platform-specific permission handling
      List<Permission> permissions = [];
      
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android 12+ (API 31+) permissions
        permissions = [
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
          Permission.location, // Still needed for scanning on some Android versions
        ];
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS permissions are handled differently through Info.plist
        DebugService().log('✅ iOS - Bluetooth permissions handled via Info.plist');
        return true;
      }

      // Check and request permissions one by one
      for (final permission in permissions) {
        DebugService().log('   Checking $permission...');
        
        var status = await permission.status;
        
        if (status.isDenied) {
          DebugService().log('   Requesting $permission...');
          status = await permission.request();
        }
        
        if (status.isPermanentlyDenied) {
          DebugService().log('❌ Permission permanently denied: $permission');
          DebugService().log('   User needs to enable in settings');
          return false;
        }
        
        if (!status.isGranted) {
          DebugService().log('❌ Permission denied: $permission (status: $status)');
          return false;
        }
        
        DebugService().log('✅ Permission granted: $permission');
      }
      
      DebugService().log('🎉 All required permissions granted!');
      return true;
      
    } catch (e) {
      DebugService().log('❌ Error checking permissions: $e');
      return false;
    }
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
    
    // Set starting state immediately
    setState(BluetoothGameState.startingHost);
    
    // Check if running on web
    if (kIsWeb) {
      DebugService().log('❌ Bluetooth not supported on web platform');
      setState(BluetoothGameState.disconnected);
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
      // Set up client connection callbacks
      BluetoothPeripheralChannel.onClientConnected = (name, address) {
        DebugService().log('✅ Client connected: $name ($address)');
        _connectedClients.add({'name': name, 'address': address});
        onPlayerConnected?.call(name);
        notifyListeners();
      };
      
      BluetoothPeripheralChannel.onClientDisconnected = (name, address) {
        DebugService().log('❌ Client disconnected: $name ($address)');
        _connectedClients.removeWhere((client) => client['address'] == address);
        onPlayerDisconnected?.call(name);
        notifyListeners();
      };
      
      BluetoothPeripheralChannel.onDataReceived = (address, data) {
        DebugService().log('📨 Data received from $address: $data');
        _handleReceivedMessage(address, data);
      };
      
      // REAL hosting approach: Start native BLE peripheral
      await _startRealHosting();
      
      _isHost = true;
      setState(BluetoothGameState.hosting); // Use setState method to properly notify listeners
      DebugService().log('✅ Now ACTUALLY hosting! State: $_state');
    } catch (e) {
      DebugService().log('❌ Failed to start hosting: $e');
      setState(BluetoothGameState.disconnected); // Use setState method
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
      
      // Try to get player name from settings, fallback to generic name
      String playerName = 'Host';
      try {
        // Import would be needed: import 'settings_screen.dart';
        // playerName = await PlayerSettings.getPlayerName();
      } catch (e) {
        DebugService().log('Could not load player name, using default');
      }
      
      final deviceName = 'BlueCard-$playerName-$hostId';
      
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



  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _scanTimer;

  Future<void> scanForHosts() async {
    DebugService().log('🔍 Starting scan for BlueCard hosts...');
    
    // Stop any existing scan first
    await stopScanning();
    
    if (!await checkPermissions()) {
      DebugService().log('❌ Missing permissions for scanning');
      return;
    }
    
    if (!await enableBluetooth()) {
      DebugService().log('❌ Bluetooth not available for scanning');
      return;
    }

    setState(BluetoothGameState.scanning);
    _discoveredDevices.clear();

    try {
      // Check if already scanning
      if (FlutterBluePlus.isScanningNow) {
        DebugService().log('⚠️ Already scanning, stopping first...');
        await FlutterBluePlus.stopScan();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Listen to scan results with robust error handling
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          try {
            for (ScanResult r in results) {
              // Filter for potential game hosts
              if (_isLikelyGameHost(r) && !_discoveredDevices.any((device) => device.remoteId == r.device.remoteId)) {
                _discoveredDevices.add(r.device);
                DebugService().log('✅ Found BlueCard host: ${r.device.platformName} (${r.device.remoteId})');
                notifyListeners();
              }
            }
          } catch (e) {
            DebugService().log('❌ Error processing scan result: $e');
          }
        },
        onError: (error) {
          DebugService().log('❌ Scan subscription error: $error');
          stopScanning();
        },
      );

      // Start scanning with timeout
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false, // Reduce permission requirements
      );
      
      DebugService().log('� Scanning started, looking for BlueCard hosts...');

      // Safety timeout to ensure scanning stops
      _scanTimer = Timer(const Duration(seconds: 16), () async {
        DebugService().log('⏰ Scan timeout reached');
        await stopScanning();
        DebugService().log('📊 Scan completed. Found ${_discoveredDevices.length} potential hosts.');
        if (_discoveredDevices.isEmpty) {
          setState(BluetoothGameState.disconnected);
        }
      });

    } catch (e) {
      DebugService().log('❌ Error during scanning: $e');
      await stopScanning();
      setState(BluetoothGameState.disconnected);
    }
  }

  Future<void> stopScanning() async {
    DebugService().log('🛑 Stopping scan...');
    
    // Cancel subscription
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    
    // Cancel timer
    _scanTimer?.cancel();
    _scanTimer = null;
    
    // Stop actual scanning
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (e) {
      DebugService().log('⚠️ Error stopping scan: $e');
    }
    
    DebugService().log('✅ Scan stopped successfully');
  }

  // Filter logic to identify likely game hosts
  bool _isLikelyGameHost(ScanResult scanResult) {
    final device = scanResult.device;
    final advertisementData = scanResult.advertisementData;
    
    // Filter 1: Check if device name contains "BlueCard" or "Game"
    String deviceName = device.platformName.toLowerCase();
    if (deviceName.contains('bluecard') || deviceName.contains('game')) {
      DebugService().log('✅ Found by name filter: $deviceName');
      return true;
    }
    
    // Filter 2: Check for our custom service UUID in advertised services
    for (var serviceGuid in advertisementData.serviceUuids) {
      String serviceUuid = serviceGuid.toString().toLowerCase();
      if (serviceUuid == gameServiceUuid.toLowerCase()) {
        DebugService().log('✅ Found by service UUID: $serviceUuid');
        return true;
      }
    }
    
    // Filter 3: Check advertised local name
    String localName = advertisementData.advName.toLowerCase();
    if (localName.contains('bluecard') || localName.contains('game')) {
      DebugService().log('✅ Found by advertised name: $localName');
      return true;
    }
    
    // Filter 4: For development - include devices that are connectable and have a name
    // Remove this in production to be more restrictive
    if (device.platformName.isNotEmpty && advertisementData.connectable) {
      DebugService().log('🔍 Potential device (dev mode): ${device.platformName}');
      return true; // Temporarily allow all named devices for testing
    }
    
    return false;
  }

  BluetoothCharacteristic? _gameCharacteristic;

  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  Future<bool> connectToHost(BluetoothDevice device) async {
    DebugService().log('🔗 Starting connection to host: ${device.platformName} (${device.remoteId})');
    
    // Stop scanning first
    await stopScanning();
    
    setState(BluetoothGameState.connecting);
    
    try {
      // Cancel any existing connection state monitoring
      await _connectionStateSubscription?.cancel();
      
      // Check if device is already connected
      final currentState = await device.connectionState.first;
      if (currentState == BluetoothConnectionState.connected) {
        DebugService().log('✅ Device already connected');
        _connectedDevice = device;
      } else {
        // Connect to the device with timeout
        DebugService().log('📡 Establishing connection...');
        await device.connect(
          timeout: const Duration(seconds: 20),
          mtu: null, // Use default MTU
        );
        _connectedDevice = device;
        
        // Wait a moment for connection to stabilize
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Set up robust connection state monitoring
      _connectionStateSubscription = device.connectionState.listen(
        (BluetoothConnectionState state) {
          DebugService().log('🔗 Connection state changed: $state');
          if (state == BluetoothConnectionState.disconnected) {
            DebugService().log('⚠️ Device disconnected unexpectedly!');
            _handleConnectionLost();
          }
        },
        onError: (error) {
          DebugService().log('❌ Connection state monitoring error: $error');
          _handleConnectionLost();
        },
      );
      
      DebugService().log('✅ Connected! Discovering services...');
      
      // Discover services with timeout
      List<BluetoothService> services;
      try {
        services = await device.discoverServices().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Service discovery timeout', const Duration(seconds: 10));
          },
        );
        DebugService().log('🔍 Found ${services.length} services');
      } catch (e) {
        DebugService().log('❌ Failed to discover services: $e');
        await _safeDisconnect(device);
        setState(BluetoothGameState.disconnected);
        return false;
      }
      
      // Find our game service
      BluetoothService? gameService;
      for (var service in services) {
        DebugService().log('   Service: ${service.uuid}');
        if (service.uuid.toString().toLowerCase() == gameServiceUuid.toLowerCase()) {
          gameService = service;
          DebugService().log('✅ Found game service!');
          break;
        }
      }
      
      if (gameService == null) {
        DebugService().log('❌ Game service not found - this might not be a BlueCard host');
        await _safeDisconnect(device);
        setState(BluetoothGameState.disconnected);
        return false;
      }
      
      // Find the game characteristic
      BluetoothCharacteristic? gameCharacteristic;
      for (var characteristic in gameService.characteristics) {
        DebugService().log('   Characteristic: ${characteristic.uuid}');
        if (characteristic.uuid.toString().toLowerCase() == gameCharacteristicUuid.toLowerCase()) {
          gameCharacteristic = characteristic;
          DebugService().log('✅ Found game characteristic!');
          break;
        }
      }
      
      if (gameCharacteristic == null) {
        DebugService().log('❌ Game characteristic not found');
        await _safeDisconnect(device);
        setState(BluetoothGameState.disconnected);
        return false;
      }
      
      // Set up notifications if supported
      try {
        if (gameCharacteristic.properties.notify) {
          DebugService().log('🔔 Setting up notifications...');
          await gameCharacteristic.setNotifyValue(true).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Notification setup timeout', const Duration(seconds: 5));
            },
          );
          
          // Set up the actual notification listener
          gameCharacteristic.onValueReceived.listen(
            (value) {
              if (value.isNotEmpty) {
                final data = String.fromCharCodes(value);
                DebugService().log('📨 Received notification: $data');
                _handleReceivedMessage(device.remoteId.str, data);
              }
            },
            onError: (error) {
              DebugService().log('❌ Notification error: $error');
            },
          );
          
          DebugService().log('✅ Notifications enabled and listener set up');
        }
        
        _gameCharacteristic = gameCharacteristic;
        
      } catch (e) {
        DebugService().log('❌ Failed to set up notifications: $e');
        await _safeDisconnect(device);
        setState(BluetoothGameState.disconnected);
        return false;
      }
      
      _isHost = false;
      setState(BluetoothGameState.connected);
      
      DebugService().log('🎉 Successfully connected to host!');
      
      // Send join message
      final joinMessage = GameMessage(
        type: GameMessageType.playerJoined,
        data: {'timestamp': DateTime.now().millisecondsSinceEpoch},
        playerId: 'client_${device.remoteId.str}',
      );
      await sendMessage(joinMessage);
      
      // Start ping timer to keep connection alive
      _startPingTimer();
      
      // For clients, we don't call onPlayerConnected since that's confusing
      // The UI will show connection success through state changes

      return true;
    } catch (e) {
      DebugService().log('❌ Error connecting to host: $e');
      if (_connectedDevice != null) {
        await _safeDisconnect(_connectedDevice!);
      }
      setState(BluetoothGameState.disconnected);
      return false;
    }
  }

  Future<void> _safeDisconnect(BluetoothDevice device) async {
    try {
      DebugService().log('🔌 Safely disconnecting from ${device.platformName}...');
      
      // Cancel connection state monitoring
      await _connectionStateSubscription?.cancel();
      _connectionStateSubscription = null;
      
      // Clear characteristic
      _gameCharacteristic = null;
      
      // Disconnect with timeout
      await device.disconnect().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          DebugService().log('⚠️ Disconnect timeout - forcing cleanup');
        },
      );
      
      DebugService().log('✅ Device disconnected safely');
      
    } catch (e) {
      DebugService().log('❌ Error during safe disconnect: $e');
    } finally {
      // Ensure cleanup regardless of errors
      _connectedDevice = null;
      _gameCharacteristic = null;
    }
  }

  Future<bool> sendMessage(GameMessage message) async {
    if (_state == BluetoothGameState.disconnected) {
      DebugService().log('❌ Cannot send message - not connected');
      return false;
    }

    try {
      final messageJson = message.toJson();
      final messageString = json.encode(messageJson);
      DebugService().log('📤 Sending message (${messageString.length} chars): ${message.type}');
      
      // Validate message size (BLE has MTU limits)
      if (messageString.length > 512) {
        DebugService().log('⚠️ Message might be too large for BLE transmission');
      }
      
      if (_isHost) {
        // Host sends via native platform channel to all clients
        try {
          final success = await BluetoothPeripheralChannel.sendData(messageString).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              DebugService().log('⏰ Host message send timeout');
              return false;
            },
          );
          
          if (success) {
            DebugService().log('✅ Message sent to all clients successfully');
            return true;
          } else {
            DebugService().log('❌ Failed to send message to clients');
            return false;
          }
        } catch (e) {
          DebugService().log('❌ Host message send error: $e');
          return false;
        }
        
      } else if (_gameCharacteristic != null && _connectedDevice != null) {
        // Client sends to host via characteristic
        try {
          // Check if device is still connected
          final connectionState = await _connectedDevice!.connectionState.first.timeout(
            const Duration(seconds: 2),
            onTimeout: () => BluetoothConnectionState.disconnected,
          );
          
          if (connectionState != BluetoothConnectionState.connected) {
            DebugService().log('❌ Device not connected, cannot send message');
            _handleConnectionLost();
            return false;
          }
          
          final data = utf8.encode(messageString);
          await _gameCharacteristic!.write(
            data, 
            withoutResponse: false,
            timeout: 5,
          );
          
          DebugService().log('✅ Message sent to host successfully');
          return true;
          
        } catch (e) {
          DebugService().log('❌ Client message send error: $e');
          
          // Check if this indicates a connection problem
          if (e.toString().contains('disconnected') || e.toString().contains('timeout')) {
            DebugService().log('🔍 Connection issue detected, handling...');
            _handleConnectionLost();
          }
          return false;
        }
        
      } else {
        DebugService().log('❌ No valid connection for sending message');
        return false;
      }
      
    } catch (e) {
      DebugService().log('❌ Unexpected error sending message: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    DebugService().log('🔌 Starting complete disconnect process...');
    
    try {
      // Stop all timers
      _stopPingTimer();
      _stopHostPingTimer();
      _reconnectionTimer?.cancel();
      _reconnectionTimer = null;
      
      // Stop scanning
      await stopScanning();
      
      // Cancel connection monitoring
      await _connectionStateSubscription?.cancel();
      _connectionStateSubscription = null;
      
      // Disconnect device if connected
      if (_connectedDevice != null) {
        await _safeDisconnect(_connectedDevice!);
      }
      
      // Stop hosting if we're a host
      if (_isHost) {
        try {
          await BluetoothPeripheralChannel.stopAdvertising();
          _connectedClients.clear();
        } catch (e) {
          DebugService().log('⚠️ Error stopping peripheral: $e');
        }
      }
      
      // Clear all state
      _connectedDevice = null;
      _gameCharacteristic = null;
      _isHost = false;
      _discoveredDevices.clear();
      _pingHistory.clear();
      _reconnectionAttempts = 0;
      
      setState(BluetoothGameState.disconnected);
      DebugService().log('✅ Complete disconnect successful');
      
    } catch (e) {
      DebugService().log('❌ Error during disconnect: $e');
      // Force cleanup
      _connectedDevice = null;
      _gameCharacteristic = null;
      _isHost = false;
      setState(BluetoothGameState.disconnected);
    }
  }

  @override
  void dispose() {
    DebugService().log('🗑️ Disposing BluetoothGameService...');
    
    // Clear callbacks to prevent memory leaks
    onMessageReceived = null;
    onPlayerConnected = null;
    onPlayerDisconnected = null;
    
    // Disconnect everything
    disconnect();
    
    super.dispose();
  }
}