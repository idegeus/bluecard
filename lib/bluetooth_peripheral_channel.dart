import 'package:flutter/services.dart';
import 'debug_service.dart';

class BluetoothPeripheralChannel {
  static const MethodChannel _channel = MethodChannel('bluecard.ble.peripheral');
  
  // Callback functions
  static Function(String, String)? onClientConnected;
  static Function(String, String)? onClientDisconnected;
  static Function(String, String)? onDataReceived;
  
  static void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onClientConnected':
          final String name = call.arguments['name'];
          final String address = call.arguments['address'];
          onClientConnected?.call(name, address);
          break;
        case 'onClientDisconnected':
          final String name = call.arguments['name'];
          final String address = call.arguments['address'];
          onClientDisconnected?.call(name, address);
          break;
        case 'onDataReceived':
          final String address = call.arguments['address'];
          final String data = call.arguments['data'];
          onDataReceived?.call(address, data);
          break;
      }
    });
  }

  /// Check if BLE peripheral is supported
  static Future<bool> isPeripheralSupported() async {
    _setupMethodCallHandler(); // Ensure handler is set up
    try {
      final bool result = await _channel.invokeMethod('isPeripheralSupported');
      return result;
    } catch (e) {
      DebugService().log('❌ Error checking peripheral support: $e');
      return false;
    }
  }
  
  /// Start BLE advertising with game service
  static Future<bool> startAdvertising({
    required String serviceUuid,
    required String deviceName,
  }) async {
    try {
      DebugService().log('� Calling native startAdvertising...');
      
      final result = await _channel.invokeMethod('startAdvertising', {
        'serviceUuid': serviceUuid,
        'deviceName': deviceName,
      });
      
      DebugService().log('✅ Native advertising result: $result');
      return result == true;
    } on PlatformException catch (e) {
      DebugService().log('❌ Platform error: ${e.message}');
      return false;
    } catch (e) {
      DebugService().log('❌ Channel error: $e');
      return false;
    }
  }
  
  /// Stop BLE advertising
  static Future<bool> stopAdvertising() async {
    try {
      DebugService().log('🛑 Calling native stopAdvertising...');
      
      final result = await _channel.invokeMethod('stopAdvertising');
      
      DebugService().log('✅ Native stop result: $result');
      return result == true;
    } on PlatformException catch (e) {
      DebugService().log('❌ Platform error: ${e.message}');
      return false;
    } catch (e) {
      DebugService().log('❌ Channel error: $e');
      return false;
    }
  }
  
  /// Setup GATT server with game service and characteristics
  static Future<bool> setupGattServer({
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    try {
      DebugService().log('🔧 Setting up GATT server...');
      
      final result = await _channel.invokeMethod('setupGattServer', {
        'serviceUuid': serviceUuid,
        'characteristicUuid': characteristicUuid,
      });
      
      DebugService().log('✅ GATT server setup result: $result');
      return result == true;
    } on PlatformException catch (e) {
      DebugService().log('❌ GATT setup error: ${e.message}');
      return false;
    } catch (e) {
      DebugService().log('❌ GATT setup error: $e');
      return false;
    }
  }
  
  /// Send data to connected client
  static Future<bool> sendData(String data) async {
    try {
      final result = await _channel.invokeMethod('sendData', {'data': data});
      return result == true;
    } catch (e) {
      DebugService().log('❌ Error sending data: $e');
      return false;
    }
  }
  
  /// Get list of connected clients
  static Future<List<Map<String, String>>> getConnectedClients() async {
    try {
      final result = await _channel.invokeMethod('getConnectedClients');
      return List<Map<String, String>>.from(result.map((item) => Map<String, String>.from(item)));
    } catch (e) {
      DebugService().log('❌ Error getting connected clients: $e');
      return [];
    }
  }
}