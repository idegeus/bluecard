import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/game_message.dart';
import 'settings_service.dart';

/// BluetoothHost - GATT Server via Foreground Service
/// Beheert de GATT service, notificaties naar clients, en verbindingen
class BluetoothHost {
  static const String serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
  static const String characteristicUuid =
      '0000fff1-0000-1000-8000-00805f9b34fb';

  static const MethodChannel _channel = MethodChannel('bluecard.host.service');

  final List<Map<String, String>> _connectedClients = [];
  final Map<String, String> _deviceToPlayerMap =
      {}; // Map device address to stable player ID
  final Map<String, String> _clientDeviceNames =
      {}; // Map playerId to device name
  final StreamController<String> _messageController =
      StreamController.broadcast();
  final StreamController<GameMessage> _gameMessageController =
      StreamController.broadcast();
  final StreamController<DateTime> _lastSyncController =
      StreamController.broadcast();
  final StreamController<List<String>> _playerIdsController =
      StreamController.broadcast();

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

  List<Map<String, String>> get playerInfo {
    // Update host name in background zonder te wachten
    _updateHostNameInBackground();

    final info = [
      {
        'playerId': 'host',
        'name': _currentHostName ?? 'Host',
        'address': 'local',
      },
    ];
    for (var client in _connectedClients) {
      final playerId = client['playerId'] ?? 'unknown';
      // Gebruik device name uit client berichten als beschikbaar, anders fallback
      final name = _clientDeviceNames[playerId] ?? client['name'] ?? 'Unknown';
      info.add({
        'playerId': playerId,
        'name': name,
        'address': client['address'] ?? '',
      });
    }
    return info;
  }

  void _updateHostNameInBackground() {
    SettingsService.getUserName().then((name) {
      if (_currentHostName != name) {
        _currentHostName = name;
        // Trigger UI refresh
        _playerIdsController.add(playerIds);
      }
    });
  }

  bool get isAdvertising => _isAdvertising;
  bool get gameStarted => _gameStarted;
  String? get hostName => _currentHostName;
  String get playerId => _playerId;
  DateTime? get lastSyncTime => _lastSyncTime;

  BluetoothHost() {
    // Setup method call handler voor callbacks van native service
    _channel.setMethodCallHandler(_handleNativeCallback);

    // Initialiseer host naam uit settings
    _initializeHostName();
  }

  /// Initialiseer host naam uit settings
  Future<void> _initializeHostName() async {
    try {
      _currentHostName = await SettingsService.getUserName();
      _log('🖥️ Host naam: $_currentHostName');
    } catch (e) {
      _currentHostName = 'Host';
      _log('⚠️ Kon host naam niet ophalen: $e');
    }
  }

  /// Update host naam (bijv. na settings wijziging)
  Future<void> updateHostName() async {
    try {
      _currentHostName = await SettingsService.getUserName();
      _log('🖥️ Host naam geüpdatet: $_currentHostName');
      // Trigger UI update door playerIds opnieuw te versturen
      _playerIdsController.add(playerIds);
    } catch (e) {
      _log('⚠️ Kon host naam niet updaten: $e');
    }
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

    // Check if this client is already connected (prevent duplicates)
    final existingClient = _connectedClients.firstWhere(
      (client) => client['address'] == address,
      orElse: () => {},
    );

    if (existingClient.isNotEmpty) {
      _log('⚠️ Client $name ($address) is al verbonden');
      return;
    }

    // Use device address to generate stable player ID
    String playerId;
    if (_deviceToPlayerMap.containsKey(address)) {
      // This device has connected before, reuse its player ID
      playerId = _deviceToPlayerMap[address]!;
      _log('🔄 Bekende device: $name herverbonden als $playerId');
    } else {
      // New device, assign new player ID
      final playerNumber = _deviceToPlayerMap.length + 1;
      playerId = 'player$playerNumber';
      _deviceToPlayerMap[address] = playerId;
      _log('🆕 Nieuw device: $name geregistreerd als $playerId');
    }
    _connectedClients.add({
      'name': name,
      'address': address,
      'playerId': playerId,
    });
    _playerIdsController.add(playerIds); // Broadcast nieuwe player lijst
    _log('📱 Client verbonden: $name ($playerId)');
    _log('👥 Totaal clients: ${_connectedClients.length}');

    // Stuur een gecombineerde welcome message met assignment en player lijst
    // Kleine delay om te zorgen dat client notifications goed ingesteld zijn
    Future.delayed(Duration(milliseconds: 500), () {
      // Stuur playerJoined message naar alle clients
      _sendWelcomeMessage(playerId);
    });
  }

  /// Client verbroken callback
  void _onClientDisconnected(String name, String address) {
    final removedClient = _connectedClients.firstWhere(
      (client) => client['address'] == address,
      orElse: () => {},
    );

    _connectedClients.removeWhere((client) => client['address'] == address);
    _playerIdsController.add(playerIds); // Broadcast nieuwe player lijst

    if (removedClient.isNotEmpty) {
      final playerId = removedClient['playerId'] ?? 'unknown';
      _log('📴 Client verbroken: $name ($playerId)');
    } else {
      _log('📴 Client verbroken: $name ($address)');
    }
    _log('👥 Totaal clients: ${_connectedClients.length}');

    // Stuur update naar alle overgebleven clients
    if (_connectedClients.isNotEmpty) {
      _sendPlayerLeftMessage();
    }
  }

  /// Data ontvangen callback - alle berichten zijn GameMessages
  void _onDataReceived(String address, Uint8List data) {
    final String message = String.fromCharCodes(data);

    try {
      // Parse als GameMessage
      final gameMessage = GameMessage.fromJson(message);

      // Update device name mapping als aanwezig
      if (gameMessage.deviceName != null &&
          gameMessage.deviceName!.isNotEmpty) {
        _clientDeviceNames[gameMessage.playerId] = gameMessage.deviceName!;

        // Update naam in connected clients lijst
        final clientIndex = _connectedClients.indexWhere(
          (client) => client['address'] == address,
        );
        if (clientIndex != -1) {
          _connectedClients[clientIndex]['name'] = gameMessage.deviceName!;
        }
      }

      _log(
        '📨 Ontvangen ${gameMessage.type.name} van ${gameMessage.deviceName ?? gameMessage.playerId} ($address)',
      );

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

  Stream<List<BluetoothDevice>> get clientsStream =>
      throw UnimplementedError('Use clientCountStream instead');
  List<BluetoothDevice> get connectedClients =>
      throw UnimplementedError('Not implemented for native GATT server');

  /// Start de Host Service en begin met adverteren
  Future<void> startServer() async {
    try {
      // Check of Bluetooth aan staat
      final bool bluetoothEnabled = await _channel.invokeMethod(
        'isBluetoothEnabled',
      );

      if (!bluetoothEnabled) {
        _log('⚠️ Bluetooth is uitgeschakeld');
        _log('📱 Probeer Bluetooth aan te zetten...');

        // Vraag om Bluetooth aan te zetten
        final bool enabled = await _channel.invokeMethod('enableBluetooth');

        if (!enabled) {
          _log('❌ Bluetooth kon niet worden aangezet');
          throw Exception(
            'Bluetooth is uitgeschakeld. Zet Bluetooth aan om door te gaan.',
          );
        }

        _log('✅ Bluetooth aangezet');
      }

      // Genereer host naam met gebruikersnaam
      final userName = await SettingsService.getUserName();
      final hostId = DateTime.now().millisecondsSinceEpoch % 10000;
      _currentHostName = '$userName-Host-$hostId';

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
        // Stuur niet als er geen clients zijn (solo spel is toegestaan)
        return;
      }

      final data = message.codeUnits;

      // Stuur via de Service naar alle clients
      await _channel.invokeMethod('sendData', {
        'data': Uint8List.fromList(data),
      });

      _log(
        '📤 Bericht verzonden naar ${_connectedClients.length} clients: "$message"',
      );
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

    _gameStarted = true;
    _log('🎮 Game gestart!');

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
    // Update host naam voor real-time accuracy
    await updateHostName();

    final now = DateTime.now();
    final pingMessage = GameMessage(
      type: GameMessageType.ping,
      timestamp: now.millisecondsSinceEpoch,
      playerId: _playerId,
      deviceName: _currentHostName,
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

  /// Stuur welcome message met complete player info naar alle clients
  Future<void> _sendWelcomeMessage(String newPlayerId) async {
    // Update host naam voor real-time accuracy
    await updateHostName();

    // Verzamel alle player IDs (host + alle clients)
    final List<String> playerIds = ['host'];
    final Map<String, String> playerNames = {
      'host': _currentHostName ?? 'Host',
    };

    for (var client in _connectedClients) {
      final playerId = client['playerId'] ?? 'unknown';
      playerIds.add(playerId);
      playerNames[playerId] =
          _clientDeviceNames[playerId] ?? client['name'] ?? 'Unknown';
    }

    // Stuur naar alle clients (inclusief de nieuwe)
    final welcomeMessage = GameMessage(
      type: GameMessageType.playerJoined,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      playerId: _playerId,
      deviceName: _currentHostName,
      content: {
        'playerCount': playerIds.length,
        'playerIds': playerIds,
        'playerNames': playerNames, // Nieuwe field voor namen mapping
        'hostName': _currentHostName, // Expliciete host naam
        'newPlayerId': newPlayerId, // Wie er net is toegevoegd
        'isWelcome': true, // Flag om te herkennen als welcome
      },
    );

    await _sendGameMessage(welcomeMessage);
    _log(
      '📢 Welcome message verzonden: ${playerIds.length} spelers (nieuw: $newPlayerId)',
    );
    _log('👥 Huidige spelers: ${playerNames.values.join(", ")}');
  }

  /// Stuur update dat een speler is weggegaan
  Future<void> _sendPlayerLeftMessage() async {
    // Verzamel alle player IDs (host + alle clients)
    final List<String> playerIds = ['host'];
    final Map<String, String> playerNames = {
      'host': _currentHostName ?? 'Host',
    };

    for (var client in _connectedClients) {
      final playerId = client['playerId'] ?? 'unknown';
      playerIds.add(playerId);
      playerNames[playerId] =
          _clientDeviceNames[playerId] ?? client['name'] ?? 'Unknown';
    }

    // Stuur update naar alle clients
    final leftMessage = GameMessage(
      type: GameMessageType.playerJoined,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      playerId: _playerId,
      deviceName: _currentHostName,
      content: {
        'playerCount': playerIds.length,
        'playerIds': playerIds,
        'playerNames': playerNames,
        'hostName': _currentHostName,
        'isWelcome': false,
      },
    );

    await _sendGameMessage(leftMessage);
    _log('👋 Player left message verzonden: ${playerIds.length} spelers');
    _log('👥 Overgebleven spelers: ${playerNames.values.join(", ")}');
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
