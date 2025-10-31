import 'dart:async';
import 'package:flutter/material.dart';
import '../services/bluetooth_host.dart';
import '../services/bluetooth_client.dart';
import '../services/pesten_game_controller.dart';
import '../services/pesten_game.dart';
import '../models/game_message.dart';
import '../models/playing_card.dart';
import '../widgets/card_widgets.dart';
import '../widgets/suit_chooser_dialog.dart';

/// Gedeeld game screen voor zowel host als client
class GameScreen extends StatefulWidget {
  final BluetoothHost? bluetoothHost;
  final BluetoothClient? bluetoothClient;
  final bool isHost;
  
  const GameScreen({
    Key? key,
    this.bluetoothHost,
    this.bluetoothClient,
    required this.isHost,
  }) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  PestenGameHost? _pestenGameHost;
  PestenGameClient? _pestenGameClient;
  PestenGameState? _gameState;
  PlayingCard? _selectedCard;
  List<StreamSubscription> _subscriptions = [];
  
  @override
  void initState() {
    super.initState();
    _setupGame();
    _setupListeners();
  }
  
  void _setupGame() {
    if (widget.isHost && widget.bluetoothHost != null) {
      _pestenGameHost = PestenGameHost(widget.bluetoothHost!);
      
      // Luister naar game state changes
      final subscription = _pestenGameHost!.stateStream.listen((state) {
        if (mounted) {
          setState(() {
            _gameState = state;
          });
        }
      });
      _subscriptions.add(subscription);
      
      // Start het Pesten spel (kaarten delen, etc)
      print('🎮 GameScreen setup (Host) - starting Pesten game...');
      print('🎮 Player count: ${widget.bluetoothHost!.totalPlayerCount}');
      print('🎮 Player IDs: ${widget.bluetoothHost!.playerIds}');
      _pestenGameHost!.startGame();
    } else if (!widget.isHost && widget.bluetoothClient != null) {
      _pestenGameClient = PestenGameClient(widget.bluetoothClient!);
      
      // Set player ID
      _pestenGameClient!.setPlayerId(widget.bluetoothClient!.playerId);
      
      // Luister naar game state changes
      final subscription = _pestenGameClient!.stateStream.listen((state) {
        if (mounted) {
          setState(() {
            _gameState = state;
          });
        }
      });
      _subscriptions.add(subscription);
    }
  }
  
  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _pestenGameHost?.dispose();
    _pestenGameClient?.dispose();
    super.dispose();
  }
  
  void _setupListeners() {
    if (!widget.isHost && widget.bluetoothClient != null) {
      // Luister naar goodbye messages van host
      widget.bluetoothClient!.gameMessageStream.listen((gameMessage) {
        if (gameMessage.type == GameMessageType.goodbye && mounted) {
          // Host heeft game afgesloten
          _showHostQuitDialog();
        }
      });
    }
  }
  
  void _showHostQuitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[400]),
            SizedBox(width: 8),
            Text(
              'Host heeft afgesloten',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'De host heeft de game afgesloten. Je wordt teruggebracht naar het hoofdmenu.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              // Sluit dialog
              Navigator.pop(context);
              
              // Disconnect en ga naar home
              await widget.bluetoothClient?.disconnect();
              // NIET dispose() aanroepen - streams blijven beschikbaar
              
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _showConnectionInfo() {
    final now = DateTime.now();
    
    // Haal lastSync direct uit de service
    final DateTime? lastSync = widget.isHost 
        ? widget.bluetoothHost?.lastSyncTime 
        : widget.bluetoothClient?.lastSyncTime;
    
    final timeSinceLastSync = lastSync != null 
        ? now.difference(lastSync).inSeconds 
        : null;
    
    // Haal playerIds en count direct uit de service
    final List<String> playerIds = widget.isHost
        ? (widget.bluetoothHost?.playerIds ?? [])
        : (widget.bluetoothClient?.playerIds ?? []);
    
    final int playerCount = widget.isHost
        ? (widget.bluetoothHost?.totalPlayerCount ?? 0)
        : (widget.bluetoothClient?.playerCount ?? 0);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[400]),
            SizedBox(width: 8),
            Text(
              'Verbindingsinfo',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              icon: Icons.router,
              label: 'Rol',
              value: widget.isHost ? 'Host' : 'Client',
            ),
            SizedBox(height: 12),
            
            _buildInfoRow(
              icon: Icons.people,
              label: 'Spelers',
              value: '$playerCount (${playerIds.join(", ")})',
            ),
            SizedBox(height: 12),
            
            _buildInfoRow(
              icon: Icons.wifi_tethering,
              label: 'Laatste sync',
              value: timeSinceLastSync != null 
                  ? '$timeSinceLastSync seconden geleden'
                  : 'Nog geen sync',
            ),
            SizedBox(height: 12),
            
            _buildInfoRow(
              icon: Icons.check_circle,
              label: 'Status',
              value: widget.isHost 
                  ? (widget.bluetoothHost?.isAdvertising ?? false ? 'Actief' : 'Gestopt')
                  : (widget.bluetoothClient?.isConnected ?? false ? 'Verbonden' : 'Niet verbonden'),
              valueColor: widget.isHost 
                  ? (widget.bluetoothHost?.isAdvertising ?? false ? Colors.green : Colors.red)
                  : (widget.bluetoothClient?.isConnected ?? false ? Colors.green : Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Sluiten'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _confirmQuitGame() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.orange[400]),
            SizedBox(width: 8),
            Text(
              'Game afsluiten?',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          widget.isHost 
              ? 'Weet je zeker dat je de game wilt afsluiten? Alle spelers worden ontkoppeld.'
              : 'Weet je zeker dat je de game wilt verlaten?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
            ),
            child: Text('Afsluiten'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      await _quitGame();
    }
  }
  
  Future<void> _quitGame() async {
    try {
      // Toon loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Roep de juiste quit methode aan
      if (widget.isHost) {
        await widget.bluetoothHost?.quitGame();
      } else {
        await widget.bluetoothClient?.quitGame();
      }
      
      // Verwijder loading indicator
      if (mounted) {
        Navigator.pop(context);
        
        // Ga terug naar home screen
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      // Verwijder loading indicator
      if (mounted) {
        Navigator.pop(context);
        
        // Toon error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij afsluiten: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
  
  Widget _buildGamePlayScreen() {
    final myPlayerId = widget.isHost ? 'host' : widget.bluetoothClient?.playerId;
    final myHand = _gameState?.playerHands[myPlayerId] ?? [];
    final isMyTurn = _gameState?.currentPlayerId == myPlayerId;
    
    return Column(
      children: [
        // Opponents section
        Expanded(
          flex: 2,
          child: _buildOpponentsSection(),
        ),
        
        // Game table (deck + discard pile)
        Expanded(
          flex: 3,
          child: _buildGameTable(isMyTurn),
        ),
        
        // My hand
        Expanded(
          flex: 2,
          child: _buildMyHandSection(myHand, isMyTurn),
        ),
      ],
    );
  }
  
  Widget _buildOpponentsSection() {
    final myPlayerId = widget.isHost ? 'host' : widget.bluetoothClient?.playerId;
    final opponents = _gameState?.playerIds.where((id) => id != myPlayerId).toList() ?? [];
    
    return Container(
      padding: EdgeInsets.all(8),
      child: Column(
        children: [
          Text(
            'Andere spelers',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: opponents.length,
              itemBuilder: (context, index) {
                final opponentId = opponents[index];
                final cardCount = _gameState?.cardsInHand(opponentId) ?? 0;
                final isCurrentPlayer = _gameState?.currentPlayerId == opponentId;
                
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: OpponentHandWidget(
                    playerId: opponentId,
                    cardCount: cardCount,
                    isCurrentPlayer: isCurrentPlayer,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGameTable(bool isMyTurn) {
    final drawPileCount = _gameState?.drawPile.length ?? 0;
    final topCard = _gameState?.topCard;
    final chosenSuit = _gameState?.chosenSuit;
    
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Direction and current player indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _gameState?.direction == GameDirection.clockwise
                    ? Icons.rotate_right
                    : Icons.rotate_left,
                color: Colors.blue,
                size: 32,
              ),
              SizedBox(width: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isMyTurn ? Colors.green : Colors.grey[800],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isMyTurn ? 'JOUW BEURT' : 'Beurt: ${_gameState?.currentPlayerId}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Deck and discard pile
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Draw pile
              Column(
                children: [
                  DeckPileWidget(
                    cardCount: drawPileCount,
                    onTap: isMyTurn ? _onDrawCards : null,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Pakstapel',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  if (_gameState?.drawCount != null && _gameState!.drawCount > 0)
                    Text(
                      'Pak ${_gameState!.drawCount}!',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              
              // Discard pile
              Column(
                children: [
                  DiscardPileWidget(topCard: topCard),
                  SizedBox(height: 8),
                  Text(
                    'Aflegstapel',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  if (chosenSuit != null)
                    Container(
                      margin: EdgeInsets.only(top: 4),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Kleur: ${_getSuitSymbol(chosenSuit)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  String _getSuitSymbol(CardSuit suit) {
    switch (suit) {
      case CardSuit.hearts:
        return '♥';
      case CardSuit.diamonds:
        return '♦';
      case CardSuit.clubs:
        return '♣';
      case CardSuit.spades:
        return '♠';
    }
  }
  
  Widget _buildMyHandSection(List<PlayingCard> myHand, bool isMyTurn) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Text(
            isMyTurn ? 'Jouw beurt - Kies een kaart' : 'Jouw hand',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: PlayerHandWidget(
              cards: myHand,
              selectedCard: _selectedCard,
              onCardTap: isMyTurn ? _onCardTap : null,
              canPlayCard: _canPlayCard,
            ),
          ),
          if (_selectedCard != null && isMyTurn)
            ElevatedButton(
              onPressed: () => _onPlayCard(_selectedCard!),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(
                'Speel kaart',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  bool _canPlayCard(PlayingCard card) {
    if (widget.isHost && _pestenGameHost != null) {
      final state = _pestenGameHost!.state;
      return state != null && state.status == GameStatus.playing;
    } else if (_gameState != null) {
      return _gameState!.status == GameStatus.playing;
    }
    return false;
  }
  
  void _onCardTap(PlayingCard card) {
    if (!_canPlayCard(card)) return;
    
    setState(() {
      _selectedCard = _selectedCard == card ? null : card;
    });
  }
  
  void _onPlayCard(PlayingCard card) async {
    final myPlayerId = widget.isHost ? 'host' : widget.bluetoothClient?.playerId;
    if (myPlayerId == null) return;
    
    if (widget.isHost && _pestenGameHost != null) {
      _pestenGameHost!.playCard(myPlayerId, card);
    } else if (_pestenGameClient != null) {
      _pestenGameClient!.playCard(card);
    }
    
    setState(() {
      _selectedCard = null;
    });
    
    // If joker was played, show suit chooser
    if (card.rank == CardRank.joker) {
      final chosenSuit = await SuitChooserDialog.show(context);
      if (chosenSuit != null) {
        if (widget.isHost && _pestenGameHost != null) {
          _pestenGameHost!.chooseSuit(chosenSuit);
        } else if (_pestenGameClient != null) {
          _pestenGameClient!.chooseSuit(chosenSuit);
        }
      }
    }
  }
  
  void _onDrawCards() {
    final myPlayerId = widget.isHost ? 'host' : widget.bluetoothClient?.playerId;
    if (myPlayerId == null) return;
    
    if (widget.isHost && _pestenGameHost != null) {
      _pestenGameHost!.drawCards(myPlayerId);
    } else if (_pestenGameClient != null) {
      _pestenGameClient!.drawCards();
    }
  }
  
  Widget _buildGameFinishedScreen() {
    final winnerId = _gameState?.winnerId;
    final myPlayerId = widget.isHost ? 'host' : widget.bluetoothClient?.playerId;
    final didIWin = winnerId == myPlayerId;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            didIWin ? Icons.emoji_events : Icons.sentiment_neutral,
            size: 100,
            color: didIWin ? Colors.amber : Colors.grey,
          ),
          SizedBox(height: 24),
          Text(
            didIWin ? '🎉 Je hebt gewonnen!' : '😔 $winnerId heeft gewonnen',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: _confirmQuitGame,
            child: Text('Terug naar hoofdmenu'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Blokkeer terugknop - gebruiker moet quit gebruiken
      onWillPop: () async {
        _confirmQuitGame();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          title: Text(widget.isHost ? 'BlueCard - Host' : 'BlueCard - Speler'),
          backgroundColor: widget.isHost ? Colors.green[700] : Colors.blue[700],
          automaticallyImplyLeading: false, // Verwijder terugknop
          actions: [
            // Info button
            IconButton(
              icon: Icon(Icons.info_outline),
              onPressed: _showConnectionInfo,
              tooltip: 'Verbindingsinfo',
            ),
            // Quit button
            IconButton(
              icon: Icon(Icons.exit_to_app),
              onPressed: _confirmQuitGame,
              tooltip: 'Game afsluiten',
            ),
          ],
        ),
        body: _gameState == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Spel wordt gestart...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              )
            : _gameState!.status == GameStatus.finished
                ? _buildGameFinishedScreen()
                : _buildGamePlayScreen(),
      ),
    );
  }
}
