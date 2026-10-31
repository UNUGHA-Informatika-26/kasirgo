import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/data/user_data.dart';
import '../../../shared/cubit/sync_cubit.dart';
import '../../../shared/printer/bluetooth_printer_cubit.dart';
import '../../../shared/printer/bluetooth_printer_dialog.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/utils/receipt_pdf_helper.dart';
import '../../../shared/widgets/barcode_scanner_screen.dart';
import '../cubit/cart_cubit.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final TextEditingController _searchController = TextEditingController();
  final CartCubit _cartCubit = CartCubit();
  StreamSubscription<SyncState>? _syncSubscription;
  late int _lastProductsRevision;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _lastProductsRevision = SupabaseService.syncCubit.state.productsRevision;
    _syncSubscription = SupabaseService.syncCubit.stream.listen((state) {
      if (state.productsRevision != _lastProductsRevision) {
        _lastProductsRevision = state.productsRevision;
        _onProductsChanged();
      }
    });
    _loadData();
  }

  Future<void> _loadData() async {
    await _cartCubit.restoreCart();
    await _loadProducts();
  }

  void _onProductsChanged() {
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      await _cartCubit.loadProducts();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat produk untuk kasir: $error')),
      );
    }
  }

  void _onSearchChanged() {
    _cartCubit.search(_searchController.text.toLowerCase().trim());
  }

  @override
  void dispose() {
    _searchController.dispose();
    unawaited(_syncSubscription?.cancel());
    _cartCubit.close();
    super.dispose();
  }

  List<Map<String, dynamic>> get _cartItems => _cartCubit.state.cartItems;
  List<Map<String, dynamic>> get _searchResults =>
      _cartCubit.state.searchResults;
  String get _searchQuery => _cartCubit.state.searchQuery;

  // Format integer ke Rupiah (misal 32500 -> Rp32.500)
  String _formatRupiah(int number) => CurrencyFormatter.formatRupiah(number);

  // Menghitung Total Pembayaran
  int get _totalBayar {
    return _cartCubit.state.totalAmount;
  }

  // Total jenis item unik
  int get _totalUniqueItems => _cartItems.length;

  // Total unit/pcs barang terjual
  int get _totalUnitsCount {
    return _cartCubit.state.totalUnits;
  }

  // Tambah Barang dari Hasil Pencarian ke Keranjang
  void _addProductToCart(Map<String, dynamic> product) {
    final added = _cartCubit.addProduct(product);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? '${product['name']} berhasil ditambahkan ke keranjang!'
              : (product['stock'] as num? ?? 0) <= 0
              ? 'Stok ${product['name']} habis.'
              : 'Jumlah ${product['name']} di keranjang sudah mencapai stok.',
        ),
        backgroundColor: added
            ? const Color(0xFF10B981)
            : const Color(0xFFDC2626),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // Tambah Kuantitas di Keranjang
  void _incrementQuantity(Map<String, dynamic> item) {
    if (!_cartCubit.increment(item['id'].toString())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok ${item['name']} tidak mencukupi.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  // Kurangi Kuantitas di Keranjang
  void _decrementQuantity(Map<String, dynamic> item) {
    _cartCubit.decrement(item['id'].toString());
  }

  // Tambah barang dari hasil Scan Barcode ke Keranjang
  void _addItemFromScan(Map<String, dynamic> scannedProduct, int qty) {
    final added = _cartCubit.addScannedProduct(scannedProduct, qty);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? '${scannedProduct['name']} ($qty item) masuk keranjang!'
              : 'Stok ${scannedProduct['name']} tidak mencukupi.',
        ),
        backgroundColor: added
            ? const Color(0xFF10B981)
            : const Color(0xFFDC2626),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Membuka Fullscreen Barcode Scanner Modal
  void _openBarcodeScanner() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Scan Barcode',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return BarcodeScannerScreen(onAddProductToCart: _addItemFromScan);
      },
    );
  }

  // Mengubah Alur "TRANSAKSI SELESAI" -> Buka Modal Bottom Sheet Pembayaran Dulu
  void _openPaymentModal() {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keranjang masih kosong!'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return _PaymentModalSheet(
          totalBayar: _totalBayar,
          totalItems: _totalUnitsCount,
          formatRupiah: _formatRupiah,
          onPaymentCompleted: (method, cashReceived, kembalian) async {
            final now = DateTime.now();
            final trxId =
                'TRX-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.microsecondsSinceEpoch}';
            try {
              await SupabaseService.saveTransaction(
                trxId: trxId,
                createdAt: now,
                totalAmount: _totalBayar,
                paymentMethod: method,
                cashReceived: cashReceived,
                changeAmount: kembalian,
                items: List<Map<String, dynamic>>.from(
                  _cartItems.map((item) => Map<String, dynamic>.from(item)),
                ),
              );
              if (!mounted) return;
              _showReceiptPage(
                trxId: trxId,
                createdAt: now,
                method: method,
                cashReceived: cashReceived,
                kembalian: kembalian,
              );
            } catch (error) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Transaksi gagal disimpan: $error')),
              );
            }
          },
        );
      },
    );
  }

  // Menampilkan Halaman Struk Transaksi Selesai (Fullscreen)
  void _showReceiptPage({
    required String trxId,
    required DateTime createdAt,
    required String method,
    required int cashReceived,
    required int kembalian,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Transaksi Selesai',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return _ReceiptPage(
          trxId: trxId,
          createdAt: createdAt,
          totalBayar: _totalBayar,
          uniqueItemCount: _totalUniqueItems,
          totalUnitsCount: _totalUnitsCount,
          paymentMethod: method,
          cashReceived: cashReceived,
          kembalian: kembalian,
          cartItems: List.from(_cartItems),
          formatRupiah: _formatRupiah,
          onNewTransaction: () {
            _cartCubit.clearCart();
            _searchController.clear();
            Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563EB);
    const textDark = Color(0xFF0F172A);
    const textGrey = Color(0xFF64748B);
    const successGreen = Color(0xFF10B981);
    const borderColor = Color(0xFFE2E8F0);

    return BlocBuilder<CartCubit, CartState>(
      bloc: _cartCubit,
      builder: (context, state) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // 1. Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 20.0,
                  bottom: 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Title & Subtitle
                    const Text(
                      'Kasir',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Transaksi cepat dan efisien',
                      style: TextStyle(fontSize: 13, color: textGrey),
                    ),
                    const SizedBox(height: 16),

                    // SCAN BARCODE Button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _openBarcodeScanner,
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        label: const Text(
                          'SCAN BARCODE',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Search Input Field (Mencari di Data Barang)
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 14, color: textDark),
                      decoration: InputDecoration(
                        hintText: 'Cari nama barang manual',
                        hintStyle: const TextStyle(
                          color: textGrey,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: textGrey,
                          size: 22,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: borderColor,
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: primaryBlue,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // TAMPILAN 1: BILA SEDANG MENCARI BARANG MANUALLY (_searchQuery.isNotEmpty)
                    if (_searchQuery.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Hasil Pencarian Barang',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          Text(
                            '${_searchResults.length} ditemukan',
                            style: const TextStyle(
                              fontSize: 13,
                              color: primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      _searchResults.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text(
                                  'Barang tidak ditemukan di Data Barang',
                                  style: TextStyle(
                                    color: textGrey,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _searchResults.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final product = _searchResults[index];
                                final price = product['price'] as int;
                                final stock =
                                    (product['stock'] as num?)?.toInt() ?? 0;
                                final quantityInCart = _cartItems
                                    .where(
                                      (item) => item['id'] == product['id'],
                                    )
                                    .fold<int>(
                                      0,
                                      (total, item) =>
                                          total + (item['quantity'] as int),
                                    );
                                final canAdd = quantityInCart < stock;

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFF1F5F9),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // 1. Nama Barang
                                            Text(
                                              product['name'],
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: textDark,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            // 2. Kode Barang / Barcode
                                            Text(
                                              product['barcode'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: textGrey,
                                              ),
                                            ),
                                            if (stock > 0 && stock <= 5)
                                              Text(
                                                'Stok menipis • $stock tersisa',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFFD97706),
                                                ),
                                              ),
                                            const SizedBox(height: 2),
                                            // 3. Harga Barang
                                            Text(
                                              '@ ${_formatRupiah(price)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: primaryBlue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryBlue,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        onPressed: canAdd
                                            ? () => _addProductToCart(product)
                                            : null,
                                        icon: const Icon(
                                          Icons.add_rounded,
                                          size: 18,
                                        ),
                                        label: Text(
                                          stock <= 0
                                              ? 'Habis'
                                              : canAdd
                                              ? 'Tambah'
                                              : 'Stok penuh',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 24),
                    ],

                    // TAMPILAN 2: DAFTAR KERANJANG
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Keranjang Belanja',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        Text(
                          '${_cartItems.length} item',
                          style: const TextStyle(fontSize: 13, color: textGrey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _cartItems.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text(
                                'Keranjang belanja masih kosong',
                                style: TextStyle(color: textGrey, fontSize: 14),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _cartItems.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _cartItems[index];
                              final stock =
                                  (item['stock'] as num?)?.toInt() ?? 0;
                              final canIncrement =
                                  (item['quantity'] as int) < stock;
                              final itemTotal =
                                  (item['unitPrice'] as int) *
                                  (item['quantity'] as int);

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFF1F5F9),
                                    width: 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x05000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Left Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // 1. Nama Produk
                                          Text(
                                            item['name'],
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: textDark,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          // 2. Kode Barang / Barcode
                                          Text(
                                            item['barcode'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: textGrey,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          // 3. Harga Barang
                                          Text(
                                            '@ ${_formatRupiah(item['unitPrice'] as int)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: textGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Middle Quantity Stepper Controls
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          // Minus Button
                                          GestureDetector(
                                            onTap: () =>
                                                _decrementQuantity(item),
                                            child: Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFE2E8F0,
                                                  ),
                                                ),
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.remove_rounded,
                                                  size: 16,
                                                  color: textDark,
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Quantity Text
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            child: Text(
                                              '${item['quantity']}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: textDark,
                                              ),
                                            ),
                                          ),
                                          // Plus Button
                                          GestureDetector(
                                            onTap: canIncrement
                                                ? () =>
                                                      _incrementQuantity(item)
                                                : null,
                                            child: Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: canIncrement
                                                    ? primaryBlue
                                                    : const Color(0xFF94A3B8),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.add_rounded,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Right Total Price per Item
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        _formatRupiah(itemTotal),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: textDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),

            // 2. Fixed Total Bayar & TRANSAKSI SELESAI Container di Paling Bawah
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 14.0,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Total Bayar Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Bayar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      Text(
                        _formatRupiah(_totalBayar),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // TRANSAKSI SELESAI Button (Green)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _openPaymentModal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: successGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'TRANSAKSI SELESAI',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modal Sheet Pembayaran (Muncul setelah klik "TRANSAKSI SELESAI")
class _PaymentModalSheet extends StatefulWidget {
  final int totalBayar;
  final int totalItems;
  final String Function(int) formatRupiah;
  final Future<void> Function(String method, int cashReceived, int kembalian)
  onPaymentCompleted;

  const _PaymentModalSheet({
    required this.totalBayar,
    required this.totalItems,
    required this.formatRupiah,
    required this.onPaymentCompleted,
  });

  @override
  State<_PaymentModalSheet> createState() => _PaymentModalSheetState();
}

class _PaymentModalSheetState extends State<_PaymentModalSheet> {
  late TextEditingController _cashController;
  late final PaymentCubit _paymentCubit;

  @override
  void initState() {
    super.initState();
    _paymentCubit = PaymentCubit(widget.totalBayar);
    _cashController = TextEditingController(
      text: _paymentCubit.state.cashReceived.toString(),
    );
  }

  @override
  void dispose() {
    _cashController.dispose();
    _paymentCubit.close();
    super.dispose();
  }

  void _setCash(int amount) {
    _paymentCubit.setCash(amount);
    _cashController.text = amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    const textDark = Color(0xFF0F172A);
    const textGrey = Color(0xFF64748B);
    const primaryBlue = Color(0xFF2563EB);
    const successGreen = Color(0xFF10B981);
    const borderColor = Color(0xFFE2E8F0);

    return BlocBuilder<PaymentCubit, PaymentState>(
      bloc: _paymentCubit,
      builder: (context, paymentState) => Padding(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            const Text(
              'Pembayaran',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle Total Bayar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total bayar • ${widget.totalItems} item',
                  style: const TextStyle(fontSize: 13, color: textGrey),
                ),
                Text(
                  widget.formatRupiah(widget.totalBayar),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Metode Pembayaran Selector Tabs
            Row(
              children: [
                _buildMethodTab(
                  'Tunai',
                  isSelected: paymentState.selectedMethod == 'Tunai',
                  hasCheck: true,
                ),
                const SizedBox(width: 8),
                _buildMethodTab(
                  'QRIS',
                  isSelected: paymentState.selectedMethod == 'QRIS',
                ),
                const SizedBox(width: 8),
                _buildMethodTab(
                  'Transfer',
                  isSelected: paymentState.selectedMethod == 'Transfer',
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (paymentState.selectedMethod == 'Tunai') ...[
              // Field Uang Diterima
              const Text(
                'Uang diterima',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: primaryBlue,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (val) {
                  _paymentCubit.setCash(
                    int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
                  );
                },
              ),
              const SizedBox(height: 12),

              // Quick Cash Chips (Uang pas, Rp50.000, Rp100.000)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _setCash(widget.totalBayar),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: const Center(
                          child: Text(
                            'Uang pas',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _setCash(50000),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: const Center(
                          child: Text(
                            'Rp50.000',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _setCash(100000),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: const Center(
                          child: Text(
                            'Rp100.000',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Card Kembalian
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDCFCE7)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kembalian',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF15803D),
                      ),
                    ),
                    Text(
                      widget.formatRupiah(
                        paymentState.changeFor(widget.totalBayar),
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Tampilan QRIS / Transfer
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      paymentState.selectedMethod == 'QRIS'
                          ? Icons.qr_code_2_rounded
                          : Icons.account_balance_rounded,
                      size: 48,
                      color: primaryBlue,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pembayaran via ${paymentState.selectedMethod}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pastikan pelanggan telah melakukan transfer/scan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: textGrey),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Button Selesaikan Pembayaran
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: successGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final method = paymentState.selectedMethod;
                  final cashReceived = method == 'Tunai'
                      ? paymentState.cashReceived
                      : widget.totalBayar;
                  final change = method == 'Tunai'
                      ? paymentState.changeFor(widget.totalBayar)
                      : 0;
                  Navigator.pop(context);
                  await widget.onPaymentCompleted(method, cashReceived, change);
                },
                child: const Text(
                  'Selesaikan Pembayaran',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodTab(
    String name, {
    required bool isSelected,
    bool hasCheck = false,
  }) {
    const primaryBlue = Color(0xFF2563EB);
    const selectedBg = Color(0xFFEFF6FF);
    const borderColor = Color(0xFFE2E8F0);
    const textDark = Color(0xFF0F172A);

    return Expanded(
      child: GestureDetector(
        onTap: () => _paymentCubit.selectMethod(name),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primaryBlue : borderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected && hasCheck) ...[
                const Icon(Icons.check_rounded, size: 16, color: primaryBlue),
                const SizedBox(width: 4),
              ],
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? primaryBlue : textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Fullscreen Receipt / Halaman Struk Transaksi Selesai
class _ReceiptPage extends StatelessWidget {
  final String trxId;
  final DateTime createdAt;
  final int totalBayar;
  final int uniqueItemCount;
  final int totalUnitsCount;
  final String paymentMethod;
  final int cashReceived;
  final int kembalian;
  final List<Map<String, dynamic>> cartItems;
  final String Function(int) formatRupiah;
  final VoidCallback onNewTransaction;

  const _ReceiptPage({
    required this.trxId,
    required this.createdAt,
    required this.totalBayar,
    required this.uniqueItemCount,
    required this.totalUnitsCount,
    required this.paymentMethod,
    required this.cashReceived,
    required this.kembalian,
    required this.cartItems,
    required this.formatRupiah,
    required this.onNewTransaction,
  });

  void _openReceiptPreview(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Pratinjau Struk',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return _ReceiptPreviewScreen(
          trxId: trxId,
          createdAt: createdAt,
          totalBayar: totalBayar,
          paymentMethod: paymentMethod,
          cashReceived: cashReceived,
          kembalian: kembalian,
          cartItems: cartItems,
          formatRupiah: formatRupiah,
          onCloseAndReset: onNewTransaction,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const textDark = Color(0xFF0F172A);
    const textGrey = Color(0xFF64748B);
    const primaryBlue = Color(0xFF2563EB);
    const successGreen = Color(0xFF10B981);
    const softGreenBg = Color(0xFFF0FDF4);
    const borderColor = Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Transaksi selesai',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
              ),
            ),

            // Scrollable Receipt Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // Green Success Circle Icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: softGreenBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle_outline_rounded,
                          color: successGreen,
                          size: 42,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title & Subtitle
                    const Text(
                      'Transaksi berhasil',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pembayaran $paymentMethod telah diterima.',
                      style: const TextStyle(fontSize: 13, color: textGrey),
                    ),
                    const SizedBox(height: 24),

                    // Receipt Details Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF1F5F9),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x05000000),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Transaction ID
                          Text(
                            trxId,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${createdAt.day}/${createdAt.month}/${createdAt.year} • ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: textGrey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 16),

                          // Row Total Bayar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total bayar',
                                style: TextStyle(fontSize: 13, color: textGrey),
                              ),
                              Text(
                                formatRupiah(totalBayar),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Row Metode Pembayaran
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Metode pembayaran',
                                style: TextStyle(fontSize: 13, color: textGrey),
                              ),
                              Text(
                                paymentMethod,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Row Uang Diterima
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Uang diterima',
                                style: TextStyle(fontSize: 13, color: textGrey),
                              ),
                              Text(
                                formatRupiah(cashReceived),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Row Kembalian
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Kembalian',
                                style: TextStyle(fontSize: 13, color: textGrey),
                              ),
                              Text(
                                formatRupiah(kembalian),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Items & Units Caption
                    Text(
                      '$uniqueItemCount item • $totalUnitsCount barang terjual',
                      style: const TextStyle(fontSize: 12, color: textGrey),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons (Cetak & Pratinjau)
                    Row(
                      children: [
                        // Tombol Cetak Langsung ke Printer Thermal
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textDark,
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: borderColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                await BluetoothPrinterDialog.show(
                                  context,
                                  receipt: ReceiptPrintData(
                                    transactionId: trxId,
                                    totalAmount: totalBayar,
                                    paymentMethod: paymentMethod,
                                    cashReceived: cashReceived,
                                    changeAmount: kembalian,
                                    items: cartItems,
                                    createdAt: createdAt,
                                    storeName: UserData.storeName,
                                    storeAddress: UserData.storeAddress,
                                    storePhone: UserData.storePhone,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.print_outlined, size: 18),
                              label: const Text(
                                'Cetak',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Tombol Pratinjau (Membuka Pratinjau Struk Thermal 58mm)
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textDark,
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: borderColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _openReceiptPreview(context),
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 18,
                              ),
                              label: const Text(
                                'Pratinjau',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Button Primary "Transaksi Baru"
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: onNewTransaction,
                        child: const Text(
                          'Transaksi Baru',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Fullscreen Pratinjau Struk (Thermal 58mm)
class _ReceiptPreviewScreen extends StatelessWidget {
  final String trxId;
  final DateTime createdAt;
  final int totalBayar;
  final String paymentMethod;
  final int cashReceived;
  final int kembalian;
  final List<Map<String, dynamic>> cartItems;
  final String Function(int) formatRupiah;
  final VoidCallback onCloseAndReset;

  const _ReceiptPreviewScreen({
    required this.trxId,
    required this.createdAt,
    required this.totalBayar,
    required this.paymentMethod,
    required this.cashReceived,
    required this.kembalian,
    required this.cartItems,
    required this.formatRupiah,
    required this.onCloseAndReset,
  });

  @override
  Widget build(BuildContext context) {
    const textDark = Color(0xFF0F172A);
    const textGrey = Color(0xFF64748B);
    const primaryBlue = Color(0xFF2563EB);
    const borderColor = Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Pratinjau struk',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Struk thermal • 58 mm',
                    style: TextStyle(fontSize: 12, color: textGrey),
                  ),
                ],
              ),
            ),

            // Thermal Paper Preview Card Container
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF1F5F9),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header Toko
                      Text(
                        UserData.storeName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontFamily: 'monospace',
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        UserData.storeAddress,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: textGrey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Telp/WA: ${UserData.storePhone}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: textGrey,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Dashed Line 1
                      const Text(
                        '----------------------------------',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Transaction Info
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trxId,
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${createdAt.day}/${createdAt.month}/${createdAt.year} • ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: textGrey,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Dashed Line 2
                      const Text(
                        '----------------------------------',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Cart Items List
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cartItems.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          final qty = item['quantity'] as int;
                          final price = item['unitPrice'] as int;
                          final total = qty * price;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'].toString().toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$qty x ${formatRupiah(price)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      color: textGrey,
                                    ),
                                  ),
                                  Text(
                                    formatRupiah(total),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      color: textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      // Dashed Line 3
                      const Text(
                        '----------------------------------',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Total & Payment
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          Text(
                            formatRupiah(totalBayar),
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Metode',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: textGrey,
                            ),
                          ),
                          Text(
                            paymentMethod,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Uang diterima',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: textGrey,
                            ),
                          ),
                          Text(
                            formatRupiah(cashReceived),
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Kembalian',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: textGrey,
                            ),
                          ),
                          Text(
                            formatRupiah(kembalian),
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Dashed Line 4
                      const Text(
                        '----------------------------------',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Footer Message
                      const Text(
                        'TERIMA KASIH',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'SELAMAT BERBELANJA KEMBALI',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Fixed Bottom Container Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
                ),
              ),
              child: Column(
                children: [
                  // Button Selesai
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context); // Close preview
                        onCloseAndReset(); // Reset cart & go to new transaction
                      },
                      child: const Text(
                        'Selesai',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Button Simpan Struk (PDF) -> Membuat & Mengunduh File PDF Asli dengan Profil Toko Terpercaya
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textDark,
                        side: const BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Menyimpan file PDF struk toko Anda...',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        await ReceiptPdfHelper.saveAndSharePdf(
                          trxId: trxId,
                          totalBayar: totalBayar,
                          paymentMethod: paymentMethod,
                          cashReceived: cashReceived,
                          kembalian: kembalian,
                          cartItems: cartItems,
                          transactionDate: createdAt,
                          storeName: UserData.storeName,
                          storeAddress: UserData.storeAddress,
                          storePhone: UserData.storePhone,
                        );
                      },
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text(
                        'Simpan Struk (PDF)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
