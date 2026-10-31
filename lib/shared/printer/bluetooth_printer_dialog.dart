import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bluetooth_printer_cubit.dart';

class BluetoothPrinterDialog extends StatefulWidget {
  final ReceiptPrintData receipt;
  final BuildContext parentContext;

  const BluetoothPrinterDialog({
    super.key,
    required this.receipt,
    required this.parentContext,
  });

  static Future<void> show(
    BuildContext context, {
    required ReceiptPrintData receipt,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          BluetoothPrinterDialog(receipt: receipt, parentContext: context),
    );
  }

  @override
  State<BluetoothPrinterDialog> createState() => _BluetoothPrinterDialogState();
}

class _BluetoothPrinterDialogState extends State<BluetoothPrinterDialog> {
  late final BluetoothPrinterCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = BluetoothPrinterCubit();
    unawaited(_cubit.scan());
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocListener<BluetoothPrinterCubit, BluetoothPrinterState>(
        listenWhen: (previous, current) =>
            previous.isPrinted != current.isPrinted && current.isPrinted,
        listener: (context, state) {
          final messenger = ScaffoldMessenger.maybeOf(widget.parentContext);
          Navigator.of(context).pop();
          messenger?.showSnackBar(
            const SnackBar(content: Text('Struk berhasil dicetak.')),
          );
        },
        child: BlocBuilder<BluetoothPrinterCubit, BluetoothPrinterState>(
          builder: (context, state) => AlertDialog(
            title: const Text('Printer Bluetooth'),
            content: SizedBox(
              width: double.maxFinite,
              child: state.isScanning
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : state.printers.isEmpty
                  ? Text(state.error ?? 'Tidak ada printer ditemukan.')
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        if (state.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              state.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        for (final printer in state.printers)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.print_outlined),
                            title: Text(printer.name ?? 'Printer Tanpa Nama'),
                            subtitle: Text(printer.address),
                            trailing: state.isPrinting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : null,
                            onTap: state.isPrinting
                                ? null
                                : () => unawaited(
                                    _cubit.printReceipt(
                                      printer,
                                      widget.receipt,
                                    ),
                                  ),
                          ),
                      ],
                    ),
            ),
            actions: [
              if (!state.isScanning && !state.isPrinting)
                TextButton.icon(
                  onPressed: () => unawaited(_cubit.scan()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Cari lagi'),
                ),
              TextButton(
                onPressed: state.isPrinting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
