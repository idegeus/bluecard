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
  final StreamController<GameMessage> _gameMessageController = StreamController.broadcast();
  final StreamController<DateTime> _lastSyncController = StreamController.broadcast();
  final StreamController<List<String>> _playerIdsController = StreamController.broadcast();
  
  bool _isAdvertising = false;
  bool _gameStarted = false;
  String? _currentHostName;
  String _playerId = 'host';
  DateTime? _lastSyncTime;
  Timer? _pingTimer;
  
  Stream<String> get messageStream => _messageController.stream;
  Stream<GameMessage> get gameMessageStream => _gameMessageController.stream;
  Stream<DateTime> get lastSyncStream => _lastSyncController.stream;
  Stream<List<String>> get playerIdsStream => _playerIdsController.stream;
  int get connectedClientCount => _connectedClients.length;
  int get totalPlayerCount => _connectedClients.length + 1; // +1 voor host
  List<String> get playerIds {
    final ids = ['host'];
    for (var client in _connectedClients) {
      ids.add(client['playerId'] ?? 'unknown');
    }
    return ids;
  }
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
    
    // Genereer player ID voor nieuwe client (gebaseerd op aantal spelers)
    final playerId = 'player${_connectedClients.length + 1}';
    
    _connectedClients.add({
      'name': name,
      'address': address,
      'playerId': playerId,
    });
    _playerIdsController.add(playerIds); // Broadcast nieuwe player lijst
    _log('📱 Client verbonden: $name ($playerId)');
    _log('👥 Totaal clients: ${_connectedClients.length}');
    
    // Kleine delay om te zorgen dat client notifications goed ingesteld zijn
    Future.delayed(Duration(milliseconds: 500), () {
      // Stuur playerJoined message naar alle clients
      _sendPlayerJoinedMessage();
    });
  }
  
  /// Client verbroken callback
  void _onClientDisconnected(String name, String address) {
    _connectedClients.removeWhere((client) => client['address'] == address);
    _playerIdsController.add(playerIds); // Broadcast nieuwe player lijst
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
      // Check of Bluetooth aan staat
      final bool bluetoothEnabled = await _channel.invokeMethod('isBluetoothEnabled');
      
      if (!bluetoothEnabled) {
        _log('⚠️ Bluetooth is uitgeschakeld');
        _log('📱 Probeer Bluetooth aan te zetten...');
        
        // Vraag om Bluetooth aan te zetten
        final bool enabled = await _channel.invokeMethod('enableBluetooth');
        
        if (!enabled) {
          _log('❌ Bluetooth kon niet worden aangezet');
          throw Exception('Bluetooth is uitgeschakeld. Zet Bluetooth aan om door te gaan.');
        }
        
        _log('✅ Bluetooth aangezet');
      }
      
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
      _playerIdsController.add(['host']); // Reset naar alleen host
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
    print('🎮 Broadcasting startGame to host itself');
    _gameMessageController.add(startMessage);
    print('🎮 startGame broadcasted');
  }
  
  /// Stuur een ping
  Future<void> sendPing() async {
    final now = DateTime.now();
    final pingMessage = GameMessage(
      type: GameMessageType.ping,
      timestamp: now.millisecondsSinceEpoch,
      playerId: _playerId,
    );
    
    await _sendGameMessage(pingMessage);
    
    // Update last sync time
    _lastSyncTime = now;
    _lastSyncController.add(now);
    
    // Broadcast ook naar host zelf
    _broadcastGameMessage(pingMessage);
  }
  
  /// Sluit game netjes af en stuur goodbye message
  Future<void> quitGame() async {
    _log('👋 Afsluiten van game...');
    
    // Stuur goodbye message naar alle clients
    final goodbyeMessage = GameMessage(
      type: GameMessageType.goodbye,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      playerId: _playerId,
    );
    
    await _sendGameMessage(goodbyeMessage);
    
    // Wacht even zodat bericht verzonden kan worden
    await Future.delayed(Duration(milliseconds: 500));
    
    // Stop de server
    await stopServer();
    
    // NIET dispose() aanroepen - streams blijven beschikbaar voor logging
    // dispose() wordt aangeroepen door de app wanneer deze echt afsluit
    
    _log('✅ Game afgesloten');
  }
  
  /// Stuur playerJoined message naar alle clients
  Future<void> _sendPlayerJoinedMessage() async {
    // Verzamel alle player IDs (host + alle clients)
    final List<String> playerIds = ['host'];
    for (var client in _connectedClients) {
      playerIds.add(client['playerId'] ?? 'unknown');
    }
    
    final playerJoinedMessage = GameMessage(
      type: GameMessageType.playerJoined,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      playerId: _playerId,
      content: {
        'playerCount': _connectedClients.length + 1, // +1 voor host
        'playerIds': playerIds,
      },
    );
    
    await _sendGameMessage(playerJoinedMessage);
    _log('📢 PlayerJoined message verzonden: ${playerIds.length} spelers');
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
    _gameMessageController.close();
    _lastSyncController.close();
    _playerIdsController.close();
  }
}
