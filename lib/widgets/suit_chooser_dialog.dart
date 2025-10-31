import 'package:flutter/material.dart';
import '../models/playing_card.dart';

/// Dialog voor het kiezen van een kleur (na joker)
class SuitChooserDialog extends StatelessWidget {
  const SuitChooserDialog({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Kies een kleur'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Welke kleur wil je kiezen?'),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SuitButton(
                suit: CardSuit.hearts,
                symbol: '♥',
                color: Colors.red,
                onTap: () => Navigator.pop(context, CardSuit.hearts),
              ),
              _SuitButton(
                suit: CardSuit.diamonds,
                symbol: '♦',
                color: Colors.red,
                onTap: () => Navigator.pop(context, CardSuit.diamonds),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SuitButton(
                suit: CardSuit.clubs,
                symbol: '♣',
                color: Colors.black,
                onTap: () => Navigator.pop(context, CardSuit.clubs),
              ),
              _SuitButton(
                suit: CardSuit.spades,
                symbol: '♠',
                color: Colors.black,
                onTap: () => Navigator.pop(context, CardSuit.spades),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  static Future<CardSuit?> show(BuildContext context) {
    return showDialog<CardSuit>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SuitChooserDialog(),
    );
  }
}

class _SuitButton extends StatelessWidget {
  final CardSuit suit;
  final String symbol;
  final Color color;
  final VoidCallback onTap;
  
  const _SuitButton({
    Key? key,
    required this.suit,
    required this.symbol,
    required this.color,
    required this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            symbol,
            style: TextStyle(
              fontSize: 48,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
