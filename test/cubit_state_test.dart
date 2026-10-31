import 'package:flutter_test/flutter_test.dart';

import 'package:kasirgo/features/cart/cubit/cart_cubit.dart';
import 'package:kasirgo/features/home/cubit/home_cubit.dart';
import 'package:kasirgo/features/reports/cubit/reports_cubit.dart';
import 'package:kasirgo/shared/cubit/sync_cubit.dart';
import 'package:kasirgo/shared/widgets/scanner_cubit.dart';

void main() {
  test('home tab selection is stored in Cubit state', () async {
    final cubit = HomeCubit();
    cubit.selectTab(2);
    expect(cubit.state, 2);
    await cubit.close();
  });

  test('report filters are stored in Cubit state', () async {
    final cubit = ReportsCubit();
    final date = DateTime(2026, 5, 12);
    cubit
      ..selectTab('Harian')
      ..selectDate(date);
    expect(cubit.state.activeTab, 'Harian');
    expect(cubit.state.selectedDate, date);
    await cubit.close();
  });

  test('payment state tracks method and cash change', () async {
    final cubit = PaymentCubit(25000);
    cubit
      ..selectMethod('QRIS')
      ..setCash(30000);
    expect(cubit.state.selectedMethod, 'QRIS');
    expect(cubit.state.changeFor(25000), 5000);
    await cubit.close();
  });

  test('scanner quantity cannot be decremented below one', () async {
    final cubit = ScannerCubit();
    cubit
      ..decrementQuantity()
      ..incrementQuantity();
    expect(cubit.state.quantity, 2);
    await cubit.close();
  });

  test('scanner quantity cannot exceed available stock', () async {
    final cubit = ScannerCubit();
    cubit
      ..incrementQuantity(maxQuantity: 1)
      ..incrementQuantity(maxQuantity: 2)
      ..incrementQuantity(maxQuantity: 2);
    expect(cubit.state.quantity, 2);
    await cubit.close();
  });

  test('sync state tracks offline status and data revisions', () async {
    final cubit = SyncCubit();
    cubit
      ..setOffline(true)
      ..productsChanged()
      ..transactionsChanged();
    expect(cubit.state.isOffline, isTrue);
    expect(cubit.state.productsRevision, 1);
    expect(cubit.state.transactionsRevision, 1);
    await cubit.close();
  });
}
