import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'bluetooth_setup_screen.dart';
import 'bluetooth_service.dart';

enum SortMode {
  numberThenColor, // Sort by number first, then by color
  colorThenNumber, // Sort by color first, then by number
}

class Player {
  final int id;
  final String name;
  List<GameCard> cards;
  bool isHuman;

  Player({
    required this.id,
    required this.name,
    required this.cards,
    this.isHuman = false,
  });
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueCard Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const CardGameScreen(),
    );
  }
}

// Card model to represent game cards
class GameCard {
  final String suit;
  final String value;
  final Color color;
  final String id;

  GameCard({
    required this.suit,
    required this.value,
    required this.color,
    required this.id,
  });

  String get displayText => '$value$suit';
  
  // Get numeric value for comparison
  int get numericValue {
    switch (value) {
      case 'A': return 1;
      case '2': return 2; // Special card - can always be played
      case '3': return 3;
      case '4': return 4;
      case '5': return 5;
      case '6': return 6;
      case '7': return 7;
      case '8': return 8;
      case '9': return 9;
      case '10': return 10;
      case 'J': return 11;
      case 'Q': return 12;
      case 'K': return 13;
      default: return 0;
    }
  }
  
  // Get color priority for sorting (red suits first, then black)
  int get colorPriority {
    switch (suit) {
      case '♥': return 1; // Hearts first
      case '♦': return 2; // Diamonds second
      case '♠': return 3; // Spades third
      case '♣': return 4; // Clubs last
      default: return 5;
    }
  }
  
  // Check if this is a special card (Joker or 2)
  bool get isSpecialCard => value == '2' || value == 'Joker';
  
  // Check if this card can be played on top of another card
  bool canPlayOn(GameCard topCard) {
    // Special cards can always be played
    if (isSpecialCard) return true;
    
    // Can play if same or higher value
    return numericValue >= topCard.numericValue;
  }
}

class CardGameScreen extends StatefulWidget {
  const CardGameScreen({super.key});

  @override
  State<CardGameScreen> createState() => _CardGameScreenState();
}

class _CardGameScreenState extends State<CardGameScreen> with TickerProviderStateMixin {
  List<Player> players = [];
  List<GameCard> centerPile = [];
  List<GameCard> drawDeck = [];
  String? selectedCardId;
  SortMode currentSortMode = SortMode.numberThenColor; // Default sorting
  int currentPlayerIndex = 0;
  int humanPlayerIndex = 0;
  int totalPlayers = 2;
  bool gameInitialized = false;

  // Helper property voor de huidige speler  
  Player get currentPlayer => players[currentPlayerIndex];
  List<GameCard> get playerCards => currentPlayer.cards;
  
  // Bluetooth service voor multiplayer
  final BluetoothGameService _bluetoothService = BluetoothGameService();

  late AnimationController _animationController;
  late AnimationController _playCardAnimationController;
  late Animation<double> _playCardAnimation;
  late Animation<Offset> _playCardSlideAnimation;
  late Animation<double> _playCardRotationAnimation;
  late Animation<double> _playCardScaleAnimation;
  GameCard? _animatingCard;
  
  late AnimationController _drawCardAnimationController;
  late Animation<double> _drawCardAnimation;
  late Animation<Offset> _drawCardSlideAnimation;
  late Animation<double> _drawCardRotationAnimation;
  late Animation<double> _drawCardScaleAnimation;
  GameCard? _drawingCard;

  @override
  void initState() {
    super.initState();
    
    // Zet wakelock aan om scherm wakker te houden tijdens het spelen
    WakelockPlus.enable();
    
    // Initialize players first, then show setup dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showGameSetupDialog();
    });
    
    // Initialize all animation controllers first
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _playCardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _drawCardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    
    // Initialize play card animations
    _playCardAnimation = CurvedAnimation(
      parent: _playCardAnimationController,
      curve: Curves.easeInOutCubic,
    );
    
    _playCardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.8),
      end: const Offset(0, -0.3),
    ).animate(CurvedAnimation(
      parent: _playCardAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _playCardRotationAnimation = Tween<double>(
      begin: 0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _playCardAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _playCardScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _playCardAnimationController,
      curve: Curves.elasticOut,
    ));
    
    // Initialize draw card animations
    _drawCardAnimation = CurvedAnimation(
      parent: _drawCardAnimationController,
      curve: Curves.easeInOutBack,
    );
    
    _drawCardSlideAnimation = Tween<Offset>(
      begin: const Offset(-0.8, -0.3),
      end: const Offset(0, 0.5),
    ).animate(CurvedAnimation(
      parent: _drawCardAnimationController,
      curve: Curves.easeOutBack,
    ));
    
    _drawCardRotationAnimation = Tween<double>(
      begin: -0.8,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _drawCardAnimationController,
      curve: Curves.bounceOut,
    ));
    
    _drawCardScaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _drawCardAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _initializeCards();
  }

  @override
  void dispose() {
    // Zet wakelock uit wanneer de app wordt gesloten
    WakelockPlus.disable();
    
    _animationController.dispose();
    _playCardAnimationController.dispose();
    _drawCardAnimationController.dispose();
    super.dispose();
  }

  void _initializeCards() {
    final suits = ['♠', '♥', '♦', '♣'];
    final values = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    
    // Reset all card collections
    for (var player in players) {
      player.cards.clear();
    }
    centerPile = [];
    drawDeck = [];
    
    // Create a full deck for drawing
    for (final suit in suits) {
      for (final value in values) {
        final color = (suit == '♥' || suit == '♦') ? Colors.red : Colors.black;
        drawDeck.add(GameCard(
          suit: suit,
          value: value,
          color: color,
          id: 'deck_${suit}_$value',
        ));
      }
    }
    
    // Shuffle the draw deck
    drawDeck.shuffle();
    
    // Give each player 7 cards from the deck
    for (int playerIndex = 0; playerIndex < players.length; playerIndex++) {
      for (int cardIndex = 0; cardIndex < 7; cardIndex++) {
        if (drawDeck.isNotEmpty) {
          final card = drawDeck.removeAt(0);
          players[playerIndex].cards.add(GameCard(
            suit: card.suit,
            value: card.value,
            color: card.color,
            id: 'player_${playerIndex}_$cardIndex',
          ));
        }
      }
    }
    
    // Sort all players' initial hands
    for (var player in players) {
      _sortCards(player.cards);
    }

    // Add one card to center pile to start
    if (drawDeck.isNotEmpty) {
      final startCard = drawDeck.removeAt(0);
      centerPile.add(GameCard(
        suit: startCard.suit,
        value: startCard.value,
        color: startCard.color,
        id: 'center_start',
      ));
    }
  }

  void _selectCard(String cardId) {
    // Only allow human player to select cards
    if (!currentPlayer.isHuman) return;
    
    setState(() {
      if (selectedCardId == cardId) {
        selectedCardId = null; // Deselect if same card is tapped
      } else {
        selectedCardId = cardId;
      }
    });
  }

  void _playCard() {
    if (selectedCardId == null) return;
    
    // Only allow current player to play if they're human
    if (!currentPlayer.isHuman) return;
    
    final cardIndex = playerCards.indexWhere((card) => card.id == selectedCardId);
    if (cardIndex == -1) return;
    
    final card = playerCards[cardIndex];
    final topCard = centerPile.last;
    
    // Check if card can be played according to rules
    if (!card.canPlayOn(topCard)) {
      // Show error or feedback that card cannot be played
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot play ${card.displayText} on ${topCard.displayText}. Need same or higher value, or a 2.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
    setState(() {
      _animatingCard = card;
      selectedCardId = null;
    });

    // Start de sick animatie
    _playCardAnimationController.forward().then((_) {
      setState(() {
        currentPlayer.cards.removeAt(cardIndex);
        centerPile.add(card);
        _animatingCard = null;
        // Cards should already be sorted, but just in case
        _sortPlayerCards();
        
        // Move to next turn
        _nextTurn();
        
        // Send Bluetooth message if connected
        _sendBluetoothMessage(GameMessageType.playCard, {
          'cardId': card.id,
          'cardSuit': card.suit,
          'cardValue': card.value,
          'cardColor': card.color,
        });
      });
      _playCardAnimationController.reset();
    });
  }
  
  void _resetGame() {
    setState(() {
      selectedCardId = null;
      gameInitialized = false;
    });
    _showGameSetupDialog();
  }
  
  // Check if player can play any card
  bool get canPlayAnyCard {
    if (centerPile.isEmpty) return true;
    final topCard = centerPile.last;
    return playerCards.any((card) => card.canPlayOn(topCard));
  }
  
  // Draw a card from the deck
  void _drawCard() {
    // Only allow human player to draw
    if (!currentPlayer.isHuman) return;
    
    if (drawDeck.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No more cards in deck!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Check if player can draw (can't play any card)
    if (canPlayAnyCard) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can play a card! Drawing is only allowed when you cannot play.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    final drawnCard = drawDeck.removeAt(0);
    final newCard = GameCard(
      suit: drawnCard.suit,
      value: drawnCard.value,
      color: drawnCard.color,
      id: 'drawn_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    setState(() {
      _drawingCard = newCard;
    });
    
    _drawCardAnimationController.forward().then((_) {
      setState(() {
        currentPlayer.cards.add(newCard);
        _sortPlayerCards();
        _drawingCard = null;
        
        // Move to next turn after drawing
        _nextTurn();
        
        // Send Bluetooth message if connected
        _sendBluetoothMessage(GameMessageType.drawCard, {
          'cardId': newCard.id,
          'cardSuit': newCard.suit,
          'cardValue': newCard.value,
          'cardColor': newCard.color,
        });
      });
      _drawCardAnimationController.reset();
    });
  }
  
  // Sort cards based on current sort mode
  void _sortCards(List<GameCard> cards) {
    switch (currentSortMode) {
      case SortMode.numberThenColor:
        cards.sort((a, b) {
          // First sort by number
          int numberComparison = a.numericValue.compareTo(b.numericValue);
          if (numberComparison != 0) return numberComparison;
          // If numbers are equal, sort by color
          return a.colorPriority.compareTo(b.colorPriority);
        });
        break;
      case SortMode.colorThenNumber:
        cards.sort((a, b) {
          // First sort by color
          int colorComparison = a.colorPriority.compareTo(b.colorPriority);
          if (colorComparison != 0) return colorComparison;
          // If colors are equal, sort by number
          return a.numericValue.compareTo(b.numericValue);
        });
        break;
    }
  }
  
  // Sort current player's cards
  void _sortPlayerCards() {
    _sortCards(playerCards);
  }
  
  // Show dialog to setup the game
  void _showGameSetupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Setup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Number of players:'),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [2, 3, 4].map((count) => 
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      totalPlayers = count;
                    });
                    Navigator.pop(context);
                    _showPlayerSelectionDialog();
                  },
                  child: Text('$count'),
                )
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  // Show dialog to select which player the user is
  void _showPlayerSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Which player are you?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(totalPlayers, (index) => 
            ListTile(
              title: Text('Player ${index + 1}'),
              onTap: () {
                setState(() {
                  humanPlayerIndex = index;
                });
                Navigator.pop(context);
                _initializeGame();
              },
            )
          ),
        ),
      ),
    );
  }
  
  // Initialize the game with players
  void _initializeGame() {
    players.clear();
    for (int i = 0; i < totalPlayers; i++) {
      players.add(Player(
        id: i,
        name: 'Player ${i + 1}',
        isHuman: i == humanPlayerIndex,
        cards: [],
      ));
    }
    
    _initializeCards();
    setState(() {
      gameInitialized = true;
      currentPlayerIndex = 0;
    });
  }
  
  // Move to next turn
  void _nextTurn() {
    setState(() {
      currentPlayerIndex = (currentPlayerIndex + 1) % totalPlayers;
    });
  }
  
  // Send Bluetooth message to other players
  void _sendBluetoothMessage(GameMessageType type, Map<String, dynamic> data) {
    if (_bluetoothService.isConnected) {
      final message = GameMessage(
        type: type,
        data: data,
        playerId: 'player_${currentPlayer.id}',
      );
      _bluetoothService.sendMessage(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F5132), // Dark green like a card table
      appBar: AppBar(
        title: const Text(
          'BlueCard Game',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0A4025),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BluetoothSetupScreen(),
                ),
              );
            },
            icon: const Icon(Icons.bluetooth, color: Colors.white),
            tooltip: 'Bluetooth Multiplayer',
          ),
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Reset Game'),
                    content: const Text('Are you sure you want to reset the game? All cards will be returned to your hand.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _resetGame();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Reset'),
                      ),
                    ],
                  );
                },
              );
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reset Game',
          ),
        ],
      ),
      body: !gameInitialized 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
        children: [
          // Main game UI
          Column(
            children: [
              // Player info area
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF0A4025),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: players.asMap().entries.map((entry) {
                    int index = entry.key;
                    Player player = entry.value;
                    bool isCurrentPlayer = index == currentPlayerIndex;
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isCurrentPlayer ? Colors.orange : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCurrentPlayer ? Colors.orange : Colors.white24,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            player.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          Text(
                            '${player.cards.length} cards',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          
          // Center pile area
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Draw deck
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: drawDeck.isNotEmpty ? _drawCard : null,
                        child: Container(
                          width: 70,
                          height: 100,
                          decoration: BoxDecoration(
                            color: drawDeck.isNotEmpty ? const Color(0xFF1A237E) : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.style,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${drawDeck.length}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  
                  // Center pile cards
                  Container(
                    width: 120,
                    height: 120,
                    alignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.center,
                      children: centerPile.asMap().entries.map((entry) {
                        final index = entry.key;
                        final card = entry.value;
                        return Transform.translate(
                          offset: Offset(index * 2.0, index * -1.0),
                          child: Transform.rotate(
                            angle: (index * 0.1) - 0.2,
                            child: PlayingCard(
                              card: card,
                              isSelected: false,
                              onTap: () {},
                              scale: 1.1,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Play button (only show if card is selected and it's human player's turn)
                  if (selectedCardId != null && currentPlayer.isHuman)
                    ElevatedButton(
                      onPressed: _playCard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'PLAY CARD',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  
                  // Draw button (only show if can't play any card, no card selected, and it's human player's turn)
                  if (!canPlayAnyCard && selectedCardId == null && drawDeck.isNotEmpty && currentPlayer.isHuman)
                    ElevatedButton(
                      onPressed: _drawCard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'DRAW CARD',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Player's hand
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          // Eerste rij
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: playerCards.take((playerCards.length + 1) ~/ 2).map((card) {
                                  final isSelected = selectedCardId == card.id;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: PlayingCard(
                                      card: card,
                                      isSelected: isSelected,
                                      onTap: () => _selectCard(card.id),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Tweede rij
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: playerCards.skip((playerCards.length + 1) ~/ 2).map((card) {
                                  final isSelected = selectedCardId == card.id;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: PlayingCard(
                                      card: card,
                                      isSelected: isSelected,
                                      onTap: () => _selectCard(card.id),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          

            ],
          ),
          
          // Play card animatie overlay
          if (_animatingCard != null)
            AnimatedBuilder(
              animation: _playCardAnimationController,
              builder: (context, child) {
                return Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: Offset(
                          _playCardSlideAnimation.value.dx * MediaQuery.of(context).size.width * 0.2,
                          _playCardSlideAnimation.value.dy * MediaQuery.of(context).size.height * 0.2,
                        ),
                        child: Transform.rotate(
                          angle: _playCardRotationAnimation.value * 3.14159,
                          child: Transform.scale(
                            scale: _playCardScaleAnimation.value,
                            child: Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.6),
                                    blurRadius: (20 * _playCardAnimation.value).clamp(0.0, double.infinity),
                                    spreadRadius: (5 * _playCardAnimation.value).clamp(0.0, double.infinity),
                                  ),
                                ],
                              ),
                              child: PlayingCard(
                                card: _animatingCard!,
                                isSelected: false,
                                onTap: () {},
                                scale: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            
          // Draw card animatie overlay  
          if (_drawingCard != null)
            AnimatedBuilder(
              animation: _drawCardAnimationController,
              builder: (context, child) {
                return Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: Offset(
                          _drawCardSlideAnimation.value.dx * MediaQuery.of(context).size.width * 0.3,
                          _drawCardSlideAnimation.value.dy * MediaQuery.of(context).size.height * 0.2,
                        ),
                        child: Transform.rotate(
                          angle: _drawCardRotationAnimation.value * 3.14159,
                          child: Transform.scale(
                            scale: _drawCardScaleAnimation.value,
                            child: Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.7),
                                    blurRadius: (25 * _drawCardAnimation.value).clamp(0.0, double.infinity),
                                    spreadRadius: (8 * _drawCardAnimation.value).clamp(0.0, double.infinity),
                                  ),
                                ],
                              ),
                              child: PlayingCard(
                                card: _drawingCard!,
                                isSelected: false,
                                onTap: () {},
                                scale: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class PlayingCard extends StatelessWidget {
  final GameCard card;
  final bool isSelected;
  final VoidCallback onTap;
  final double scale;

  const PlayingCard({
    super.key,
    required this.card,
    required this.isSelected,
    required this.onTap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()
            ..scale(scale)
            ..translate(0.0, isSelected ? -5.0 : 0.0),
        child: Container(
          width: 60,
          height: 85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.yellow : Colors.grey.shade300,
              width: isSelected ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: isSelected ? 8 : 4,
                offset: Offset(0, isSelected ? 4 : 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Links boven
              Positioned(
                top: 4,
                left: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.value,
                      style: TextStyle(
                        color: card.color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      card.suit,
                      style: TextStyle(
                        color: card.color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Rechts onder (omgedraaid)
              Positioned(
                bottom: 4,
                right: 4,
                child: Transform.rotate(
                  angle: 3.14159, // 180 graden
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.value,
                        style: TextStyle(
                          color: card.color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        card.suit,
                        style: TextStyle(
                          color: card.color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
