import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/game_message.dart';

/// BluetoothHost - GATT Server voor de kaartspel host
/// Beheert de GATT service, notificaties naar clients, en verbindingen
class BluetoothHost {
  static const String serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
  static const String characteristicUuid = '0000fff1-0000-1000-8000-00805f9b34fb';
  
  static const MethodChannel _channel = MethodChannel('bluecard.gatt.server');
  
  final List<Map<String, String>> _connectedClients = []; // Changed to Map to store name & address
  final StreamController<String> _messageController = StreamController.broadcast();
  final StreamController<int> _clientCountController = StreamController.broadcast();
  final StreamController<GameMessage> _gameMessageController = StreamController.broadcast();
  final StreamController<PingInfo> _pingController = StreamController.broadcast();
  
  bool _isAdvertising = false;
  bool _gameStarted = false;
  String? _currentHostName;
  String _playerId = 'host';
  
  Stream<String> get messageStream => _messageController.stream;
  Stream<int> get clientCountStream => _clientCountController.stream;
  Stream<GameMessage> get gameMessageStream => _gameMessageController.stream;
  Stream<PingInfo> get pingStream => _pingController.stream;
  int get connectedClientCount => _connectedClients.length;
  bool get isAdvertising => _isAdvertising;
  bool get gameStarted => _gameStarted;
  String? get hostName => _currentHostName;
  String get playerId => _playerId;
  
  BluetoothHost() {
    // Setup method call handler voor callbacks van native code
    _channel.setMethodCallHandler(_handleNativeCallback);
  }
  
  /// Handle callbacks van de native GATT server
  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case 'onClientConnected':
        final String name = call.arguments['name'] ?? 'Unknown';
        final String address = call.arguments['address'] ?? '';
        _onClientConnected(name, address);
        break;
        
      case 'onClientDisconnected':
        final String name = call.arguments['name'] ?? 'Unknown';
        final String address = call.arguments['address'] ?? '';
        _onClientDisconnected(name, address);
        break;
        
      case 'onDataReceived':
        final String address = call.arguments['address'] ?? '';
        final Uint8List data = call.arguments['data'];
        _onDataReceived(address, data);
        break;
    }
  }
  
  /// Client verbonden callback
  void _onClientConnected(String name, String address) {
    if (_gameStarted) {
      _messageController.add('⛔ Game al gestart, client $name geweigerd');
      return;
    }
    
    _connectedClients.add({'name': name, 'address': address});
    _clientCountController.add(_connectedClients.length);
    _messageController.add('📱 Client verbonden: $name ($address)');
    _messageController.add('👥 Totaal clients: ${_connectedClients.length}');
  }
  
  /// Client verbroken callback
  void _onClientDisconnected(String name, String address) {
    _connectedClients.removeWhere((client) => client['address'] == address);
    _clientCountController.add(_connectedClients.length);
    _messageController.add('📴 Client verbroken: $name ($address)');
    _messageController.add('👥 Totaal clients: ${_connectedClients.length}');
  }
  
  /// Data ontvangen callback - parse als GameMessage
  void _onDataReceived(String address, Uint8List data) {
    final String message = String.fromCharCodes(data);
    _messageController.add('📨 Data ontvangen van $address: $message');
    
    try {
      // Parse als GameMessage
      final gameMessage = GameMessage.fromJson(message);
      
      // Broadcast naar alle clients inclusief host zelf
      _broadcastGameMessage(gameMessage);
      
    } catch (e) {
      _messageController.add('⚠️ Kon message niet parsen als JSON: $e');
    }
  }
  
  Stream<List<BluetoothDevice>> get clientsStream => throw UnimplementedError('Use clientCountStream instead');
  List<BluetoothDevice> get connectedClients => throw UnimplementedError('Not implemented for native GATT server');
  
  /// Start de GATT server en begin met adverteren
  Future<void> startServer() async {
    try {
      // Genereer unieke host naam met BlueCard
      final hostId = DateTime.now().millisecondsSinceEpoch % 10000;
      _currentHostName = 'BlueCard-Host-$hostId';
      
      _messageController.add('🚀 Starting native GATT server...');
      _messageController.add('📱 Device name: $_currentHostName');
      
      // Roep de native Kotlin methode aan
      final bool success = await _channel.invokeMethod('startServer', {
        'deviceName': _currentHostName,
      });
      
      if (success) {
        _isAdvertising = true;
        _messageController.add('✅ GATT Server gestart!');
        _messageController.add('📡 Service UUID: $serviceUuid');
        _messageController.add('📝 Characteristic UUID: $characteristicUuid');
        _messageController.add('🔍 Zoek naar "$_currentHostName" in je Bluetooth scanner');
      } else {
        _messageController.add('❌ GATT Server kon niet starten');
        throw Exception('Failed to start GATT server');
      }
      
    } catch (e) {
      _isAdvertising = false;
      _messageController.add('❌ Fout bij starten server: $e');
      rethrow;
    }
  }
  
  /// Stop de GATT server
  Future<void> stopServer() async {
    try {
      _messageController.add('🛑 Stopping GATT server...');
      
      // Roep de native Kotlin methode aan
      await _channel.invokeMethod('stopServer');
      
      _isAdvertising = false;
      _currentHostName = null;
      _connectedClients.clear();
      _clientCountController.add(0);
      _messageController.add('✅ GATT Server gestopt');
      
    } catch (e) {
      _messageController.add('❌ Fout bij stoppen server: $e');
      rethrow;
    }
  }
  
  /// Stuur notificatie naar alle clients
  Future<void> sendNotificationToClients(String message) async {
    try {
      _messageController.add('📤 Sending notification: $message');
      
      // Converteer string naar bytes
      final data = message.codeUnits;
      
      // Roep de native Kotlin methode aan
      final bool success = await _channel.invokeMethod('sendData', {
        'data': Uint8List.fromList(data),
      });
      
      if (success) {
        _messageController.add('✅ Notificatie verzonden naar alle clients');
      } else {
        _messageController.add('⚠️ Geen clients verbonden of verzenden mislukt');
      }
      
    } catch (e) {
      _messageController.add('❌ Fout bij verzenden notificatie: $e');
      rethrow;
    }
  }
  
  /// Start het spel - geen nieuwe clients meer toegestaan
  Future<void> startGame() async {
    if (_gameStarted) {
      _messageController.add('⚠️ Game is al gestart');
      return;
    }
    
    if (_connectedClients.isEmpty) {
      _messageController.add('⚠️ Geen clients verbonden');
      return;
    }
    
    _gameStarted = true;
    _messageController.add('🎮 Game gestart! Geen nieuwe spelers meer toegestaan');
    
    // Stuur start_game message naar alle clients
    final startMessage = GameMessage(
      type: GameMessageType.startGame,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      playerId: _playerId,
    );
    
    await _sendGameMessage(startMessage);
    
    // Broadcast ook naar host zelf
    _gameMessageController.add(startMessage);
  }
  
  /// Stuur een ping
  Future<void> sendPing() async {
    final pingMessage = GameMessage(
      type: GameMessageType.ping,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      playerId: _playerId,
    );
    
    await _sendGameMessage(pingMessage);
    
    // Broadcast ook naar host zelf
    _broadcastGameMessage(pingMessage);
  }
  
  /// Stuur GameMessage naar alle clients
  Future<void> _sendGameMessage(GameMessage message) async {
    try {
      final jsonString = message.toJson();
      final data = jsonString.codeUnits;
      
      await _channel.invokeMethod('sendData', {
        'data': Uint8List.fromList(data),
      });
      
    } catch (e) {
      _messageController.add('❌ Fout bij verzenden game message: $e');
      rethrow;
    }
  }
  
  /// Broadcast GameMessage naar alle clients EN host zelf
  void _broadcastGameMessage(GameMessage message) {
    // Add to game message stream
    _gameMessageController.add(message);
    
    // Add to ping stream if it's a ping
    if (message.type == GameMessageType.ping) {
      _pingController.add(PingInfo(
        timestamp: message.timestamp,
        playerId: message.playerId,
        receivedAt: DateTime.now(),
      ));
    }
    
    _messageController.add('📡 Broadcast: ${message.type.name} van ${message.playerId}');
  }
  
  void dispose() {
    _messageController.close();
    _clientCountController.close();
    _gameMessageController.close();
    _pingController.close();
  }
}
