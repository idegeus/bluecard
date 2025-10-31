/// Speelkaart suit (kleur)
enum CardSuit {
  hearts,   // Harten ♥
  diamonds, // Ruiten ♦
  clubs,    // Klaver ♣
  spades,   // Schoppen ♠
}

/// Speelkaart rank (waarde)
enum CardRank {
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,   // Boer
  queen,  // Vrouw
  king,   // Heer
  ace,    // Aas
  joker,  // Joker
}

/// Speelkaart
class PlayingCard {
  final CardSuit? suit; // Null voor joker
  final CardRank rank;
  
  const PlayingCard({
    this.suit,
    required this.rank,
  });
  
  /// Nummer waarde van de kaart (voor vergelijking)
  int get value {
    switch (rank) {
      case CardRank.two: return 2;
      case CardRank.three: return 3;
      case CardRank.four: return 4;
      case CardRank.five: return 5;
      case CardRank.six: return 6;
      case CardRank.seven: return 7;
      case CardRank.eight: return 8;
      case CardRank.nine: return 9;
      case CardRank.ten: return 10;
      case CardRank.jack: return 11;
      case CardRank.queen: return 12;
      case CardRank.king: return 13;
      case CardRank.ace: return 14;
      case CardRank.joker: return 15;
    }
  }
  
  /// Symbol voor de kaart
  String get symbol {
    if (rank == CardRank.joker) return '🃏';
    
    final suitSymbol = suit == null ? '' : {
      CardSuit.hearts: '♥',
      CardSuit.diamonds: '♦',
      CardSuit.clubs: '♣',
      CardSuit.spades: '♠',
    }[suit]!;
    
    final rankSymbol = {
      CardRank.two: '2',
      CardRank.three: '3',
      CardRank.four: '4',
      CardRank.five: '5',
      CardRank.six: '6',
      CardRank.seven: '7',
      CardRank.eight: '8',
      CardRank.nine: '9',
      CardRank.ten: '10',
      CardRank.jack: 'J',
      CardRank.queen: 'Q',
      CardRank.king: 'K',
      CardRank.ace: 'A',
      CardRank.joker: 'JK',
    }[rank]!;
    
    return '$rankSymbol$suitSymbol';
  }
  
  /// Kleur voor de kaart (rood of zwart)
  bool get isRed => suit == CardSuit.hearts || suit == CardSuit.diamonds;
  
  /// Speciale kaart in Pesten
  bool get isSpecial {
    return rank == CardRank.seven || // Pak 2 kaarten
           rank == CardRank.eight || // Beurt overslaan
           rank == CardRank.ace ||   // Richting omkeren
           rank == CardRank.joker;   // Troef kiezen
  }
  
  /// Compact serialisatie als single integer (voor BLE)
  /// Format: suit(4bit) + rank(4bit) = 8bit (1 byte)
  /// Joker = 0xFF
  int toCompact() {
    if (suit == null) return 0xFF; // Joker
    return (suit!.index << 4) | rank.index;
  }
  
  /// Compact deserialisatie
  factory PlayingCard.fromCompact(int encoded) {
    if (encoded == 0xFF) {
      return const PlayingCard(rank: CardRank.joker);
    }
    return PlayingCard(
      suit: CardSuit.values[(encoded >> 4) & 0x0F],
      rank: CardRank.values[encoded & 0x0F],
    );
  }
  
  /// Legacy JSON serialisatie (backwards compatibility)
  Map<String, dynamic> toJson() {
    return {
      'suit': suit?.index,
      'rank': rank.index,
    };
  }
  
  /// Legacy JSON deserialisatie
  factory PlayingCard.fromJson(Map<String, dynamic> json) {
    return PlayingCard(
      suit: json['suit'] != null ? CardSuit.values[json['suit']] : null,
      rank: CardRank.values[json['rank']],
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayingCard && 
           other.suit == suit && 
           other.rank == rank;
  }
  
  @override
  int get hashCode => suit.hashCode ^ rank.hashCode;
  
  @override
  String toString() => symbol;
}

/// Kaartendek
class Deck {
  final List<PlayingCard> cards = [];
  
  Deck({bool includeJokers = true}) {
    // Voeg alle kaarten toe
    for (final suit in CardSuit.values) {
      for (final rank in CardRank.values) {
        if (rank != CardRank.joker) {
          cards.add(PlayingCard(suit: suit, rank: rank));
        }
      }
    }
    
    // Voeg jokers toe
    if (includeJokers) {
      cards.add(const PlayingCard(rank: CardRank.joker));
      cards.add(const PlayingCard(rank: CardRank.joker));
    }
  }
  
  /// Schud het deck
  void shuffle() {
    cards.shuffle();
  }
  
  /// Trek een kaart
  PlayingCard? draw() {
    if (cards.isEmpty) return null;
    return cards.removeLast();
  }
  
  /// Aantal kaarten in deck
  int get size => cards.length;
  
  /// Is deck leeg
  bool get isEmpty => cards.isEmpty;
}
