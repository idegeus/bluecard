import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../models/game_message.dart';

/// BluetoothClient - Verbindt met de GATT server van de host via ClientService
/// Beheert de verbinding via een Foreground Service die in de achtergrond draait
class BluetoothClient {
  static const String serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
  static const String characteristicUuid = '0000fff1-0000-1000-8000-00805f9b34fb';
  
  // MethodChannel voor communicatie met ClientService
  static const MethodChannel _channel = MethodChannel('bluecard.client.service');
  
  final StreamController<String> _messageController = StreamController.broadcast();
  final StreamController<bool> _connectionController = StreamController.broadcast();
  final StreamController<GameMessage> _gameMessageController = StreamController.broadcast();
  final StreamController<PingInfo> _pingController = StreamController.broadcast();
  final StreamController<DateTime> _lastSyncController = StreamController.broadcast();
  
  bool _isConnected = false;
  bool _isScanning = false;
  String _playerId = 'client';
  String? _connectedHostName;
  
  Stream<String> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<GameMessage> get gameMessageStream => _gameMessageController.stream;
  Stream<PingInfo> get pingStream => _pingController.stream;
  Stream<DateTime> get lastSyncStream => _lastSyncController.stream;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  String? get connectedHostName => _connectedHostName;
  String get playerId => _playerId;
  
  BluetoothClient() {
    // Setup callback handlers voor berichten van de ClientService
    _channel.setMethodCallHandler(_handleCallback);
  }
  
  void setPlayerId(String id) {
    _playerId = id;
  }
  
  /// Helper om berichten zowel naar UI als debug log te sturen
  void _log(String message) {
    _messageController.add(message);
    print('[BluetoothClient] $message'); // Flutter debug console
  }
  
  /// Callback handler voor berichten van de ClientService
  Future<void> _handleCallback(MethodCall call) async {
    switch (call.method) {
      case 'onConnectionStateChanged':
        final bool connected = call.arguments['connected'] ?? false;
        _isConnected = connected;
        _connectionController.add(connected);
        
        if (connected) {
          _log('✅ Verbonden met host service');
          _isScanning = false;
        } else {
          _log('⚠️ Verbinding verbroken');
          _connectedHostName = null;
        }
        break;
        
      case 'onDataReceived':
        final Uint8List data = call.arguments['data'];
        final message = String.fromCharCodes(data);
        
        // Alle berichten zijn nu GameMessages
        try {
          final gameMessage = GameMessage.fromJson(message);
          _gameMessageController.add(gameMessage);
          
          _log('📨 Ontvangen ${gameMessage.type.name} van host');
          
          // Handle specifieke message types
          switch (gameMessage.type) {
            case GameMessageType.ping:
              final pingInfo = PingInfo(
                timestamp: gameMessage.timestamp,
                playerId: gameMessage.playerId,
                receivedAt: DateTime.now(),
              );
              _pingController.add(pingInfo);
              
              // Update last sync time
              if (!_lastSyncController.isClosed) {
                _lastSyncController.add(DateTime.now());
              }
              break;
              
            case GameMessageType.startGame:
              _log('🎮 Game gestart door host!');
              break;
          }
          
          // Log content als het bestaat
          if (gameMessage.content != null && gameMessage.content!.isNotEmpty) {
            _log('📦 Content: ${gameMessage.content}');
          }
        } catch (e) {
          _log('❌ Fout bij parsen bericht: $e');
          _log('📨 Raw bericht: $message');
        }
        break;
        
      case 'onGameMessage':
        final String jsonString = call.arguments['message'];
        try {
          final gameMessage = GameMessage.fromJson(jsonString);
          _gameMessageController.add(gameMessage);
          
          if (gameMessage.type == GameMessageType.startGame) {
            _log('🎮 Game gestart door host!');
          }
        } catch (e) {
          _log('❌ Fout bij parsen game message: $e');
        }
        break;
        
      default:
        _log('⚠️ Unknown callback: ${call.method}');
    }
  }
  
  /// Start de Client Service en zoek naar een host
  Future<void> searchForHost() async {
    try {
      _isScanning = true;
      _log('🔍 Starting Client Service...');
      _log('📡 Service UUID: $serviceUuid');
      
      // Start de Foreground Service
      // De service begint automatisch met scannen naar BlueCard hosts
      final bool success = await _channel.invokeMethod('startClientService');
      
      if (success) {
        _log('✅ Client Service gestart!');
        _log('🔍 Zoeken naar BlueCard hosts...');
        _log('🔔 Notificatie actief - service draait in achtergrond');
      } else {
        _log('❌ Client Service kon niet starten');
        _isScanning = false;
        throw Exception('Failed to start client service');
      }
      
    } catch (e) {
      _isScanning = false;
      _log('❌ Fout bij starten client service: $e');
      rethrow;
    }
  }
  
  /// Stuur een ping naar de host via de Service
  Future<void> sendPing() async {
    if (!_isConnected) {
      _log('⚠️ Niet verbonden met host');
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
      
      await _channel.invokeMethod('sendDataToHost', {
        'data': Uint8List.fromList(bytes),
      });
      
      _log('📤 Ping verzonden naar host');
      
    } catch (e) {
      _log('❌ Fout bij verzenden ping: $e');
      rethrow;
    }
  }
  
  /// Stuur een custom message naar de host
  Future<void> sendMessage({
    required GameMessageType type,
    Map<String, dynamic>? content,
  }) async {
    if (!_isConnected) {
      _log('⚠️ Niet verbonden met host');
      return;
    }
    
    try {
      final message = GameMessage(
        type: type,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        playerId: _playerId,
        content: content,
      );
      
      final jsonString = message.toJson();
      final bytes = jsonString.codeUnits;
      
      await _channel.invokeMethod('sendDataToHost', {
        'data': Uint8List.fromList(bytes),
      });
      
      _log('📤 ${type.name} verzonden naar host');
      
    } catch (e) {
      _log('❌ Fout bij verzenden: $e');
      rethrow;
    }
  }
  
  /// Stop de Client Service en disconnect van de host
  Future<void> disconnect() async {
    try {
      _log('🛑 Stopping Client Service...');
      
      // Stop de Foreground Service
      await _channel.invokeMethod('stopClientService');
      
      _isConnected = false;
      _isScanning = false;
      _connectedHostName = null;
      _connectionController.add(false);
      _log('✅ Client Service gestopt');
      
    } catch (e) {
      _log('❌ Fout bij stoppen service: $e');
      rethrow;
    }
  }
  
  void dispose() {
    _messageController.close();
    _connectionController.close();
    _gameMessageController.close();
    _pingController.close();
    _lastSyncController.close();
  }
}
