import 'dart:async';
import 'package:flutter/material.dart';
import '../services/bluetooth_host.dart';
import '../services/game_service.dart';
import '../services/game_engine.dart';
import '../models/game_message.dart';
import '../models/game_type.dart';
import '../widgets/player_list.dart';
import '../widgets/message_log.dart';
import 'game_screen.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  final BluetoothHost _bluetoothHost = BluetoothHost();
  final GameService _gameService = GameService();
  final GameEngine _gameEngine = GameEngine();

  final List<String> _messages = [];
  bool _isServerStarted = false;
  GameType? _selectedGameType;
  bool _hasShownSoloWarning = false;

  // Stream subscriptions om te kunnen cancellen
  late final List<StreamSubscription> _subscriptions;

  @override
  void initState() {
    super.initState();
    _subscriptions = [];
    _setupListeners();
    _requestPermissions();

    // Automatisch server starten zodra screen geladen is
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startServer();
    });
  }

  void _setupListeners() {
    // Luister naar Bluetooth berichten
    _subscriptions.add(
      _bluetoothHost.messageStream.listen((message) {
        if (mounted) {
          setState(() {
            _messages.insert(0, message);
            if (_messages.length > 50) {
              _messages.removeLast();
            }
          });
        }
      }),
    );

    // Trigger rebuild wanneer player IDs updaten
    _subscriptions.add(
      _bluetoothHost.playerIdsStream.listen((_) {
        if (mounted) {
          setState(() {});
        }
      }),
    );

    // Luister naar game messages voor navigatie
    _subscriptions.add(
      _bluetoothHost.gameMessageStream.listen((gameMessage) {
        print('🎮 HostScreen received gameMessage: ${gameMessage.type}');
        if (gameMessage.type == GameMessageType.startGame && mounted) {
          print('🎮 HostScreen navigating to GameScreen...');
          // Navigeer naar gedeelde game screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  GameScreen(bluetoothHost: _bluetoothHost, isHost: true),
            ),
          );
        }
      }),
    );

    // Luister naar game events
    _subscriptions.add(
      _gameService.eventStream.listen((event) {
        if (mounted) {
          setState(() {
            _messages.insert(0, event);
            if (_messages.length > 50) {
              _messages.removeLast();
            }
          });
        }
      }),
    );
  }

  Future<void> _requestPermissions() async {
    // Permissions worden automatisch gevraagd door de service
    // bij het starten van de HostService
  }

  Future<void> _startServer() async {
    try {
      setState(() {
        _isServerStarted = false;
      });
      // Start de Host Foreground Service
      await _bluetoothHost.startServer();
      _gameService.initializeGame();

      setState(() {
        _isServerStarted = true;
      });
    } catch (e) {
      _showError('Fout bij starten server: $e');
    }
  }

  Future<void> _stopServer() async {
    // Stop de Host Service (sluit alle verbindingen en stopt de foreground service)
    await _bluetoothHost.stopServer();
    setState(() {
      _isServerStarted = false;
    });
  }

  Future<void> _startGame() async {
    // Check of een spel is geselecteerd
    if (_selectedGameType == null) {
      _showGameTypeSelector();
      return;
    }

    // Check of de host alleen is en nog geen warning heeft gezien
    if (_bluetoothHost.totalPlayerCount == 1 && !_hasShownSoloWarning) {
      _hasShownSoloWarning = true;
      _showSoloWarning();
      return;
    }

    try {
      // Initialiseer game engine met geselecteerd speltype
      _gameEngine.selectGame(_selectedGameType!, _bluetoothHost.playerIds);

      // Stuur startGame message (zal navigatie triggeren via listener)
      await _bluetoothHost.startGame();
    } catch (e) {
      _showError('Fout bij starten game: $e');
    }
  }

  void _showSoloWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Row(
          children: [
            Icon(Icons.person, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text(
              'Je bent alleen!',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Wacht op meer spelers, of druk nog een keer op Start om solo te spelen.',
          style: TextStyle(color: Colors.grey[300], fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  void _showGameTypeSelector() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text(
          'Kies een spel',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: GameType.values.map((gameType) {
              // Check of aantal spelers binnen range is
              final rules = _createRulesForInfo(gameType);
              final playerCount = _bluetoothHost.totalPlayerCount;
              final isValid =
                  playerCount >= rules.minPlayers &&
                  playerCount <= rules.maxPlayers;

              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: isValid
                      ? () {
                          setState(() {
                            _selectedGameType = gameType;
                          });
                          Navigator.pop(context);
                          _startGame();
                        }
                      : null,
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isValid ? Colors.grey[800] : Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isValid ? Colors.green : Colors.grey[700]!,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(gameType.emoji, style: TextStyle(fontSize: 24)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                gameType.displayName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isValid ? Colors.white : Colors.grey,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                gameType.description,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '${rules.minPlayers}-${rules.maxPlayers} spelers',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isValid ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isValid)
                          Icon(Icons.lock, color: Colors.grey, size: 18),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuleren', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  GameRules _createRulesForInfo(GameType gameType) {
    switch (gameType) {
      case GameType.freePlay:
        return FreePlayRules();
      case GameType.zweedsPesten:
        return ZweedsPestenRules();
    }
  }

  Future<void> _sendPing() async {
    try {
      await _bluetoothHost.sendPing();
    } catch (e) {
      _showError('Fout bij verzenden ping: $e');
    }
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

    // NIET de services disposen - deze moeten actief blijven voor andere schermen
    // De services worden alleen gedisposed bij quitGame()
    // _bluetoothHost.dispose();
    // _gameService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Spel starten'),
        backgroundColor: Color(0xFF0D2E15),
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
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _isServerStarted
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: _isServerStarted ? Colors.green : Colors.grey,
                        size: 32,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isServerStarted
                                  ? 'Server actief'
                                  : 'Server gestopt',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _isServerStarted
                                  ? 'Wachten op clients...'
                                  : 'Start de server om te beginnen',
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

                  if (!_isServerStarted) ...[
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startServer,
                        icon: Icon(Icons.play_arrow),
                        label: Text('Start Server'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],

                  if (_isServerStarted) ...[
                    SizedBox(height: 20),

                    // Toon geselecteerd spel
                    if (_selectedGameType != null) ...[
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _selectedGameType!.emoji,
                              style: TextStyle(fontSize: 24),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Geselecteerd: ${_selectedGameType!.displayName}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _selectedGameType!.description,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.white),
                              onPressed: _bluetoothHost.gameStarted
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedGameType = null;
                                      });
                                    },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _bluetoothHost.gameStarted
                                ? null
                                : _startGame,
                            icon: Icon(Icons.play_arrow),
                            label: Text(
                              _selectedGameType == null
                                  ? 'Kies Spel'
                                  : 'Start Game',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _sendPing,
                            icon: Icon(Icons.wifi_tethering),
                            label: Text('Ping'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _stopServer,
                          icon: Icon(Icons.stop),
                          label: Text('Stop'),
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

            // Spelers lijst
            if (_bluetoothHost.playerIds.isNotEmpty) ...[
              PlayerList(
                playerCount: _bluetoothHost.totalPlayerCount,
                playerIds: _bluetoothHost.playerIds,
              ),
              SizedBox(height: 16),
            ],

            // Berichten log
            Expanded(child: MessageLog(messages: _messages)),
          ],
        ),
      ),
    );
  }
}
