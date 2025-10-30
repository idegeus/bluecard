import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/game_message.dart';

/// BluetoothClient - Verbindt met de GATT server van de host
/// Beheert de verbinding, luistert naar notificaties, en stuurt acties
class BluetoothClient {
  static const String serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
  static const String characteristicUuid = '0000fff1-0000-1000-8000-00805f9b34fb';
  
  BluetoothDevice? _hostDevice;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _notificationSubscription;
  
  final StreamController<String> _messageController = StreamController.broadcast();
  final StreamController<bool> _connectionController = StreamController.broadcast();
  final StreamController<GameMessage> _gameMessageController = StreamController.broadcast();
  final StreamController<PingInfo> _pingController = StreamController.broadcast();
  
  bool _isConnected = false;
  bool _isScanning = false;
  String _playerId = 'client';
  
  Stream<String> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<GameMessage> get gameMessageStream => _gameMessageController.stream;
  Stream<PingInfo> get pingStream => _pingController.stream;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  BluetoothDevice? get hostDevice => _hostDevice;
  String get playerId => _playerId;
  
  void setPlayerId(String id) {
    _playerId = id;
  }
  
  /// Start met zoeken naar de host
  Future<void> searchForHost() async {
    try {
      // Check Bluetooth support
      if (await FlutterBluePlus.isSupported == false) {
        throw Exception('Bluetooth wordt niet ondersteund');
      }
      
      // Check of Bluetooth aan staat
      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _messageController.add('⚠️ Bluetooth is uit, probeer aan te zetten...');
        await FlutterBluePlus.turnOn();
        await Future.delayed(Duration(seconds: 2));
      }
      
      _isScanning = true;
      _messageController.add('🔍 Zoeken naar BlueCard host...');
      _messageController.add('📡 Service UUID: $serviceUuid');
      
      int deviceCount = 0;
      
      // Start scanning - luister naar ALLE onScanResults
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          for (var result in results) {
            deviceCount++;
            final deviceName = result.device.platformName;
            final isBlueCardHost = deviceName.isNotEmpty && deviceName.contains('BlueCard');
            
            // Log alleen BlueCard hosts
            if (isBlueCardHost) {
              final deviceId = result.device.remoteId.toString();
              final rssi = result.rssi;
              
              _messageController.add('✅ BlueCard host gevonden: $deviceName');
              _messageController.add('   ID: $deviceId | RSSI: $rssi dBm');
              _messageController.add('🔗 Automatisch verbinden...');
              FlutterBluePlus.stopScan();
              _connectToHost(result.device);
              return;
            }
          }
        },
        onError: (error) {
          _messageController.add('❌ Scan fout: $error');
          _isScanning = false;
        },
      );
      
      // Start de scan met agressieve settings
      _messageController.add('🚀 Starting scan...');
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: 15),
        androidUsesFineLocation: true,
      );
      
      _messageController.add('⏳ Scanning for 15 seconds...');
      
      // Wacht op timeout
      await Future.delayed(Duration(seconds: 15));
      
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      _isScanning = false;
      
      if (_hostDevice == null) {
        _messageController.add('⚠️ Geen BlueCard host gevonden na 15 seconden');
        _messageController.add('� Totaal $deviceCount devices gevonden');
        _messageController.add('�💡 Tip: Controleer of:');
        _messageController.add('   - De host is gestart');
        _messageController.add('   - Bluetooth permissions zijn gegeven');
        _messageController.add('   - Location services zijn aan (vereist voor BLE scan)');
      }
      
    } catch (e) {
      _messageController.add('❌ Fout bij zoeken: $e');
      _isScanning = false;
      rethrow;
    }
  }
  
  /// Verbind met de host
  Future<void> connectToHost(BluetoothDevice device) async {
    await _connectToHost(device);
  }
  
  /// Verbind met de host (private)
  Future<void> _connectToHost(BluetoothDevice device) async {
    try {
      // Stop scanning
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      _isScanning = false;
      
      _hostDevice = device;
      _messageController.add('📡 Verbinden met ${device.platformName}...');
      
      // Connect
      await device.connect(timeout: Duration(seconds: 15));
      _isConnected = true;
      _connectionController.add(true);
      _messageController.add('✅ Verbonden met host!');
      
      // Discover services
      _messageController.add('🔍 Discovering services...');
      List<BluetoothService> services = await device.discoverServices();
      _messageController.add('📋 Gevonden ${services.length} services');
      
      // Log alle services voor debugging
      for (var service in services) {
        _messageController.add('   Service: ${service.uuid}');
      }
      
      // Vind de game service en characteristic
      bool foundService = false;
      for (var service in services) {
        final serviceUuidStr = service.uuid.toString().toLowerCase().replaceAll('-', '');
        final targetUuidStr = serviceUuid.toLowerCase().replaceAll('-', '');
        
        if (serviceUuidStr.contains(targetUuidStr.substring(4, 8))) { // Match op 0xFFF0
          foundService = true;
          _messageController.add('✅ Game service gevonden: ${service.uuid}');
          
          for (var char in service.characteristics) {
            _messageController.add('   Characteristic: ${char.uuid}');
            
            final charUuidStr = char.uuid.toString().toLowerCase().replaceAll('-', '');
            final targetCharStr = characteristicUuid.toLowerCase().replaceAll('-', '');
            
            if (charUuidStr.contains(targetCharStr.substring(4, 8))) { // Match op 0xFFF1
              _characteristic = char;
              _messageController.add('✅ Game characteristic gevonden!');
              
              // Subscribe to notifications
              await _subscribeToNotifications(char);
              break;
            }
          }
          break;
        }
      }
      
      if (!foundService) {
        _messageController.add('⚠️ Game service niet gevonden. Zoek naar: $serviceUuid');
      }
      
      // Setup disconnect handler
      _setupDisconnectHandler(device);
      
    } catch (e) {
      _messageController.add('❌ Verbindingsfout: $e');
      _isConnected = false;
      _connectionController.add(false);
      rethrow;
    }
  }
  
  /// Subscribe naar notificaties van de host
  Future<void> _subscribeToNotifications(BluetoothCharacteristic char) async {
    try {
      await char.setNotifyValue(true);
      
      _notificationSubscription = char.onValueReceived.listen((value) {
        String message = String.fromCharCodes(value);
        _messageController.add('📨 Notificatie van host: $message');
        
        // Parse als GameMessage
        try {
          final gameMessage = GameMessage.fromJson(message);
          _gameMessageController.add(gameMessage);
          
          // Als het een ping is, voeg toe aan ping stream
          if (gameMessage.type == GameMessageType.ping) {
            _pingController.add(PingInfo(
              timestamp: gameMessage.timestamp,
              playerId: gameMessage.playerId,
              receivedAt: DateTime.now(),
            ));
          }
          
        } catch (e) {
          _messageController.add('⚠️ Kon message niet parsen als JSON: $e');
        }
      });
      
      _messageController.add('🔔 Notificaties ingeschakeld');
      
    } catch (e) {
      _messageController.add('❌ Notificatie fout: $e');
    }
  }
  
  /// Setup disconnect handler
  void _setupDisconnectHandler(BluetoothDevice device) {
    device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _isConnected = false;
        _connectionController.add(false);
        _messageController.add('📴 Verbinding verbroken');
        
        // Probeer automatisch opnieuw te verbinden
        _attemptReconnect();
      }
    });
  }
  
  /// Probeer opnieuw te verbinden
  Future<void> _attemptReconnect() async {
    if (_hostDevice == null) return;
    
    _messageController.add('🔄 Proberen opnieuw te verbinden...');
    
    await Future.delayed(Duration(seconds: 2));
    
    try {
      await _connectToHost(_hostDevice!);
    } catch (e) {
      _messageController.add('❌ Reconnect mislukt: $e');
      
      // Probeer nogmaals na 5 seconden
      await Future.delayed(Duration(seconds: 5));
      _attemptReconnect();
    }
  }
  
  /// Stuur een ping naar de host
  Future<void> sendPing() async {
    if (!_isConnected || _characteristic == null) {
      _messageController.add('⚠️ Niet verbonden met host');
      return;
    }
    
    try {
      final pingMessage = GameMessage(
        type: GameMessageType.ping,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        playerId: _playerId,
      );
      
      final jsonString = pingMessage.toJson();
      final bytes = jsonString.codeUnits;
      
      await _characteristic!.write(bytes, withoutResponse: false);
      
      _messageController.add('📤 Ping verzonden naar host');
      
    } catch (e) {
      _messageController.add('❌ Fout bij verzenden ping: $e');
      rethrow;
    }
  }
  
  /// Stuur actie naar de host
  Future<void> sendActionToHost(Map<String, dynamic> action) async {
    if (!_isConnected || _characteristic == null) {
      _messageController.add('⚠️ Niet verbonden met host');
      return;
    }
    
    try {
      // Converteer actie naar bytes
      String jsonString = action.toString();
      List<int> bytes = jsonString.codeUnits;
      
      // Schrijf naar characteristic
      await _characteristic!.write(bytes, withoutResponse: false);
      
      _messageController.add('📤 Actie verzonden naar host: ${action['type']}');
      
    } catch (e) {
      _messageController.add('❌ Fout bij verzenden: $e');
      rethrow;
    }
  }
  
  /// Disconnect van de host
  Future<void> disconnect() async {
    if (_hostDevice != null) {
      try {
        await _hostDevice!.disconnect();
      } catch (e) {
        // Ignore disconnect errors
      }
    }
    
    _isConnected = false;
    _connectionController.add(false);
    _hostDevice = null;
    _characteristic = null;
    
    _messageController.add('🛑 Verbinding afgesloten');
  }
  
  void dispose() {
    _scanSubscription?.cancel();
    _notificationSubscription?.cancel();
    _messageController.close();
    _connectionController.close();
    _gameMessageController.close();
    _pingController.close();
  }
}
