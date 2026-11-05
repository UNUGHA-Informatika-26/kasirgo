# KasirGo

KasirGo adalah aplikasi kasir dan inventory berbasis Flutter. Aplikasi ini menangani autentikasi, produk, keranjang belanja, transaksi penjualan, laporan, penyimpanan offline, pemindaian barcode, dan pencetakan nota.

Dokumentasi ini dibuat berdasarkan implementasi yang ada di repository saat ini.

## Teknologi

- Flutter/Dart dengan Material 3.
- `flutter_bloc` untuk state management berbasis Cubit.
- Supabase untuk autentikasi dan penyimpanan data cloud.
- Hive CE untuk cache dan penyimpanan offline lokal.
- `connectivity_plus` untuk mendeteksi koneksi dan memicu sinkronisasi.
- `mobile_scanner` untuk pemindaian barcode.
- `flutter_bluetooth_printer` untuk printer Bluetooth thermal.
- `pdf` dan `printing` untuk membuat, preview, berbagi, dan mencetak nota PDF.
- `uuid` untuk ID lokal/transaksi.

Dependency lengkap tersedia di [pubspec.yaml](pubspec.yaml).

## Fitur aplikasi

### Autentikasi

- Splash screen dan pemulihan sesi otomatis.
- Login, registrasi, logout, dan reset password melalui email.
- Pengelolaan profil toko saat registrasi.
- Status loading, berhasil, dan error melalui `AuthCubit`.

Implementasi: [lib/auth/](lib/auth/), terutama [auth_cubit.dart](lib/auth/cubit/auth_cubit.dart), [login_pages.dart](lib/auth/login_pages.dart), [register_pages.dart](lib/auth/register_pages.dart), dan [forgot_password_page.dart](lib/auth/forgot_password_page.dart).

### Beranda dan navigasi

- Halaman utama setelah login.
- Navigasi ke Dashboard, Produk, Keranjang, dan Laporan.
- Tab aktif disimpan oleh `HomeCubit`.

Implementasi: [home_page.dart](lib/features/home/pages/home_page.dart) dan [home_cubit.dart](lib/features/home/cubit/home_cubit.dart).

### Manajemen produk

- Menampilkan dan mencari produk.
- Menambah, mengubah, dan menghapus produk.
- Data nama, barcode, harga modal, harga jual, stok, dan status produk.
- Pemindaian barcode saat mengisi atau mencari produk.
- Memuat ulang data ketika ada perubahan produk.

Implementasi: [products_page.dart](lib/features/products/pages/products_page.dart) dan [products_cubit.dart](lib/features/products/cubit/products_cubit.dart).

### Keranjang dan transaksi

- Menambah produk secara manual atau melalui barcode.
- Menambah/mengurangi jumlah item dan mengosongkan keranjang.
- Perhitungan total harga dan total unit.
- Persistensi dan pemulihan keranjang dari penyimpanan lokal.
- Checkout dengan metode Tunai, QRIS, atau Transfer.
- Perhitungan uang diterima dan kembalian untuk pembayaran tunai.
- Validasi stok dan pencegahan overselling di database.
- Detail dan nota transaksi.

Implementasi: [cart_page.dart](lib/features/cart/pages/cart_page.dart) dan [cart_cubit.dart](lib/features/cart/cubit/cart_cubit.dart).

### Dashboard

- Daftar dan pencarian transaksi.
- Ringkasan data penjualan.
- Perubahan profil toko: nama, alamat, nomor telepon, dan email.
- Pemuatan ulang transaksi setelah sinkronisasi.

Implementasi: [dashboard_page.dart](lib/features/dashboard/pages/dashboard_page.dart) dan [dashboard_cubit.dart](lib/features/dashboard/cubit/dashboard_cubit.dart).

### Laporan

- Laporan harian, bulanan, dan tahunan.
- Filter tanggal, bulan, dan tahun.
- Ringkasan omzet, laba, dan jumlah transaksi.
- Grafik penjualan dan daftar nota.
- Rincian transaksi berdasarkan periode.
- Navigasi dari laporan tahunan ke bulanan dan dari bulanan ke harian.

Implementasi: [reports_page.dart](lib/features/reports/pages/reports_page.dart) dan [reports_cubit.dart](lib/features/reports/cubit/reports_cubit.dart).

### Scanner dan printer

- Scanner barcode dengan status izin kamera, proses scan, sukses, dan tidak ditemukan.
- Kontrol flashlight dan jumlah produk hasil scan.
- Pembuatan, preview, penyimpanan, dan berbagi nota PDF.
- Pencarian perangkat dan pencetakan nota melalui printer Bluetooth.

Implementasi scanner berada di [barcode_scanner_screen.dart](lib/shared/widgets/barcode_scanner_screen.dart) dan [scanner_cubit.dart](lib/shared/widgets/scanner_cubit.dart). Implementasi nota/printer berada di [receipt_pdf_helper.dart](lib/shared/utils/receipt_pdf_helper.dart), [receipt_pdf_preview.dart](lib/shared/widgets/receipt_pdf_preview.dart), [bluetooth_printer_cubit.dart](lib/shared/printer/bluetooth_printer_cubit.dart), dan [bluetooth_printer_dialog.dart](lib/shared/printer/bluetooth_printer_dialog.dart).

### Mode offline dan sinkronisasi

- Cache profil, produk, keranjang, dan transaksi menggunakan Hive.
- Antrean operasi yang belum terkirim ke server.
- Deteksi koneksi dan sinkronisasi saat koneksi kembali.
- Revision counter untuk memberi tahu halaman produk/transaksi bahwa data berubah.
- Status offline melalui `SyncCubit`.

Implementasi: [offline_store.dart](lib/shared/services/offline_store.dart), [supabase_service.dart](lib/shared/services/supabase_service.dart), dan [sync_cubit.dart](lib/shared/cubit/sync_cubit.dart).

## Arsitektur dan state management

Struktur aplikasi menggunakan pendekatan feature-based:

```text
lib/
├── auth/                 # autentikasi dan AuthCubit
├── features/
│   ├── home/             # navigasi utama
│   ├── products/         # produk
│   ├── cart/             # keranjang dan pembayaran
│   ├── dashboard/        # transaksi dan profil toko
│   └── reports/          # laporan
└── shared/
    ├── cubit/            # state lintas fitur
    ├── data/             # data profil dan model sederhana
    ├── printer/          # Bluetooth printer
    ├── services/         # Supabase dan penyimpanan offline
    ├── utils/            # formatter, kalkulasi, dan PDF
    └── widgets/          # scanner dan widget bersama
```

| Cubit | Tanggung jawab |
|---|---|
| `AuthCubit` | Login, registrasi, logout, restore session, reset password, visibilitas password |
| `HomeCubit` | Tab navigasi aktif |
| `ProductsCubit` | Daftar, pencarian, CRUD, dan loading produk |
| `CartCubit` | Isi keranjang, pencarian, jumlah item, total, dan persistensi |
| `PaymentCubit` | Metode pembayaran, uang tunai, dan kembalian |
| `DashboardCubit` | Daftar/pencarian transaksi dan pembaruan profil |
| `ReportsCubit` | Filter dan data ringkasan laporan |
| `ScannerCubit` | Status scanner, flashlight, barcode, dan jumlah hasil scan |
| `BluetoothPrinterCubit` | Scan printer, status printer, dan pencetakan |
| `SyncCubit` | Status offline dan perubahan produk/transaksi |

State aplikasi utama menggunakan Cubit dengan `BlocProvider`, `BlocBuilder`, dan `BlocListener`. Tidak ditemukan penggunaan `setState()` untuk state bisnis. State lokal Flutter tetap memakai `StatefulWidget`, `TextEditingController`, `AnimationController`, `MobileScannerController`, dan `StreamSubscription` untuk lifecycle, input form, animasi, kamera, dan listener koneksi.

## Backend dan data

`SupabaseService` menjadi service utama untuk autentikasi, profil toko, produk, transaksi, item transaksi, dan sinkronisasi offline. [OfflineStore](lib/shared/services/offline_store.dart) menangani cache lokal dan antrean perubahan.

Migration database tersedia di [supabase/migrations/](supabase/migrations/):

- penambahan `unit_cost` pada item transaksi;
- pengurangan stok saat transaksi selesai;
- validasi jumlah stok untuk mencegah overselling;
- validasi bahwa transaksi dibuat oleh pengguna yang sedang login.

## Menjalankan proyek

### Prasyarat

- Flutter SDK yang kompatibel dengan Dart SDK `^3.13.5`.
- Android Studio/Xcode sesuai target platform.
- Project Supabase yang sudah dikonfigurasi.
- Perangkat/emulator untuk menguji kamera dan printer Bluetooth.

### Instalasi dan menjalankan

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Untuk memilih perangkat tertentu:

```bash
flutter devices
flutter run -d <device-id>
```

### Konfigurasi Supabase

Konfigurasi Supabase saat ini berada di [supabase_service.dart](lib/shared/services/supabase_service.dart). Sebelum production, URL dan key sebaiknya dipindahkan ke konfigurasi environment/build flavor, bukan ditulis langsung di source code. Migration di [supabase/migrations/](supabase/migrations/) juga perlu diterapkan ke database Supabase yang digunakan.

## Pengujian

Test yang tersedia mencakup state Cubit, formatter mata uang, kalkulasi laba, pembuatan nota PDF, dan widget test dasar. File test berada di [test/](test/).

```bash
flutter test
```

## Asset dan platform

- Asset gambar aplikasi berada di [assets/images/](assets/images/), termasuk logo dan splash screen.
- Scaffold Flutter untuk Android, iOS, Windows, macOS, Linux, dan Web tersedia di repository.
- Fitur kamera dan printer Bluetooth bergantung pada permission serta kemampuan platform yang digunakan.

## Catatan pengembangan

- `SupabaseService` dan `OfflineStore` adalah lapisan service/data utama.
- `UserData` menyimpan sebagian data profil toko dalam properti statis yang digunakan oleh halaman aplikasi.
- Data transaksi offline menggunakan UUID dan akan disinkronkan ketika memungkinkan.
- Jalankan `flutter analyze` dan `flutter test` sebelum rilis untuk memeriksa kode dan test otomatis.
- Sebelum deployment production, verifikasi credential, permission kamera/Bluetooth, kebijakan keamanan Supabase, dan migration database.
