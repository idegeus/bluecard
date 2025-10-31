/// Types van spellen die gespeeld kunnen worden
enum GameType {
  freePlay,
  president,
  hearts,
  uno,
  pesten,
}

extension GameTypeExtension on GameType {
  String get displayName {
    switch (this) {
      case GameType.freePlay:
        return 'Vrij Spel';
      case GameType.president:
        return 'President';
      case GameType.hearts:
        return 'Hearts';
      case GameType.uno:
        return 'UNO';
      case GameType.pesten:
        return 'Pesten';
    }
  }
  
  String get description {
    switch (this) {
      case GameType.freePlay:
        return 'Speel vrij met kaarten';
      case GameType.president:
        return 'Klassiek kaartspel waarbij spelers proberen van hun kaarten af te komen';
      case GameType.hearts:
        return 'Vermijd harten en de schoppen vrouw';
      case GameType.uno:
        return 'Leg kaarten op kleur of cijfer, speciale actiekaarten';
      case GameType.pesten:
        return 'Leg kaarten op kleur of waarde en pest je tegenstanders';
    }
  }
  
  String get emoji {
    switch (this) {
      case GameType.freePlay:
        return '🃏';
      case GameType.president:
        return '👑';
      case GameType.hearts:
        return '❤️';
      case GameType.uno:
        return '🎴';
      case GameType.pesten:
        return '😈';
    }
  }
}
