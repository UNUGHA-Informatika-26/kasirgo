import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/reports_cubit.dart';
import '../../../shared/data/user_data.dart';
import '../../../shared/cubit/sync_cubit.dart';
import '../../../shared/printer/bluetooth_printer_cubit.dart';
import '../../../shared/printer/bluetooth_printer_dialog.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/widgets/receipt_pdf_preview.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const _monthNames = ReportsCubit.monthNames;
  final ReportsCubit _reportsCubit = ReportsCubit();
  StreamSubscription<SyncState>? _syncSubscription;
  late int _lastTransactionRevision;

  String get _activeTab => _reportsCubit.state.activeTab;
  DateTime get _selectedDate => _reportsCubit.state.selectedDate;
  String get _selectedMonth => _reportsCubit.state.selectedMonth;
  int get _selectedYear => _reportsCubit.state.selectedYear;
  List<Map<String, dynamic>> get _transactions =>
      _reportsCubit.state.transactions;
  bool get _isLoading => _reportsCubit.state.isLoading;

  @override
  void initState() {
    super.initState();
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
      await _reportsCubit.loadTransactions();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat laporan: $error')));
    }
  }

  @override
  void dispose() {
    unawaited(_syncSubscription?.cancel());
    _reportsCubit.close();
    super.dispose();
  }

  // Format Rupiah
  String _formatRupiah(int number) =>
      CurrencyFormatter.formatRupiah(number, spaceAfterSymbol: true);

  int? _profitForTransactions(Iterable<Map<String, dynamic>> transactions) {
    var total = 0;
    var hasTransactions = false;
    var hasProfitData = false;
    for (final transaction in transactions) {
      hasTransactions = true;
      final profit = transaction['profitInt'] as int?;
      if (profit == null) continue;
      hasProfitData = true;
      total += profit;
    }
    return hasProfitData || !hasTransactions ? total : null;
  }

  // Menghitung jumlah hari tepat dalam bulan terpilih (28, 29, 30, atau 31 hari)
  int _getDaysInSelectedMonth() {
    final monthMap = {
      'januari': 1,
      'februari': 2,
      'maret': 3,
      'april': 4,
      'mei': 5,
      'juni': 6,
      'juli': 7,
      'agustus': 8,
      'september': 9,
      'oktober': 10,
      'november': 11,
      'desember': 12,
    };

    final parts = _selectedMonth.toLowerCase().split(' ');
    final monthName = parts.isNotEmpty ? parts[0] : 'september';
    final yearNum = parts.length > 1
        ? (int.tryParse(parts[1]) ?? DateTime.now().year)
        : _selectedYear;
    final monthNum = monthMap[monthName] ?? DateTime.now().month;

    // DateTime(year, month + 1, 0).day menghitung hari terakhir dalam bulan tersebut secara presisi
    return DateTime(yearNum, monthNum + 1, 0).day;
  }

  List<Map<String, dynamic>> get _dailyNotaList => _transactions
      .where((transaction) {
        final date = transaction['dateTime'] as DateTime;
        return date.year == _selectedDate.year &&
            date.month == _selectedDate.month &&
            date.day == _selectedDate.day;
      })
      .map(
        (transaction) => {...transaction, 'amount': transaction['amountInt']},
      )
      .toList();

  List<Map<String, dynamic>> get _dailyChartTrend {
    final amounts = List<int>.filled(12, 0);
    for (final transaction in _dailyNotaList) {
      final date = transaction['dateTime'] as DateTime;
      amounts[date.hour ~/ 2] += transaction['amountInt'] as int;
    }
    final maxAmount = amounts.fold<int>(
      0,
      (max, amount) => amount > max ? amount : max,
    );
    return List.generate(12, (index) {
      final hour = index * 2;
      final amount = amounts[index];
      return {
        'label': '$hour',
        'heightRatio': maxAmount == 0 ? 0.0 : amount / maxAmount,
        'isPeak': amount > 0 && amount == maxAmount,
      };
    });
  }

  List<Map<String, dynamic>> _getMonthlyDailyChartTrend() {
    final dailyTotals = List<int>.filled(_getDaysInSelectedMonth(), 0);
    final monthTransactions = _transactions.where((transaction) {
      final date = transaction['dateTime'] as DateTime;
      return date.year == _selectedYearForMonth &&
          date.month == _selectedMonthNumber;
    });
    for (final transaction in monthTransactions) {
      final date = transaction['dateTime'] as DateTime;
      dailyTotals[date.day - 1] += transaction['amountInt'] as int;
    }
    final maxAmount = dailyTotals.fold<int>(
      0,
      (max, amount) => amount > max ? amount : max,
    );
    return List.generate(dailyTotals.length, (index) {
      final amount = dailyTotals[index];
      return {
        'label': '${index + 1}',
        'heightRatio': maxAmount == 0 ? 0.0 : amount / maxAmount,
        'isPeak': amount > 0 && amount == maxAmount,
      };
    });
  }

  int get _selectedMonthNumber {
    final parts = _selectedMonth.split(' ');
    return _monthNames.indexOf(parts.first) + 1;
  }

  int get _selectedYearForMonth {
    final parts = _selectedMonth.split(' ');
    return parts.length > 1 ? int.parse(parts[1]) : _selectedYear;
  }

  List<Map<String, dynamic>> get _monthlyDailyBreakdown {
    final byDay = <int, List<Map<String, dynamic>>>{};
    for (final transaction in _transactions) {
      final date = transaction['dateTime'] as DateTime;
      if (date.year == _selectedYearForMonth &&
          date.month == _selectedMonthNumber) {
        byDay.putIfAbsent(date.day, () => []).add(transaction);
      }
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return days.map((day) {
      final items = byDay[day]!;
      final total = items.fold<int>(
        0,
        (sum, transaction) => sum + (transaction['amountInt'] as int),
      );
      final profit = _profitForTransactions(items);
      return {
        'date':
            '$day ${_monthNames[_selectedMonthNumber - 1]} $_selectedYearForMonth',
        'transactions': items.length,
        'amount': _formatRupiah(total),
        'profit': profit == null ? '—' : _formatRupiah(profit),
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _yearlyMonthlyBreakdown {
    final byMonth = <int, List<Map<String, dynamic>>>{};
    for (final transaction in _transactions) {
      final date = transaction['dateTime'] as DateTime;
      if (date.year == _selectedYear) {
        byMonth.putIfAbsent(date.month, () => []).add(transaction);
      }
    }
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    return months.map((month) {
      final items = byMonth[month]!;
      final total = items.fold<int>(
        0,
        (sum, transaction) => sum + (transaction['amountInt'] as int),
      );
      final profit = _profitForTransactions(items);
      return {
        'month': '${_monthNames[month - 1]} $_selectedYear',
        'transactions': items.length,
        'amount': _formatRupiah(total),
        'profit': profit == null ? '—' : _formatRupiah(profit),
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _yearlyChartTrend {
    final totals = List<int>.filled(12, 0);
    for (final transaction in _transactions) {
      final date = transaction['dateTime'] as DateTime;
      if (date.year == _selectedYear) {
        totals[date.month - 1] += transaction['amountInt'] as int;
      }
    }
    final maxAmount = totals.fold<int>(
      0,
      (max, amount) => amount > max ? amount : max,
    );
    return List.generate(12, (index) {
      final amount = totals[index];
      return {
        'label': _monthNames[index].substring(0, 3),
        'heightRatio': maxAmount == 0 ? 0.0 : amount / maxAmount,
        'isPeak': amount > 0 && amount == maxAmount,
      };
    }).toList();
  }

  // Modal DatePicker untuk Tab Harian
  Future<void> _pickDailyDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      _reportsCubit.selectDate(picked);
    }
  }

  // Modal MonthPicker untuk Tab Bulanan
  void _pickMonth() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final months =
            <String>{
              '${_monthNames[DateTime.now().month - 1]} ${DateTime.now().year}',
              ..._transactions.map((transaction) {
                final date = transaction['dateTime'] as DateTime;
                return '${_monthNames[date.month - 1]} ${date.year}';
              }),
            }.toList()..sort((first, second) {
              final firstParts = first.split(' ');
              final secondParts = second.split(' ');
              final firstDate = DateTime(
                int.parse(firstParts[1]),
                _monthNames.indexOf(firstParts[0]) + 1,
              );
              final secondDate = DateTime(
                int.parse(secondParts[1]),
                _monthNames.indexOf(secondParts[0]) + 1,
              );
              return secondDate.compareTo(firstDate);
            });
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pilih Bulan & Tahun',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              ...months.map(
                (m) => ListTile(
                  title: Text(
                    m,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: m == _selectedMonth
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: m == _selectedMonth
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  onTap: () {
                    _reportsCubit.selectMonth(m);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Modal YearPicker untuk Tab Tahunan
  void _pickYear() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final years = <int>{
          DateTime.now().year,
          ..._transactions.map(
            (transaction) => (transaction['dateTime'] as DateTime).year,
          ),
        }.toList()..sort((a, b) => b.compareTo(a));
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pilih Tahun Laporan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              ...years.map(
                (y) => ListTile(
                  title: Text(
                    'Tahun $y',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: y == _selectedYear
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: y == _selectedYear
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  onTap: () {
                    _reportsCubit.selectYear(y);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Modal Detail Struk Transaksi saat Nota diklik
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

        final itemsList = nota['cartItems'] as List<dynamic>;

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
              // Header
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

              // Receipt Paper Card
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
                          'Jam: ${nota['time']}',
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
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${i['quantity']}x ${i['name']}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: textDark,
                              ),
                            ),
                            Text(
                              _formatRupiah(
                                (i['quantity'] as int) *
                                    (i['unitPrice'] as int),
                              ),
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

                    // Total
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
                          _formatRupiah(nota['amount'] as int),
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
                          'BAYAR (${nota['method']})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: textGrey,
                          ),
                        ),
                        Text(
                          _formatRupiah(nota['cashReceived'] as int),
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
                          _formatRupiah(nota['kembalian'] as int),
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
                    totalAmount: nota['amount'] as int,
                    paymentMethod: nota['method'] as String,
                    cashReceived: nota['cashReceived'] as int,
                    changeAmount: nota['kembalian'] as int,
                    items: List<Map<String, dynamic>>.from(nota['cartItems']),
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
                        totalAmount: nota['amount'] as int,
                        paymentMethod: nota['method'] as String,
                        cashReceived: nota['cashReceived'] as int,
                        changeAmount: nota['kembalian'] as int,
                        items: List<Map<String, dynamic>>.from(
                          nota['cartItems'],
                        ),
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsCubit, ReportsState>(
      bloc: _reportsCubit,
      builder: (context, state) {
        const primaryBlue = Color(0xFF2563EB);
        const textDark = Color(0xFF0F172A);
        const textGrey = Color(0xFF64748B);
        const badgeBg = Color(0xFFEFF6FF);
        const lightBarColor = Color(0xFFDCE7FE);

        // Ambil data berdasarkan state terbaru agar ringkasan dan grafik ikut diperbarui.
        List<Map<String, dynamic>> currentChartData = [];
        String totalOmset = '';
        String totalProfit = '';
        String totalTransactions = '';
        String timeFilterLabel = '';

        final daysInSelectedMonth = _getDaysInSelectedMonth();
        final selectedTransactions = _transactions.where((transaction) {
          final date = transaction['dateTime'] as DateTime;
          if (_activeTab == 'Harian') {
            return date.year == _selectedDate.year &&
                date.month == _selectedDate.month &&
                date.day == _selectedDate.day;
          }
          if (_activeTab == 'Bulanan') {
            return date.year == _selectedYearForMonth &&
                date.month == _selectedMonthNumber;
          }
          return date.year == _selectedYear;
        }).toList();
        final selectedSales = selectedTransactions.fold<int>(
          0,
          (total, transaction) => total + (transaction['amountInt'] as int),
        );
        totalOmset = _formatRupiah(selectedSales);
        final selectedProfit = _profitForTransactions(selectedTransactions);
        totalProfit = selectedProfit == null
            ? '—'
            : _formatRupiah(selectedProfit);
        totalTransactions = '${selectedTransactions.length} Transaksi';

        if (_activeTab == 'Harian') {
          currentChartData = _dailyChartTrend;
          timeFilterLabel =
              '${_selectedDate.day} ${_monthNames[_selectedDate.month - 1]} ${_selectedDate.year}';
        } else if (_activeTab == 'Bulanan') {
          currentChartData = _getMonthlyDailyChartTrend();
          timeFilterLabel = _selectedMonth;
        } else {
          currentChartData = _yearlyChartTrend;
          timeFilterLabel = 'Tahun $_selectedYear';
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Title & Subtitle
                const Text(
                  'Laporan Penjualan',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pantau omzet dan histori transaksi dari database toko Anda.',
                  style: TextStyle(fontSize: 13, color: textGrey),
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(),
                  ),

                // 1. Tab Switcher (Atas): [ Harian ] | [ Bulanan ] | [ Tahunan ]
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton('Harian'),
                      _buildTabButton('Bulanan'),
                      _buildTabButton('Tahunan'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Filter Tanggal / Waktu (Atas-Tengah) sesuai Tab
                InkWell(
                  onTap: () {
                    if (_activeTab == 'Harian') {
                      _pickDailyDate();
                    } else if (_activeTab == 'Bulanan') {
                      _pickMonth();
                    } else {
                      _pickYear();
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter Waktu Laporan ($_activeTab)',
                              style: const TextStyle(
                                fontSize: 11,
                                color: textGrey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeFilterLabel,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: primaryBlue,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Card Ringkasan Utama (Tengah)
                Row(
                  children: [
                    // Card 1: Total Omset
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
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
                            const Text(
                              'Total Omset',
                              style: TextStyle(fontSize: 11, color: textGrey),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              totalOmset,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Card 2: Laba Bersih
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFDCFCE7),
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
                            const Text(
                              'Laba Bersih',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF15803D),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              totalProfit,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Card 3: Jumlah Transaksi
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
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
                            const Text(
                              'Transaksi',
                              style: TextStyle(fontSize: 11, color: textGrey),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              totalTransactions,
                              style: const TextStyle(
                                fontSize: 13,
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
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Laba dihitung dari harga jual dikurangi harga modal saat transaksi. '
                    'Transaksi sebelum pencatatan modal mungkin belum tercakup.',
                    style: TextStyle(fontSize: 11, color: textGrey),
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Grafik Penjualan (Tampilan Visual Batang Sesuai Jumlah Hari Bulan Terpilih)
                Container(
                  padding: const EdgeInsets.all(18),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Grafik Penjualan ($_activeTab)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          Text(
                            _activeTab == 'Harian'
                                ? 'Tren 24 Jam'
                                : _activeTab == 'Bulanan'
                                ? 'Tanggal 1 - $daysInSelectedMonth'
                                : '12 Bulan',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Bar Chart Visualization (Scrollable Horizontal untuk Tanggal Sesuai Bulan)
                      SizedBox(
                        height: 115,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: currentChartData.map((item) {
                              final double heightRatio =
                                  item['heightRatio'] as double;
                              final bool isPeak = item['isPeak'] as bool;
                              final String label = item['label'] as String;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: _activeTab == 'Harian'
                                          ? 18
                                          : _activeTab == 'Bulanan'
                                          ? 16
                                          : 14,
                                      height: 80 * heightRatio,
                                      decoration: BoxDecoration(
                                        color: isPeak
                                            ? primaryBlue
                                            : lightBarColor,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: _activeTab == 'Harian'
                                            ? 10
                                            : _activeTab == 'Bulanan'
                                            ? 10
                                            : 10,
                                        color: isPeak ? primaryBlue : textGrey,
                                        fontWeight: isPeak
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Daftar Rincian (Bawah) sesuai Tab & Interaksi Klik
                Container(
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
                    children: [
                      // Blue Header Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: const BoxDecoration(
                          color: primaryBlue,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(15),
                          ),
                        ),
                        child: Text(
                          _activeTab == 'Harian'
                              ? 'Daftar Nota Transaksi Hari Ini'
                              : _activeTab == 'Bulanan'
                              ? 'Breakdown Penjualan per Tanggal'
                              : 'Breakdown Penjualan per Bulan',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // TAB A: HARIAN (Daftar Nota/Transaksi -> Diklik Buka Detail Struk)
                      if (_activeTab == 'Harian') ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _dailyNotaList.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final nota = _dailyNotaList[index];
                            return InkWell(
                              onTap: () => _showTransactionDetailModal(nota),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nota['id'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Jam ${nota['time']} • ${nota['items']} item',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: textGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          _formatRupiah(nota['amount'] as int),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: textDark,
                                          ),
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

                      // TAB B: BULANAN (Breakdown Tanggal -> Diklik Berpindah ke Tab Harian)
                      if (_activeTab == 'Bulanan') ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _monthlyDailyBreakdown.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final item = _monthlyDailyBreakdown[index];
                            return InkWell(
                              onTap: () {
                                _reportsCubit.selectDailyBreakdownDate(
                                  item['date'] as String,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Berpindah ke Laporan Harian ${item['date']}',
                                    ),
                                    backgroundColor: primaryBlue,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['date'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item['transactions']} Transaksi',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: textGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          item['amount'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0FDF4),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'Laba: ${item['profit']}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF15803D),
                                            ),
                                          ),
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

                      // TAB C: TAHUNAN (Breakdown Bulan -> Diklik Berpindah ke Tab Bulanan)
                      if (_activeTab == 'Tahunan') ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _yearlyMonthlyBreakdown.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final item = _yearlyMonthlyBreakdown[index];
                            return InkWell(
                              onTap: () {
                                _reportsCubit
                                  ..selectTab('Bulanan')
                                  ..selectMonth(item['month'] as String);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Berpindah ke Laporan Bulanan ${item['month']}',
                                    ),
                                    backgroundColor: primaryBlue,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['month'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item['transactions']} Transaksi',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: textGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          item['amount'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0FDF4),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'Laba: ${item['profit']}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF15803D),
                                            ),
                                          ),
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
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget Helper Tombol Tab
  Widget _buildTabButton(String tabName) {
    final isSelected = _activeTab == tabName;
    const primaryBlue = Color(0xFF2563EB);
    const textDark = Color(0xFF0F172A);

    return Expanded(
      child: GestureDetector(
        onTap: () => _reportsCubit.selectTab(tabName),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primaryBlue : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              tabName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? primaryBlue : textDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
