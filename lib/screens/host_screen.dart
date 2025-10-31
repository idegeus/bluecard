import 'dart:async';
import 'package:flutter/material.dart';
import '../services/bluetooth_host.dart';
import '../services/game_service.dart';
import '../models/game_message.dart';
import '../widgets/player_list.dart';
import '../widgets/message_log.dart';
import 'game_screen.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({Key? key}) : super(key: key);

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  final BluetoothHost _bluetoothHost = BluetoothHost();
  final GameService _gameService = GameService();
  
  final List<String> _messages = [];
  bool _isServerStarted = false;
  
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
    _subscriptions.add(_bluetoothHost.messageStream.listen((message) {
      if (mounted) {
        setState(() {
          _messages.insert(0, message);
          if (_messages.length > 50) {
            _messages.removeLast();
          }
        });
      }
    }));
    
    // Trigger rebuild wanneer player IDs updaten
    _subscriptions.add(_bluetoothHost.playerIdsStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    }));
    
    // Luister naar game messages voor navigatie
    _subscriptions.add(_bluetoothHost.gameMessageStream.listen((gameMessage) {
      print('🎮 HostScreen received gameMessage: ${gameMessage.type}');
      if (gameMessage.type == GameMessageType.startGame && mounted) {
        print('🎮 HostScreen navigating to GameScreen...');
        // Navigeer naar gedeelde game screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GameScreen(
              bluetoothHost: _bluetoothHost,
              isHost: true,
            ),
          ),
        );
      }
    }));
    
    // Luister naar game events
    _subscriptions.add(_gameService.eventStream.listen((event) {
      if (mounted) {
        setState(() {
          _messages.insert(0, event);
          if (_messages.length > 50) {
            _messages.removeLast();
          }
        });
      }
    }));
  }
  
  Future<void> _requestPermissions() async {
    // Permissions worden automatisch gevraagd door de service
    // bij het starten van de HostService
  }
  
  Future<void> _startServer() async {
    try {
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
    try {
      await _bluetoothHost.startGame();
    } catch (e) {
      _showError('Fout bij starten game: $e');
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
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
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
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('Host'),
        backgroundColor: Colors.green[700],
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
                      _isServerStarted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _isServerStarted ? Colors.green : Colors.grey,
                      size: 32,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isServerStarted ? 'Server actief' : 'Server gestopt',
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
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_bluetoothHost.gameStarted || _bluetoothHost.connectedClientCount == 0) 
                              ? null 
                              : _startGame,
                          icon: Icon(Icons.play_arrow),
                          label: Text(_bluetoothHost.connectedClientCount == 0 
                              ? 'Wacht op spelers...' 
                              : 'Start Game'),
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
          Expanded(
            child: MessageLog(messages: _messages),
          ),
        ],
      ),
    );
  }
}
