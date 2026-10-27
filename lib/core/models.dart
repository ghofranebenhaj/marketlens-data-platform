enum DataMode { demo, normal }

class Asset {
  const Asset(this.symbol, this.name, this.sector, this.fixture);
  final String symbol, name, sector;
  final int fixture;
}

const catalog = [
  Asset('AAPL', 'Apple', 'Technologie', 22000),
  Asset('MSFT', 'Microsoft', 'Logiciels', 42000),
  Asset('GOOGL', 'Alphabet', 'Internet', 17500),
  Asset('AMZN', 'Amazon', 'Commerce', 18500),
  Asset('NVDA', 'NVIDIA', 'Semi-conducteurs', 13000),
  Asset('TSLA', 'Tesla', 'Automobile', 25000),
];
Asset assetFor(String symbol) => catalog.firstWhere((a) => a.symbol == symbol);
final demoClock = DateTime.utc(2026, 10, 23, 20);
const priceMaxAge = Duration(minutes: 15);

class PricePoint {
  const PricePoint(this.at, this.cents);
  final DateTime at;
  final int cents;
}

class Quote {
  const Quote({
    required this.symbol,
    required this.price,
    required this.previous,
    required this.at,
    required this.mode,
    required this.points,
    this.cachedAt,
    this.historyCachedAt,
  });
  final String symbol;
  final int price, previous;
  final DateTime at;
  final DataMode mode;
  final List<PricePoint> points;
  final DateTime? cachedAt, historyCachedAt;
  bool fresh(DateTime now) =>
      !at.isAfter(now.add(const Duration(minutes: 1))) &&
      now.difference(at) <= priceMaxAge;
}

class Position {
  const Position(
    this.symbol,
    this.quantity,
    this.averageNumerator,
    this.averageDenominator,
  );
  final String symbol;
  final int quantity, averageNumerator, averageDenominator;
}

class Account {
  const Account(this.id, this.name, this.email, this.balance);
  final int id, balance;
  final String name, email;
}
