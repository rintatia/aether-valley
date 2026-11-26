# Aturan aset Aether Valley v7

Game membaca aset dari daftar di `data/assets.json`. Selama file belum ada, game memakai kotak warna polos seukuran aset itu. Begitu file dengan **nama dan ukuran persis** di bawah dimasukkan, dia langsung muncul. Tidak perlu mengubah kode.

## Aturan umum
- PNG, latar transparan (kecuali ubin: penuh tanpa transparan).
- 1 piksel seni = 1 piksel gambar. Jangan diperbesar, jangan dihaluskan (tanpa antialias, tanpa blur).
- Hanya warna dari palet 47 (daftar di bawah). Tidak ada gradasi di luar palet.
- Satu sumber cahaya: dari kiri atas. Bayangan jatuh ke kanan bawah.
- Sudut pandang: top-down 3/4 (atas terlihat sedikit, sisi depan terlihat).
- Nama file huruf kecil, garis bawah, tanpa spasi. Persis seperti tabel.

## Cara objek berdiri
- Objek dan bangunan berdiri di **tepi bawah gambar**: bagian bawah gambar = tanah tempat ia menapak. Sisakan ruang kosong transparan di atas, bukan di bawah.
- Karakter: kaki di 4 piksel terbawah, badan di tengah horizontal.

## Ubin tanah & air (16×16, harus bisa disambung ke segala arah)

| File | Ukuran (piksel) | Keterangan |
|---|---|---|
| `assets/tanah/rumput.png` | 16×16 |  |
| `assets/tanah/tanah_garap.png` | 16×16 |  |
| `assets/tanah/jalan.png` | 16×16 |  |
| `assets/tanah/pasir.png` | 16×16 |  |
| `assets/air/air.png` | 16×16 |  |

## Karakter (strip animasi, bingkai berjajar ke kanan)

| File | Ukuran (piksel) | Keterangan |
|---|---|---|
| `assets/karakter/petani_jalan_bawah_4f.png` | 64×24 (4 bingkai @ 16×24) |  |
| `assets/karakter/petani_jalan_atas_4f.png` | 64×24 (4 bingkai @ 16×24) |  |
| `assets/karakter/petani_jalan_kiri_4f.png` | 64×24 (4 bingkai @ 16×24) |  |
| `assets/karakter/petani_jalan_kanan_4f.png` | 64×24 (4 bingkai @ 16×24) |  |

## Objek (berdiri di atas satu petak)

| File | Ukuran (piksel) | Keterangan |
|---|---|---|
| `assets/objek/pohon.png` | 32×48 |  |
| `assets/objek/semak.png` | 16×16 |  |
| `assets/objek/batu.png` | 16×16 |  |
| `assets/objek/kotak_kirim.png` | 16×16 |  |

## Bangunan (berdiri di atas tapak 5×3 petak)

| File | Ukuran (piksel) | Keterangan |
|---|---|---|
| `assets/bangunan/rumah_pemain.png` | 80×64 | Rumah |
| `assets/bangunan/toko_serba_ada.png` | 80×64 | Toko Serba Ada |
| `assets/bangunan/pandai_besi.png` | 80×64 | Pandai Besi |
| `assets/bangunan/kedai.png` | 80×64 | Kedai |
| `assets/bangunan/rumah_tetua.png` | 80×64 | Rumah Tetua |

## Palet 47 warna

`#1E3F2B`, `#2F6A32`, `#4E912F`, `#6EA427`, `#94BD1B`, `#BFE33E`, `#7A5A1E`, `#B58A2A`, `#E0B83C`, `#FFD65A`, `#FFEE9A`, `#241912`, `#43251D`, `#7F442C`, `#A55E36`, `#C87D38`, `#DE9A4C`, `#EDBB78`, `#6B2231`, `#A43F46`, `#D8574F`, `#D15976`, `#F37CAB`, `#FC9CBF`, `#F9BECF`, `#3B2A5A`, `#6B5BA8`, `#9C8CF0`, `#C9BFFA`, `#1F4E8C`, `#2480BE`, `#34A0D6`, `#78C8EB`, `#C4EBF7`, `#1F5F5A`, `#2E8F82`, `#2B2730`, `#4A4650`, `#6B6670`, `#8E8A8A`, `#B5B0A6`, `#D8D3C4`, `#F8F1EA`, `#8A5A3C`, `#C68672`, `#E8B28A`, `#F5D0B0`

## Urutan pengerjaan yang disarankan
1. Karakter petani (4 arah) — paling sering terlihat.
2. Ubin: rumput, tanah garap, jalan, pasir, air.
3. Objek: pohon, semak, batu, kotak kirim.
4. Bangunan: rumah, toko serba ada, pandai besi, kedai, rumah tetua.

Ubin yang menyambung ke ubin lain (tepi rumput ke jalan, rumput ke air) menyusul sebagai set terpisah setelah ubin dasar jadi.
