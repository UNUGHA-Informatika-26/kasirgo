import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/data/product_data.dart';
import '../../../shared/services/offline_store.dart';
import '../../../shared/services/supabase_service.dart';

class CartState {
  final List<Map<String, dynamic>> cartItems;
  final List<Map<String, dynamic>> products;
  final String searchQuery;

  const CartState({
    this.cartItems = const [],
    this.products = const [],
    this.searchQuery = '',
  });

  List<Map<String, dynamic>> get searchResults {
    final query = searchQuery.trim();
    if (query.isEmpty) return const [];
    final normalizedQuery = query.toLowerCase();
    return products.where((product) {
      final name = product['name'].toString().toLowerCase();
      final barcode = (product['barcode'] ?? '').toString().toLowerCase();
      return name.contains(normalizedQuery) ||
          barcode.contains(normalizedQuery);
    }).toList();
  }

  int get totalAmount => cartItems.fold<int>(
    0,
    (total, item) =>
        total + (item['unitPrice'] as int) * (item['quantity'] as int),
  );

  int get totalUnits => cartItems.fold<int>(
    0,
    (total, item) => total + (item['quantity'] as int),
  );

  CartState copyWith({
    List<Map<String, dynamic>>? cartItems,
    List<Map<String, dynamic>>? products,
    String? searchQuery,
  }) {
    return CartState(
      cartItems: cartItems ?? this.cartItems,
      products: products ?? this.products,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  String? get _userId =>
      SupabaseService.client.auth.currentUser?.id ?? OfflineStore.activeUserId;

  Future<void> restoreCart() async {
    final userId = _userId;
    if (userId == null) return;
    final savedCart = OfflineStore.getCart(userId);
    if (savedCart != null && savedCart.isNotEmpty) {
      emit(state.copyWith(cartItems: savedCart));
    }
  }

  Future<void> loadProducts() async {
    final products = await SupabaseService.fetchProducts();
    ProductData.replaceProducts(products);
    emit(state.copyWith(products: products));
  }

  void search(String query) => emit(state.copyWith(searchQuery: query));

  void addProduct(Map<String, dynamic> product) {
    final price = (product['price'] ?? product['unitPrice'] ?? 0) as int;
    final items = _copyItems(state.cartItems);
    final index = items.indexWhere((item) => item['id'] == product['id']);
    if (index >= 0) {
      items[index]['quantity'] = (items[index]['quantity'] as int) + 1;
    } else {
      items.add({
        'id': product['id'],
        'name': product['name'],
        'barcode': product['barcode'] ?? '',
        'unitPrice': price,
        'costPrice': (product['costPrice'] as num?)?.toInt() ?? 0,
        'quantity': 1,
      });
    }
    _emitAndPersist(items);
  }

  void addScannedProduct(Map<String, dynamic> product, int quantity) {
    final items = _copyItems(state.cartItems);
    final index = items.indexWhere((item) => item['id'] == product['id']);
    if (index >= 0) {
      items[index]['quantity'] = (items[index]['quantity'] as int) + quantity;
    } else {
      items.add({
        'id': product['id'],
        'name': product['name'],
        'barcode': product['barcode'],
        'unitPrice': product['unitPrice'],
        'costPrice': (product['costPrice'] as num?)?.toInt() ?? 0,
        'quantity': quantity,
      });
    }
    _emitAndPersist(items);
  }

  void increment(String productId) {
    final items = _copyItems(state.cartItems);
    final item = items.firstWhere((entry) => entry['id'] == productId);
    item['quantity'] = (item['quantity'] as int) + 1;
    _emitAndPersist(items);
  }

  void decrement(String productId) {
    final items = _copyItems(state.cartItems);
    final index = items.indexWhere((entry) => entry['id'] == productId);
    if (index < 0) return;
    final quantity = items[index]['quantity'] as int;
    if (quantity > 1) {
      items[index]['quantity'] = quantity - 1;
    } else {
      items.removeAt(index);
    }
    _emitAndPersist(items);
  }

  void clearCart() {
    _emitAndPersist([]);
    emit(state.copyWith(searchQuery: ''));
  }

  void _emitAndPersist(List<Map<String, dynamic>> items) {
    emit(state.copyWith(cartItems: items));
    final userId = _userId;
    if (userId != null) unawaited(OfflineStore.cacheCart(userId, items));
  }

  List<Map<String, dynamic>> _copyItems(List<Map<String, dynamic>> items) =>
      items.map((item) => Map<String, dynamic>.from(item)).toList();
}

class PaymentState {
  final String selectedMethod;
  final int cashReceived;

  const PaymentState({
    this.selectedMethod = 'Tunai',
    required this.cashReceived,
  });

  int changeFor(int total) {
    final change = cashReceived - total;
    return change > 0 ? change : 0;
  }

  PaymentState copyWith({String? selectedMethod, int? cashReceived}) {
    return PaymentState(
      selectedMethod: selectedMethod ?? this.selectedMethod,
      cashReceived: cashReceived ?? this.cashReceived,
    );
  }
}

class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit(int total)
    : super(PaymentState(cashReceived: total > 50000 ? total : 50000));

  void selectMethod(String method) =>
      emit(state.copyWith(selectedMethod: method));

  void setCash(int amount) => emit(state.copyWith(cashReceived: amount));
}
