import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../utils/receipt_pdf_helper.dart';

class ReceiptPdfPreview extends StatelessWidget {
  final String transactionId;
  final int totalAmount;
  final String paymentMethod;
  final int cashReceived;
  final int changeAmount;
  final List<Map<String, dynamic>> items;
  final DateTime transactionDate;
  final String storeName;
  final String storeAddress;
  final String storePhone;

  const ReceiptPdfPreview({
    super.key,
    required this.transactionId,
    required this.totalAmount,
    required this.paymentMethod,
    required this.cashReceived,
    required this.changeAmount,
    required this.items,
    required this.transactionDate,
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
  });

  static Future<void> show(
    BuildContext context, {
    required String transactionId,
    required int totalAmount,
    required String paymentMethod,
    required int cashReceived,
    required int changeAmount,
    required List<Map<String, dynamic>> items,
    required DateTime transactionDate,
    required String storeName,
    required String storeAddress,
    required String storePhone,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ReceiptPdfPreview(
          transactionId: transactionId,
          totalAmount: totalAmount,
          paymentMethod: paymentMethod,
          cashReceived: cashReceived,
          changeAmount: changeAmount,
          items: items,
          transactionDate: transactionDate,
          storeName: storeName,
          storeAddress: storeAddress,
          storePhone: storePhone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pratinjau PDF Struk'),
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Simpan PDF',
            onPressed: () async {
              try {
                await ReceiptPdfHelper.saveAndSharePdf(
                  trxId: transactionId,
                  totalBayar: totalAmount,
                  paymentMethod: paymentMethod,
                  cashReceived: cashReceived,
                  kembalian: changeAmount,
                  cartItems: items,
                  transactionDate: transactionDate,
                  storeName: storeName,
                  storeAddress: storeAddress,
                  storePhone: storePhone,
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal menyimpan PDF: $error')),
                );
              }
            },
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) => ReceiptPdfHelper.generateReceiptPdf(
          trxId: transactionId,
          totalBayar: totalAmount,
          paymentMethod: paymentMethod,
          cashReceived: cashReceived,
          kembalian: changeAmount,
          cartItems: items,
          transactionDate: transactionDate,
          storeName: storeName,
          storeAddress: storeAddress,
          storePhone: storePhone,
        ),
        initialPageFormat: ReceiptPdfHelper.format58mm,
        pageFormats: {'Struk 58 mm': ReceiptPdfHelper.format58mm},
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: '$transactionId.pdf',
        allowPrinting: true,
        allowSharing: false,
      ),
    );
  }
}
