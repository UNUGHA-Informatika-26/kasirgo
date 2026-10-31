import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/shared/utils/profit_calculator.dart';

void main() {
  test('calculates net profit as selling price minus cost price', () {
    final profit = calculateNetProfit([
      {'unitPrice': 6000, 'unitCost': 5500, 'quantity': 1},
    ]);

    expect(profit, 500);
  });

  test('multiplies per-item profit by quantity', () {
    final profit = calculateNetProfit([
      {'unitPrice': 6000, 'unitCost': 5500, 'quantity': 3},
    ]);

    expect(profit, 1500);
  });

  test('returns null when cost data is missing', () {
    final profit = calculateNetProfit([
      {'unitPrice': 6000, 'quantity': 1},
    ]);

    expect(profit, isNull);
  });

  test('returns null when the transaction has no item details', () {
    expect(calculateNetProfit([]), isNull);
  });
}
