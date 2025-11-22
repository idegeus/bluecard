import 'package:flutter/material.dart';

class SuitCardData {
  final String rank;
  final String suit;
  final Color color;
  const SuitCardData(this.rank, this.suit, this.color);
}

class SuitCard extends StatelessWidget {
  final SuitCardData data;
  final double? height;
  final double? width;
  const SuitCard({super.key, required this.data, this.height, this.width});

  @override
  Widget build(BuildContext context) {
    // Flexibele hoogte zodat interne content nooit overflowt; fallback naar standaard.
    final double cardWidth = width ?? 90;
    final double cardHeight =
        height ?? 150; // iets groter dan oorspronkelijke 130
    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFBFBFB),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Column(
          children: [
            // Bovenhoek
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 10),
              child: Align(
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.rank,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      data.suit,
                      style: TextStyle(
                        color: data.color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Midden symbool (expand om aan te passen aan hoogte)
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    data.suit,
                    style: TextStyle(
                      fontSize: 42,
                      color: data.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            // Onderhoek
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, right: 10),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      data.rank,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      data.suit,
                      style: TextStyle(
                        color: data.color,
                        fontSize: 18,
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
    );
  }
}
