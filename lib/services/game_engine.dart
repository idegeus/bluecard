import '../models/game_type.dart';

/// Abstract basis class voor game rules
/// Elk speltype implementeert deze interface met zijn eigen regels
abstract class GameRules {
  final GameType gameType;
  
  GameRules(this.gameType);
  
  /// Initialiseer het spel met spelers
  Map<String, dynamic> initializeGame(List<String> playerIds);
  
  /// Valideer of een zet geldig is
  bool isValidMove(Map<String, dynamic> gameState, Map<String, dynamic> move);
  
  /// Voer een zet uit en return nieuwe game state
  Map<String, dynamic> executeMove(Map<String, dynamic> gameState, Map<String, dynamic> move);
  
  /// Check of het spel afgelopen is
  bool isGameOver(Map<String, dynamic> gameState);
  
  /// Bepaal de winnaar(s)
  List<String> getWinners(Map<String, dynamic> gameState);
  
  /// Get beschikbare acties voor huidige speler
  List<Map<String, dynamic>> getAvailableActions(Map<String, dynamic> gameState, String playerId);
  
  /// Get minimum en maximum aantal spelers
  int get minPlayers;
  int get maxPlayers;
}

/// GameEngine - Beheert het actieve spel en delegeert naar de juiste rules
class GameEngine {
  GameType? _currentGameType;
  GameRules? _currentRules;
  Map<String, dynamic> _gameState = {};
  
  GameType? get currentGameType => _currentGameType;
  Map<String, dynamic> get gameState => Map.from(_gameState);
  bool get isInitialized => _currentRules != null;
  
  /// Selecteer en initialiseer een speltype
  void selectGame(GameType gameType, List<String> playerIds) {
    _currentGameType = gameType;
    _currentRules = _createRules(gameType);
    
    // Valideer aantal spelers
    if (playerIds.length < _currentRules!.minPlayers) {
      throw Exception('Minimaal ${_currentRules!.minPlayers} spelers nodig voor ${gameType.displayName}');
    }
    if (playerIds.length > _currentRules!.maxPlayers) {
      throw Exception('Maximaal ${_currentRules!.maxPlayers} spelers toegestaan voor ${gameType.displayName}');
    }
    
    _gameState = _currentRules!.initializeGame(playerIds);
  }
  
  /// Maak de juiste rules instantie voor het speltype
  GameRules _createRules(GameType gameType) {
    switch (gameType) {
      case GameType.freePlay:
        return FreePlayRules();
      case GameType.president:
        return PresidentRules();
      case GameType.hearts:
        return HeartsRules();
      case GameType.uno:
        return UnoRules();
      case GameType.pesten:
        return PestenRules();
    }
  }
  
  /// Valideer een zet
  bool isValidMove(Map<String, dynamic> move) {
    if (_currentRules == null) return false;
    return _currentRules!.isValidMove(_gameState, move);
  }
  
  /// Voer een zet uit
  Map<String, dynamic> executeMove(Map<String, dynamic> move) {
    if (_currentRules == null) {
      throw Exception('Geen spel geselecteerd');
    }
    
    if (!isValidMove(move)) {
      throw Exception('Ongeldige zet');
    }
    
    _gameState = _currentRules!.executeMove(_gameState, move);
    return Map.from(_gameState);
  }
  
  /// Check of spel afgelopen is
  bool isGameOver() {
    if (_currentRules == null) return false;
    return _currentRules!.isGameOver(_gameState);
  }
  
  /// Get winnaars
  List<String> getWinners() {
    if (_currentRules == null) return [];
    return _currentRules!.getWinners(_gameState);
  }
  
  /// Get beschikbare acties voor speler
  List<Map<String, dynamic>> getAvailableActions(String playerId) {
    if (_currentRules == null) return [];
    return _currentRules!.getAvailableActions(_gameState, playerId);
  }
  
  /// Reset de engine
  void reset() {
    _currentGameType = null;
    _currentRules = null;
    _gameState = {};
  }
}

// ============================================================================
// GAME RULES IMPLEMENTATIES
// ============================================================================

/// Vrij spel - geen regels, gewoon kaarten spelen
class FreePlayRules extends GameRules {
  FreePlayRules() : super(GameType.freePlay);
  
  @override
  int get minPlayers => 1;
  
  @override
  int get maxPlayers => 10;
  
  @override
  Map<String, dynamic> initializeGame(List<String> playerIds) {
    return {
      'gameType': 'freePlay',
      'players': playerIds,
      'currentPlayer': 0,
      'started': true,
    };
  }
  
  @override
  bool isValidMove(Map<String, dynamic> gameState, Map<String, dynamic> move) {
    // In vrij spel is alles toegestaan
    return true;
  }
  
  @override
  Map<String, dynamic> executeMove(Map<String, dynamic> gameState, Map<String, dynamic> move) {
    // Geen state updates nodig in vrij spel
    return gameState;
  }
  
  @override
  bool isGameOver(Map<String, dynamic> gameState) {
    // Vrij spel eindigt nooit automatisch
    return false;
  }
  
  @override
  List<String> getWinners(Map<String, dynamic> gameState) {
    // Geen winnaars in vrij spel
    return [];
  }
  
  @override
  List<Map<String, dynamic>> getAvailableActions(Map<String, dynamic> gameState, String playerId) {
    // Alle acties zijn toegestaan
    return [];
  }
}

/// President spelregels
class PresidentRules extends GameRules {
  PresidentRules() : super(GameType.president);
  
  @override
  int get minPlayers => 3;
  
  @override
  int get maxPlayers => 7;
  
  @override
  Map<String, dynamic> initializeGame(List<String> playerIds) {
    // TODO: Implementeer president spelregels
    return {
      'gameType': 'president',
      'players': playerIds,
      'currentPlayer': 0,
      'hands': {}, // Kaarten per speler
      'pile': [], // Stapel op tafel
      'started': true,
    };
  }
  
  @override
  bool isValidMove(Map<String, dynamic> gameState, Map<String, dynamic> move) {
    // TODO: Implementeer validatie
    return true;
  }
  
  @override
  Map<String, dynamic> executeMove(Map<String, dynamic> gameState, Map<String, dynamic> move) {
    // TODO: Implementeer zet
    return gameState;
  }
  
  @override
  bool isGameOver(Map<String, dynamic> gameState) {
    // TODO: Implementeer game over check
    return false;
  }
  
  @override
  List<String> getWinners(Map<String, dynamic> gameState) {
    // TODO: Implementeer winnaar bepaling
    return [];
  }
  
  @override
  List<Map<String, dynamic>> getAvailableActions(Map<String, dynamic> gameState, String playerId) {
    // TODO: Implementeer beschikbare acties
    return [];
  }
}

/// Hearts spelregels
class HeartsRules extends GameRules {
  HeartsRules() : super(GameType.hearts);
  
  @override
  int get minPlayers => 4;
  
  @override
  int get maxPlayers => 4;
  
  @override
  Map<String, dynamic> initializeGame(List<String> playerIds) {
    return {
      'gameType': 'hearts',
      'players': playerIds,
      'currentPlayer': 0,
      'started': true,
    };
  }
  
  @override
  bool isValidMove(Map<String, dynamic> gameState, Map<String, dynamic> move) => true;
  
  @override
  Map<String, dynamic> executeMove(Map<String, dynamic> gameState, Map<String, dynamic> move) => gameState;
  
  @override
  bool isGameOver(Map<String, dynamic> gameState) => false;
  
  @override
  List<String> getWinners(Map<String, dynamic> gameState) => [];
  
  @override
  List<Map<String, dynamic>> getAvailableActions(Map<String, dynamic> gameState, String playerId) => [];
}

/// UNO spelregels
class UnoRules extends GameRules {
  UnoRules() : super(GameType.uno);
  
  @override
  int get minPlayers => 2;
  
  @override
  int get maxPlayers => 10;
  
  @override
  Map<String, dynamic> initializeGame(List<String> playerIds) {
    return {
      'gameType': 'uno',
      'players': playerIds,
      'currentPlayer': 0,
      'started': true,
    };
  }
  
  @override
  bool isValidMove(Map<String, dynamic> gameState, Map<String, dynamic> move) => true;
  
  @override
  Map<String, dynamic> executeMove(Map<String, dynamic> gameState, Map<String, dynamic> move) => gameState;
  
  @override
  bool isGameOver(Map<String, dynamic> gameState) => false;
  
  @override
  List<String> getWinners(Map<String, dynamic> gameState) => [];
  
  @override
  List<Map<String, dynamic>> getAvailableActions(Map<String, dynamic> gameState, String playerId) => [];
}

/// Pesten spelregels
class PestenRules extends GameRules {
  PestenRules() : super(GameType.pesten);
  
  @override
  int get minPlayers => 2;
  
  @override
  int get maxPlayers => 8;
  
  @override
  Map<String, dynamic> initializeGame(List<String> playerIds) {
    return {
      'gameType': 'pesten',
      'players': playerIds,
      'currentPlayer': 0,
      'started': true,
    };
  }
  
  @override
  bool isValidMove(Map<String, dynamic> gameState, Map<String, dynamic> move) => true;
  
  @override
  Map<String, dynamic> executeMove(Map<String, dynamic> gameState, Map<String, dynamic> move) => gameState;
  
  @override
  bool isGameOver(Map<String, dynamic> gameState) => false;
  
  @override
  List<String> getWinners(Map<String, dynamic> gameState) => [];
  
  @override
  List<Map<String, dynamic>> getAvailableActions(Map<String, dynamic> gameState, String playerId) => [];
}
