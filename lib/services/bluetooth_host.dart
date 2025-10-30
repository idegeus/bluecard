import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/game_message.dart';

/// BluetoothHost - GATT Server via Foreground Service
/// Beheert de GATT service, notificaties naar clients, en verbindingen
class BluetoothHost {
  static const String serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
  static const String characteristicUuid = '0000fff1-0000-1000-8000-00805f9b34fb';
  
  static const MethodChannel _channel = MethodChannel('bluecard.host.service');
  
  final List<Map<String, String>> _connectedClients = [];
  final StreamController<String> _messageController = StreamController.broadcast();
  final StreamController<int> _clientCountController = StreamController.broadcast();
  final StreamController<GameMessage> _gameMessageController = StreamController.broadcast();
  final StreamController<DateTime> _lastSyncController = StreamController.broadcast();
  
  bool _isAdvertising = false;
  bool _gameStarted = false;
  String? _currentHostName;
  String _playerId = 'host';
  DateTime? _lastSyncTime;
  Timer? _pingTimer;
  
  Stream<String> get messageStream => _messageController.stream;
  Stream<int> get clientCountStream => _clientCountController.stream;
  Stream<GameMessage> get gameMessageStream => _gameMessageController.stream;
  Stream<DateTime> get lastSyncStream => _lastSyncController.stream;
  int get connectedClientCount => _connectedClients.length;
  int get totalPlayerCount => _connectedClients.length + 1; // +1 voor host
  bool get isAdvertising => _isAdvertising;
  bool get gameStarted => _gameStarted;
  String? get hostName => _currentHostName;
  String get playerId => _playerId;
  DateTime? get lastSyncTime => _lastSyncTime;
  
  BluetoothHost() {
    // Setup method call handler voor callbacks van native service
    _channel.setMethodCallHandler(_handleNativeCallback);
  }
  
  /// Helper om berichten zowel naar UI als debug log te sturen
  void _log(String message) {
    _messageController.add(message);
    print('[BluetoothHost] $message'); // Flutter debug console
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
      _log('⛔ Game al gestart, client $name geweigerd');
      return;
    }
    
    _connectedClients.add({'name': name, 'address': address});
    _clientCountController.add(_connectedClients.length);
    _log('📱 Client verbonden: $name ($address)');
    _log('👥 Totaal clients: ${_connectedClients.length}');
  }
  
  /// Client verbroken callback
  void _onClientDisconnected(String name, String address) {
    _connectedClients.removeWhere((client) => client['address'] == address);
    _clientCountController.add(_connectedClients.length);
    _log('📴 Client verbroken: $name ($address)');
    _log('👥 Totaal clients: ${_connectedClients.length}');
  }
  
  /// Data ontvangen callback - alle berichten zijn GameMessages
  void _onDataReceived(String address, Uint8List data) {
    final String message = String.fromCharCodes(data);
    
    try {
      // Parse als GameMessage
      final gameMessage = GameMessage.fromJson(message);
      
      _log('📨 Ontvangen ${gameMessage.type.name} van ${gameMessage.playerId} ($address)');
      
      // Log content als het bestaat
      if (gameMessage.content != null && gameMessage.content!.isNotEmpty) {
        _log('📦 Content: ${gameMessage.content}');
      }
      
      // Broadcast naar alle clients inclusief host zelf
      _broadcastGameMessage(gameMessage);
      
    } catch (e) {
      _log('❌ Fout bij parsen bericht: $e');
      _log('📨 Raw bericht: $message');
    }
  }
  
  Stream<List<BluetoothDevice>> get clientsStream => throw UnimplementedError('Use clientCountStream instead');
  List<BluetoothDevice> get connectedClients => throw UnimplementedError('Not implemented for native GATT server');
  
  /// Start de Host Service en begin met adverteren
  Future<void> startServer() async {
    try {
      // Genereer unieke host naam met BlueCard
      final hostId = DateTime.now().millisecondsSinceEpoch % 10000;
      _currentHostName = 'BlueCard-Host-$hostId';
      
      _log('🚀 Starting Host Service...');
      _log('📱 Device name: $_currentHostName');
      
      // Start de Foreground Service
      final bool success = await _channel.invokeMethod('startHostService', {
        'deviceName': _currentHostName,
      });
      
      if (success) {
        _isAdvertising = true;
        _startPingTimer();
        _log('✅ Host Service gestart!');
        _log('📡 Service UUID: $serviceUuid');
        _log('📝 Characteristic UUID: $characteristicUuid');
        _log('🔍 Zoek naar "$_currentHostName" in je Bluetooth scanner');
        _log('🔔 Notificatie actief - service draait in achtergrond');
      } else {
        _log('❌ Host Service kon niet starten');
        throw Exception('Failed to start host service');
      }
      
    } catch (e) {
      _isAdvertising = false;
      _log('❌ Fout bij starten server: $e');
      rethrow;
    }
  }
  
  /// Stop de Host Service
  Future<void> stopServer() async {
    try {
      _log('🛑 Stopping Host Service...');
      
      _stopPingTimer();
      
      // Stop de Foreground Service
      await _channel.invokeMethod('stopHostService');
      
      _isAdvertising = false;
      _gameStarted = false;
      _currentHostName = null;
      _connectedClients.clear();
      _clientCountController.add(0);
      _log('✅ Host Service gestopt');
      
    } catch (e) {
      _log('❌ Fout bij stoppen server: $e');
      rethrow;
    }
  }
  
  /// Stuur notificatie naar alle clients via de Service
  Future<void> sendNotificationToClients(String message) async {
    try {
      if (_connectedClients.isEmpty) {
        _log('⚠️ Geen clients verbonden');
        return;
      }
      
      final data = message.codeUnits;
      
      // Stuur via de Service naar alle clients
      await _channel.invokeMethod('sendData', {
        'data': Uint8List.fromList(data),
      });
      
      _log('📤 Bericht verzonden naar ${_connectedClients.length} clients: "$message"');
      
    } catch (e) {
      _log('❌ Fout bij verzenden notificatie: $e');
      rethrow;
    }
  }
  
  /// Start het spel - geen nieuwe clients meer toegestaan
  Future<void> startGame() async {
    if (_gameStarted) {
      _log('⚠️ Game is al gestart');
      return;
    }
    
    if (_connectedClients.isEmpty) {
      _log('⚠️ Geen clients verbonden');
      return;
    }
    
    _gameStarted = true;
    _log('🎮 Game gestart! Geen nieuwe spelers meer toegestaan');
    
    // Roep de native methode aan
    await _channel.invokeMethod('startGame');
    
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
  
  /// Start automatische ping timer (elke 10 seconden)
  void _startPingTimer() {
    _stopPingTimer(); // Stop oude timer indien actief
    
    _pingTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (_isAdvertising && _connectedClients.isNotEmpty) {
        sendPing();
      }
    });
    
    _log('⏱️ Automatische ping gestart (elke 10s)');
  }
  
  /// Stop automatische ping timer
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }
  
  /// Stuur een custom message naar alle clients
  Future<void> sendMessage({
    required GameMessageType type,
    Map<String, dynamic>? content,
  }) async {
    final message = GameMessage(
      type: type,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      playerId: _playerId,
      content: content,
    );
    
    await _sendGameMessage(message);
    
    // Broadcast ook naar host zelf
    _broadcastGameMessage(message);
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
      _log('❌ Fout bij verzenden game message: $e');
      rethrow;
    }
  }
  
  /// Broadcast GameMessage naar alle clients EN host zelf
  void _broadcastGameMessage(GameMessage message) {
    // Add to game message stream
    _gameMessageController.add(message);
    
    _log('📡 Broadcast: ${message.type.name} van ${message.playerId}');
  }
  
  void dispose() {
    _messageController.close();
    _clientCountController.close();
    _gameMessageController.close();
    _lastSyncController.close();
  }
}
