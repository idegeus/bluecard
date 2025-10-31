import 'dart:async';
import '../models/playing_card.dart';

/// Spel richting voor Pesten
enum GameDirection {
  clockwise,        // Met de klok mee
  counterClockwise, // Tegen de klok in
}

/// Spel status
enum GameStatus {
  waiting,  // Wachten op spelers
  playing,  // Spel bezig
  finished, // Spel afgelopen
}

/// Pesten spel state
class PestenGameState {
  final List<String> playerIds;        // Alle spelers
  final Map<String, List<PlayingCard>> playerHands; // Kaarten per speler
  final List<PlayingCard> drawPile;    // Trek stapel
  final List<PlayingCard> discardPile; // Afleg stapel
  final int currentPlayerIndex;        // Huidige speler index
  final GameDirection direction;       // Spel richting
  final GameStatus status;             // Spel status
  final String? winnerId;              // Winnaar (als spel afgelopen)
  final int drawCount;                 // Aantal kaarten dat gepakt moet worden (voor 7)
  final CardSuit? chosenSuit;          // Gekozen kleur (na joker)
  
  const PestenGameState({
    required this.playerIds,
    required this.playerHands,
    required this.drawPile,
    required this.discardPile,
    required this.currentPlayerIndex,
    this.direction = GameDirection.clockwise,
    this.status = GameStatus.waiting,
    this.winnerId,
    this.drawCount = 0,
    this.chosenSuit,
  });
  
  /// Huidige speler ID
  String get currentPlayerId => playerIds[currentPlayerIndex];
  
  /// Bovenste kaart op aflegstapel
  PlayingCard? get topCard => discardPile.isEmpty ? null : discardPile.last;
  
  /// Aantal kaarten in hand van speler
  int cardsInHand(String playerId) {
    return playerHands[playerId]?.length ?? 0;
  }
  
  /// Kopie maken met wijzigingen
  PestenGameState copyWith({
    List<String>? playerIds,
    Map<String, List<PlayingCard>>? playerHands,
    List<PlayingCard>? drawPile,
    List<PlayingCard>? discardPile,
    int? currentPlayerIndex,
    GameDirection? direction,
    GameStatus? status,
    String? winnerId,
    int? drawCount,
    CardSuit? chosenSuit,
    bool clearChosenSuit = false,
  }) {
    return PestenGameState(
      playerIds: playerIds ?? this.playerIds,
      playerHands: playerHands ?? this.playerHands,
      drawPile: drawPile ?? this.drawPile,
      discardPile: discardPile ?? this.discardPile,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      winnerId: winnerId ?? this.winnerId,
      drawCount: drawCount ?? this.drawCount,
      chosenSuit: clearChosenSuit ? null : (chosenSuit ?? this.chosenSuit),
    );
  }
  
  /// JSON serialisatie (ultra-compact integer array format)
  /// Format: [playerId_count, ...playerIds_as_strings, hand_count, ...hands, drawPile_count, discard_count, ...discard, meta]
  /// Meta packed int: status(2bit)|direction(1bit)|currentIndex(5bit)|drawCount(8bit)|chosenSuit(4bit)|winnerId_index(4bit)
  Map<String, dynamic> toJson() {
    // Build compact arrays per player
    final List<dynamic> data = [];
    
    // Player IDs als strings (kunnen niet als int)
    data.add(playerIds.length);
    data.addAll(playerIds);
    
    // Hands als integer arrays per speler (in volgorde van playerIds)
    for (final playerId in playerIds) {
      final hand = playerHands[playerId] ?? [];
      data.add(hand.length);
      data.addAll(hand.map((c) => c.toCompact()));
    }
    
    // DrawPile count
    data.add(drawPile.length);
    
    // DiscardPile als integers
    data.add(discardPile.length);
    data.addAll(discardPile.map((c) => c.toCompact()));
    
    // Meta data als packed integer
    // Bits: [unused(12)] [chosenSuit(4)] [winnerId_index(4)] [drawCount(8)] [currentIndex(4)]
    final winnerIndex = winnerId != null ? playerIds.indexOf(winnerId!) : 15;
    final meta = (status.index << 28) |
                 (direction.index << 27) |
                 (currentPlayerIndex << 22) |
                 (drawCount << 14) |
                 ((chosenSuit?.index ?? 15) << 10) |
                 (winnerIndex << 6);
    data.add(meta);
    
    return {'d': data};
  }
  
  /// JSON deserialisatie
  factory PestenGameState.fromJson(Map<String, dynamic> json) {
    final List data = json['d'];
    int idx = 0;
    
    // Parse player IDs
    final playerCount = data[idx++] as int;
    final playerIds = <String>[];
    for (int i = 0; i < playerCount; i++) {
      playerIds.add(data[idx++] as String);
    }
    
    // Parse hands
    final playerHands = <String, List<PlayingCard>>{};
    for (final playerId in playerIds) {
      final handCount = data[idx++] as int;
      final hand = <PlayingCard>[];
      for (int i = 0; i < handCount; i++) {
        hand.add(PlayingCard.fromCompact(data[idx++] as int));
      }
      playerHands[playerId] = hand;
    }
    
    // Parse drawPile count
    final drawPileCount = data[idx++] as int;
    final drawPile = List<PlayingCard>.filled(
      drawPileCount,
      const PlayingCard(suit: CardSuit.hearts, rank: CardRank.two),
    );
    
    // Parse discardPile
    final discardCount = data[idx++] as int;
    final discardPile = <PlayingCard>[];
    for (int i = 0; i < discardCount; i++) {
      discardPile.add(PlayingCard.fromCompact(data[idx++] as int));
    }
    
    // Parse meta
    final meta = data[idx++] as int;
    final status = GameStatus.values[(meta >> 28) & 0x03];
    final direction = GameDirection.values[(meta >> 27) & 0x01];
    final currentPlayerIndex = (meta >> 22) & 0x1F;
    final drawCount = (meta >> 14) & 0xFF;
    final chosenSuitIndex = (meta >> 10) & 0x0F;
    final winnerIndex = (meta >> 6) & 0x0F;
    
    final chosenSuit = chosenSuitIndex == 15 ? null : CardSuit.values[chosenSuitIndex];
    final winnerId = winnerIndex == 15 ? null : playerIds[winnerIndex];
    
    return PestenGameState(
      playerIds: playerIds,
      playerHands: playerHands,
      drawPile: drawPile,
      discardPile: discardPile,
      currentPlayerIndex: currentPlayerIndex,
      direction: direction,
      status: status,
      winnerId: winnerId,
      drawCount: drawCount,
      chosenSuit: chosenSuit,
    );
  }
}

/// Pesten spel service
class PestenGame {
  PestenGameState _state;
  final _stateController = StreamController<PestenGameState>.broadcast();
  
  PestenGame(List<String> playerIds)
      : _state = PestenGameState(
          playerIds: playerIds,
          playerHands: {},
          drawPile: [],
          discardPile: [],
          currentPlayerIndex: 0,
        );
  
  /// Stream van game state updates
  Stream<PestenGameState> get stateStream => _stateController.stream;
  
  /// Huidige game state
  PestenGameState get state => _state;
  
  /// Start een nieuw spel
  void startGame() {
    print('🎲 [PestenGame] startGame() called');
    print('🎲 [PestenGame] Player IDs: ${_state.playerIds}');
    
    // Maak een nieuw deck
    final deck = Deck(includeJokers: true);
    deck.shuffle();
    
    print('🎲 [PestenGame] Deck created and shuffled (${deck.size} cards)');
    
    // Deel 7 kaarten aan elke speler
    final playerHands = <String, List<PlayingCard>>{};
    for (final playerId in _state.playerIds) {
      playerHands[playerId] = [];
      for (int i = 0; i < 7; i++) {
        final card = deck.draw();
        if (card != null) {
          playerHands[playerId]!.add(card);
        }
      }
      print('🎲 [PestenGame] Dealt 7 cards to $playerId');
    }
    
    // Eerste kaart op aflegstapel
    final firstCard = deck.draw();
    final discardPile = firstCard != null ? [firstCard] : <PlayingCard>[];
    
    print('🎲 [PestenGame] First card on discard: $firstCard');
    print('🎲 [PestenGame] Remaining in deck: ${deck.cards.length}');
    
    // Update state
    _state = _state.copyWith(
      playerHands: playerHands,
      drawPile: deck.cards,
      discardPile: discardPile,
      currentPlayerIndex: 0,
      status: GameStatus.playing,
      direction: GameDirection.clockwise,
      drawCount: 0,
      clearChosenSuit: true,
    );
    
    print('🎲 [PestenGame] State updated, broadcasting...');
    _stateController.add(_state);
    print('🎲 [PestenGame] State broadcasted!');
  }
  
  /// Check of een kaart gespeeld mag worden
  bool canPlayCard(PlayingCard card) {
    final topCard = _state.topCard;
    if (topCard == null) return true;
    
    // Joker mag altijd
    if (card.rank == CardRank.joker) return true;
    
    // Als er een kleur gekozen is (na joker), moet deze kleur gespeeld worden
    if (_state.chosenSuit != null) {
      return card.suit == _state.chosenSuit;
    }
    
    // Zelfde kleur of zelfde waarde
    return card.suit == topCard.suit || card.rank == topCard.rank;
  }
  
  /// Speel een kaart
  bool playCard(String playerId, PlayingCard card) {
    // Check of het de beurt van deze speler is
    if (_state.currentPlayerId != playerId) return false;
    
    // Check of speler deze kaart heeft
    final hand = _state.playerHands[playerId];
    if (hand == null || !hand.contains(card)) return false;
    
    // Check of kaart gespeeld mag worden
    if (!canPlayCard(card)) return false;
    
    // Verwijder kaart uit hand
    final newHand = List<PlayingCard>.from(hand)..remove(card);
    final newPlayerHands = Map<String, List<PlayingCard>>.from(_state.playerHands);
    newPlayerHands[playerId] = newHand;
    
    // Voeg kaart toe aan aflegstapel
    final newDiscardPile = List<PlayingCard>.from(_state.discardPile)..add(card);
    
    // Update state
    _state = _state.copyWith(
      playerHands: newPlayerHands,
      discardPile: newDiscardPile,
      clearChosenSuit: true,
    );
    
    // Check voor winnaar
    if (newHand.isEmpty) {
      _state = _state.copyWith(
        status: GameStatus.finished,
        winnerId: playerId,
      );
      _stateController.add(_state);
      return true;
    }
    
    // Handel speciale kaart effecten af
    _handleSpecialCard(card);
    
    return true;
  }
  
  /// Handel speciale kaart effecten af
  void _handleSpecialCard(PlayingCard card) {
    switch (card.rank) {
      case CardRank.seven:
        // Pak 2 kaarten
        _state = _state.copyWith(drawCount: _state.drawCount + 2);
        _nextPlayer();
        break;
        
      case CardRank.eight:
        // Beurt overslaan
        _nextPlayer();
        _nextPlayer();
        break;
        
      case CardRank.ace:
        // Richting omkeren
        _state = _state.copyWith(
          direction: _state.direction == GameDirection.clockwise
              ? GameDirection.counterClockwise
              : GameDirection.clockwise,
        );
        _nextPlayer();
        break;
        
      case CardRank.joker:
        // Joker - kleur kiezen (gebeurt via aparte methode)
        // Ga niet door naar volgende speler, wacht op kleur keuze
        break;
        
      default:
        // Normale kaart
        _nextPlayer();
    }
    
    _stateController.add(_state);
  }
  
  /// Kies kleur (na joker)
  void chooseSuit(CardSuit suit) {
    _state = _state.copyWith(chosenSuit: suit);
    _nextPlayer();
    _stateController.add(_state);
  }
  
  /// Pak kaarten van deck
  void drawCards(String playerId, [int count = 1]) {
    // Check of het de beurt van deze speler is
    if (_state.currentPlayerId != playerId) return;
    
    final hand = List<PlayingCard>.from(_state.playerHands[playerId] ?? []);
    final drawPile = List<PlayingCard>.from(_state.drawPile);
    
    int drawAmount = count;
    
    // Als er kaarten gepakt moeten worden (na 7), pak die
    if (_state.drawCount > 0) {
      drawAmount = _state.drawCount;
    }
    
    // Pak kaarten
    for (int i = 0; i < drawAmount; i++) {
      if (drawPile.isEmpty) {
        // Schud aflegstapel terug in deck (behalve bovenste kaart)
        if (_state.discardPile.length > 1) {
          final topCard = _state.discardPile.last;
          drawPile.addAll(_state.discardPile.sublist(0, _state.discardPile.length - 1));
          drawPile.shuffle();
          _state = _state.copyWith(discardPile: [topCard]);
        } else {
          break; // Geen kaarten meer
        }
      }
      
      if (drawPile.isNotEmpty) {
        hand.add(drawPile.removeLast());
      }
    }
    
    // Update state
    final newPlayerHands = Map<String, List<PlayingCard>>.from(_state.playerHands);
    newPlayerHands[playerId] = hand;
    
    _state = _state.copyWith(
      playerHands: newPlayerHands,
      drawPile: drawPile,
      drawCount: 0, // Reset draw count
    );
    
    // Ga door naar volgende speler
    _nextPlayer();
    _stateController.add(_state);
  }
  
  /// Ga naar volgende speler
  void _nextPlayer() {
    int nextIndex;
    if (_state.direction == GameDirection.clockwise) {
      nextIndex = (_state.currentPlayerIndex + 1) % _state.playerIds.length;
    } else {
      nextIndex = (_state.currentPlayerIndex - 1) % _state.playerIds.length;
      if (nextIndex < 0) nextIndex += _state.playerIds.length;
    }
    
    _state = _state.copyWith(currentPlayerIndex: nextIndex);
  }
  
  /// Dispose
  void dispose() {
    _stateController.close();
  }
}
