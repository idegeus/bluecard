import 'package:flutter/material.dart';
import '../models/playing_card.dart';

/// Widget voor het weergeven van een speelkaart
class CardWidget extends StatelessWidget {
  final PlayingCard card;
  final bool isSelected;
  final bool canPlay;
  final VoidCallback? onTap;
  final double width;
  final double height;
  
  const CardWidget({
    Key? key,
    required this.card,
    this.isSelected = false,
    this.canPlay = true,
    this.onTap,
    this.width = 60,
    this.height = 90,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canPlay ? onTap : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: width,
        height: height,
        margin: EdgeInsets.symmetric(horizontal: 2),
        transform: isSelected 
            ? (Matrix4.identity()..translate(0.0, -10.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? Colors.blue
                : canPlay
                    ? Colors.grey
                    : Colors.grey.shade300,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.symbol,
              style: TextStyle(
                fontSize: width * 0.5,
                color: card.isRed ? Colors.red : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (card.isSpecial)
              Icon(
                Icons.star,
                size: width * 0.3,
                color: Colors.amber,
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget voor de achterkant van een kaart
class CardBackWidget extends StatelessWidget {
  final double width;
  final double height;
  
  const CardBackWidget({
    Key? key,
    this.width = 60,
    this.height = 90,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.blue.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.shade700,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.diamond,
          size: width * 0.6,
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }
}

/// Widget voor de deck stapel
class DeckPileWidget extends StatelessWidget {
  final int cardCount;
  final VoidCallback? onTap;
  
  const DeckPileWidget({
    Key? key,
    required this.cardCount,
    this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: cardCount > 0 ? onTap : null,
      child: SizedBox(
        width: 66, // CardBackWidget width (60) + offset (6)
        height: 96, // CardBackWidget height (90) + offset (6)
        child: Stack(
          children: [
            // Stapel effect
            for (int i = 0; i < 3; i++)
              Positioned(
                left: i * 2.0,
                top: i * 2.0,
                child: CardBackWidget(),
              ),
            // Aantal kaarten badge
            if (cardCount > 0)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$cardCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget voor de aflegstapel
class DiscardPileWidget extends StatelessWidget {
  final PlayingCard? topCard;
  
  const DiscardPileWidget({
    Key? key,
    this.topCard,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Lege stapel
        Container(
          width: 60,
          height: 90,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.shade400,
              width: 2,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              Icons.layers,
              color: Colors.grey.shade300,
              size: 30,
            ),
          ),
        ),
        // Bovenste kaart
        if (topCard != null)
          CardWidget(card: topCard!, canPlay: false),
      ],
    );
  }
}

/// Widget voor de hand van een speler
class PlayerHandWidget extends StatelessWidget {
  final List<PlayingCard> cards;
  final PlayingCard? selectedCard;
  final Function(PlayingCard)? onCardTap;
  final bool Function(PlayingCard)? canPlayCard;
  
  const PlayerHandWidget({
    Key? key,
    required this.cards,
    this.selectedCard,
    this.onCardTap,
    this.canPlayCard,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Container(
        height: 100,
        child: Center(
          child: Text(
            'Geen kaarten',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    
    return Container(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          final isSelected = card == selectedCard;
          final canPlay = canPlayCard?.call(card) ?? true;
          
          return CardWidget(
            card: card,
            isSelected: isSelected,
            canPlay: canPlay,
            onTap: onCardTap != null ? () => onCardTap!(card) : null,
          );
        },
      ),
    );
  }
}

/// Widget voor opponent hands (alleen aantal kaarten)
class OpponentHandWidget extends StatelessWidget {
  final String playerId;
  final int cardCount;
  final bool isCurrentPlayer;
  
  const OpponentHandWidget({
    Key? key,
    required this.playerId,
    required this.cardCount,
    this.isCurrentPlayer = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isCurrentPlayer 
            ? Colors.green.withOpacity(0.2)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentPlayer ? Colors.green : Colors.grey,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person,
            color: isCurrentPlayer ? Colors.green : Colors.grey,
          ),
          SizedBox(width: 8),
          Text(
            playerId,
            style: TextStyle(
              fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          SizedBox(width: 8),
          Row(
            children: [
              CardBackWidget(width: 30, height: 45),
              SizedBox(width: 4),
              Text(
                'x$cardCount',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
