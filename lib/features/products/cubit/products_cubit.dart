import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/data/product_data.dart';
import '../../../shared/services/supabase_service.dart';

class ProductsState {
  final List<Map<String, dynamic>> products;
  final String query;
  final bool isLoading;
  final bool isSaving;
  final Object? error;

  const ProductsState({
    this.products = const [],
    this.query = '',
    this.isLoading = true,
    this.isSaving = false,
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
    bool? isSaving,
    Object? error,
    bool clearError = false,
  }) {
    return ProductsState(
      products: products ?? this.products,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ProductsCubit extends Cubit<ProductsState> {
  ProductsCubit() : super(const ProductsState());

  bool _mutationInProgress = false;

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

  Future<bool> insertProduct(Map<String, dynamic> product) async {
    if (_mutationInProgress) return false;
    _mutationInProgress = true;
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final savedProduct = await SupabaseService.insertProduct(product);
      final products = [savedProduct, ...state.products];
      ProductData.replaceProducts(products);
      emit(state.copyWith(products: products, isSaving: false));
      return true;
    } catch (error) {
      emit(state.copyWith(isSaving: false, error: error));
      rethrow;
    } finally {
      _mutationInProgress = false;
    }
  }

  Future<bool> updateProduct(String id, Map<String, dynamic> product) async {
    if (_mutationInProgress) return false;
    _mutationInProgress = true;
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final savedProduct = await SupabaseService.updateProduct(id, product);
      final products = state.products
          .map(
            (existingProduct) => existingProduct['id'].toString() == id
                ? savedProduct
                : existingProduct,
          )
          .toList();
      ProductData.replaceProducts(products);
      emit(state.copyWith(products: products, isSaving: false));
      return true;
    } catch (error) {
      emit(state.copyWith(isSaving: false, error: error));
      rethrow;
    } finally {
      _mutationInProgress = false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    if (_mutationInProgress) return false;
    _mutationInProgress = true;
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await SupabaseService.deleteProduct(id);
      final products = state.products
          .where((product) => product['id'].toString() != id)
          .toList();
      ProductData.replaceProducts(products);
      emit(state.copyWith(products: products, isSaving: false));
      return true;
    } catch (error) {
      emit(state.copyWith(isSaving: false, error: error));
      rethrow;
    } finally {
      _mutationInProgress = false;
    }
  }
}
