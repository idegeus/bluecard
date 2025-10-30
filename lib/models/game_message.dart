import 'dart:convert';

/// Types van game messages
enum GameMessageType {
  startGame,
  ping,
}

/// Game message voor communicatie tussen host en clients
class GameMessage {
  final GameMessageType type;
  final int timestamp;
  final String playerId;
  
  GameMessage({
    required this.type,
    required this.timestamp,
    required this.playerId,
  });
  
  /// Converteer naar JSON string
  String toJson() {
    return jsonEncode({
      'type': type.name,
      'timestamp': timestamp,
      'playerId': playerId,
    });
  }
  
  /// Parse van JSON string
  factory GameMessage.fromJson(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    
    return GameMessage(
      type: GameMessageType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => GameMessageType.ping,
      ),
      timestamp: data['timestamp'] as int,
      playerId: data['playerId'] as String,
    );
  }
  
  @override
  String toString() => 'GameMessage(type: ${type.name}, timestamp: $timestamp, playerId: $playerId)';
}

/// Ping info voor display
class PingInfo {
  final int timestamp;
  final String playerId;
  final DateTime receivedAt;
  
  PingInfo({
    required this.timestamp,
    required this.playerId,
    required this.receivedAt,
  });
  
  String get formattedTimestamp => DateTime.fromMillisecondsSinceEpoch(timestamp).toString();
  String get formattedReceived => receivedAt.toString();
}
