import 'package:intl/intl.dart';

int roundedRatio(int n, int d) {
  return roundedBigRatio(BigInt.from(n), BigInt.from(d));
}

int roundedBigRatio(BigInt n, BigInt d) {
  if (d <= BigInt.zero) throw ArgumentError('Dénominateur invalide');
  final a = n.abs();
  final b = d;
  final result = (a * BigInt.two + b) ~/ (b * BigInt.two);
  if (result.bitLength > 62) {
    throw const AppFailure('Montant supérieur à la limite de précision.');
  }
  return n.isNegative ? -result.toInt() : result.toInt();
}

int productRatio(int a, int b, int d) =>
    roundedBigRatio(BigInt.from(a) * BigInt.from(b), BigInt.from(d));

int realizedGain(int price, int qty, int averageNum, int averageDen) =>
    roundedBigRatio(
      (BigInt.from(price) * BigInt.from(averageDen) - BigInt.from(averageNum)) *
          BigInt.from(qty),
      BigInt.from(averageDen),
    );

({int numerator, int denominator}) decimalRatio(String input) {
  final m = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?$').firstMatch(input.trim());
  if (m == null) throw const FormatException('Décimal invalide');
  final fraction = m[3] ?? '';
  if (fraction.length > 12) throw const FormatException('Précision excessive');
  return (
    numerator: int.parse('${m[1]}${m[2]}$fraction'),
    denominator: BigInt.from(10).pow(fraction.length).toInt(),
  );
}

int cents(String input) {
  final r = decimalRatio(input);
  return productRatio(r.numerator, 100, r.denominator);
}

String money(int value, {String currency = 'USD'}) =>
    '${value < 0 ? '−' : ''}${NumberFormat.decimalPattern('fr').format(value.abs() ~/ 100)},${(value.abs() % 100).toString().padLeft(2, '0')} $currency';

String percent(int gain, int cost) {
  if (cost == 0) return '—';
  final bp = productRatio(gain, 10000, cost.abs());
  return '${bp < 0 ? '−' : '+'}${bp.abs() ~/ 100},${(bp.abs() % 100).toString().padLeft(2, '0')} %';
}

String stamp(DateTime time) =>
    '${DateFormat('dd/MM/yyyy HH:mm').format(time.toUtc())} UTC';

class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
