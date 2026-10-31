import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class OfflineStore {
  static const _boxName = 'kasirgo_offline';
  static const _uuid = Uuid();
  static Box<dynamic>? _box;

  static Box<dynamic> get _data {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('Penyimpanan offline belum diinisialisasi.');
    }
    return box;
  }

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  static String? get activeUserId => _data.get('active_user_id') as String?;

  static Future<void> setActiveUserId(String? userId) async {
    if (userId == null) {
      await _data.delete('active_user_id');
    } else {
      await _data.put('active_user_id', userId);
    }
  }

  static Future<void> cacheProfile(
    String userId,
    Map<String, dynamic> profile,
  ) async {
    await _data.put('profile:$userId', Map<String, dynamic>.from(profile));
  }

  static Map<String, dynamic>? profileFor(String userId) {
    final value = _data.get('profile:$userId');
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  static Future<void> cacheCart(
    String userId,
    List<Map<String, dynamic>> items,
  ) async {
    await _data.put(
      'cart:$userId',
      items.map((item) => Map<String, dynamic>.from(item)).toList(),
    );
  }

  static List<Map<String, dynamic>>? getCart(String userId) {
    final value = _data.get('cart:$userId');
    if (value == null) return null;
    return (value as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<void> cacheProducts(
    String userId,
    List<Map<String, dynamic>> products,
  ) async {
    final prefix = 'product:$userId:';
    final previousKeys = _data.keys
        .where((key) => key is String && key.startsWith(prefix))
        .toList();
    await _data.deleteAll(previousKeys);
    for (final product in products) {
      final id = product['id']?.toString();
      if (id != null) {
        await _data.put('$prefix$id', Map<String, dynamic>.from(product));
      }
    }
    await _data.put('products_cached:$userId', true);
  }

  static List<Map<String, dynamic>>? productsFor(String userId) {
    if (_data.get('products_cached:$userId') != true) return null;
    final prefix = 'product:$userId:';
    return _data.keys
        .where((key) => key is String && key.startsWith(prefix))
        .map((key) => Map<String, dynamic>.from(_data.get(key) as Map))
        .toList();
  }

  static Future<void> putProduct(
    String userId,
    Map<String, dynamic> product,
  ) async {
    await _data.put(
      'product:$userId:${product['id']}',
      Map<String, dynamic>.from(product),
    );
    await _data.put('products_cached:$userId', true);
  }

  static Future<void> removeProduct(String userId, String productId) async {
    await _data.delete('product:$userId:$productId');
    await _data.put('products_cached:$userId', true);
  }

  static Future<void> cacheTransaction(
    String userId,
    Map<String, dynamic> transaction,
  ) async {
    await _data.put(
      'transaction:$userId:${transaction['id']}',
      Map<String, dynamic>.from(transaction),
    );
  }

  static List<Map<String, dynamic>> transactionsFor(String userId) {
    final prefix = 'transaction:$userId:';
    return _data.keys
        .where((key) => key is String && key.startsWith(prefix))
        .map((key) => Map<String, dynamic>.from(_data.get(key) as Map))
        .toList();
  }

  static Future<void> enqueue(
    String userId,
    String type,
    Map<String, dynamic> payload,
  ) async {
    final id = _uuid.v4();
    await _data.put('queue:$id', {
      'id': id,
      'userId': userId,
      'type': type,
      'payload': Map<String, dynamic>.from(payload),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static List<Map<String, dynamic>> pendingFor(String userId) {
    return _data.keys
        .where((key) => key is String && key.startsWith('queue:'))
        .map((key) => Map<String, dynamic>.from(_data.get(key) as Map))
        .where((item) => item['userId'] == userId)
        .toList()
      ..sort(
        (a, b) =>
            (a['createdAt'] as String).compareTo(b['createdAt'] as String),
      );
  }

  static Future<void> removeQueueItem(String id) async {
    await _data.delete('queue:$id');
  }

  static int pendingCount(String userId) => pendingFor(userId).length;
}
