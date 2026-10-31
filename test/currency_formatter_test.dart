import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/shared/utils/currency_formatter.dart';

void main() {
  test('formats Rupiah with dot-separated thousands', () {
    expect(CurrencyFormatter.formatRupiah(32500), 'Rp32.500');
  });

  test('supports the spaced Rupiah format used in reports', () {
    expect(
      CurrencyFormatter.formatRupiah(32500, spaceAfterSymbol: true),
      'Rp 32.500',
    );
  });

  test('preserves the sign for negative amounts', () {
    expect(CurrencyFormatter.formatRupiah(-32500), '-Rp32.500');
  });
}
