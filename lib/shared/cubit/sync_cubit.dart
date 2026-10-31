import 'package:flutter_bloc/flutter_bloc.dart';

class SyncState {
  final int productsRevision;
  final int transactionsRevision;
  final bool isOffline;

  const SyncState({
    this.productsRevision = 0,
    this.transactionsRevision = 0,
    this.isOffline = false,
  });

  SyncState copyWith({
    int? productsRevision,
    int? transactionsRevision,
    bool? isOffline,
  }) {
    return SyncState(
      productsRevision: productsRevision ?? this.productsRevision,
      transactionsRevision: transactionsRevision ?? this.transactionsRevision,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class SyncCubit extends Cubit<SyncState> {
  SyncCubit() : super(const SyncState());

  void setOffline(bool isOffline) => emit(state.copyWith(isOffline: isOffline));

  void productsChanged() =>
      emit(state.copyWith(productsRevision: state.productsRevision + 1));

  void transactionsChanged() => emit(
    state.copyWith(transactionsRevision: state.transactionsRevision + 1),
  );
}
