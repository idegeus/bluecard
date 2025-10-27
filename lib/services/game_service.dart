import 'dart:async';

/// GameService - Beheert de game state en validatie
/// Dit is waar alle game logica plaatsvindt
class GameService {
  final StreamController<Map<String, dynamic>> _stateController = 
      StreamController.broadcast();
  final StreamController<String> _eventController = 
      StreamController.broadcast();
  
  Map<String, dynamic> _gameState = {
    'initialized': false,
    'players': [],
    'currentTurn': 0,
  };
  
  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;
  Stream<String> get eventStream => _eventController.stream;
  Map<String, dynamic> get currentState => Map.from(_gameState);
  
  /// Initialiseer de game
  void initializeGame() {
    _gameState = {
      'initialized': true,
      'players': [],
      'currentTurn': 0,
      'gameStarted': false,
    };
    
    _stateController.add(_gameState);
    _eventController.add('🎮 Game geïnitialiseerd');
  }
  
  /// Voeg een speler toe
  void addPlayer(String playerId, String playerName) {
    List<dynamic> players = _gameState['players'] ?? [];
    
    if (!players.any((p) => p['id'] == playerId)) {
      players.add({
        'id': playerId,
        'name': playerName,
        'connected': true,
      });
      
      _gameState['players'] = players;
      _stateController.add(_gameState);
      _eventController.add('👤 Speler toegevoegd: $playerName');
    }
  }
  
  /// Verwijder een speler
  void removePlayer(String playerId) {
    List<dynamic> players = _gameState['players'] ?? [];
    players.removeWhere((p) => p['id'] == playerId);
    
    _gameState['players'] = players;
    _stateController.add(_gameState);
    _eventController.add('👋 Speler verwijderd');
  }
  
  /// Verwerk een client actie
  Future<bool> processClientAction(String clientId, Map<String, dynamic> action) async {
    String actionType = action['type'] ?? 'unknown';
    
    _eventController.add('⚙️ Verwerken actie: $actionType van client $clientId');
    
    // Valideer de actie
    if (!_validateAction(clientId, action)) {
      _eventController.add('❌ Ongeldige actie: $actionType');
      return false;
    }
    
    // Voer de actie uit
    bool success = await _executeAction(clientId, action);
    
    if (success) {
      // Broadcast de nieuwe state naar alle clients
      _stateController.add(_gameState);
      _eventController.add('✅ Actie uitgevoerd: $actionType');
    }
    
    return success;
  }
  
  /// Valideer of een actie geldig is
  bool _validateAction(String clientId, Map<String, dynamic> action) {
    // Basis validatie
    if (!_gameState['initialized']) {
      return false;
    }
    
    // Check of de speler bestaat
    List<dynamic> players = _gameState['players'] ?? [];
    if (!players.any((p) => p['id'] == clientId)) {
      return false;
    }
    
    String actionType = action['type'] ?? '';
    
    // Validatie per actie type
    switch (actionType) {
      case 'test':
        return true; // Test acties zijn altijd geldig
        
      case 'playCard':
        // Valideer of het de beurt van deze speler is
        // TODO: Implementeer beurt logica
        return true;
        
      case 'drawCard':
        return true;
        
      default:
        return false;
    }
  }
  
  /// Voer een actie uit
  Future<bool> _executeAction(String clientId, Map<String, dynamic> action) async {
    String actionType = action['type'] ?? '';
    
    switch (actionType) {
      case 'test':
        // Test actie - doe niets speciaals
        _eventController.add('🧪 Test actie ontvangen van $clientId');
        return true;
        
      case 'playCard':
        // TODO: Implementeer kaart spelen logica
        _eventController.add('🃏 Kaart gespeeld door $clientId');
        return true;
        
      case 'drawCard':
        // TODO: Implementeer kaart trekken logica
        _eventController.add('🎴 Kaart getrokken door $clientId');
        return true;
        
      default:
        return false;
    }
  }
  
  /// Update de game state (voor host)
  void updateState(Map<String, dynamic> newState) {
    _gameState = Map.from(newState);
    _stateController.add(_gameState);
    _eventController.add('📊 State geüpdatet');
  }
  
  /// Reset de game
  void resetGame() {
    _gameState = {
      'initialized': false,
      'players': [],
      'currentTurn': 0,
    };
    
    _stateController.add(_gameState);
    _eventController.add('🔄 Game gereset');
  }
  
  void dispose() {
    _stateController.close();
    _eventController.close();
  }
}
