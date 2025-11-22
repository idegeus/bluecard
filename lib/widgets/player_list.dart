import 'package:flutter/material.dart';

/// Herbruikbaar widget om spelerlijst te tonen
class PlayerList extends StatelessWidget {
  final int playerCount;
  final List<String> playerIds;

  const PlayerList({
    super.key,
    required this.playerCount,
    required this.playerIds,
  });

  @override
  Widget build(BuildContext context) {
    if (playerIds.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Colors.blue[400], size: 24),
              SizedBox(width: 8),
              Text(
                'Spelers ($playerCount)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: playerIds.map((playerId) {
              final isHost = playerId == 'host';
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isHost ? Colors.green[900] : Colors.blue[900],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isHost ? Colors.green[700]! : Colors.blue[700]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHost ? Icons.star : Icons.person,
                      size: 16,
                      color: isHost ? Colors.green[300] : Colors.blue[300],
                    ),
                    SizedBox(width: 6),
                    Text(
                      playerId,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
