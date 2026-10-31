int? calculateNetProfit(Iterable<Map<String, dynamic>> items) {
  var total = 0;
  var hasItems = false;
  for (final item in items) {
    hasItems = true;
    final unitPrice = item['unitPrice'];
    final unitCost = item['unitCost'];
    final quantity = item['quantity'];
    if (unitPrice is! num || unitCost is! num || quantity is! num) {
      return null;
    }
    total += (unitPrice.toInt() - unitCost.toInt()) * quantity.toInt();
  }
  return hasItems ? total : null;
}
