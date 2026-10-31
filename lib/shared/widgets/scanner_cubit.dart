import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/product_data.dart';

enum ScannerStatus { permissionDenied, scanning, scanSuccess, scanNotFound }

class ScannerState {
  final ScannerStatus status;
  final bool isFlashOn;
  final int quantity;
  final String detectedBarcode;
  final Map<String, dynamic> scannedProduct;

  const ScannerState({
    this.status = ScannerStatus.scanning,
    this.isFlashOn = false,
    this.quantity = 1,
    this.detectedBarcode = '',
    this.scannedProduct = const {},
  });

  ScannerState copyWith({
    ScannerStatus? status,
    bool? isFlashOn,
    int? quantity,
    String? detectedBarcode,
    Map<String, dynamic>? scannedProduct,
    bool clearProduct = false,
  }) {
    return ScannerState(
      status: status ?? this.status,
      isFlashOn: isFlashOn ?? this.isFlashOn,
      quantity: quantity ?? this.quantity,
      detectedBarcode: detectedBarcode ?? this.detectedBarcode,
      scannedProduct: clearProduct
          ? const {}
          : scannedProduct ?? this.scannedProduct,
    );
  }
}

class ScannerCubit extends Cubit<ScannerState> {
  ScannerCubit() : super(const ScannerState());

  void toggleFlashlight() => emit(state.copyWith(isFlashOn: !state.isFlashOn));

  void retry() => emit(state.copyWith(status: ScannerStatus.scanning));

  void incrementQuantity() =>
      emit(state.copyWith(quantity: state.quantity + 1));

  void decrementQuantity() {
    if (state.quantity > 1) emit(state.copyWith(quantity: state.quantity - 1));
  }

  void processBarcode(String code, {required bool isFromDataBarang}) {
    Map<String, dynamic>? match;
    for (final product in ProductData.registeredProducts) {
      if ((product['barcode'] ?? '').toString().trim() == code.trim()) {
        match = product;
        break;
      }
    }

    if (match != null) {
      emit(
        state.copyWith(
          detectedBarcode: code,
          scannedProduct: {
            'id': match['id'],
            'name': match['name'],
            'barcode': match['barcode'],
            'unitPrice': match['price'] ?? match['unitPrice'] ?? 0,
            'costPrice': match['costPrice'] ?? match['cost_price'] ?? 0,
            'stock': match['stock'] ?? 0,
          },
          status: ScannerStatus.scanSuccess,
        ),
      );
    } else {
      emit(
        state.copyWith(
          detectedBarcode: code,
          clearProduct: true,
          status: isFromDataBarang
              ? ScannerStatus.scanSuccess
              : ScannerStatus.scanNotFound,
        ),
      );
    }
  }
}
