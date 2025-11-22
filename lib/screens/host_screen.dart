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

    if (_bluetoothHost.totalPlayerCount == 1) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ping verzonden naar alle spelers'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
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
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (_isServerStarted) {
          await _stopServer();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Spel starten'),
          backgroundColor: Color(0xFF0D2E15),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: Icon(Icons.network_check),
              onPressed: _sendPing,
              tooltip: 'Ping',
            ),
            if (_isServerStarted)
              IconButton(
                icon: Icon(Icons.stop_circle_outlined),
                onPressed: _stopServer,
                tooltip: 'Stop Server',
              ),
            if (!_isServerStarted)
              IconButton(
                icon: Icon(Icons.play_circle_outline),
                onPressed: _startServer,
                tooltip: 'Start Server',
              ),
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

              // Wachten op spelers tekst - toon als server actief is maar geen spelers verbonden zijn
              if (_isServerStarted && _bluetoothHost.playerIds.length <= 1) ...[
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Wachten op spelers...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],

              // Start Spel button at bottom - only show when server is started and players are connected
              if (_isServerStarted && _bluetoothHost.playerIds.length > 1) ...[
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.2),
                          Colors.green.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.green.withOpacity(0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: !_bluetoothHost.gameStarted ? _startGame : null,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.withOpacity(0.9),
                                      Colors.green.withOpacity(0.6),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.play_arrow,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 20),
                              Expanded(
                                child: Text(
                                  'Start Spel',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
