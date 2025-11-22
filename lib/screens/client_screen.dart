import 'dart:async';
import 'package:flutter/material.dart';
import '../services/bluetooth_client.dart';
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
  String? _hostName;

  // Stream subscriptions om te kunnen cancellen
  late final List<StreamSubscription> _subscriptions;

  @override
  void initState() {
    super.initState();
    _subscriptions = [];
    _setupListeners();
    _requestPermissions();

    // Automatisch beginnen met zoeken naar hosts zodra screen geladen is
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchAndConnect();
    });
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
              _hostName = _bluetoothClient.connectedHostName ?? 'BlueCard Host';
              _isSearching = false; // Stop searching wanneer verbonden
            } else {
              _hostName = null;
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
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('Client'),
        backgroundColor: Colors.blue[700],
        actions: [
          if (_isConnected)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 12, color: Colors.green[300]),
                    SizedBox(width: 8),
                    Text('Verbonden'),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Status kaart
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _isConnected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: _isConnected ? Colors.green : Colors.grey,
                      size: 32,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isConnected ? 'Verbonden' : 'Niet verbonden',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _isConnected
                                ? 'Host: ${_hostName ?? "Onbekend"}'
                                : 'Zoek naar een host om te verbinden',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

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
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],

                if (_isConnected) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _sendTestAction,
                          icon: Icon(Icons.send),
                          label: Text('Test Actie'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _disconnect,
                        icon: Icon(Icons.close),
                        label: Text('Disconnect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
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
            ),
            SizedBox(height: 16),
          ],

          // Berichten log
          Expanded(child: MessageLog(messages: _messages)),
        ],
      ),
    );
  }
}
