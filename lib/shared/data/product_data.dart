class ProductData {
  static final List<Map<String, dynamic>> registeredProducts = [];

  static void replaceProducts(List<Map<String, dynamic>> products) {
    registeredProducts
      ..clear()
      ..addAll(products);
  }
}
