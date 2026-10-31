class CurrencyFormatter {
  const CurrencyFormatter._();

  static String formatRupiah(int amount, {bool spaceAfterSymbol = false}) {
    final digits = amount.abs().toString();
    final grouped = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        grouped.write('.');
      }
      grouped.write(digits[index]);
    }

    final sign = amount < 0 ? '-' : '';
    final separator = spaceAfterSymbol ? ' ' : '';
    return '${sign}Rp$separator$grouped';
  }
}
