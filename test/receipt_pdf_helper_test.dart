import 'package:flutter_test/flutter_test.dart';
import 'package:kasirgo/shared/utils/receipt_pdf_helper.dart';

void main() {
  test('generates a PDF receipt with the transaction details', () async {
    final pdf = await ReceiptPdfHelper.generateReceiptPdf(
      trxId: 'trx-001',
      totalBayar: 6000,
      paymentMethod: 'Tunai',
      cashReceived: 10000,
      kembalian: 4000,
      cartItems: [
        {'name': 'Produk', 'quantity': 1, 'unitPrice': 6000},
      ],
      transactionDate: DateTime(2026, 1, 1, 12),
      storeName: 'Toko',
      storeAddress: 'Jl. Contoh',
      storePhone: '08123456789',
    );

    expect(pdf, isNotEmpty);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
  });
}
