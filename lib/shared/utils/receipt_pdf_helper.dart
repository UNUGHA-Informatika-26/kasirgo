import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'currency_formatter.dart';

class ReceiptPdfHelper {
  // Format ukuran kertas thermal 58mm
  static final PdfPageFormat format58mm = PdfPageFormat(
    58 * PdfPageFormat.mm,
    double.infinity,
    marginTop: 3 * PdfPageFormat.mm,
    marginBottom: 3 * PdfPageFormat.mm,
    marginLeft: 2.5 * PdfPageFormat.mm,
    marginRight: 2.5 * PdfPageFormat.mm,
  );

  // Generate Dokumen PDF Struk 58mm Bergaya Minimarket
  static Future<Uint8List> generateReceiptPdf({
    required String trxId,
    required int totalBayar,
    required String paymentMethod,
    required int cashReceived,
    required int kembalian,
    required List<Map<String, dynamic>> cartItems,
    DateTime? transactionDate,
    String storeName = '',
    String storeAddress = '',
    String storePhone = '',
  }) async {
    final pdf = pw.Document();
    final date = transactionDate ?? DateTime.now();

    final fontCourier = pw.Font.helvetica();
    final fontCourierBold = pw.Font.helveticaBold();

    pdf.addPage(
      pw.Page(
        pageFormat: format58mm,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. Header Toko
              pw.Center(
                child: pw.Text(
                  storeName.toUpperCase(),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: fontCourierBold,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  storeAddress,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: fontCourier,
                    fontSize: 6.5,
                    color: PdfColors.black,
                  ),
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Center(
                child: pw.Text(
                  'Telp/WA: $storePhone',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: fontCourier,
                    fontSize: 6,
                    color: PdfColors.black,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),

              // Dashed Line 1
              pw.Text(
                '------------------------------------------',
                maxLines: 1,
                style: pw.TextStyle(
                  font: fontCourier,
                  fontSize: 6,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 3),

              // 2. Info Transaksi
              pw.Text(
                'NO. TRANSAKSI',
                style: pw.TextStyle(font: fontCourier, fontSize: 5.5),
              ),
              pw.SizedBox(height: 1),
              pw.SizedBox(
                width: format58mm.availableWidth,
                child: pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    trxId,
                    maxLines: 1,
                    softWrap: false,
                    style: pw.TextStyle(font: fontCourierBold, fontSize: 9),
                  ),
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                'TANGGAL  : ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                style: pw.TextStyle(font: fontCourier, fontSize: 6),
              ),
              pw.SizedBox(height: 3),

              // Dashed Line 2
              pw.Text(
                '------------------------------------------',
                maxLines: 1,
                style: pw.TextStyle(
                  font: fontCourier,
                  fontSize: 6,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 3),

              // 3. Daftar Barang Belanjaan (Layout 2 Baris Minimarket)
              ...cartItems.map((item) {
                final qty = item['quantity'] as int;
                final price = item['unitPrice'] as int;
                final total = qty * price;

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Baris 1: Nama Produk
                      pw.Text(
                        item['name'].toString().toUpperCase(),
                        style: pw.TextStyle(
                          font: fontCourierBold,
                          fontSize: 6.5,
                        ),
                      ),
                      // Baris 2: Qty x Harga & Total
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '$qty x ${CurrencyFormatter.formatRupiah(price, spaceAfterSymbol: true)}',
                            style: pw.TextStyle(font: fontCourier, fontSize: 6),
                          ),
                          pw.Text(
                            CurrencyFormatter.formatRupiah(
                              total,
                              spaceAfterSymbol: true,
                            ),
                            style: pw.TextStyle(
                              font: fontCourier,
                              fontSize: 6.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              // Dashed Line 3
              pw.Text(
                '------------------------------------------',
                maxLines: 1,
                style: pw.TextStyle(
                  font: fontCourier,
                  fontSize: 6,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 3),

              // 4. Ringkasan Total & Pembayaran
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(font: fontCourierBold, fontSize: 7.5),
                  ),
                  pw.Text(
                    CurrencyFormatter.formatRupiah(
                      totalBayar,
                      spaceAfterSymbol: true,
                    ),
                    style: pw.TextStyle(font: fontCourierBold, fontSize: 7.5),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),

              // Metode Pembayaran
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Metode',
                    style: pw.TextStyle(font: fontCourier, fontSize: 6.5),
                  ),
                  pw.Text(
                    paymentMethod,
                    style: pw.TextStyle(font: fontCourier, fontSize: 6.5),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),

              // Uang diterima
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Uang diterima',
                    style: pw.TextStyle(font: fontCourier, fontSize: 6.5),
                  ),
                  pw.Text(
                    CurrencyFormatter.formatRupiah(
                      cashReceived,
                      spaceAfterSymbol: true,
                    ),
                    style: pw.TextStyle(font: fontCourier, fontSize: 6.5),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),

              // Kembalian
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Kembali',
                    style: pw.TextStyle(font: fontCourier, fontSize: 6.5),
                  ),
                  pw.Text(
                    CurrencyFormatter.formatRupiah(
                      kembalian,
                      spaceAfterSymbol: true,
                    ),
                    style: pw.TextStyle(font: fontCourier, fontSize: 6.5),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),

              // Dashed Line 4
              pw.Text(
                '==========================================',
                maxLines: 1,
                style: pw.TextStyle(
                  font: fontCourier,
                  fontSize: 6,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 4),

              // 5. Footer Struk Minimarket
              pw.Center(
                child: pw.Text(
                  'TERIMA KASIH',
                  style: pw.TextStyle(font: fontCourierBold, fontSize: 7),
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Center(
                child: pw.Text(
                  'SELAMAT BERBELANJA KEMBALI',
                  style: pw.TextStyle(font: fontCourier, fontSize: 6),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // 1. Simpan / Unduh / Share File PDF Struk
  static Future<void> saveAndSharePdf({
    required String trxId,
    required int totalBayar,
    required String paymentMethod,
    required int cashReceived,
    required int kembalian,
    required List<Map<String, dynamic>> cartItems,
    DateTime? transactionDate,
    String storeName = '',
    String storeAddress = '',
    String storePhone = '',
  }) async {
    final pdfBytes = await generateReceiptPdf(
      trxId: trxId,
      totalBayar: totalBayar,
      paymentMethod: paymentMethod,
      cashReceived: cashReceived,
      kembalian: kembalian,
      cartItems: cartItems,
      transactionDate: transactionDate,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
    );

    await Printing.sharePdf(bytes: pdfBytes, filename: '$trxId.pdf');
  }

  // 2. Cetak Struk Langsung ke Printer Thermal (Bluetooth / USB / Network Printer)
  static Future<void> printReceiptToPrinter({
    required String trxId,
    required int totalBayar,
    required String paymentMethod,
    required int cashReceived,
    required int kembalian,
    required List<Map<String, dynamic>> cartItems,
    DateTime? transactionDate,
    String storeName = '',
    String storeAddress = '',
    String storePhone = '',
  }) async {
    final pdfBytes = await generateReceiptPdf(
      trxId: trxId,
      totalBayar: totalBayar,
      paymentMethod: paymentMethod,
      cashReceived: cashReceived,
      kembalian: kembalian,
      cartItems: cartItems,
      transactionDate: transactionDate,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: trxId,
    );
  }
}
