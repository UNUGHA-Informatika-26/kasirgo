import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scanner_cubit.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final Function(Map<String, dynamic> product, int qty)? onAddProductToCart;
  final Function(String barcode)? onBarcodeScanned;

  const BarcodeScannerScreen({
    super.key,
    this.onAddProductToCart,
    this.onBarcodeScanned,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  final ScannerCubit _scannerCubit = ScannerCubit();

  late final AnimationController _animationController;
  late final Animation<double> _laserAnimation;

  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool get _isFromDataBarang => widget.onBarcodeScanned != null;
  ScannerStatus get _status => _scannerCubit.state.status;
  bool get _isFlashOn => _scannerCubit.state.isFlashOn;
  int get _scanQuantity => _scannerCubit.state.quantity;
  String get _detectedBarcode => _scannerCubit.state.detectedBarcode;
  Map<String, dynamic> get _scannedProduct =>
      _scannerCubit.state.scannedProduct;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _laserAnimation = Tween<double>(begin: 12.0, end: 210.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController.dispose();
    _scannerCubit.close();
    super.dispose();
  }

  void _toggleFlashlight() {
    _scannerCubit.toggleFlashlight();
    _scannerController.toggleTorch();
  }

  void _processScannedBarcode(String code) {
    _scannerCubit.processBarcode(code, isFromDataBarang: _isFromDataBarang);
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF0F172A);
    const cardDark = Color(0xFF1E293B);
    const primaryBlue = Color(0xFF2563EB);
    const successGreen = Color(0xFF10B981);
    const errorRed = Color(0xFFEF4444);

    Color frameColor = Colors.white;
    if (_status == ScannerStatus.scanSuccess) {
      frameColor = successGreen;
    } else if (_status == ScannerStatus.scanNotFound) {
      frameColor = errorRed;
    }

    final titleText = _isFromDataBarang
        ? 'Scan Barcode Produk Baru'
        : 'Scan Barcode Kasir';

    return BlocBuilder<ScannerCubit, ScannerState>(
      bloc: _scannerCubit,
      builder: (context, state) => Scaffold(
        backgroundColor: darkBg,
        body: SafeArea(
          child: Column(
            children: [
              // Top App Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close Button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cardDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    // Title
                    Text(
                      titleText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    // Flashlight Button
                    GestureDetector(
                      onTap: _toggleFlashlight,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cardDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isFlashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: _isFlashOn ? primaryBlue : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Body Content berdasarkan Status
              Expanded(
                child: _status == ScannerStatus.permissionDenied
                    ? _buildPermissionDeniedView(context)
                    : _buildScannerOverlayView(frameColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // View State 0: Izin Kamera Ditolak
  Widget _buildPermissionDeniedView(BuildContext context) {
    const cardDark = Color(0xFF1E293B);
    const primaryBlue = Color(0xFF2563EB);
    const textGrey = Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: cardDark,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.no_photography_outlined,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Izin kamera ditolak',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Aktifkan akses kamera untuk KasirGo di pengaturan perangkat agar dapat memindai barcode produk.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: textGrey, height: 1.4),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                _scannerCubit.retry();
              },
              child: const Text(
                'Coba Buka Kamera',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Anda tetap bisa memasukkan kode barang secara manual.',
            style: TextStyle(fontSize: 13, color: textGrey),
          ),
        ],
      ),
    );
  }

  // View State 1, 2, 3: Fullscreen Scanner & Overlay dengan Live Kamera
  Widget _buildScannerOverlayView(Color frameColor) {
    const cardDark = Color(0xFF1E293B);
    const textGrey = Color(0xFF94A3B8);

    return Column(
      children: [
        const SizedBox(height: 20),
        // Scanner Box Frame dengan Live Preview Kamera & Laser Animasi
        Container(
          width: 280,
          height: 240,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Live Stream Kamera Fisik HP
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MobileScanner(
                  controller: _scannerController,
                  fit: BoxFit.cover,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null &&
                          barcode.rawValue!.isNotEmpty) {
                        _processScannedBarcode(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                  errorBuilder: (context, error) {
                    return const Center(
                      child: Text(
                        'Kamera tidak tersedia',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    );
                  },
                ),
              ),

              // 4 Bracket Corners Frame
              _buildCornerBracket(Alignment.topLeft, frameColor),
              _buildCornerBracket(Alignment.topRight, frameColor),
              _buildCornerBracket(Alignment.bottomLeft, frameColor),
              _buildCornerBracket(Alignment.bottomRight, frameColor),

              // Garis Laser Animasi Bergerak Naik-Turun
              AnimatedBuilder(
                animation: _laserAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: _laserAnimation.value,
                    left: 18,
                    right: 18,
                    child: Container(
                      height: 3.0,
                      decoration: BoxDecoration(
                        color: frameColor,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: frameColor.withAlpha(220),
                            blurRadius: 8,
                            spreadRadius: 1.5,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Text Subtitle
        Text(
          _isFromDataBarang
              ? 'Arahkan kamera ke kemasan barang untuk mengambil barcode'
              : 'Arahkan kamera ke barcode produk transaksi',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: textGrey),
        ),
        const SizedBox(height: 12),

        // Pill Badge Status ("Memindai...") jika sedang scanning
        if (_status == ScannerStatus.scanning)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cardDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'Memindai...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        const Spacer(),

        // Bottom Sheet Modal / Helper Text
        if (_status == ScannerStatus.scanning)
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              children: const [
                Text(
                  'Pastikan barcode terlihat jelas',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Jaga kamera tetap stabil dan gunakan flash jika cahaya kurang.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: textGrey),
                ),
              ],
            ),
          )
        else if (_status == ScannerStatus.scanSuccess)
          _buildScanSuccessModal()
        else if (_status == ScannerStatus.scanNotFound)
          _buildScanNotFoundModal(),
      ],
    );
  }

  // Modal Sheet untuk Scan Berhasil
  Widget _buildScanSuccessModal() {
    const textDark = Color(0xFF0F172A);
    const textGrey = Color(0xFF64748B);
    const successGreen = Color(0xFF10B981);
    const primaryBlue = Color(0xFF2563EB);

    final barcodeScanned = _detectedBarcode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Status
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: successGreen, size: 24),
              SizedBox(width: 8),
              Text(
                'Scan berhasil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Modal Khusus untuk DATA BARANG
          if (_isFromDataBarang) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kode Barcode Terdeteksi:',
                    style: TextStyle(fontSize: 12, color: textGrey),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    barcodeScanned,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textDark,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        _scannerCubit.retry();
                      },
                      child: const Text('Scan Ulang'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        widget.onBarcodeScanned!(barcodeScanned);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Gunakan Barcode Ini',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Modal Khusus untuk KASIR
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _scannedProduct['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      Text(
                        'Rp ${_scannedProduct['unitPrice']}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Barcode: $barcodeScanned',
                        style: const TextStyle(fontSize: 12, color: textGrey),
                      ),
                      Text(
                        (_scannedProduct['stock'] as num? ?? 0) <= 0
                            ? 'Habis'
                            : (_scannedProduct['stock'] as num? ?? 0) <= 5
                            ? 'Stok menipis • ${_scannedProduct['stock']}'
                            : 'Stok ${_scannedProduct['stock']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: (_scannedProduct['stock'] as num? ?? 0) <= 0
                              ? const Color(0xFFDC2626)
                              : (_scannedProduct['stock'] as num? ?? 0) <= 5
                              ? const Color(0xFFD97706)
                              : textGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Jumlah',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        _scannerCubit.decrementQuantity();
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.remove_rounded,
                            size: 18,
                            color: textDark,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$_scanQuantity',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap:
                          _scanQuantity <
                              ((_scannedProduct['stock'] as num?)?.toInt() ?? 0)
                          ? () => _scannerCubit.incrementQuantity(
                              maxQuantity:
                                  (_scannedProduct['stock'] as num?)?.toInt() ??
                                  0,
                            )
                          : null,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color:
                              _scanQuantity <
                                  ((_scannedProduct['stock'] as num?)
                                          ?.toInt() ??
                                      0)
                              ? primaryBlue
                              : const Color(0xFF94A3B8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textDark,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        _scannerCubit.retry();
                      },
                      child: const Text('Scan Lagi'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed:
                          ((_scannedProduct['stock'] as num?)?.toInt() ?? 0) > 0
                          ? () {
                              if (widget.onAddProductToCart != null) {
                                widget.onAddProductToCart!(
                                  _scannedProduct,
                                  _scanQuantity,
                                );
                              }
                              Navigator.pop(context);
                            }
                          : null,
                      child: Text(
                        ((_scannedProduct['stock'] as num?)?.toInt() ?? 0) > 0
                            ? 'Tambah ke Keranjang'
                            : 'Stok habis',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Modal Sheet untuk Barcode Tidak Dikenali
  Widget _buildScanNotFoundModal() {
    const textDark = Color(0xFF0F172A);
    const textGrey = Color(0xFF64748B);
    const errorRed = Color(0xFFEF4444);
    const primaryBlue = Color(0xFF2563EB);
    final scannedCode = _detectedBarcode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Status
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: errorRed, size: 24),
              SizedBox(width: 8),
              Text(
                'Barcode tidak dikenali',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          const Text(
            'Produk belum terdaftar di Data Barang',
            style: TextStyle(fontSize: 14, color: textGrey),
          ),
          const SizedBox(height: 4),
          Text(
            'Barcode: $scannedCode',
            style: const TextStyle(fontSize: 13, color: textGrey),
          ),
          const SizedBox(height: 20),

          if (_isFromDataBarang) ...[
            SizedBox(
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  widget.onBarcodeScanned!(scannedCode);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Gunakan Barcode Ini',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: textDark,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _scannerCubit.retry();
                },
                child: const Text('Coba Scan Lagi'),
              ),
            ),
          ] else ...[
            SizedBox(
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _scannerCubit.retry();
                },
                child: const Text(
                  'Coba Scan Lagi',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: textDark,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Tambah Barang'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Builder 4 Sudut Bracket Frame Barcode
  Widget _buildCornerBracket(Alignment alignment, Color color) {
    const double length = 28;
    const double thickness = 3.5;

    final bool isTop =
        alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final bool isLeft =
        alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;

    return Align(
      alignment: alignment,
      child: SizedBox(
        width: length,
        height: length,
        child: Stack(
          children: [
            // Horizontal bar
            Positioned(
              top: isTop ? 0 : null,
              bottom: isTop ? null : 0,
              left: 0,
              right: 0,
              child: Container(height: thickness, color: color),
            ),
            // Vertical bar
            Positioned(
              left: isLeft ? 0 : null,
              right: isLeft ? null : 0,
              top: 0,
              bottom: 0,
              child: Container(width: thickness, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
