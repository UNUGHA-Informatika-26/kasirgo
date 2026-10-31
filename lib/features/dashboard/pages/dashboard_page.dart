import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/dashboard_cubit.dart';
import '../../../auth/cubit/auth_cubit.dart';
import '../../../auth/cubit/auth_state.dart';
import '../../../auth/login_pages.dart';
import '../../../shared/data/user_data.dart';
import '../../../shared/cubit/sync_cubit.dart';
import '../../../shared/printer/bluetooth_printer_cubit.dart';
import '../../../shared/printer/bluetooth_printer_dialog.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/receipt_pdf_preview.dart';

class DashboardPage extends StatefulWidget {
  final VoidCallback? onMulaiTransaksi;

  const DashboardPage({super.key, this.onMulaiTransaksi});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _searchController = TextEditingController();
  final DashboardCubit _dashboardCubit = DashboardCubit();
  StreamSubscription<SyncState>? _syncSubscription;
  late int _lastTransactionRevision;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _lastTransactionRevision =
        SupabaseService.syncCubit.state.transactionsRevision;
    _syncSubscription = SupabaseService.syncCubit.stream.listen((state) {
      if (state.transactionsRevision != _lastTransactionRevision) {
        _lastTransactionRevision = state.transactionsRevision;
        _onTransactionsChanged();
      }
    });
    _loadTransactions();
  }

  void _onTransactionsChanged() {
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      await _dashboardCubit.loadTransactions();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat riwayat transaksi: $error')),
      );
    }
  }

  void _onSearchChanged() {
    _dashboardCubit.search(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.dispose();
    unawaited(_syncSubscription?.cancel());
    _dashboardCubit.close();
    super.dispose();
  }

  List<Map<String, dynamic>> get _allTransactions =>
      _dashboardCubit.state.transactions;
  List<Map<String, dynamic>> get _filteredTransactions =>
      _dashboardCubit.state.filteredTransactions;
  bool get _isLoadingTransactions => _dashboardCubit.state.isLoading;

  String _formatRupiah(int number) => DashboardCubit.formatRupiah(number);

  // Modal Detail Struk Transaksi saat Riwayat Transaksi diklik
  void _showTransactionDetailModal(Map<String, dynamic> nota) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        const textDark = Color(0xFF0F172A);
        const textGrey = Color(0xFF64748B);
        const primaryBlue = Color(0xFF2563EB);
        const borderColor = Color(0xFFE2E8F0);

        final itemsList = (nota['cartItems'] as List<dynamic>?) ?? [];
        final totalAmount = (nota['amountInt'] as int?) ?? 0;

        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Modal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detail Struk ${nota['id']}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Receipt Paper Card (Struk Kertas Thermal)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Text(
                      UserData.storeName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      UserData.storeAddress,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: textGrey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Telp/WA: ${UserData.storePhone}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: textGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '----------------------------------',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          nota['id'],
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Jam: ${nota['time'] ?? "09:00"}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: textGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '----------------------------------',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Items List
                    ...itemsList.map((i) {
                      final qty = i['quantity'] as int;
                      final price = i['unitPrice'] as int;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${qty}x ${i['name']}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: textDark,
                              ),
                            ),
                            Text(
                              _formatRupiah(qty * price),
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    const Text(
                      '----------------------------------',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Total & Payment Summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formatRupiah(totalAmount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BAYAR (${nota['method'] ?? "Tunai"})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: textGrey,
                          ),
                        ),
                        Text(
                          _formatRupiah(
                            (nota['cashReceived'] as int?) ?? totalAmount,
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'KEMBALI',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: textGrey,
                          ),
                        ),
                        Text(
                          _formatRupiah((nota['kembalian'] as int?) ?? 0),
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: textDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryBlue,
                    side: const BorderSide(color: primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => ReceiptPdfPreview.show(
                    context,
                    transactionId: nota['id'].toString(),
                    totalAmount: totalAmount,
                    paymentMethod:
                        (nota['method'] as String?) ?? 'Tunai',
                    cashReceived:
                        (nota['cashReceived'] as int?) ?? totalAmount,
                    changeAmount: (nota['kembalian'] as int?) ?? 0,
                    items: List<Map<String, dynamic>>.from(itemsList),
                    transactionDate: nota['dateTime'] as DateTime,
                    storeName: UserData.storeName,
                    storeAddress: UserData.storeAddress,
                    storePhone: UserData.storePhone,
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text(
                    'Pratinjau / Simpan PDF',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Button Cetak Ulang Struk
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await BluetoothPrinterDialog.show(
                      context,
                      receipt: ReceiptPrintData(
                        transactionId: nota['id'].toString(),
                        totalAmount: totalAmount,
                        paymentMethod:
                            (nota['method'] as String?) ?? 'Tunai',
                        cashReceived:
                            (nota['cashReceived'] as int?) ?? totalAmount,
                        changeAmount: (nota['kembalian'] as int?) ?? 0,
                        items: List<Map<String, dynamic>>.from(itemsList),
                        createdAt: nota['dateTime'] as DateTime,
                        storeName: UserData.storeName,
                        storeAddress: UserData.storeAddress,
                        storePhone: UserData.storePhone,
                      ),
                    );
                  },
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text(
                    'Cetak Ulang Struk',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Modal Tampilan Profil
  void _showProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        const textDark = Color(0xFF0F172A);
        const textGrey = Color(0xFF64748B);
        const primaryBlue = Color(0xFF2563EB);

        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Modal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profil Toko & Usaha',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Store Avatar Circle
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.storefront_rounded,
                    color: primaryBlue,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                UserData.storeName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Akun Kasir Aktif',
                style: TextStyle(fontSize: 12, color: textGrey),
              ),
              const SizedBox(height: 20),

              // Detail List Cards
              _buildProfileDetailItem(
                icon: Icons.person_outline_rounded,
                label: 'Nama Usaha / Toko',
                value: UserData.storeName,
              ),
              const SizedBox(height: 10),
              _buildProfileDetailItem(
                icon: Icons.location_on_outlined,
                label: 'Alamat Usaha',
                value: UserData.storeAddress,
              ),
              const SizedBox(height: 10),
              _buildProfileDetailItem(
                icon: Icons.phone_android_rounded,
                label: 'No. WhatsApp / Telepon',
                value: UserData.storePhone,
              ),
              const SizedBox(height: 10),
              _buildProfileDetailItem(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: UserData.storeEmail,
              ),
              const SizedBox(height: 24),

              // Tombol Edit Profil di Paling Bawah
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Tutup modal profil
                    _showEditProfileModal(); // Buka modal edit
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text(
                    'Edit Profil',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2563EB), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Modal Form Edit Profil
  void _showEditProfileModal() {
    final nameCtrl = TextEditingController(text: UserData.storeName);
    final addressCtrl = TextEditingController(text: UserData.storeAddress);
    final phoneCtrl = TextEditingController(text: UserData.storePhone);
    final emailCtrl = TextEditingController(text: UserData.storeEmail);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        const textDark = Color(0xFF0F172A);
        const primaryBlue = Color(0xFF2563EB);
        const borderColor = Color(0xFFE2E8F0);

        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Profil Usaha',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Field 1: Nama Usaha
              const Text(
                'Nama Usaha / Toko',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
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
              ),
              const SizedBox(height: 12),

              // Field 2: Alamat Toko
              const Text(
                'Alamat Usaha',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: InputDecoration(
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
              ),
              const SizedBox(height: 12),

              // Field 3: Phone
              const Text(
                'No. WhatsApp / Telepon',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
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
              ),
              const SizedBox(height: 12),

              // Field 4: Email
              const Text(
                'Email',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
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
              ),
              const SizedBox(height: 20),

              // Button Simpan Perubahan
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      await SupabaseService.updateProfile(
                        name: nameCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                      );
                      if (!context.mounted) return;
                      _dashboardCubit.profileUpdated();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profil usaha berhasil diperbarui!'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gagal menyimpan profil: $error'),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Simpan Perubahan',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => BlocListener<AuthCubit, AuthState>(
        listenWhen: (previous, current) =>
            current.operation == AuthOperation.logout &&
            current.status != AuthStatus.loading,
        listener: (context, state) {
          if (state.status == AuthStatus.unauthenticated) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPages()),
              (route) => false,
            );
          } else if (state.status == AuthStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gagal keluar dari akun: ${state.message}'),
              ),
            );
          }
        },
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Konfirmasi Keluar'),
          content: const Text('Apakah Anda yakin ingin keluar dari akun?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                context.read<AuthCubit>().logout();
              },
              child: const Text('Keluar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563EB);
    const textDark = Color(0xFF0F172A);
    const textGrey = Color(0xFF64748B);
    const redColor = Color(0xFFDC2626);
    const cardBg = Color(0xFFF8FAFC);
    const borderColor = Color(0xFFE2E8F0);
    final now = DateTime.now();
    final todayTransactions = _allTransactions.where((transaction) {
      final date = transaction['dateTime'] as DateTime;
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
    final todaySales = todayTransactions.fold<int>(
      0,
      (total, transaction) => total + (transaction['amountInt'] as int),
    );

    return BlocBuilder<DashboardCubit, DashboardState>(
      bloc: _dashboardCubit,
      builder: (context, state) => SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Greeting & Date
            Text(
              'Halo, ${UserData.storeName}!',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${now.day}/${now.month}/${now.year}',
              style: const TextStyle(fontSize: 14, color: textGrey),
            ),
            const SizedBox(height: 16),

            // 2. Row Action Buttons: Profil Saya & Keluar Akun
            Row(
              children: [
                // Button Profil Saya
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _showProfileModal,
                      icon: const Icon(
                        Icons.person_outline_rounded,
                        color: primaryBlue,
                        size: 20,
                      ),
                      label: const Text(
                        'Profil Toko',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: primaryBlue, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Button Keluar Akun
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(
                        Icons.exit_to_app_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Keluar Akun',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: redColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 3. Summary Cards (Total Penjualan & Total Transaksi)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Total Penjualan
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Penjualan Hari Ini',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: textGrey,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            _formatRupiah(todaySales),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Total Transaksi
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Transaksi Hari Ini',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: textGrey,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '${todayTransactions.length} Transaksi',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Button "+ MULAI TRANSAKSI"
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: widget.onMulaiTransaksi,
                icon: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                label: const Text(
                  'MULAI TRANSAKSI',
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
            const SizedBox(height: 28),

            // 5. Section Title & Subtitle Riwayat Transaksi
            const Text(
              'Riwayat Transaksi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Laporan & riwayat transaksi kasir',
              style: TextStyle(fontSize: 13, color: textGrey),
            ),
            const SizedBox(height: 16),

            // 6. Search Input Field
            TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14, color: textDark),
              decoration: InputDecoration(
                hintText: 'Cari nomor transaksi',
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
                  borderSide: const BorderSide(color: borderColor, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 7. Transaction List Container
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
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
                  // Container Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Daftar transaksi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        Text(
                          '${_filteredTransactions.length} transaksi',
                          style: const TextStyle(fontSize: 13, color: textGrey),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // Transaction Items List (Clickable to open Detail Struk Modal)
                  _isLoadingTransactions
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _filteredTransactions.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              'Transaksi tidak ditemukan',
                              style: TextStyle(color: textGrey, fontSize: 14),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredTransactions.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final item = _filteredTransactions[index];
                            return InkWell(
                              onTap: () => _showTransactionDetailModal(item),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Left Info
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['id'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item['date'],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: textGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Right Info
                                    Row(
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${item['items']} item',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: textGrey,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item['amount'],
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: textDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          color: textGrey,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
