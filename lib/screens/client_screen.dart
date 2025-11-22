import 'dart:async';
import 'package:flutter/material.dart';
import '../services/bluetooth_client.dart';
import '../services/settings_service.dart';
import '../models/game_message.dart';
import '../widgets/player_list.dart';
import '../widgets/message_log.dart';
import 'game_screen.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final BluetoothClient _bluetoothClient = BluetoothClient();

  final List<String> _messages = [];
  bool _isConnected = false;
  bool _isSearching = false;
  String _currentUserName = '';

  // Stream subscriptions om te kunnen cancellen
  late final List<StreamSubscription> _subscriptions;

  @override
  void initState() {
    super.initState();
    _subscriptions = [];
    _setupListeners();
    _requestPermissions();
    _loadUserName();

    // Automatisch beginnen met zoeken naar hosts zodra screen geladen is
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchAndConnect();
    });
  }

  Future<void> _loadUserName() async {
    try {
      final userName = await SettingsService.getUserName();
      if (mounted) {
        setState(() {
          _currentUserName = userName;
        });
      }
    } catch (e) {
      // Fallback als SettingsService niet beschikbaar is
      _currentUserName = 'Mijn Apparaat';
    }
  }

  void _setupListeners() {
    // Luister naar berichten
    _subscriptions.add(
      _bluetoothClient.messageStream.listen((message) {
        if (mounted) {
          setState(() {
            _messages.insert(0, message);
            if (_messages.length > 50) {
              _messages.removeLast();
            }
          });
        }

        // Toon notificatie bij ontvangen berichten van host
        if (message.contains('📨 Notificatie van host:')) {
          _showNotification(message.substring(message.indexOf(':') + 2));
        }
      }),
    );

    // Luister naar verbindingsstatus
    _subscriptions.add(
      _bluetoothClient.connectionStream.listen((connected) {
        if (mounted) {
          setState(() {
            _isConnected = connected;
            if (connected) {
              _isSearching = false; // Stop searching wanneer verbonden
            }
          });
        }
      }),
    );

    // Luister naar game messages voor auto-navigatie
    _subscriptions.add(
      _bluetoothClient.gameMessageStream.listen((gameMessage) {
        if (!mounted) return;

        switch (gameMessage.type) {
          case GameMessageType.startGame:
            // Navigeer naar gedeelde game screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => GameScreen(
                  bluetoothClient: _bluetoothClient,
                  isHost: false,
                ),
              ),
            );
            break;

          case GameMessageType.playerJoined:
            // Trigger rebuild voor player lijst update
            setState(() {});
            break;

          default:
            break;
        }
      }),
    );
  }

  Future<void> _requestPermissions() async {
    // Permissions worden automatisch gevraagd door de service
    // bij het starten van de ClientService
  }

  Future<void> _searchAndConnect() async {
    setState(() {
      _isSearching = true;
    });

    try {
      // Check eerst of we al connected zijn
      if (_isConnected) {
        _showError('Al verbonden met een host');
        setState(() {
          _isSearching = false;
        });
        return;
      }

      // Start de Client Foreground Service die automatisch zoekt naar hosts
      _messages.insert(0, '🔍 Starting Client Service...');
      _messages.insert(0, '💡 De service draait in de achtergrond');
      _messages.insert(0, '💡 Je ontvangt een notificatie tijdens het zoeken');
      setState(() {});

      await _bluetoothClient.searchForHost();

      // _isSearching blijft true tot verbinding gemaakt is of timeout
      // De connectionStream listener zet het op false bij verbinding

      // Timeout na 30 seconden als geen verbinding
      Future.delayed(Duration(seconds: 30), () {
        if (_isSearching && !_isConnected && mounted) {
          setState(() {
            _isSearching = false;
          });
          _showError('Geen host gevonden. Probeer opnieuw.');
        }
      });
    } catch (e) {
      _showError('Fout bij zoeken: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _disconnect() async {
    // Stop de Client Service (sluit verbinding en stopt de foreground service)
    await _bluetoothClient.disconnect();
  }

  Future<void> _sendTestAction() async {
    await _bluetoothClient.sendMessage(
      type: GameMessageType.ping,
      content: {
        'message': 'Test actie van client!',
        'extra': 'Extra informatie',
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ping verzonden naar host'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.notifications, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue[700],
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    // Cancel alle stream subscriptions om memory leaks te voorkomen
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }

    // NIET de service disposen - deze moet actief blijven voor andere schermen
    // De service wordt alleen gedisposed bij quitGame()
    // _bluetoothClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (_isConnected) {
          await _disconnect();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF0D2E15),
          foregroundColor: Colors.white,
          title: Text('Meedoen aan spel'),
          actions: [
            if (_isConnected) ...[
              IconButton(
                icon: Icon(Icons.network_check),
                onPressed: _sendTestAction,
                tooltip: 'Test Actie',
              ),
              IconButton(
                icon: Icon(Icons.exit_to_app),
                onPressed: _disconnect,
                tooltip: 'Disconnect',
              ),
            ],
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D2E15), Color(0xFF06210F), Color(0xFF04170B)],
            ),
          ),
          child: Column(
            children: [
              // Status kaart
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 9, 32, 15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (_isConnected) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 32,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Verbonden met ${_bluetoothClient.connectedHostName ?? "onbekende host"}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (!_isConnected) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSearching ? null : _searchAndConnect,
                          icon: _isSearching
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(Icons.search),
                          label: Text(_isSearching ? 'Zoeken...' : 'Zoek Host'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Spelers lijst (alleen tonen als verbonden en er spelers zijn)
              if (_isConnected && _bluetoothClient.playerIds.isNotEmpty) ...[
                PlayerList(
                  playerCount: _bluetoothClient.playerCount,
                  playerIds: _bluetoothClient.playerIds,
                  playerInfo: _buildPlayerInfoList(),
                ),
                SizedBox(height: 16),
              ],

              // Berichten log
              Expanded(child: MessageLog(messages: _messages)),

              // Wachten op game start
              if (_isConnected) ...[
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 9, 32, 15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Wachten tot het spel wordt gestart...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Bouw player info lijst voor display
  List<Map<String, String>> _buildPlayerInfoList() {
    // Update gebruikersnaam in background
    _updateUserNameInBackground();

    final List<Map<String, String>> playerInfo = [];

    // Host info
    if (_bluetoothClient.playerIds.contains('host')) {
      playerInfo.add({
        'playerId': 'host',
        'name': _bluetoothClient.connectedHostName ?? 'Host',
        'address': 'local',
      });
    }

    // Client info
    final playerNames = _bluetoothClient.playerNames;
    for (String playerId in _bluetoothClient.playerIds) {
      if (playerId != 'host') {
        String playerName;

        // Als dit onze eigen player ID is, gebruik onze gebruikersnaam uit settings
        if (playerId == _bluetoothClient.playerId) {
          playerName = _currentUserName.isNotEmpty
              ? _currentUserName
              : _bluetoothClient.deviceName;
        } else {
          // Voor andere clients, gebruik de naam van de host mapping
          playerName = playerNames[playerId] ?? 'Unknown Player';
        }

        playerInfo.add({
          'playerId': playerId,
          'name': playerName,
          'address': '',
        });
      }
    }

    return playerInfo;
  }

  void _updateUserNameInBackground() {
    SettingsService.getUserName().then((name) {
      if (_currentUserName != name) {
        setState(() {
          _currentUserName = name;
        });
        // Update ook de bluetooth client device name
        _bluetoothClient.updateDeviceName();
      }
    });
  }
}
