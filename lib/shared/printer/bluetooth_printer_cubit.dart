import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';

import '../utils/currency_formatter.dart';

class ReceiptPrintData {
  final String transactionId;
  final int totalAmount;
  final String paymentMethod;
  final int cashReceived;
  final int changeAmount;
  final List<Map<String, dynamic>> items;
  final DateTime createdAt;
  final String storeName;
  final String storeAddress;
  final String storePhone;

  const ReceiptPrintData({
    required this.transactionId,
    required this.totalAmount,
    required this.paymentMethod,
    required this.cashReceived,
    required this.changeAmount,
    required this.items,
    required this.createdAt,
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
  });
}

class BluetoothPrinterState {
  final List<BluetoothDevice> printers;
  final bool isScanning;
  final bool isPrinting;
  final bool isPrinted;
  final String? error;

  const BluetoothPrinterState({
    this.printers = const [],
    this.isScanning = false,
    this.isPrinting = false,
    this.isPrinted = false,
    this.error,
  });

  BluetoothPrinterState copyWith({
    List<BluetoothDevice>? printers,
    bool? isScanning,
    bool? isPrinting,
    bool? isPrinted,
    String? error,
    bool clearError = false,
  }) {
    return BluetoothPrinterState(
      printers: printers ?? this.printers,
      isScanning: isScanning ?? this.isScanning,
      isPrinting: isPrinting ?? this.isPrinting,
      isPrinted: isPrinted ?? this.isPrinted,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class BluetoothPrinterCubit extends Cubit<BluetoothPrinterState> {
  BluetoothPrinterCubit() : super(const BluetoothPrinterState());

  StreamSubscription<dynamic>? _discoverySubscription;

  Future<void> scan() async {
    await _discoverySubscription?.cancel();
    final found = <String, BluetoothDevice>{};
    emit(
      state.copyWith(printers: const [], isScanning: true, clearError: true),
    );

    try {
      _discoverySubscription = FlutterBluetoothPrinter.discovery.listen(
        (discoveryState) {
          if (discoveryState is DiscoveryResult) {
            for (final printer in discoveryState.devices) {
              found[printer.address] = printer;
            }
            if (!isClosed) {
              emit(state.copyWith(printers: found.values.toList()));
            }
          } else if (discoveryState is BluetoothDisabledState) {
            if (!isClosed) {
              emit(
                state.copyWith(
                  error: 'Aktifkan Bluetooth di Android, lalu cari lagi.',
                ),
              );
            }
          } else if (discoveryState is PermissionRestrictedState) {
            if (!isClosed) {
              emit(
                state.copyWith(
                  error:
                      'Izin Bluetooth ditolak. Izinkan akses perangkat '
                      'terdekat untuk KasirGo di Setelan Android.',
                ),
              );
            }
          }
        },
        onError: (Object error) {
          if (!isClosed) {
            emit(
              state.copyWith(error: 'Gagal mencari printer Bluetooth: $error'),
            );
          }
        },
      );
      await Future<void>.delayed(const Duration(seconds: 10));
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;
      if (!isClosed) {
        emit(
          state.copyWith(
            isScanning: false,
            error: found.isEmpty && state.error == null
                ? 'Printer tidak ditemukan. Pastikan printer menyala dan '
                      'sudah dipasangkan melalui Setelan Bluetooth Android.'
                : state.error,
          ),
        );
      }
    } catch (error) {
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;
      if (!isClosed) {
        emit(
          state.copyWith(
            isScanning: false,
            error: 'Gagal mencari printer Bluetooth: $error',
          ),
        );
      }
    }
  }

  Future<void> printReceipt(
    BluetoothDevice printer,
    ReceiptPrintData receipt,
  ) async {
    if (state.isPrinting) return;
    emit(state.copyWith(isPrinting: true, isPrinted: false, clearError: true));

    var connected = false;
    String? errorMessage;
    try {
      connected = await FlutterBluetoothPrinter.connect(printer.address);
      if (!connected) {
        throw StateError(
          'Tidak dapat terhubung ke ${printer.name ?? printer.address}.',
        );
      }
      final printed = await FlutterBluetoothPrinter.printBytes(
        address: printer.address,
        data: _buildTicket(receipt),
        keepConnected: true,
      );
      if (!printed) {
        throw StateError('Printer tidak menerima data struk.');
      }
    } catch (error) {
      errorMessage = 'Gagal mencetak struk: $error';
    } finally {
      if (connected) {
        try {
          await FlutterBluetoothPrinter.disconnect(printer.address);
        } catch (error) {
          errorMessage ??=
              'Struk terkirim, tetapi koneksi printer gagal '
              'ditutup: $error';
        }
      }
    }

    if (isClosed) return;
    if (errorMessage != null) {
      emit(state.copyWith(isPrinting: false, error: errorMessage));
    } else {
      emit(state.copyWith(isPrinting: false, isPrinted: true));
    }
  }

  Uint8List _buildTicket(ReceiptPrintData receipt) {
    final bytes = <int>[0x1B, 0x40];

    if (receipt.storeName.trim().isNotEmpty) {
      bytes.addAll([0x1B, 0x61, 0x01, 0x1B, 0x45, 0x01]);
      _appendText(bytes, receipt.storeName.toUpperCase());
      bytes.addAll([0x1B, 0x45, 0x00, 0x1B, 0x61, 0x00]);
    }
    if (receipt.storeAddress.trim().isNotEmpty) {
      _appendWrappedText(bytes, receipt.storeAddress);
    }
    if (receipt.storePhone.trim().isNotEmpty) {
      _appendWrappedText(bytes, 'Tel: ${receipt.storePhone}');
    }

    _appendText(bytes, '--------------------------------');
    _appendText(bytes, 'No: ${receipt.transactionId}');
    _appendText(bytes, _formatDate(receipt.createdAt));
    _appendText(bytes, '--------------------------------');

    for (final item in receipt.items) {
      final name = item['name']?.toString() ?? 'Produk';
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      final unitPrice = (item['unitPrice'] as num?)?.toInt() ?? 0;
      _appendWrappedText(bytes, name.toUpperCase());
      _appendText(
        bytes,
        _formatRow(
          '$quantity x ${_formatRupiah(unitPrice)}',
          _formatRupiah(quantity * unitPrice),
        ),
      );
    }

    _appendText(bytes, '--------------------------------');
    bytes.addAll([0x1B, 0x45, 0x01]);
    _appendText(bytes, _formatRow('TOTAL', _formatRupiah(receipt.totalAmount)));
    bytes.addAll([0x1B, 0x45, 0x00]);
    _appendWrappedText(bytes, 'Pembayaran: ${receipt.paymentMethod}');
    if (receipt.paymentMethod.toLowerCase() == 'tunai') {
      _appendWrappedText(
        bytes,
        'Tunai: ${_formatRupiah(receipt.cashReceived)}',
      );
      _appendWrappedText(
        bytes,
        'Kembali: ${_formatRupiah(receipt.changeAmount)}',
      );
    }
    _appendText(bytes, '--------------------------------');
    bytes.addAll([0x1B, 0x61, 0x01]);
    _appendText(bytes, 'Terima kasih');
    bytes.addAll([0x1B, 0x61, 0x00, 0x0A, 0x0A, 0x0A, 0x1D, 0x56, 0x00]);

    return Uint8List.fromList(bytes);
  }

  void _appendText(List<int> bytes, String text) {
    bytes.addAll(text.runes.map((rune) => rune <= 0xFF ? rune : 0x3F));
    bytes.add(0x0A);
  }

  void _appendWrappedText(List<int> bytes, String text) {
    final characters = text.runes.toList();
    for (var start = 0; start < characters.length; start += 32) {
      final chunk = String.fromCharCodes(characters.skip(start).take(32));
      _appendText(bytes, chunk);
    }
  }

  String _formatRow(String left, String right) {
    final rightText = right.length > 31
        ? right.substring(right.length - 31)
        : right;
    final availableLeft = 31 - rightText.length;
    final leftText = left.length > availableLeft
        ? left.substring(left.length - availableLeft)
        : left;
    return '${leftText.padRight(availableLeft)} $rightText';
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatRupiah(int amount) {
    return CurrencyFormatter.formatRupiah(amount);
  }

  @override
  Future<void> close() async {
    await _discoverySubscription?.cancel();
    return super.close();
  }
}
