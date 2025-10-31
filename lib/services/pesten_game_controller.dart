import 'dart:async';
import '../models/game_message.dart';
import '../models/playing_card.dart';
import '../services/pesten_game.dart';
import '../services/bluetooth_host.dart';
import '../services/bluetooth_client.dart';

/// Host-side Pesten game controller
class PestenGameHost {
  final BluetoothHost _bluetoothHost;
  late final PestenGame _game;
  final _stateController = StreamController<PestenGameState>.broadcast();
  StreamSubscription? _gameSubscription;
  
  PestenGameHost(this._bluetoothHost);
  
  /// Stream van game state updates
  Stream<PestenGameState> get stateStream => _stateController.stream;
  
  /// Huidige game state
  PestenGameState? get state => _game.state;
  
  /// Start een nieuw Pesten spel
  void startGame() {
    print('🎮 [PestenGameHost] startGame() called');
    print('🎮 [PestenGameHost] Player IDs: ${_bluetoothHost.playerIds}');
    
    // Maak game aan met alle spelers
    _game = PestenGame(_bluetoothHost.playerIds);
    
    // Luister naar game state changes
    _gameSubscription?.cancel();
    _gameSubscription = _game.stateStream.listen((state) {
      print('🎮 [PestenGameHost] State change received');
      _stateController.add(state);
      _broadcastGameState(state);
    });
    
    // Start het spel
    print('🎮 [PestenGameHost] Starting PestenGame...');
    _game.startGame();
    print('🎮 [PestenGameHost] PestenGame started!');
    
    // Broadcast start bericht
    _bluetoothHost.broadcastMessage(
      GameMessage(
        type: GameMessageType.startGame,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        playerId: _bluetoothHost.playerIds.first, // Host
      ),
    );
  }
  
  /// Broadcast game state naar alle clients
  void _broadcastGameState(PestenGameState state) {
    final json = state.toJson();
    final jsonString = json.toString();
    print('🎮 [PestenGameHost] Broadcasting game state (${jsonString.length} bytes)');
    print('🎮 [PestenGameHost] State JSON: ${jsonString.substring(0, jsonString.length > 200 ? 200 : jsonString.length)}...');
    
    _bluetoothHost.broadcastMessage(
      GameMessage(
        type: GameMessageType.gameState,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        playerId: _bluetoothHost.playerIds.first, // Host
        content: json,
      ),
    );
  }
  
  /// Speel een kaart (als host of client actie)
  void playCard(String playerId, PlayingCard card) {
    if (_game.playCard(playerId, card)) {
      // Broadcast kaart gespeeld (compact format)
      _bluetoothHost.broadcastMessage(
        GameMessage(
          type: GameMessageType.cardPlayed,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          playerId: playerId,
          content: {
            'c': card.toCompact(), // compact: 1 byte instead of object
          },
        ),
      );
    }
  }
  
  /// Pak kaarten (als host of client actie)
  void drawCards(String playerId, [int count = 1]) {
    _game.drawCards(playerId, count);
    
    // Broadcast kaarten gepakt (compact)
    _bluetoothHost.broadcastMessage(
      GameMessage(
        type: GameMessageType.cardDrawn,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        playerId: playerId,
        content: {
          'n': count, // 'n' instead of 'count'
        },
      ),
    );
  }
  
  /// Kies kleur (na joker)
  void chooseSuit(CardSuit suit) {
    _game.chooseSuit(suit);
    
    // Broadcast kleur keuze (compact)
    _bluetoothHost.broadcastMessage(
      GameMessage(
        type: GameMessageType.suitChosen,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        playerId: _bluetoothHost.playerIds.first, // Host
        content: {
          's': suit.index, // 's' instead of 'suit'
        },
      ),
    );
  }
  
  /// Verwerk client acties
  void handleClientMessage(GameMessage message) {
    switch (message.type) {
      case GameMessageType.cardPlayed:
        final cardCompact = message.content?['c'];
        if (cardCompact != null) {
          final card = PlayingCard.fromCompact(cardCompact);
          playCard(message.playerId, card);
        }
        break;
        
      case GameMessageType.cardDrawn:
        final count = message.content?['n'] ?? 1;
        drawCards(message.playerId, count);
        break;
        
      case GameMessageType.suitChosen:
        final suitIndex = message.content?['s'];
        if (suitIndex != null) {
          chooseSuit(CardSuit.values[suitIndex]);
        }
        break;
        
      default:
        break;
    }
  }
  
  /// Dispose
  void dispose() {
    _gameSubscription?.cancel();
    _stateController.close();
  }
}

/// Client-side Pesten game controller
class PestenGameClient {
  final BluetoothClient _bluetoothClient;
  final _stateController = StreamController<PestenGameState>.broadcast();
  PestenGameState? _currentState;
  StreamSubscription? _messageSubscription;
  String? _myPlayerId;
  
  PestenGameClient(this._bluetoothClient) {
    // Luister naar game berichten van host
    _messageSubscription = _bluetoothClient.gameMessageStream.listen((message) {
      _handleHostMessage(message);
    });
  }
  
  /// Stream van game state updates
  Stream<PestenGameState> get stateStream => _stateController.stream;
  
  /// Huidige game state
  PestenGameState? get state => _currentState;
  
  /// Set de player ID voor deze client
  void setPlayerId(String playerId) {
    _myPlayerId = playerId;
  }
  
  /// Verwerk berichten van host
  void _handleHostMessage(GameMessage message) {
    switch (message.type) {
      case GameMessageType.gameState:
        if (message.content != null) {
          _currentState = PestenGameState.fromJson(message.content!);
          _stateController.add(_currentState!);
        }
        break;
        
      case GameMessageType.startGame:
        // Game is gestart
        break;
        
      default:
        break;
    }
  }
  
  /// Speel een kaart
  void playCard(PlayingCard card) {
    if (_myPlayerId == null) return;
    
    _bluetoothClient.sendMessage(
      type: GameMessageType.cardPlayed,
      content: {
        'c': card.toCompact(), // compact format
      },
    );
  }
  
  /// Pak kaarten
  void drawCards([int count = 1]) {
    if (_myPlayerId == null) return;
    
    _bluetoothClient.sendMessage(
      type: GameMessageType.cardDrawn,
      content: {
        'n': count, // compact format
      },
    );
  }
  
  /// Kies kleur (na joker)
  void chooseSuit(CardSuit suit) {
    if (_myPlayerId == null) return;
    
    _bluetoothClient.sendMessage(
      type: GameMessageType.suitChosen,
      content: {
        's': suit.index, // compact format
      },
    );
  }
  
  /// Dispose
  void dispose() {
    _messageSubscription?.cancel();
    _stateController.close();
  }
}
