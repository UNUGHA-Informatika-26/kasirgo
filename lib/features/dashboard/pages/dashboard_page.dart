import 'package:flutter/material.dart';
import '../../../auth/login_pages.dart';

class DashboardPage extends StatefulWidget {
  final VoidCallback? onMulaiTransaksi;

  const DashboardPage({
    super.key,
    this.onMulaiTransaksi,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _searchController = TextEditingController();

  // Dummy list transaksi
  final List<Map<String, dynamic>> _allTransactions = [
    {
      'id': 'TRX-240118-001',
      'items': 4,
      'date': '18 Jan 2025 • 09:12',
      'amount': 'Rp120.000',
    },
    {
      'id': 'TRX-240118-002',
      'items': 6,
      'date': '18 Jan 2025 • 09:28',
      'amount': 'Rp185.000',
    },
    {
      'id': 'TRX-240118-003',
      'items': 2,
      'date': '18 Jan 2025 • 10:05',
      'amount': 'Rp42.000',
    },
    {
      'id': 'TRX-240118-004',
      'items': 3,
      'date': '18 Jan 2025 • 10:41',
      'amount': 'Rp96.000',
    },
    {
      'id': 'TRX-240118-005',
      'items': 1,
      'date': '18 Jan 2025 • 11:15',
      'amount': 'Rp15.000',
    },
  ];

  List<Map<String, dynamic>> _filteredTransactions = [];

  @override
  void initState() {
    super.initState();
    _filteredTransactions = List.from(_allTransactions);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTransactions = List.from(_allTransactions);
      } else {
        _filteredTransactions = _allTransactions.where((trx) {
          final id = trx['id'].toString().toLowerCase();
          return id.contains(query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPages()),
                (route) => false,
              );
            },
            child: const Text('Keluar'),
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
    const redColor = Color(0xFFDC2626);
    const cardBg = Color(0xFFF8FAFC);
    const borderColor = Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Greeting & Date
          const Text(
            'Halo, Nama Pengguna!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Jum'at, 2 Oktober 2026",
            style: TextStyle(
              fontSize: 14,
              color: textGrey,
            ),
          ),
          const SizedBox(height: 16),

          // 2. Button Keluar Akun
          SizedBox(
            height: 48,
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
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: redColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
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
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Penjualan Hari Ini',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: textGrey,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Rp 450.000',
                          style: TextStyle(
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
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Transaksi Hari Ini',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: textGrey,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '15 Transaksi',
                          style: TextStyle(
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
            style: TextStyle(
              fontSize: 13,
              color: textGrey,
            ),
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
                        style: const TextStyle(
                          fontSize: 13,
                          color: textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                // Transaction Items List
                _filteredTransactions.isEmpty
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
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Left Info
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
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
                              ],
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
    );
  }
}
