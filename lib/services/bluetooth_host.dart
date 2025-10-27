import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BluetoothHost - GATT Server voor de kaartspel host
/// Beheert de GATT service, notificaties naar clients, en verbindingen
class BluetoothHost {
  static const String serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
  static const String characteristicUuid = '0000fff1-0000-1000-8000-00805f9b34fb';
  
  static const MethodChannel _channel = MethodChannel('bluecard.gatt.server');
  
  final List<Map<String, String>> _connectedClients = []; // Changed to Map to store name & address
  final StreamController<String> _messageController = StreamController.broadcast();
  final StreamController<int> _clientCountController = StreamController.broadcast();
  
  bool _isAdvertising = false;
  String? _currentHostName;
  
  Stream<String> get messageStream => _messageController.stream;
  Stream<int> get clientCountStream => _clientCountController.stream;
  int get connectedClientCount => _connectedClients.length;
  bool get isAdvertising => _isAdvertising;
  String? get hostName => _currentHostName;
  
  BluetoothHost() {
    // Setup method call handler voor callbacks van native code
    _channel.setMethodCallHandler(_handleNativeCallback);
    _messageController.add('🔧 BluetoothHost initialized, callback handler registered');
  }
  
  /// Handle callbacks van de native GATT server
  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    print('🔔 [BluetoothHost] Native callback received: ${call.method}');
    print('🔔 [BluetoothHost] Arguments: ${call.arguments}');
    _messageController.add('📞 Native callback received: ${call.method}');
    
    switch (call.method) {
      case 'onClientConnected':
        final String name = call.arguments['name'] ?? 'Unknown';
        final String address = call.arguments['address'] ?? '';
        print('🔔 [BluetoothHost] Processing onClientConnected: $name ($address)');
        _messageController.add('🔔 Processing onClientConnected: $name ($address)');
        _onClientConnected(name, address);
        break;
        
      case 'onClientDisconnected':
        final String name = call.arguments['name'] ?? 'Unknown';
        final String address = call.arguments['address'] ?? '';
        print('🔔 [BluetoothHost] Processing onClientDisconnected: $name ($address)');
        _messageController.add('🔔 Processing onClientDisconnected: $name ($address)');
        _onClientDisconnected(name, address);
        break;
        
      case 'onDataReceived':
        final String address = call.arguments['address'] ?? '';
        final Uint8List data = call.arguments['data'];
        print('🔔 [BluetoothHost] Processing onDataReceived from: $address (${data.length} bytes)');
        _messageController.add('🔔 Processing onDataReceived from: $address');
        _onDataReceived(address, data);
        break;
        
      default:
        print('⚠️ [BluetoothHost] Unknown callback method: ${call.method}');
        _messageController.add('⚠️ Unknown callback method: ${call.method}');
    }
  }
  
  /// Client verbonden callback
  void _onClientConnected(String name, String address) {
    print('✅ [BluetoothHost] _onClientConnected called: $name ($address)');
    _connectedClients.add({'name': name, 'address': address});
    print('✅ [BluetoothHost] Client added, total: ${_connectedClients.length}');
    _clientCountController.add(_connectedClients.length);
    print('✅ [BluetoothHost] Count stream updated');
    _messageController.add('📱 Client verbonden: $name ($address)');
    _messageController.add('👥 Totaal clients: ${_connectedClients.length}');
    print('✅ [BluetoothHost] Messages added to stream');
  }
  
  /// Client verbroken callback
  void _onClientDisconnected(String name, String address) {
    _connectedClients.removeWhere((client) => client['address'] == address);
    _clientCountController.add(_connectedClients.length);
    _messageController.add('📴 Client verbroken: $name ($address)');
    _messageController.add('👥 Totaal clients: ${_connectedClients.length}');
  }
  
  /// Data ontvangen callback
  void _onDataReceived(String address, Uint8List data) {
    final String message = String.fromCharCodes(data);
    _messageController.add('📨 Data ontvangen van $address: $message');
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
  
  /// Test method om callbacks te checken
  Future<void> testNativeCallback() async {
    try {
      _messageController.add('🧪 Testing native callback...');
      
      // Vraag aantal clients op
      final int count = await _channel.invokeMethod('getConnectedClients');
      _messageController.add('📊 Native reports $count connected clients');
      
      // Update de UI
      if (count != _connectedClients.length) {
        _messageController.add('⚠️ Mismatch! Flutter has ${_connectedClients.length}, native has $count');
      }
      
    } catch (e) {
      _messageController.add('❌ Test failed: $e');
    }
  }
  
  void dispose() {
    _messageController.close();
    _clientCountController.close();
  }
}
