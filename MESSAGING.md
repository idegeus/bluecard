# BlueCard Messaging Protocol

## Gestandaardiseerd Message Formaat

Alle communicatie tussen Host en Client gebruikt het `GameMessage` formaat:

```dart
{
  "type": "ping",              // Message type (enum)
  "timestamp": 1234567890,     // Unix timestamp in milliseconds
  "playerId": "host-1234",     // Unieke ID van afzender
  "content": {                 // Optioneel - extra data
    "key": "value"
  }
}
```

## Message Types

### Huidige Types
- `ping` - Heartbeat/latency check + algemene communicatie
- `startGame` - Game start signaal

### Uitbreidbaar
Nieuwe types kunnen later worden toegevoegd aan de `GameMessageType` enum in `lib/models/game_message.dart` wanneer nodig.

## API Gebruik

### Client naar Host

```dart
// Ping sturen (ook voor algemene acties)
await bluetoothClient.sendPing();

// Custom message met content
await bluetoothClient.sendMessage(
  type: GameMessageType.ping,
  content: {
    'message': 'Hello from client!',
    'data': 42,
  },
);
```

### Host naar Clients

```dart
// Ping sturen
await bluetoothHost.sendPing();

// Custom message met content
await bluetoothHost.sendMessage(
  type: GameMessageType.ping,
  content: {
    'action': 'update_score',
    'score': 100,
  },
);

// Game starten
await bluetoothHost.startGame();
```

## Message Handling

### Ontvangen Berichten

Beide client en host ontvangen berichten via de `gameMessageStream`:

```dart
bluetoothClient.gameMessageStream.listen((gameMessage) {
  print('Type: ${gameMessage.type.name}');
  print('Van: ${gameMessage.playerId}');
  print('Timestamp: ${gameMessage.timestamp}');
  
  if (gameMessage.content != null) {
    print('Content: ${gameMessage.content}');
  }
  
  // Handle specifieke types
  switch (gameMessage.type) {
    case GameMessageType.ping:
      // Handle ping
      break;
    case GameMessageType.startGame:
      // Start game
      break;
    default:
      // Handle andere types
      break;
  }
});
```

## Voordelen

✅ **Consistent** - Alle berichten hebben dezelfde structuur  
✅ **Type-safe** - Gebruik van enums voorkomt typos  
✅ **Uitbreidbaar** - Nieuwe types gemakkelijk toe te voegen  
✅ **Flexibel** - Content veld voor custom data  
✅ **Bidirectioneel** - Zelfde formaat voor beide richtingen  
✅ **MTU-geoptimaliseerd** - Automatische chunking bij grote berichten  

## Transport Laag

- **MTU Negotiation**: Automatisch verhogen naar 512 bytes (van standaard 23)
- **Chunking**: Berichten >MTU worden automatisch opgesplitst
- **Buffering**: Chunks worden verzameld tot compleet JSON object
- **Reliability**: 5ms delay tussen chunks voor stabiele transmissie
