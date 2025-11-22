/// Types van spellen die gespeeld kunnen worden
enum GameType { freePlay, zweedsPesten }

extension GameTypeExtension on GameType {
  String get displayName {
    switch (this) {
      case GameType.freePlay:
        return 'Vrij Spel';
      case GameType.zweedsPesten:
        return 'Zweeds pesten';
    }
  }

  String get description {
    switch (this) {
      case GameType.freePlay:
        return 'Speel vrij met kaarten';
      case GameType.zweedsPesten:
        return 'Pesten met een twist';
    }
  }

  String get emoji {
    switch (this) {
      case GameType.freePlay:
        return '🃏';
      case GameType.zweedsPesten:
        return '🇸🇪';
    }
  }
}
