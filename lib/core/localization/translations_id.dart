import 'app_translations.dart';

class AppTranslationsId implements AppTranslations {
  // Navigation
  @override String get navDashboard => 'Beranda';
  @override String get navTransactions => 'Transaksi';
  @override String get navWallet => 'Dompet';
  @override String get navPlanning => 'Perencanaan';
  @override String get navSettings => 'Pengaturan';
  @override String get navReports => 'Laporan';
  
  @override String get dashboardTitle => 'Dashboard Saya';
  @override String get dashboardOverview => 'Ringkasan';
  @override String get dashboardTotalBalance => 'Total Saldo';
  @override String get dashboardNetWorth => 'Kekayaan Bersih';
  @override String get dashboardIncome => 'Pemasukan';
  @override String get dashboardExpense => 'Pengeluaran';
  @override String get recentTransactions => 'Transaksi Terkini';
  @override String get viewAll => 'Lihat Semua';
  @override String get noTransactions => 'Belum ada transaksi';
  
  // Common
  @override String get ok => 'OK';
  @override String get cancel => 'Batal';
  @override String get save => 'Simpan';
  @override String get delete => 'Hapus';
  @override String get edit => 'Ubah';
  @override String get search => 'Cari';
  @override String get error => 'Kesalahan';
  @override String get success => 'Berhasil';
  @override String get loading => 'Memuat...';
  @override String get commonSearch => 'Cari...';
  @override String get commonToday => 'Hari Ini';
  @override String get commonYesterday => 'Kemarin';
  @override String get commonThisMonth => 'Bulan Ini';
  @override String get commonPastDue => 'Terlewat';
  @override String get commonDueToday => 'Jatuh tempo hari ini';
  @override String get commonDaysLeft => 'hari lagi';
  @override String get commonTarget => 'Target';
  @override String get commonOf => 'dari';
  @override String get commonPaid => 'Terbayar';
  @override String get commonAmount => 'Jumlah';
  @override String get commonMax => 'MAKS';
  @override String get filterAll => 'Semua';

  // Transaction Entry
  @override String get entryTitleAdd => 'Tambah Transaksi';
  @override String get entryTitleEdit => 'Ubah Transaksi';
  @override String get entryAmount => 'JUMLAH';
  @override String get entryTypeIncome => 'Pemasukan';
  @override String get entryTypeExpense => 'Pengeluaran';
  @override String get entryTypeTransfer => 'Transfer';
  @override String get entryCategoryCreated => 'Kategori berhasil dibuat';
  @override String get entryCategory => 'Kategori';
  @override String get entryAccount => 'Akun';
  @override String get entryFromAccount => 'Dari Akun';
  @override String get entryToAccount => 'Ke Akun';
  @override String get entryNote => 'Catatan';
  @override String get entryNoteHint => 'Tambah catatan...';
  @override String get entryDate => 'Tanggal';
  @override String get entrySaveButton => 'Simpan Transaksi';
  
  @override String get entrySelectCategory => 'Pilih kategori';
  @override String get entrySearchCategory => 'Cari kategori...';
  @override String get entrySearchAccount => 'Cari akun...';
  @override String get entryNoAccounts => 'Tidak ada akun ditemukan';
  @override String get entryAddCategory => 'Tambah Kategori Baru'; 

  
  @override String get entrySelectAccount => 'Pilih akun';
  @override String get entryAddNote => 'Tambah Catatan';
  @override String get entryEditNote => 'Ubah Catatan';
  
  // Transaction Feedback
  @override String transactionCreated(String amount) => 'Transaksi sebesar $amount berhasil dibuat!';
  @override String transactionUpdated(String amount) => 'Transaksi berhasil diperbarui!';
  @override String get errorInsufficientFunds => 'Saldo tidak mencukupi';
  @override String get errorSelectCategory => 'Mohon pilih kategori';
  @override String get errorSelectAccount => 'Mohon pilih akun';
  @override String get errorSelectDestAccount => 'Mohon pilih akun tujuan';
  @override String get errorInvalidAmount => 'Mohon masukkan jumlah yang valid';
  @override String get errorNoActiveProfile => 'Tidak ada profil aktif';
  @override String get errorEnterCategoryName => 'Mohon masukkan nama kategori';
  @override String get errorLoadingCashFlow => 'Gagal memuat arus kas: ';
  @override String get errorLoadingCategories => 'Gagal memuat kategori: ';
  
  @override String get accountTitleAdd => 'Akun Baru';
  @override String get accountTitleEdit => 'Edit Akun';
  @override String get accountNameExists => 'Nama akun sudah ada. Silakan gunakan nama lain.';
  @override String get accountNoProfile => 'Belum ada profil aktif. Silakan buat profil terlebih dahulu.';
  @override String get accountAdjustmentRequired => 'Mohon masukkan jumlah penyesuaian';
  @override String get accountAdjustmentApplied => 'Penyesuaian diterapkan';
  @override String get accountBalanceAdjustment => 'Penyesuaian Saldo';
  @override String get accountAdjustmentHint => 'Masukkan positif untuk tambah, negatif untuk kurang';
  @override String get accountApply => 'Terapkan';
  @override String get accountViewHistory => 'Lihat Riwayat Transaksi';
  @override String get accountEditDetails => 'Edit Detail';
  @override String get accountNameHint => 'Nama Akun';
  @override String get accountBalanceHint => 'Saldo Awal';
  @override String get accountStartingBalanceHint => 'Saldo Awal';
  @override String get accountBalanceRequired => 'Saldo diperlukan';
  @override String get accountType => 'Tipe';
  @override String get accountCurrency => 'MATA UANG';
  @override String get accountSave => 'Simpan Akun';

  // Settings
  @override String get settingsTheme => 'Tema';
  @override String get settingsLanguage => 'Bahasa';
  @override String get settingsProfile => 'Profil';
  @override String get settingsPreferences => 'Preferensi';
  @override String get settingsSecurity => 'Keamanan';
  @override String get settingsAbout => 'Tentang';
  @override String get settingsSyncBackup => 'Sinkronisasi & Cadangan';
  @override String get settingsManageCategories => 'Kelola Kategori';
  @override String get settingsBackupRestore => 'Cadangan & Pemulihan';
  @override String get settingsBaseCurrency => 'Mata Uang Dasar';
  @override String get settingsShowDecimals => 'Tampilkan Desimal';

  @override String get settingsAboutApp => 'Tentang Rich Together';
  
  // About Screen
  @override String get aboutTagline => 'Teman finansial pribadi Anda';
  @override String get aboutFeatures => 'Fitur';
  @override String get aboutFeatureExpense => 'Pelacakan Pengeluaran';
  @override String get aboutFeatureBudget => 'Manajemen Anggaran';
  @override String get aboutFeatureAnalytics => 'Analisis & Laporan';
  @override String get aboutFeatureMultiProfile => 'Dukungan Multi-Profil';
  @override String get aboutFeatureOffline => 'Offline & Aman';
  @override String get aboutDeveloper => 'Pengembang';
  @override String get aboutContact => 'Kontak';
  @override String get aboutCopyright => '© 2026 Rich Together. Hak cipta dilindungi.';

  // Help & FAQ
  @override String get helpTitle => 'Bantuan & FAQ';
  @override String get helpFaq1Question => 'Bagaimana cara menambah transaksi?';
  @override String get helpFaq1Answer => 'Ketuk tombol + di layar Transaksi, isi detailnya (jumlah, kategori, akun), dan ketuk Simpan.';
  @override String get helpFaq2Question => 'Bagaimana cara membuat profil tambahan?';
  @override String get helpFaq2Answer => 'Buka Pengaturan, ketuk kartu profil Anda, lalu pilih "Tambah Profil Baru". Setiap profil menyimpan datanya secara terpisah.';
  @override String get helpFaq3Question => 'Bisakah saya melacak beberapa mata uang?';
  @override String get helpFaq3Answer => 'Ya! Anda dapat mengatur mata uang berbeda untuk setiap akun. Atur mata uang dasar di Pengaturan untuk melihat total gabungan.';
  @override String get helpFaq4Question => 'Bagaimana cara mengatur transaksi berulang?';
  @override String get helpFaq4Answer => 'Saat menambah transaksi, ketuk "Buat Berulang" dan pilih frekuensinya (harian, mingguan, bulanan, tahunan).';
  @override String get helpFaq5Question => 'Apakah data saya aman?';
  @override String get helpFaq5Answer => 'Ya! Semua data disimpan secara lokal di perangkat Anda. Kami tidak pernah mengirim data keuangan Anda ke server eksternal.';
  @override String get helpFaq6Question => 'Bagaimana cara mencadangkan data saya?';
  @override String get helpFaq6Answer => 'Buka Pengaturan > Manajemen Data > Cadangan. Anda dapat menyimpan ke Google Drive atau mengekspor ke file.';
  @override String get helpFaq7Question => 'Bisakah saya menggunakan aplikasi secara offline?';
  @override String get helpFaq7Answer => 'Tentu saja! Rich Together bekerja 100% offline. Internet hanya dibutuhkan untuk fitur opsional seperti cadangan cloud.';
  @override String get helpContactSupport => 'Hubungi tim dukungan kami';
  @override String get helpContactEmail => 'axiomtech.dev@gmail.com';

  // Privacy Policy
  @override String get privacyTitle => 'Kebijakan Privasi';
  @override String get privacyLastUpdated => 'Terakhir diperbarui: Februari 2026';
  @override String get privacyDataCollectionTitle => 'Pengumpulan Data';
  @override String get privacyDataCollectionContent => 'Rich Together dirancang dengan mengutamakan privasi Anda. Semua data keuangan Anda disimpan secara lokal di perangkat Anda. Kami tidak mengumpulkan, mengirim, atau menyimpan informasi keuangan pribadi Anda di server eksternal.';
  @override String get privacyLocalStorageTitle => 'Penyimpanan Lokal';
  @override String get privacyLocalStorageContent => 'Data Anda disimpan dengan aman di perangkat menggunakan database SQLite terenkripsi. Aplikasi beroperasi sepenuhnya offline, artinya data Anda tidak pernah meninggalkan ponsel kecuali Anda secara eksplisit memilih untuk mencadangkan.';
  @override String get privacyBackupTitle => 'Cadangan Opsional';
  @override String get privacyBackupContent => 'Jika Anda memilih untuk menggunakan cadangan Google Drive, data Anda akan dienkripsi dan disimpan di akun Google Drive pribadi Anda. Kami tidak memiliki akses ke file cadangan Anda.';
  @override String get privacyAnalyticsTitle => 'Tanpa Analitik Pihak Ketiga';
  @override String get privacyAnalyticsContent => 'Kami tidak menggunakan layanan analitik pihak ketiga yang melacak perilaku Anda atau mengumpulkan informasi pribadi.';
  @override String get privacyDeletionTitle => 'Penghapusan Data';
  @override String get privacyDeletionContent => 'Anda dapat menghapus semua data Anda kapan saja dari menu Pengaturan. Menghapus aplikasi juga akan menghapus semua data yang tersimpan secara lokal.';
  @override String get privacyContactTitle => 'Kontak';
  @override String get privacyContactContent => 'Jika Anda memiliki pertanyaan tentang Kebijakan Privasi ini, silakan hubungi kami di privacy@richtogether.app';

  // Terms of Service
  @override String get termsTitle => 'Syarat Layanan';
  @override String get termsLastUpdated => 'Terakhir diperbarui: Februari 2026';
  @override String get termsAcceptanceTitle => '1. Penerimaan Syarat';
  @override String get termsAcceptanceContent => 'Dengan menggunakan Rich Together, Anda menyetujui Syarat Layanan ini. Jika Anda tidak setuju, mohon jangan gunakan aplikasi ini.';
  @override String get termsUsageTitle => '2. Penggunaan Aplikasi';
  @override String get termsUsageContent => 'Rich Together adalah alat pelacak keuangan pribadi yang dirancang untuk penggunaan individu. Anda bertanggung jawab untuk menjaga kerahasiaan data Anda dan PIN atau kata sandi yang Anda buat.';
  @override String get termsAccuracyTitle => '3. Akurasi Data';
  @override String get termsAccuracyContent => 'Aplikasi ini menyediakan alat untuk melacak keuangan Anda, tetapi kami tidak menjamin keakuratan perhitungan. Anda harus memverifikasi semua informasi keuangan secara mandiri.';
  @override String get termsAdviceTitle => '4. Bukan Saran Finansial';
  @override String get termsAdviceContent => 'Rich Together bukan pengganti saran finansial profesional. Aplikasi ini hanya untuk tujuan informasi. Konsultasikan dengan penasihat keuangan yang berkualifikasi untuk keputusan investasi.';
  @override String get termsLiabilityTitle => '5. Batasan Tanggung Jawab';
  @override String get termsLiabilityContent => 'Kami tidak bertanggung jawab atas kerugian finansial, kehilangan data, atau kerusakan yang timbul dari penggunaan aplikasi ini.';
  @override String get termsUpdatesTitle => '6. Pembaruan';
  @override String get termsUpdatesContent => 'Kami dapat memperbarui syarat ini dari waktu ke waktu. Penggunaan berkelanjutan atas aplikasi merupakan penerimaan terhadap syarat yang diperbarui.';
  @override String get termsContactTitle => '7. Kontak';
  @override String get termsContactContent => 'Untuk pertanyaan tentang Syarat Layanan ini, hubungi kami di legal@richtogether.app';

  // Sync Screen
  @override String get syncTitle => 'Sinkronisasi & Cadangan';
  @override String get syncSignIn => 'Masuk';
  @override String get syncSignUp => 'Daftar';
  @override String get syncFullName => 'Nama Lengkap';
  @override String get syncEmail => 'Email';
  @override String get syncPassword => 'Kata Sandi';
  @override String get syncNoAccount => 'Belum punya akun? Daftar';
  @override String get syncHaveAccount => 'Sudah punya akun? Masuk';
  @override String get syncConnectedAs => 'Terhubung sebagai';
  @override String get syncBackedUp => 'Data Anda dicadangkan ke cloud.';
  @override String get syncNow => 'Sinkronkan Sekarang';
  @override String get syncLogOut => 'Keluar';
  @override String get syncLoggedIn => 'Berhasil masuk!';
  @override String get syncCompleted => 'Sinkronisasi selesai!';
  @override String get syncFailed => 'Sinkronisasi gagal';
  @override String get syncStillNeedHelp => 'Masih butuh bantuan?';

  @override String get settingsClearData => 'Hapus Semua Data';

  // Wealth / Navigation
  @override String get navWealth => 'Kekayaan';
  @override String get wealthBudget => 'Anggaran';
  @override String get wealthGoals => 'Target';
  @override String get wealthInvestment => 'Investasi';

  // Goals
  @override String get goalTitleAdd => 'Target Baru';
  @override String get goalTitleEdit => 'Edit Target';
  @override String get goalName => 'Nama Target';
  @override String get goalNameHint => 'cth. Dana Pernikahan, Dana Darurat';
  @override String get goalTargetAmount => 'Jumlah Target';
  @override String get goalCurrency => 'Mata Uang';
  @override String get goalDeadline => 'Tenggat';
  @override String get goalNoDeadline => 'Tanpa tenggat';
  @override String get goalLinkAccounts => 'Hubungkan Akun';
  @override String get goalSaved => 'Terkumpul';
  @override String get goalRemaining => 'Sisa';
  @override String get goalMonthlyNeeded => 'Kebutuhan bulanan';
  @override String get goalAchieved => 'Tercapai!';
  @override String get goalMarkAchieved => 'Tandai Tercapai';
  @override String get goalNoGoals => 'Belum ada target';
  @override String get goalNoGoalsHint => 'Tap + untuk membuat target keuangan';
  @override String get goalDeleted => 'Target dihapus';

  // Debts
  @override String get debtTitle => 'Hutang';
  @override String get debtTitleAdd => 'Hutang Baru';
  @override String get debtTitleEdit => 'Edit Hutang';
  @override String get debtPayable => 'Saya Berhutang';
  @override String get debtReceivable => 'Piutang Saya';
  @override String get debtPersonName => 'Nama Orang';
  @override String get debtPersonNameHint => 'Siapa?';
  @override String get debtDueDate => 'Jatuh Tempo';
  @override String get debtSettle => 'Lunaskan';
  @override String get debtSettleAccount => 'Akun Pelunasan';
  @override String get debtNoDebts => 'Tidak ada hutang';
  @override String get debtNoDebtsHint => 'Tap + untuk menambah catatan hutang';
  @override String get debtSettled => 'Hutang lunas';

  // Investment
  @override String get investmentPlaceholder => 'Pelacakan Investasi';
  @override String get investmentPlaceholderHint => 'Segera hadir — pantau portofolio Anda di sini';

  // Recurring
  @override String get recurringTitle => 'Transaksi Berulang';
  @override String get recurringTitleAdd => 'Buat Transaksi Berulang';
  @override String get recurringTitleEdit => 'Edit Transaksi Berulang';
  @override String get recurringFrequency => 'Frekuensi';
  @override String get recurringInterval => 'Setiap';
  @override String get recurringStartDate => 'Tanggal Mulai';
  @override String get recurringEndDate => 'Tanggal Selesai';
  @override String get recurringNoEndDate => 'Tanpa akhir';
  @override String get recurringLastRun => 'Terakhir jalan';
  @override String get recurringNextRun => 'Jadwal berikutnya';
  @override String get recurringNoRecurring => 'Tidak ada transaksi berulang';
  @override String get recurringNoRecurringHint => 'Ketuk + untuk membuat jadwal rutin';
  @override String get recurringDaily => 'Harian';
  @override String get recurringWeekly => 'Mingguan';
  @override String get recurringMonthly => 'Bulanan';
  @override String get recurringYearly => 'Tahunan';

  // Budget
  @override String get budgetTitle => 'Anggaran';
  @override String get budgetTitleAdd => 'Buat Anggaran';
  @override String get budgetTitleEdit => 'Edit Anggaran';
  @override String get budgetAmount => 'Nominal Batas';
  @override String get budgetPeriod => 'Periode';
  @override String get budgetSpent => 'Terpakai';
  @override String get budgetRemaining => 'Sisa';
  @override String get budgetExceeded => 'Melebihi';
  @override String get budgetLimit => 'Batas';
  @override String get budgetNoBudgets => 'Belum ada anggaran';
  @override String get budgetNoBudgetsHint => 'Ketuk + untuk membatasi pengeluaran';

  // Dashboard & Reports
  @override String get chartCashflow => 'Arus Kas';
  @override String get chartSpending => 'Pengeluaran per Kategori';
  @override String get reportTabIncomeExpr => 'Pemasukan';
  @override String get reportTabCashflow => 'Arus Kas';
  @override String get reportTabSpending => 'Pengeluaran';
  @override String get reportNoData => 'Tidak ada data untuk periode ini';
  @override String get reportNet => 'Pendapatan Bersih';
  @override String get dashboardBalanceCurrency => 'Saldo per Mata Uang';
  @override String get close => 'Tutup';

  @override String get walletTitle => 'Akun Saya';
  @override String get walletNoAccounts => 'Belum ada akun.\nKetuk + untuk menambahkan.';

  // Settings
  @override String get settingsTapToSwitch => 'Ketuk untuk ganti profil';
  @override String get settingsConnectSupabase => 'Hubungkan ke Supabase';
  @override String get settingsLockApp => 'Kunci Aplikasi';
  @override String get settingsLockAppSubtitleOn => 'Butuh PIN/Biometrik';
  @override String get settingsLockAppSubtitleOff => 'Aplikasi tidak terkunci';
  @override String get settingsBiometric => 'Login Biometrik';
  @override String get settingsChangePin => 'Ubah PIN';
  @override String get settingsAboutTitle => 'Tentang Rich Together';
  @override String get settingsHelp => 'Bantuan & FAQ';
  @override String get settingsPrivacy => 'Kebijakan Privasi';
  @override String get settingsTerms => 'Syarat Layanan';
  @override String get settingsSelectCurrency => 'Pilih Mata Uang';
  @override String get settingsVerifyPin => 'Verifikasi PIN Saat Ini';
  @override String get settingsEnterCurrentPin => 'Masukkan PIN saat ini';
  @override String get settingsSetNewPin => 'Buat PIN Baru';
  @override String get settingsEnterNewPin => 'Masukkan PIN baru (6 digit)';
  @override String get settingsConfirmNewPin => 'Konfirmasi PIN baru';
  @override String get settingsPinLengthError => 'PIN harus 6 digit';
  @override String get settingsPinMatchError => 'PIN tidak cocok';
  @override String get settingsPinSetSuccess => 'PIN berhasil diatur';
  @override String get settingsIncorrectPin => 'PIN salah';
  @override String get settingsClearDataTitle => 'Hapus Semua Data?';
  @override String get settingsClearDataContent => 'Ini akan menghapus SEMUA data Anda secara permanen (transaksi, akun, kategori). Tindakan ini tidak dapat dibatalkan.';
  @override String get settingsClearDataConfirmPrompt => 'Ketik "Konfirmasi" untuk melanjutkan:';
  @override String get settingsClearDataConfirmKeyword => 'Konfirmasi';
  @override String get settingsClearEverything => 'Hapus Semuanya';
  @override String get settingsClearSuccess => 'Semua data berhasil dihapus';
  @override String get settingsClearError => 'Gagal menghapus data';
  @override String get genericCancel => 'Batal';
  @override String get genericVerify => 'Verifikasi';
  @override String get genericSet => 'Atur PIN';
  @override String get settingsVersion => 'Versi';
  @override String get settingsNoProfile => 'Tidak Ada Profil';
}
