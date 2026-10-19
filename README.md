# Konco Space Customer App

Aplikasi Flutter untuk pelanggan coffee shop **Konco Space**. Memungkinkan pelanggan menjelajahi menu, melakukan kustomisasi pesanan, checkout dengan berbagai metode pembayaran digital/tunai, serta melacak status antrean pesanan secara real-time.

Aplikasi ini berkomunikasi langsung dengan backend Laravel melalui REST API menggunakan **Dio** dan autentikasi token **Laravel Sanctum**. Tidak ada koneksi langsung ke database — seluruh operasi data terisolasi melalui API.

> **Catatan Arsitektur:** Versi awal aplikasi ini menggunakan Supabase. Saat ini aplikasi telah **sepenuhnya dimigrasikan ke backend Laravel** (`Konco Space Admin/Backend`). Seluruh ketergantungan Supabase telah dihapus.

---

## Fitur Utama

### 1. Autentikasi & Manajemen Akun

- **Registrasi**: Pendaftaran akun baru (nama lengkap, email, nomor HP opsional, password). Registrasi langsung melakukan auto-login dan persistensi token.
- **Login**: Masuk dengan email dan password.
- **Session Persistence**: Token Sanctum dan profil pengguna tersimpan aman di perangkat via `flutter_secure_storage`.
- **Auto-Logout (401 Interceptor)**: Jika sesi kedaluwarsa atau token tidak valid, aplikasi otomatis membersihkan penyimpanan lokal dan mengarahkan kembali ke halaman Login.
- **Logout**: Memutus sesi aktif via API (`POST /auth/logout`) dan membersihkan data lokal.

### 2. Katalog & Eksplorasi Menu

- **Filter Kategori Dinamis**: Mengambil daftar kategori secara real-time dari `GET /categories` dengan opsi default "Semua".
- **Katalog Menu**: Menampilkan grid produk dari `GET /menus` beserta foto, harga, dan deskripsi singkat.
- **Lihat Semua**: Tombol "Lihat Semua" di Home membuka layar `AllProductsScreen` yang menampilkan seluruh menu (kategori "Semua") dalam grid penuh. Produk yang diketuk tetap membuka layar detail.

### 3. Detail & Kustomisasi Produk (Condiment Dinamis)

- **Grup & Opsi Condiment Dinamis**: Setiap produk memuat relasi `condiment_groups` dan `options` dari backend (contoh: _Ukuran_, _Tingkat Manis_, _Extra_).
- **Single-Select & Multi-Select**: Mendukung opsi wajib/opsional dan single/multi-select dengan penambahan harga masing-masing (`additional_price`).
- **Quantity Stepper**: Pengaturan jumlah pesanan secara langsung.
- **Sinkronisasi Backend**: Pilihan condiment dikirim sebagai `condiment_option_ids` terstruktur untuk pemotongan BOM backend, serta ringkasan teks otomatis pada `notes` per item pesanan.

### 4. Keranjang Belanja (Cart)

- Manajemen item: Tambah/kurang kuantitas atau hapus item.
- Kalkulasi harga dinamis: `unitPrice` dihitung dari harga dasar produk ditambah seluruh `additional_price` condiment yang dipilih. Subtotal dan total dihitung secara real-time.
- Identifikasi unik: Baris keranjang membedakan kombinasi condiment yang berbeda untuk produk yang sama.
- Navigasi cepat ke lembar pemilihan metode pembayaran.

### 5. Checkout & Multi-Metode Pembayaran

Mendukung 3 metode pembayaran utama:

- **Cash (Tunai)**: Pemesanan langsung masuk ke antrean, pembayaran diselesaikan di kasir fisik.
- **QRIS Dinamis**: Menampilkan kode QR (`qr_code_url` dari Midtrans) dengan mekanisme **auto-polling status setiap 4 detik**.
- **Virtual Account (VA)**: Pilihan bank transfer (**BCA**, **BNI**, **BRI**, **Mandiri**) lengkap dengan nomor VA, tombol salin ke clipboard, dan auto-polling status.

### 6. Pelacakan Pesanan (Order Tracking)

- **Timeline Status Interaktif**: Pembaruan status berkala melalui **polling setiap 5 detik**:
  $$\text{Pesanan Diterima (pending)} \longrightarrow \text{Sedang Dibuat (processing)} \longrightarrow \text{Siap Diambil (ready)} \longrightarrow \text{Selesai (completed)}$$
- **Polling Resilient**: Service menangani error transien (timeout/koneksi putus) secara transparan tanpa menginterupsi antarmuka polling.
- Informasi nomor antrean (`Antrean #X`) dan estimasi waktu penyiapan.
- Dialog konfirmasi otomatis saat pesanan telah berstatus `completed`.

### 7. Profil & Riwayat Pesanan

- **Informasi Pengguna**: Menampilkan nama, email, nomor telepon, dan tanggal bergabung dari `GET /auth/me`.
- **Riwayat Transaksi**: Daftar seluruh pesanan sebelumnya yang ditarik dari `GET /orders`.

---

## Tech Stack

| Layer                | Teknologi                            | Keterangan                                               |
| -------------------- | ------------------------------------ | -------------------------------------------------------- |
| **Framework**        | Flutter 3.44.x (Dart 3.11+)          | Mobile Multiplatform (Android/iOS)                       |
| **State Management** | `StatefulWidget` + static `AppState` | State reaktif terpusat                                   |
| **HTTP Client**      | `dio` ^5.4.0                         | Network client + Interceptors                            |
| **Secure Storage**   | `flutter_secure_storage` ^9.0.0      | Penyimpanan token terenkripsi                            |
| **Typography**       | `google_fonts` ^6.1.0                | Font family: Plus Jakarta Sans                           |
| **Icons**            | `lucide_icons_flutter` ^3.0.0        | Kompatibel dengan Flutter 3.44+ (`final class IconData`) |
| **Animations**       | `animations` ^2.0.11                 | Transisi halaman halus                                   |

---

## Design System

Token desain didefinisikan secara terpusat untuk menjaga konsistensi visual:

| Token          | Nilai Hex | Penggunaan                                                                |
| -------------- | --------- | ------------------------------------------------------------------------- |
| `kBrandDark`   | `#1C2C22` | Warna utama (Forest Deep Green / Espresso Dark), AppBar, tombol CTA utama |
| `kBrandAccent` | `#D4AF37` | Aksen emas, highlight status, badge, elemen aktif                         |
| `kBrandLight`  | `#F7F7F5` | Latar belakang layar (Scaffold Background)                                |
| `kBrandMuted`  | `#EEEEEB` | Border kartu, garis pembatas, background netral                           |

---

## Struktur Direktori

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart       ← Konfigurasi base URL, timeout, & secure storage keys
│   ├── network/
│   │   ├── api_client.dart          ← Dio instance, AuthInterceptor, & global 401 handler
│   │   └── api_endpoints.dart       ← Konstanta seluruh endpoint API
│   ├── storage/
│   │   └── token_storage.dart       ← Helper FlutterSecureStorage (Token & User Cache)
│   └── utils/
│       └── json_parse.dart          ← Parser tipe data aman (double, int, bool, datetime)
├── services/
│   └── api_services.dart            ← AuthService, ProductService, OrderService, ProfileService
├── models.dart                      ← Product, CartItem, Order, UserProfile, status mapping
└── main.dart                        ← Entry point, AppState, Navigasi, & seluruh UI Screens
```

---

## Setup & Instalasi

### 1. Prasyarat

- Flutter SDK 3.44.x atau lebih baru
- Android Studio / VS Code dengan Flutter Plugin
- Android Emulator atau Device Fisik
- Backend Laravel (`Konco Space Backend/Admin`) aktif dan dapat diakses

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Konfigurasi Backend URL

Aplikasi menggunakan `--dart-define` untuk menyuntikkan endpoint API secara dinamis tanpa perlu mengubah kode sumber:

```bash
# 1. Android Emulator (mengarah ke localhost mesin host)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api

# 2. Perangkat Fisik (via jaringan Wi-Fi / LAN yang sama)
flutter run --dart-define=API_BASE_URL=http://<IP-KOMPUTER-ANDA>:8000/api

# 3. Web / Desktop / iOS Simulator
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api

# 4. Production / Cloudflare Tunnel (HTTPS)
flutter run --dart-define=API_BASE_URL=https://api.koncospace.my.id/api
```

_Catatan: Nilai default fallback adalah `http://10.0.2.2:8000/api` pada `lib/core/constants/app_constants.dart`._

---

## Akun Uji Coba

Gunakan kredensial pengujian yang telah di-seed pada backend:

| Role         | Email                      | Password   |
| ------------ | -------------------------- | ---------- |
| **Customer** | `customer@koncospace.test` | `password` |

_Atau buat akun baru langsung melalui menu **Daftar** di aplikasi._

---

## Alur Pengujian End-to-End

1. **Autentikasi**: Buka aplikasi $\rightarrow$ Login menggunakan akun customer atau daftar akun baru.
2. **Eksplorasi Menu**: Di layar Home, gunakan filter kategori (misal: "Coffee") $\rightarrow$ Produk tersaring dinamis.
   - Ketuk **Lihat Semua** di sebelah "Pilihan Populer" $\rightarrow$ Layar "Semua Menu" menampilkan seluruh produk $\rightarrow$ Ketuk produk untuk membuka detail.
3. **Kustomisasi**: Pilih salah satu menu $\rightarrow$ Atur opsi condiment (Ukuran, Tingkat Manis, Extra, dll.) dan jumlah $\rightarrow$ Klik **Tambah ke Keranjang**.
4. **Keranjang**: Masuk ke tab Keranjang $\rightarrow$ Verifikasi item, pilihan condiment, dan total harga $\rightarrow$ Klik **Pilih Pembayaran**.
5. **Checkout**:
   - Pilih metode **Cash**, **QRIS**, atau **Virtual Account (BCA/BNI/BRI/Mandiri)**.
   - Klik **Pesan Sekarang**.
6. **Pembayaran**:
   - Jika memilih QRIS/VA: Layar menampilkan QR / Nomor VA. Polling status berjalan otomatis tiap 4 detik hingga pembayaran terdeteksi.
   - Jika memilih Cash: Pesanan langsung dialihkan ke tab tracking.
7. **Tracking Antrean**: Tab Pesanan akan melakukan polling status tiap 5 detik (`pending` $\rightarrow$ `processing` $\rightarrow$ `ready` $\rightarrow$ `completed`).
8. **Penyelesaian**: Saat status menjadi `completed`, dialog sukses muncul.
9. **Riwayat & Profil**: Buka tab Profil $\rightarrow$ Verifikasi data pengguna dan daftar riwayat transaksi.
10. **Keluar**: Tekan tombol Logout $\rightarrow$ Token dihapus dan layar kembali ke halaman Login.

---

## Daftar Endpoint API

Format respons standar backend:

```json
{
  "success": true,
  "data": { ... },
  "message": "OK"
}
```

| Method | Endpoint         | Fungsi                                                                                |
| ------ | ---------------- | ------------------------------------------------------------------------------------- |
| `POST` | `/auth/register` | Mendaftarkan akun customer baru & mengembalikan token                                 |
| `POST` | `/auth/login`    | Autentikasi email & password, mengembalikan token                                     |
| `POST` | `/auth/logout`   | Mencabut token autentikasi aktif                                                      |
| `GET`  | `/auth/me`       | Mengambil data profil pelanggan aktif                                                 |
| `GET`  | `/menus`         | Mengambil seluruh katalog menu aktif                                                  |
| `GET`  | `/categories`    | Mengambil daftar kategori menu                                                        |
| `POST` | `/orders`        | Membuat pesanan baru (`preorder`, metode bayar, daftar item + `condiment_option_ids`) |
| `GET`  | `/orders`        | Mengambil riwayat seluruh pesanan milik pelanggan                                     |
| `GET`  | `/orders/{id}`   | Mengambil detail spesifik pesanan & status pembayaran                                 |

Payload pembuatan order (`POST /orders`):

```json
{
  "order_type": "preorder",
  "payment_method": "cash",
  "items": [
    {
      "menu_id": 3,
      "quantity": 1,
      "condiment_option_ids": [2, 5],
      "notes": "Large, Normal"
    }
  ]
}
```

---

## Keamanan & Standar Rilis

- **Penyimpanan Kredensial**: Token autentikasi disimpan di Keystore/EncryptedSharedPreferences melalui `flutter_secure_storage`. Kata sandi pengguna tidak pernah disimpan di storage lokal.
- **Header Autentikasi**: Header `Authorization: Bearer <token>` disematkan otomatis pada setiap request oleh `_AuthInterceptor`.
- **Logging Terproteksi**: `LogInterceptor` Dio hanya aktif pada mode debug (`kDebugMode`) dan dinonaktifkan secara otomatis pada mode release.

### Perintah Build & Analisis

```bash
# Menjalankan linter static analysis
flutter analyze

# Membangun APK Release
flutter build apk --release --dart-define=API_BASE_URL=https://<api-host>/api
```

---

## Lisensi

Internal use only — Proyek **Konco Space**.
