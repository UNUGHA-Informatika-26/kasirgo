import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/services/supabase_service.dart';
import '../../../shared/utils/currency_formatter.dart';

class DashboardState {
  final List<Map<String, dynamic>> transactions;
  final String query;
  final bool isLoading;
  final Object? error;
  final int profileRevision;

  const DashboardState({
    this.transactions = const [],
    this.query = '',
    this.isLoading = true,
    this.error,
    this.profileRevision = 0,
  });

  List<Map<String, dynamic>> get filteredTransactions => transactions
      .where(
        (transaction) => transaction['id'].toString().toLowerCase().contains(
          query.toLowerCase(),
        ),
      )
      .toList();

  DashboardState copyWith({
    List<Map<String, dynamic>>? transactions,
    String? query,
    bool? isLoading,
    Object? error,
    bool clearError = false,
    int? profileRevision,
  }) {
    return DashboardState(
      transactions: transactions ?? this.transactions,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      profileRevision: profileRevision ?? this.profileRevision,
    );
  }
}

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit() : super(const DashboardState());

  Future<void> loadTransactions() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final fetched = await SupabaseService.fetchTransactions();
      final transactions = fetched.map((transaction) {
        final date = transaction['dateTime'] as DateTime;
        return {
          ...transaction,
          'date':
              '${date.day}/${date.month}/${date.year} • ${transaction['time']}',
          'amount': formatRupiah(transaction['amountInt'] as int),
        };
      }).toList();
      emit(state.copyWith(transactions: transactions, isLoading: false));
    } catch (error) {
      emit(state.copyWith(isLoading: false, error: error));
      rethrow;
    }
  }

  void search(String query) => emit(state.copyWith(query: query));

  void profileUpdated() {
    emit(state.copyWith(profileRevision: state.profileRevision + 1));
  }

  static String formatRupiah(int number) {
    return CurrencyFormatter.formatRupiah(number, spaceAfterSymbol: true);
  }
}
