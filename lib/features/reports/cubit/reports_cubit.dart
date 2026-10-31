import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/services/supabase_service.dart';

class ReportsState {
  final String activeTab;
  final DateTime selectedDate;
  final String selectedMonth;
  final int selectedYear;
  final List<Map<String, dynamic>> transactions;
  final bool isLoading;
  final Object? error;

  const ReportsState({
    required this.activeTab,
    required this.selectedDate,
    required this.selectedMonth,
    required this.selectedYear,
    this.transactions = const [],
    this.isLoading = true,
    this.error,
  });

  ReportsState copyWith({
    String? activeTab,
    DateTime? selectedDate,
    String? selectedMonth,
    int? selectedYear,
    List<Map<String, dynamic>>? transactions,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return ReportsState(
      activeTab: activeTab ?? this.activeTab,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedYear: selectedYear ?? this.selectedYear,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ReportsCubit extends Cubit<ReportsState> {
  static const monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  ReportsCubit()
    : super(
        ReportsState(
          activeTab: 'Bulanan',
          selectedDate: DateTime.now(),
          selectedMonth:
              '${monthNames[DateTime.now().month - 1]} ${DateTime.now().year}',
          selectedYear: DateTime.now().year,
        ),
      );

  Future<void> loadTransactions() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final transactions = await SupabaseService.fetchTransactions();
      emit(state.copyWith(transactions: transactions, isLoading: false));
    } catch (error) {
      emit(state.copyWith(isLoading: false, error: error));
      rethrow;
    }
  }

  void selectTab(String tab) => emit(state.copyWith(activeTab: tab));
  void selectDate(DateTime date) => emit(state.copyWith(selectedDate: date));
  void selectMonth(String month) => emit(state.copyWith(selectedMonth: month));
  void selectYear(int year) => emit(state.copyWith(selectedYear: year));

  void selectDailyBreakdownDate(String date) {
    final parts = date.split(' ');
    final day = int.tryParse(parts.first);
    final month = monthNames.indexOf(parts.length > 1 ? parts[1] : '') + 1;
    if (day == null || month < 1) return;
    final year = parts.length > 2
        ? int.tryParse(parts[2]) ?? state.selectedYear
        : state.selectedYear;
    emit(
      state.copyWith(
        activeTab: 'Harian',
        selectedDate: DateTime(year, month, day),
      ),
    );
  }
}
