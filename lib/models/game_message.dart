import 'dart:convert';

/// Types van game messages
enum GameMessageType {
  startGame,
  ping,
}

/// Game message voor communicatie tussen host en clients
/// Gestandaardiseerd formaat voor alle berichten
class GameMessage {
  final GameMessageType type;
  final int timestamp;
  final String playerId;
  final Map<String, dynamic>? content;  // Optionele content
  
  GameMessage({
    required this.type,
    required this.timestamp,
    required this.playerId,
    this.content,
  });
  
  /// Converteer naar JSON string
  String toJson() {
    final Map<String, dynamic> map = {
      'type': type.name,
      'timestamp': timestamp,
      'playerId': playerId,
    };
    
    // Voeg content toe als het bestaat
    if (content != null && content!.isNotEmpty) {
      map['content'] = content!;
    }
    
    return jsonEncode(map);
  }
  
  /// Parse van JSON string
  factory GameMessage.fromJson(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    
    // Parse type - fallback naar ping als onbekend
    GameMessageType messageType;
    try {
      messageType = GameMessageType.values.firstWhere(
        (e) => e.name == data['type'],
      );
    } catch (e) {
      messageType = GameMessageType.ping;
    }
    
    return GameMessage(
      type: messageType,
      timestamp: data['timestamp'] as int,
      playerId: data['playerId'] as String,
      content: data['content'] as Map<String, dynamic>?,
    );
  }
  
  @override
  String toString() {
    if (content != null && content!.isNotEmpty) {
      return 'GameMessage(type: ${type.name}, playerId: $playerId, content: $content)';
    }
    return 'GameMessage(type: ${type.name}, playerId: $playerId)';
  }
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
