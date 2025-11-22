import 'package:flutter/material.dart';
import '../services/player_identity_service.dart';
import '../services/settings_service.dart';

/// Herbruikbaar widget om spelerlijst te tonen
class PlayerList extends StatefulWidget {
  final int playerCount;
  final List<String> playerIds;

  const PlayerList({
    super.key,
    required this.playerCount,
    required this.playerIds,
  });

  @override
  State<PlayerList> createState() => _PlayerListState();
}

class _PlayerListState extends State<PlayerList> {
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final userName = await SettingsService.getUserName();
      setState(() {
        _currentUserName = userName;
      });
    } catch (e) {
      // Fallback, geen gebruikersnaam beschikbaar
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.playerIds.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.fromARGB(255, 9, 32, 15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Spelers',
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
            children: widget.playerIds.map((playerId) {
              final isHost = playerId.startsWith('host');
              final displayName = _getDisplayName(playerId);
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
                      displayName,
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

  /// Zet player ID om naar leesbare naam
  String _getDisplayName(String playerId) {
    if (playerId.startsWith('host')) {
      // Voor host, gebruik de gebruikersnaam of 'Host' als fallback
      return _currentUserName ?? 'Host';
    } else if (playerId.startsWith('client_')) {
      final digest = playerId.substring(7); // Verwijder 'client_' prefix
      return PlayerIdentityService.getReadableName(digest);
    } else if (playerId.startsWith('connecting_')) {
      return 'Verbinden...';
    } else {
      return playerId; // Fallback voor oude IDs
    }
  }
}
