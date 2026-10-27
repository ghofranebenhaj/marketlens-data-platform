import 'package:hive/hive.dart';

class Watchlist {
  Watchlist(this.box);
  final Box<dynamic> box;
  Set<String> read(String scope) => Set<String>.from(
    box.get('$scope:favorites', defaultValue: <String>[]) as List,
  );
  Future<void> toggle(String scope, String symbol) async {
    final values = read(scope);
    values.contains(symbol) ? values.remove(symbol) : values.add(symbol);
    await box.put('$scope:favorites', values.toList());
  }
}
