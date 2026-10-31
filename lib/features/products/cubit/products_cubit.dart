import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/data/product_data.dart';
import '../../../shared/services/supabase_service.dart';

class ProductsState {
  final List<Map<String, dynamic>> products;
  final String query;
  final bool isLoading;
  final Object? error;

  const ProductsState({
    this.products = const [],
    this.query = '',
    this.isLoading = true,
    this.error,
  });

  List<Map<String, dynamic>> get filteredProducts {
    final normalizedQuery = query.toLowerCase();
    return products.where((product) {
      final name = product['name'].toString().toLowerCase();
      final barcode = (product['barcode'] ?? '').toString().toLowerCase();
      return name.contains(normalizedQuery) ||
          barcode.contains(normalizedQuery);
    }).toList();
  }

  ProductsState copyWith({
    List<Map<String, dynamic>>? products,
    String? query,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return ProductsState(
      products: products ?? this.products,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ProductsCubit extends Cubit<ProductsState> {
  ProductsCubit() : super(const ProductsState());

  Future<void> loadProducts() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final products = await SupabaseService.fetchProducts();
      ProductData.replaceProducts(products);
      emit(state.copyWith(products: products, isLoading: false));
    } catch (error) {
      emit(state.copyWith(isLoading: false, error: error));
      rethrow;
    }
  }

  void search(String query) => emit(state.copyWith(query: query));

  Future<void> insertProduct(Map<String, dynamic> product) async {
    await SupabaseService.insertProduct(product);
    await loadProducts();
  }

  Future<void> updateProduct(String id, Map<String, dynamic> product) async {
    await SupabaseService.updateProduct(id, product);
    await loadProducts();
  }

  Future<void> deleteProduct(String id) async {
    await SupabaseService.deleteProduct(id);
    final products = state.products
        .where((product) => product['id'].toString() != id)
        .toList();
    ProductData.replaceProducts(products);
    emit(state.copyWith(products: products));
  }
}
