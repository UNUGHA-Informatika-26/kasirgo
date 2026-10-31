import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/user_data.dart';
import '../cubit/sync_cubit.dart';
import '../utils/profit_calculator.dart';
import 'offline_store.dart';

class SupabaseService {
  // Ganti dengan URL & Key dari Dashboard Supabase Anda (Project Settings -> API)
  static const String supabaseUrl = 'https://acfdfyafauuzghxlhffh.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFjZmRmeWFmYXV1emdoeGxoZmZoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI3Nzg5NTEsImV4cCI6MjEwODM1NDk1MX0.Uk_bVB58BFrXw11hpAFYksQ2nqQf8yanR6a-LuyHb5I';

  static SupabaseClient get client => Supabase.instance.client;
  static final SyncCubit syncCubit = SyncCubit();
  static const _uuid = Uuid();
  static StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;
  static bool _isSyncing = false;
  static Completer<void>? _syncCompleter;

  static String _requireUserId() {
    return client.auth.currentUser?.id ??
        OfflineStore.activeUserId ??
        (throw StateError('Silakan login untuk mengakses data.'));
  }

  // Inisialisasi Supabase saat aplikasi pertama kali berjalan
  static Future<void> init() async {
    await OfflineStore.init();
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
    _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(_syncPendingChanges());
      }
    });
  }

  // --- 1. FITUR AUTENTIKASI ---

  // Register Akun Baru & Simpan Profil Toko
  static Future<AuthResponse> registerUser({
    required String email,
    required String password,
    required String storeName,
    required String storeAddress,
    required String storePhone,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'store_name': storeName,
        'store_address': storeAddress,
        'store_phone': storePhone,
      },
    );

    final user = response.user;
    if (user != null && response.session != null) {
      await OfflineStore.setActiveUserId(user.id);
      await _saveProfile(
        userId: user.id,
        name: storeName,
        address: storeAddress,
        phone: storePhone,
        email: email,
      );
    }

    return response;
  }

  // Login Akun & Load Profil Toko
  static Future<AuthResponse> loginUser({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user != null) {
      await OfflineStore.setActiveUserId(user.id);
      await _loadUserProfile(user, email);
      unawaited(_syncPendingChanges());
    }

    return response;
  }

  static Future<bool> restoreSession() async {
    final user = client.auth.currentUser;
    if (user != null) {
      await OfflineStore.setActiveUserId(user.id);
      try {
        await _loadUserProfile(user, user.email ?? '');
      } catch (error) {
        syncCubit.setOffline(true);
        final cachedProfile = OfflineStore.profileFor(user.id);
        if (cachedProfile != null) {
          _applyProfile(cachedProfile);
        } else {
          final metadata = user.userMetadata ?? const <String, dynamic>{};
          _applyProfile({
            'store_name': metadata['store_name'] ?? '',
            'store_address': metadata['store_address'] ?? '',
            'store_phone': metadata['store_phone'] ?? '',
            'store_email': user.email ?? '',
          });
        }
        debugPrint('Memulihkan profil offline: $error');
      }
      unawaited(_syncPendingChanges());
      return true;
    }

    final cachedUserId = OfflineStore.activeUserId;
    final cachedProfile = cachedUserId == null
        ? null
        : OfflineStore.profileFor(cachedUserId);
    if (cachedUserId == null || cachedProfile == null) return false;

    syncCubit.setOffline(true);
    _applyProfile(cachedProfile);
    return true;
  }

  static Future<void> _loadUserProfile(User user, String email) async {
    final profile = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (profile != null) {
      final cached = {
        'store_name': profile['store_name'] ?? '',
        'store_address': profile['store_address'] ?? '',
        'store_phone': profile['store_phone'] ?? '',
        'store_email': profile['store_email'] ?? email,
      };
      await OfflineStore.cacheProfile(user.id, cached);
      _applyProfile(cached);
      syncCubit.setOffline(OfflineStore.pendingCount(user.id) > 0);
      return;
    }

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final storeName = metadata['store_name']?.toString() ?? '';
    final storeAddress = metadata['store_address']?.toString() ?? '';
    final storePhone = metadata['store_phone']?.toString() ?? '';
    if (storeName.isNotEmpty ||
        storeAddress.isNotEmpty ||
        storePhone.isNotEmpty) {
      await _saveProfile(
        userId: user.id,
        name: storeName,
        address: storeAddress,
        phone: storePhone,
        email: email,
      );
    } else {
      final cached = {
        'store_name': '',
        'store_address': '',
        'store_phone': '',
        'store_email': email,
      };
      await OfflineStore.cacheProfile(user.id, cached);
      _applyProfile(cached);
    }
  }

  static void _applyProfile(Map<String, dynamic> profile) {
    UserData.updateProfile(
      name: profile['store_name']?.toString() ?? '',
      address: profile['store_address']?.toString() ?? '',
      phone: profile['store_phone']?.toString() ?? '',
      email: profile['store_email']?.toString() ?? '',
    );
  }

  // Kirim Email Reset Password
  static Future<void> sendPasswordReset(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  // Logout Akun
  static Future<void> logout() async {
    await client.auth.signOut();
    await OfflineStore.setActiveUserId(null);
    UserData.updateProfile(name: '', address: '', phone: '', email: '');
  }

  // --- 2. FITUR DATA BARANG (PRODUCTS) ---

  // Ambil Semua Produk dari Database
  static Future<List<Map<String, dynamic>>> fetchProducts() async {
    final userId = _requireUserId();
    try {
      final response = await client
          .from('products')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      final products = List<Map<String, dynamic>>.from(response).map((product) {
        return {...product, 'costPrice': product['cost_price'] ?? 0};
      }).toList();
      final mergedProducts = _mergePendingProducts(userId, products);
      await OfflineStore.cacheProducts(userId, mergedProducts);
      syncCubit.setOffline(OfflineStore.pendingCount(userId) > 0);
      return mergedProducts;
    } catch (error) {
      syncCubit.setOffline(true);
      final cached = OfflineStore.productsFor(userId);
      if (cached == null) {
        throw StateError('Data produk belum tersedia offline: $error');
      }
      debugPrint('Memuat produk dari cache offline: $error');
      return cached;
    }
  }

  // Tambah Produk Baru ke Database
  static Future<Map<String, dynamic>> insertProduct(
    Map<String, dynamic> product,
  ) async {
    final userId = _requireUserId();
    final record = _productRecord(userId, {
      ...product,
      'id': product['id'] ?? _uuid.v4(),
    });
    final cachedProduct = {...record, 'costPrice': record['cost_price']};
    await OfflineStore.putProduct(userId, cachedProduct);
    await OfflineStore.enqueue(userId, 'product_upsert', record);
    try {
      await _syncPendingChanges(throwOnFailure: true);
    } catch (error) {
      throw StateError(
        'Produk sudah tersimpan di perangkat, tetapi gagal dikirim ke '
        'Supabase: $error',
      );
    }
    syncCubit.productsChanged();
    return cachedProduct;
  }

  // Update Produk di Database
  static Future<Map<String, dynamic>> updateProduct(
    String id,
    Map<String, dynamic> product,
  ) async {
    final userId = _requireUserId();
    final record = _productRecord(userId, {...product, 'id': id});
    final cachedProduct = {...record, 'costPrice': record['cost_price']};
    await OfflineStore.putProduct(userId, cachedProduct);
    await OfflineStore.enqueue(userId, 'product_upsert', record);
    try {
      await _syncPendingChanges(throwOnFailure: true);
    } catch (error) {
      throw StateError(
        'Perubahan produk tersimpan di perangkat, tetapi gagal dikirim ke '
        'Supabase: $error',
      );
    }
    syncCubit.productsChanged();
    return cachedProduct;
  }

  // Hapus Produk dari Database
  static Future<void> deleteProduct(String id) async {
    final userId = _requireUserId();
    await OfflineStore.removeProduct(userId, id);
    await OfflineStore.enqueue(userId, 'product_delete', {'id': id});
    await _syncPendingChanges();
    syncCubit.productsChanged();
  }

  // --- 3. FITUR TRANSAKSI ---

  // Simpan Transaksi Selesai
  static Future<void> saveTransaction({
    required String trxId,
    required DateTime createdAt,
    required int totalAmount,
    required String paymentMethod,
    required int cashReceived,
    required int changeAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    final userId = _requireUserId();

    final itemsToInsert = items.map((item) {
      final qty = item['quantity'] as int;
      final price = item['unitPrice'] as int;
      final costPrice = (item['costPrice'] as num?)?.toInt();
      if (costPrice == null) {
        throw StateError('Harga modal produk ${item['name']} tidak tersedia.');
      }
      return {
        'transaction_id': trxId,
        'product_name': item['name'],
        'quantity': qty,
        'unit_price': price,
        'unit_cost': costPrice,
        'subtotal': qty * price,
      };
    }).toList();

    final transaction = {
      'id': trxId,
      'user_id': userId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'cash_received': cashReceived,
      'change_amount': changeAmount,
      'transaction_items': itemsToInsert,
    };
    await OfflineStore.cacheTransaction(userId, transaction);
    await OfflineStore.enqueue(userId, 'transaction', transaction);
    syncCubit.transactionsChanged();
    await _syncPendingChanges();
  }

  // Ambil Riwayat Transaksi
  static Future<List<Map<String, dynamic>>> fetchTransactions() async {
    final userId = _requireUserId();
    List<Map<String, dynamic>> transactions;
    try {
      final response = await client
          .from('transactions')
          .select('*, transaction_items(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      transactions = List<Map<String, dynamic>>.from(response);
      for (final transaction in transactions) {
        await OfflineStore.cacheTransaction(userId, transaction);
      }
      syncCubit.setOffline(OfflineStore.pendingCount(userId) > 0);
    } catch (error) {
      syncCubit.setOffline(true);
      transactions = OfflineStore.transactionsFor(userId);
      if (transactions.isEmpty) {
        throw StateError('Riwayat transaksi belum tersedia offline: $error');
      }
      debugPrint('Memuat transaksi dari cache offline: $error');
    }

    final pendingTransactionIds = OfflineStore.pendingFor(userId)
        .where((operation) => operation['type'] == 'transaction')
        .map((operation) => (operation['payload'] as Map)['id'].toString())
        .toSet();
    final merged =
        {
          for (final transaction in transactions)
            transaction['id'].toString(): transaction,
          for (final transaction in OfflineStore.transactionsFor(userId))
            if (pendingTransactionIds.contains(transaction['id'].toString()))
              transaction['id'].toString(): transaction,
        }.values.toList()..sort(
          (a, b) =>
              DateTime.parse(b['created_at'].toString())
                  .compareTo(DateTime.parse(a['created_at'].toString())),
        );

    return merged.map((transaction) {
      final createdAt = _transactionDateTime(transaction);
      final items =
          (transaction['transaction_items'] as List<dynamic>? ?? const [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .map((item) {
                return {
                  'name': item['product_name'],
                  'quantity': item['quantity'],
                  'unitPrice': item['unit_price'],
                  'unitCost': item['unit_cost'] == null
                      ? null
                      : (item['unit_cost'] as num).toInt(),
                  'subtotal': item['subtotal'],
                };
              })
              .toList();
      final profit = calculateNetProfit(items);
      return {
        ...transaction,
        'dateTime': createdAt,
        'date': '${createdAt.day}/${createdAt.month}/${createdAt.year}',
        'time':
            '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
        'items': items.fold<int>(
          0,
          (total, item) => total + (item['quantity'] as int),
        ),
        'amountInt': transaction['total_amount'],
        'profitInt': profit,
        'method': transaction['payment_method'],
        'cashReceived': transaction['cash_received'],
        'kembalian': transaction['change_amount'],
        'cartItems': items,
      };
    }).toList();
  }

  static DateTime _transactionDateTime(Map<String, dynamic> transaction) {
    final id = transaction['id']?.toString();
    final timestamp = id != null && id.startsWith('TRX-')
        ? int.tryParse(id.split('-').last)
        : null;

    if (timestamp != null) {
      return DateTime.fromMicrosecondsSinceEpoch(timestamp);
    }

    return DateTime.parse(transaction['created_at'].toString()).toLocal();
  }

  static Future<void> updateProfile({
    required String name,
    required String address,
    required String phone,
    required String email,
  }) async {
    final userId = _requireUserId();

    // Perbarui email login di Supabase Auth jika email berubah
    final currentUser = client.auth.currentUser;
    if (currentUser != null && currentUser.email != email) {
      await client.auth.updateUser(UserAttributes(email: email));
    }

    final profile = {
      'store_name': name,
      'store_address': address,
      'store_phone': phone,
      'store_email': email,
    };
    await OfflineStore.cacheProfile(userId, profile);
    _applyProfile(profile);
    await OfflineStore.enqueue(userId, 'profile_upsert', {
      'id': userId,
      ...profile,
    });
    await _syncPendingChanges();
  }

  static Future<void> _saveProfile({
    required String userId,
    required String name,
    required String address,
    required String phone,
    required String email,
  }) async {
    await client.from('profiles').upsert({
      'id': userId,
      'store_name': name,
      'store_address': address,
      'store_phone': phone,
      'store_email': email,
    });
    await OfflineStore.cacheProfile(userId, {
      'store_name': name,
      'store_address': address,
      'store_phone': phone,
      'store_email': email,
    });
    UserData.updateProfile(
      name: name,
      address: address,
      phone: phone,
      email: email,
    );
  }

  static Map<String, dynamic> _productRecord(
    String userId,
    Map<String, dynamic> product,
  ) {
    return {
      'id': product['id'].toString(),
      'user_id': userId,
      'name': product['name'],
      'barcode': product['barcode'],
      'cost_price': product['costPrice'] ?? product['cost_price'] ?? 0,
      'price': product['price'],
      'stock': product['stock'],
      'status': product['status'] ?? 'tersedia',
    };
  }

  static List<Map<String, dynamic>> _mergePendingProducts(
    String userId,
    List<Map<String, dynamic>> products,
  ) {
    final byId = {
      for (final product in products) product['id'].toString(): product,
    };
    for (final operation in OfflineStore.pendingFor(userId)) {
      final payload = Map<String, dynamic>.from(operation['payload'] as Map);
      if (operation['type'] == 'product_upsert') {
        byId[payload['id'].toString()] = {
          ...payload,
          'costPrice': payload['cost_price'] ?? 0,
        };
      } else if (operation['type'] == 'product_delete') {
        byId.remove(payload['id'].toString());
      }
    }
    return byId.values.toList();
  }

  static Future<void> _syncPendingChanges({bool throwOnFailure = false}) async {
    final user = client.auth.currentUser;
    if (user == null) {
      if (throwOnFailure) {
        throw StateError('Tidak ada sesi login Supabase yang aktif.');
      }
      return;
    }
    if (_isSyncing) {
      if (!throwOnFailure) return;
      await _syncCompleter!.future;
      return _syncPendingChanges(throwOnFailure: true);
    }

    _isSyncing = true;
    final completer = Completer<void>();
    _syncCompleter = completer;
    try {
      final pending = OfflineStore.pendingFor(user.id);
      if (pending.isEmpty) {
        syncCubit.setOffline(false);
        return;
      }
      for (final operation in pending) {
        final payload = Map<String, dynamic>.from(operation['payload'] as Map);
        switch (operation['type']) {
          case 'product_upsert':
            await client.from('products').upsert(payload, onConflict: 'id');
            break;
          case 'product_delete':
            await client
                .from('products')
                .delete()
                .eq('id', payload['id'])
                .eq('user_id', user.id);
            break;
          case 'profile_upsert':
            await client.from('profiles').upsert(payload);
            break;
          case 'transaction':
            final items = (payload['transaction_items'] as List)
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();
            final header = Map<String, dynamic>.from(payload)
              ..remove('transaction_items');
            await client.from('transactions').upsert(header, onConflict: 'id');
            await client
                .from('transaction_items')
                .delete()
                .eq('transaction_id', payload['id']);
            await client.from('transaction_items').insert(items);
            break;
          default:
            throw StateError('Jenis sinkronisasi tidak dikenali.');
        }
        await OfflineStore.removeQueueItem(operation['id'] as String);
      }
      syncCubit.setOffline(false);
      if (pending.isNotEmpty) {
        syncCubit
          ..productsChanged()
          ..transactionsChanged();
      }
    } catch (error) {
      syncCubit.setOffline(true);
      debugPrint('Sinkronisasi offline tertunda: $error');
      if (throwOnFailure) rethrow;
    } finally {
      _isSyncing = false;
      _syncCompleter = null;
      completer.complete();
    }
  }
}
