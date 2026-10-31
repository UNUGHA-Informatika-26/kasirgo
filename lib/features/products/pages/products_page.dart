import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/cubit/sync_cubit.dart';
import '../../../shared/services/supabase_service.dart';
import '../cubit/products_cubit.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/widgets/barcode_scanner_screen.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ProductsCubit _productsCubit = ProductsCubit();
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
        _loadProducts();
      }
    });
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      await _productsCubit.loadProducts();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal memuat produk: $error')));
    }
  }

  void _onSearchChanged() {
    _productsCubit.search(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.dispose();
    unawaited(_syncSubscription?.cancel());
    unawaited(_productsCubit.close());
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredProducts =>
      _productsCubit.state.filteredProducts;
  bool get _isLoading => _productsCubit.state.isLoading;

  // Format integer ke Rupiah (misal 8500 -> Rp8.500)
  String _formatRupiah(int number) => CurrencyFormatter.formatRupiah(number);

  // Dialog / Modal Form Tambah atau Edit Produk
  void _showProductForm({Map<String, dynamic>? existingProduct}) {
    final isEdit = existingProduct != null;
    final nameController = TextEditingController(
      text: isEdit ? existingProduct['name'] : '',
    );
    final barcodeController = TextEditingController(
      text: isEdit ? (existingProduct['barcode'] ?? '') : '',
    );
    final costPriceController = TextEditingController(
      text: isEdit ? (existingProduct['costPrice'] ?? 0).toString() : '',
    );
    final priceController = TextEditingController(
      text: isEdit ? existingProduct['price'].toString() : '',
    );
    final stockController = TextEditingController(
      text: isEdit ? existingProduct['stock'].toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Barang' : 'Tambah Barang Baru',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Field 1: Nama Barang
              const Text(
                'Nama Barang',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Masukkan nama barang',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Field 2: Kode Barang / Barcode dengan Tombol Scan
              const Text(
                'Kode Barang / Barcode',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: barcodeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Ketik manual atau scan',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      showGeneralDialog(
                        context: context,
                        barrierDismissible: false,
                        barrierLabel: 'Scan Barcode',
                        transitionDuration: const Duration(milliseconds: 250),
                        pageBuilder: (context, anim1, anim2) {
                          return BarcodeScannerScreen(
                            onBarcodeScanned: (scannedCode) {
                              barcodeController.text = scannedCode;
                            },
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    label: const Text('Scan'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Field 3 & 4: Harga Beli (Modal) & Harga Jual (Row)
              Row(
                children: [
                  // Field 3: Harga Beli (Modal)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Harga Beli (Modal)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: costPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Modal Rp',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Field 4: Harga Jual
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Harga Jual',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Jual Rp',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Field 5: Stok Barang
              const Text(
                'Stok Barang',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Contoh: 24',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Button Simpan
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final barcode = barcodeController.text.trim();
                    final costPrice =
                        int.tryParse(costPriceController.text) ?? 0;
                    final price = int.tryParse(priceController.text) ?? 0;
                    final stock = int.tryParse(stockController.text);

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nama barang wajib diisi.'),
                        ),
                      );
                      return;
                    }
                    if (stock == null || stock < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Stok harus berupa angka nol atau lebih.'),
                        ),
                      );
                      return;
                    }

                    final product = {
                      'name': name,
                      'barcode': barcode,
                      'costPrice': costPrice,
                      'price': price,
                      'stock': stock,
                      'status': stock > 0 ? 'tersedia' : 'habis',
                    };
                    try {
                      if (isEdit) {
                        await _productsCubit.updateProduct(
                          existingProduct['id'].toString(),
                          product,
                        );
                      } else {
                        await _productsCubit.insertProduct(product);
                      }
                      if (context.mounted) Navigator.pop(context);
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gagal menyimpan produk: $error'),
                        ),
                      );
                    }
                  },
                  child: Text(
                    isEdit ? 'Simpan Perubahan' : 'Tambah Barang',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Dialog Konfirmasi Hapus Produk
  void _deleteProduct(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Barang'),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${product['name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await _productsCubit.deleteProduct(product['id'].toString());
                if (!mounted || !dialogContext.mounted) return;
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Gagal menghapus produk: $error')),
                );
                return;
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563EB);
    const textDark = Color(0xFF0F172A);
    const textGrey = Color(0xFF64748B);
    const badgeBg = Color(0xFFEFF6FF);
    const borderColor = Color(0xFFE2E8F0);

    return BlocBuilder<ProductsCubit, ProductsState>(
      bloc: _productsCubit,
      builder: (context, state) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showProductForm(),
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          elevation: 4,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Title & Subtitle
              const Text(
                'Data Barang',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Cari, tambah, dan kelola stok produk dengan cepat.',
                style: TextStyle(fontSize: 13, color: textGrey),
              ),
              const SizedBox(height: 16),

              // 2. Search Field
              TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14, color: textDark),
                decoration: InputDecoration(
                  hintText: 'Cari nama / barcode...',
                  hintStyle: const TextStyle(color: textGrey, fontSize: 14),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: textGrey,
                    size: 22,
                  ),
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

              // 3. Section Title & Count Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Daftar Barang',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_filteredProducts.length} produk',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4. Product Cards List
              _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _filteredProducts.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'Barang tidak ditemukan',
                          style: TextStyle(color: textGrey, fontSize: 14),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredProducts.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _filteredProducts[index];
                        final costPrice = (item['costPrice'] ?? 0) as int;
                        final stock = (item['stock'] as num?)?.toInt() ?? 0;
                        final stockLabel = stock <= 0
                            ? 'Habis'
                            : stock <= 5
                            ? 'Stok menipis'
                            : item['status'] ?? 'tersedia';
                        final stockColor = stock <= 0
                            ? const Color(0xFFDC2626)
                            : stock <= 5
                            ? const Color(0xFFD97706)
                            : textGrey;

                        return Container(
                          padding: const EdgeInsets.all(16),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Product Name & Stock Info
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        // Kode Barang / Barcode
                                        Text(
                                          item['barcode'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: textGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Stok $stock',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: stockColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        stockLabel,
                                        style: const TextStyle(
                                          fontSize: 12,
                                        ).copyWith(
                                          color: stockColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Price Subtitle (Harga Jual & Modal)
                              Text(
                                'Harga jual ${_formatRupiah(item['price'])} • Modal ${_formatRupiah(costPrice)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: textGrey,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Action Buttons (Edit & Hapus)
                              Row(
                                children: [
                                  // Edit Button
                                  InkWell(
                                    onTap: () =>
                                        _showProductForm(existingProduct: item),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Edit',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Hapus Button
                                  InkWell(
                                    onTap: () => _deleteProduct(item),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Hapus',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 80), // Space for FAB
            ],
          ),
        ),
      ),
    );
  }
}
