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
  @override String get commonOthers => 'Lainnya';
  @override String get filterAll => 'Semua';
  @override String get commonShare => 'Bagikan';

  // Transaction Entry
  @override String get entryTitleAdd => 'Tambah Transaksi';
  @override String get entryTitleEdit => 'Ubah Transaksi';
  @override String get entryAmount => 'JUMLAH';
  @override String get entryTypeIncome => 'Pemasukan';
  @override String get entryTypeExpense => 'Pengeluaran';
  @override String get entryTypeTransfer => 'Transfer';
  @override String get entryTypeAdjustmentIn => 'Penyesuaian +';
  @override String get entryTypeAdjustmentOut => 'Penyesuaian -';
  @override String get entryTypeDebtIn => 'Dipinjam';
  @override String get entryTypeDebtOut => 'Dipinjamkan';
  @override String get entryTypeDebtPaymentOut => 'Bayar Hutang';
  @override String get entryTypeDebtPaymentIn => 'Terima Piutang';
  @override String get entryCategoryCreated => 'Kategori berhasil dibuat';
  @override String get entryCategory => 'Kategori';
  @override String get entryAccount => 'Akun';
  @override String get entryFromAccount => 'Dari Akun';
  @override String get entryToAccount => 'Ke Akun';
  @override String get entryTitle => 'Judul';
  @override String get entryTitleHint => 'Masukkan judul...';
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
  @override String get accountInitialBalance => 'Saldo Awal';
  @override String get accountInitialBalanceHint => 'Menetapkan saldo awal langsung — tanpa membuat transaksi';
  @override String get accountAdjustBalance => 'Sesuaikan Saldo';
  @override String get accountAdjustBalanceHint => 'Membuat transaksi penyesuaian untuk mencapai saldo ini';
  @override String get accountInitialBalanceApplied => 'Saldo awal diperbarui';
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
  @override String get settingsNotifications => 'Notifikasi';
  @override String get settingsDailyReminder => 'Pengingat Harian';
  @override String get settingsReminderTime => 'Waktu Pengingat';
  @override String get notificationReminderTitle => '💰 Waktunya mencatat!';
  @override String get notificationReminderBody => "Jangan lupa catat transaksi Anda hari ini.";
  @override String get settingsSyncBackup => 'Sinkronisasi & Cadangan';
  @override String get settingsManageCategories => 'Kelola Kategori';
  @override String get settingsBackupRestore => 'Cadangan & Pemulihan';
  @override String get settingsBaseCurrency => 'Mata Uang Dasar';
  @override String get settingsShowDecimals => 'Tampilkan Desimal';
  @override String get settingsCardShadow => 'Bayangan Kartu';
  @override String get settingsPremium => 'Premium';

  @override String get settingsAboutApp => 'Tentang Richer';
  
  // About Screen
  @override String get aboutTagline => 'Teman finansial pribadi Anda';
  @override String get aboutFeatures => 'Fitur';
  @override String get aboutFeatureExpense => 'Pelacakan Pengeluaran';
  @override String get aboutFeatureBudget => 'Manajemen Anggaran';
  @override String get aboutFeatureAnalytics => 'Analisis & Laporan';
  @override String get aboutFeatureMultiProfile => 'Dukungan Multi-Profil';
  @override String get aboutFeatureOffline => 'Offline & Aman';
  @override String get aboutFeatureGoals => 'Target Keuangan';
  @override String get aboutFeatureDebts => 'Pelacakan Hutang';
  @override String get aboutFeatureRecurring => 'Transaksi Berulang';
  @override String get aboutFeatureMultiCurrency => 'Multi Mata Uang';
  @override String get aboutFeatureSync => 'Sinkronisasi & Cadangan';
  @override String get aboutFeatureInvestment => 'Kelola Investasi';
  @override String get aboutFeatureEncrypted => 'Database Terenkripsi';
  @override String get aboutComingSoon => 'Segera Hadir';
  @override String get aboutDeveloper => 'Pengembang';
  @override String get aboutContact => 'Kontak';
  @override String get aboutCopyright => '© 2026 Richer - Money Management. Hak cipta dilindungi.';
  @override String get aboutEncryptionWarning => 'Saat Anda mengekspor cadangan, file hasil ekspor TIDAK DIENKRIPSI agar Anda dapat memulihkannya di perangkat lain. Simpan file cadangan Anda di tempat yang aman.';

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
  @override String get helpFaq5Answer => 'Data Anda disimpan sepenuhnya di perangkat Anda dan tidak pernah dikirim ke server eksternal. Kami menyarankan untuk mengamankan perangkat Anda dengan kunci layar yang kuat guna melindungi data keuangan Anda.';
  @override String get helpFaq6Question => 'Bagaimana cara mencadangkan data saya?';
  @override String get helpFaq6Answer => 'Buka Pengaturan > Manajemen Data > Cadangan & Pemulihan. Anda dapat mengekspor database ke file dan membagikannya melalui email, pesan, atau penyimpanan cloud.';
  @override String get helpFaq7Question => 'Bisakah saya menggunakan aplikasi secara offline?';
  @override String get helpFaq7Answer => 'Tentu saja! Richer - Money Management bekerja 100% offline. Internet hanya dibutuhkan untuk fitur opsional seperti pembaruan kurs mata uang.';
  @override String get helpFaq8Question => 'Apakah database saya terenkripsi?';
  @override String get helpFaq8Answer => 'Ya — data Anda disimpan dalam database SQLite lokal yang dienkripsi dengan SQLCipher (AES-256). Data Anda tidak pernah dikirim ke luar dan tetap sepenuhnya privat di perangkat Anda.';
  @override String get helpContactSupport => 'Hubungi tim dukungan kami';
  @override String get helpContactEmail => 'axiomtech.dev@gmail.com';

  // Privacy Policy
  @override String get privacyTitle => 'Kebijakan Privasi';
  @override String get privacyLastUpdated => 'Terakhir diperbarui: Maret 2026';
  @override String get privacyDataCollectionTitle => 'Pengumpulan Data';
  @override String get privacyDataCollectionContent => 'Richer - Money Management dirancang dengan mengutamakan privasi Anda. Semua data keuangan Anda disimpan secara lokal di perangkat Anda. Kami tidak mengumpulkan, mengirim, atau menyimpan informasi keuangan pribadi Anda di server eksternal.';
  @override String get privacyLocalStorageTitle => 'Penyimpanan Lokal';
  @override String get privacyLocalStorageContent => 'Data Anda disimpan dengan aman di perangkat menggunakan database SQLite. Aplikasi beroperasi sepenuhnya offline, artinya data Anda tidak pernah meninggalkan ponsel kecuali Anda secara eksplisit memilih untuk mengekspor cadangan.';
  @override String get privacyEncryptionTitle => 'Keamanan Data';
  @override String get privacyEncryptionContent => 'Data keuangan Anda disimpan secara lokal di perangkat Anda dalam database SQLite yang dienkripsi dengan enkripsi SQLCipher tingkat militer. Data Anda tetap sepenuhnya privat dan aman di perangkat ini.';
  @override String get privacyBackupTitle => 'Cadangan Opsional';
  @override String get privacyBackupContent => 'Saat Anda mengekspor cadangan, data Anda disimpan ke dalam file portabel yang dapat digunakan untuk memulihkan data di perangkat mana pun. Anda bertanggung jawab untuk menjaga keamanan file cadangan Anda. Kami tidak memiliki akses ke file cadangan Anda.';
  @override String get privacyAnalyticsTitle => 'Tanpa Analitik Pihak Ketiga';
  @override String get privacyAnalyticsContent => 'Kami tidak menggunakan layanan analitik pihak ketiga yang melacak perilaku Anda atau mengumpulkan informasi pribadi.';
  @override String get privacyDeletionTitle => 'Penghapusan Data';
  @override String get privacyDeletionContent => 'Anda dapat menghapus semua data Anda kapan saja dari menu Pengaturan. Menghapus aplikasi juga akan menghapus semua data yang tersimpan secara lokal.';
  @override String get privacyContactTitle => 'Kontak';
  @override String get privacyContactContent => 'Jika Anda memiliki pertanyaan tentang Kebijakan Privasi ini, silakan hubungi kami di privacy@richtogether.app';

  // Terms of Service
  @override String get termsTitle => 'Syarat Layanan';
  @override String get termsLastUpdated => 'Terakhir diperbarui: Maret 2026';
  @override String get termsAcceptanceTitle => '1. Penerimaan Syarat';
  @override String get termsAcceptanceContent => 'Dengan menggunakan Richer - Money Management, Anda menyetujui Syarat Layanan ini. Jika Anda tidak setuju, mohon jangan gunakan aplikasi ini.';
  @override String get termsUsageTitle => '2. Penggunaan Aplikasi';
  @override String get termsUsageContent => 'Richer - Money Management adalah alat pelacak keuangan pribadi yang dirancang untuk penggunaan individu. Anda bertanggung jawab untuk menjaga kerahasiaan data Anda dan PIN atau kata sandi yang Anda buat.';
  @override String get termsAccuracyTitle => '3. Akurasi Data';
  @override String get termsAccuracyContent => 'Aplikasi ini menyediakan alat untuk melacak keuangan Anda, tetapi kami tidak menjamin keakuratan perhitungan. Anda harus memverifikasi semua informasi keuangan secara mandiri.';
  @override String get termsAdviceTitle => '4. Bukan Saran Finansial';
  @override String get termsAdviceContent => 'Richer - Money Management bukan pengganti saran finansial profesional. Aplikasi ini hanya untuk tujuan informasi. Konsultasikan dengan penasihat keuangan yang berkualifikasi untuk keputusan investasi.';
  @override String get termsLiabilityTitle => '5. Batasan Tanggung Jawab';
  @override String get termsLiabilityContent => 'Kami tidak bertanggung jawab atas kerugian finansial, kehilangan data, atau kerusakan yang timbul dari penggunaan aplikasi ini.';
  @override String get termsUpdatesTitle => '6. Pembaruan';
  @override String get termsUpdatesContent => 'Kami dapat memperbarui syarat ini dari waktu ke waktu. Penggunaan berkelanjutan atas aplikasi merupakan penerimaan terhadap syarat yang diperbarui.';
  @override String get termsSecurityTitle => '7. Keamanan Data';
  @override String get termsSecurityContent => 'Data Anda disimpan secara lokal di perangkat ini dalam database SQLite yang dienkripsi. Anda bertanggung jawab dalam menjaga keamanan file backup yang diekspor.';
  @override String get termsContactTitle => '8. Kontak';
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

  @override  String get settingsSendFeedback => 'Kirim Masukan';
  @override String get settingsSendFeedbackHint => 'Beri tahu kami pendapat Anda atau laporkan masalah...';
  @override String get settingsSendFeedbackSuccess => 'Masukan berhasil dikirim!';
  @override String get settingsSendFeedbackError => 'Gagal mengirim masukan: ';
  @override String get settingsSendFeedbackEmpty => 'Masukan tidak boleh kosong';

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
  @override String get goalSelectAccounts => 'Pilih Akun';
  @override String get goalAllAccounts => 'Semua Akun';
  @override String get goalNoAccountsAvailable => 'Tidak ada akun tersedia';
  @override String get goalSearchAccounts => 'Cari akun...';
  @override String get goalClearAll => 'Hapus semua';
  @override String get goalAccountsSelected => 'akun dipilih';

  // Debts
  @override String get debtTitle => 'Hutang';
  @override String get debtTitleAdd => 'Hutang Baru';
  @override String get debtTitleEdit => 'Edit Hutang';
  @override String get debtPayable => 'Saya Berhutang';
  @override String get debtReceivable => 'Piutang Saya';
  @override String get debtPersonName => 'Nama Orang';
  @override String get debtPersonNameHint => 'Siapa?';
  @override String get debtCreatedDate => 'Tanggal Dibuat';
  @override String get debtDueDate => 'Jatuh Tempo';
  @override String get debtSettle => 'Lunaskan';
  @override String get debtSettleGroup => 'Lunaskan Semua';
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
  @override String get recurringName => 'Judul';
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
  @override String budgetPeriodLimit(String period) => 'Batas $period';
  @override String get budgetNoBudgets => 'Belum ada anggaran';
  @override String get budgetNoBudgetsHint => 'Ketuk + untuk membatasi pengeluaran';

  // Dashboard & Reports
  @override String get chartCashflow => 'Arus Kas';
  @override String get chartSpending => 'Pengeluaran per Kategori';
  @override String get chartSavingsRate => 'Tren Rasio Tabungan';
  @override String get savingsRateLabel => 'Rasio Tabungan';
  @override String get savingsRateVsPrev => 'vs bulan lalu';
  @override String get deepAnalyticsTab => 'Analisis Mendalam';
  @override String get monthlyDetailsTab => 'Detail Bulanan';
  @override String get monthOverMonthTitle => 'Perbandingan Bulan';
  @override String get monthOverMonthThisMonth => 'Bulan Ini';
  @override String get monthOverMonthLastMonth => 'Bulan Lalu';
  @override String get monthOverMonthLastYear => 'Tahun Lalu';
  @override String get ytdTopCategoriesTitle => 'Pengeluaran Teratas (YTD)';
  @override String get categoryTrendTitle => 'Tren Kategori';
  @override String get sectionTrends => 'Tren';
  @override String get sectionSpendingAnalysis => 'Analisis Pengeluaran';
  @override String get sectionBehaviorPatterns => 'Pola Perilaku';
  @override String get dowSpendingTitle => 'Pengeluaran per Hari';
  @override String get dowMon => 'Sen';
  @override String get dowTue => 'Sel';
  @override String get dowWed => 'Rab';
  @override String get dowThu => 'Kam';
  @override String get dowFri => 'Jum';
  @override String get dowSat => 'Sab';
  @override String get dowSun => 'Min';
  @override String get recurringSplitTitle => 'Tetap vs Bebas';
  @override String get recurringSplitCommitted => 'Tetap';
  @override String get recurringSplitDiscretionary => 'Bebas';
  @override String get recurringSplitNoData => 'Tidak ada pengeluaran tetap';
  @override String get budgetPerfTitle => 'Performa Anggaran';
  @override String get budgetPerfExceeded => 'anggaran terlampaui';
  @override String get budgetPerfNoBudgets => 'Buat anggaran untuk melihat performa';
  @override String get reportTabIncomeExpr => 'Pemasukan';
  @override String get reportTabCashflow => 'Arus Kas';
  @override String get reportTabSpending => 'Pengeluaran';
  @override String get reportNoData => 'Tidak ada data untuk periode ini';
  @override String get reportNet => 'Pendapatan Bersih';
  @override String get dashboardBalanceCurrency => 'Saldo per Mata Uang';
  @override String get close => 'Tutup';

  @override String get walletTitle => 'Akun Saya';
  @override String get walletNoAccounts => 'Belum ada akun.\nKetuk + untuk menambahkan.';
  @override String get walletSearch => 'Cari akun...';
  @override String get walletNoResults => 'Akun tidak ditemukan';

  // Settings
  @override String get settingsTapToSwitch => 'Ketuk untuk ganti profil';
  @override String get settingsConnectSupabase => 'Hubungkan ke Supabase';
  @override String get settingsLockApp => 'Kunci Aplikasi';
  @override String get settingsLockAppSubtitleOn => 'Butuh PIN/Biometrik';
  @override String get settingsLockAppSubtitleOff => 'Aplikasi tidak terkunci';
  @override String get settingsBiometric => 'Login Biometrik';
  @override String get settingsChangePin => 'Ubah PIN';
  @override String get settingsAboutTitle => 'Tentang Richer';
  @override String get settingsRateUs => 'Beri Penilaian';
  @override String get settingsJoinCommunity => 'Gabung Komunitas';
  @override String get settingsWhatsNew => 'Yang Baru';
  @override String get settingsNoAnnouncements => 'Tidak ada pengumuman baru';
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
  @override String get settingsClearDataContent => 'Ini akan menghapus SEMUA data Anda secara permanen termasuk semua profil, transaksi, akun, dan kategori. Tindakan ini tidak dapat dibatalkan.';
  @override String get settingsClearDataConfirmPrompt => 'Ketik "Konfirmasi" untuk melanjutkan:';
  @override String get settingsClearDataConfirmKeyword => 'Konfirmasi';
  @override String get settingsClearEverything => 'Hapus Semuanya';
  @override String get settingsClearSuccess => 'Semua data berhasil dihapus';
  @override String get settingsClearError => 'Gagal menghapus data';
  @override String get deleteProfileTitle => 'Hapus Profil';
  @override String get deleteProfileContent => 'Ini akan menghapus profil ini dan SEMUA datanya secara permanen termasuk transaksi, akun, kategori, anggaran, dan tujuan.\n\nTindakan ini tidak dapat dibatalkan.';
  @override String get deleteProfileButton => 'Hapus Profil';
  @override String get deleteProfileSuccess => 'Profil berhasil dihapus';
  @override String get genericCancel => 'Batal';
  @override String get genericVerify => 'Verifikasi';
  @override String get genericSet => 'Atur PIN';
  @override String get settingsVersion => 'Versi';
  @override String get settingsNoProfile => 'Tidak Ada Profil';

  // Premium
  @override String get premiumRedeemVoucher => 'Tukar Voucher (Premium Seumur Hidup)';
  @override String get premiumGetPremium => 'Dapatkan Premium (Seumur Hidup)';
  @override String get premiumLifetimeSubtitle => 'Buka semua fitur.';
  @override String get premiumGetPremiumSubtitle => 'Buka semua fitur. Dukung Richer.';
  @override String get premiumSyncSubscription => 'Langganan Sinkronisasi';
  @override String get premiumSyncSubtitle => 'Fitur Premium + Sinkronisasi antar perangkat — tahunan';
  @override String get premiumRestorePurchase => 'Pulihkan Pembelian';
  @override String get premiumEnterVoucherCode => 'Masukkan kode voucher';
  @override String get premiumRedeem => 'Tukar';
  @override String get premiumActivated => 'Premium diaktifkan! 🎉';
  @override String get premiumInvalidVoucher => 'Kode voucher tidak valid.';
  @override String get premiumVoucherUsed => 'Voucher ini sudah digunakan.';
  @override String get premiumNotSignedIn => 'Silakan masuk terlebih dahulu.';
  @override String get premiumVoucherDisabled => 'Penukaran voucher tidak tersedia.';
  @override String get premiumRestored => 'Premium dipulihkan: ';
  @override String get premiumCheckingPlayStore => 'Memeriksa pembelian Play Store...';
  @override String get premiumSignInGoogle => 'Masuk dengan Google';
  @override String get premiumRestartAppToHideAds => 'Muat ulang aplikasi agar iklan hilang sepenuhnya';
  @override String get premiumVoucherSuccessTitle => 'Premium Seumur Hidup Aktif';
  @override String get premiumVoucherSuccessBody => 'Semua sudah siap. Terima kasih banyak — ini sungguh berarti. Nikmati semua fiturnya, dan semoga rezeki selalu hadir untukmu.';
  @override String get premiumSignInRequired => 'Diperlukan untuk tukar voucher & pulihkan pembelian';
  @override String get premiumSignInFailed => 'Masuk gagal. Silakan coba lagi.';
  @override String get premiumSignInSuccess => 'Berhasil masuk.';
  @override String get premiumSignOutSuccess => 'Berhasil keluar.';
  @override String get premiumSignedInTryAgain => 'Berhasil masuk! Silakan coba lagi untuk menukar voucher Anda.';
  @override String get categoryTapToEditIcon => 'Ketuk untuk ganti ikon';

  // Report Details
  @override String get reportDetailChart => 'Grafik';
  @override String get reportDetailCategory => 'Kategori';
  @override String get reportDetailTitle => 'Judul';
  @override String get reportDetailByCategory => 'per Kategori';
  @override String get reportDetailByTitle => 'per Judul';
  @override String get reportDetailDailyAvgExpense => 'Rata-rata Pengeluaran/Hari';
  @override String get reportDetailDailyAvgIncome => 'Rata-rata Pemasukan/Hari';

  // Export Report
  @override String get exportReport => 'Ekspor Laporan';
  @override String get exportDateFrom => 'Dari Tanggal';
  @override String get exportDateTo => 'Sampai Tanggal';
  @override String get exportSelectStartDate => 'Pilih tanggal awal';
  @override String get exportSelectEndDate => 'Pilih tanggal akhir';
  @override String get exportButton => 'Ekspor XLSX';
  @override String get exportSuccess => 'Laporan berhasil diekspor';
  @override String get exportError => 'Gagal mengekspor laporan';
  @override String get exportNoData => 'Tidak ada transaksi dalam rentang tanggal ini';
  @override String get exportGenerating => 'Membuat laporan...';

  // Categories Screen
  @override String get categoriesTitle => 'Kelola Kategori';
  @override String get categoriesSearchHint => 'Cari kategori...';
  @override String get categoriesFilterExpense => 'Pengeluaran';
  @override String get categoriesFilterIncome => 'Pemasukan';
  @override String categoryUsedInTransactions(int count) =>
      count == 1 ? 'Digunakan dalam 1 transaksi' : 'Digunakan dalam $count transaksi';
  @override String get categoryNoneFound => 'Tidak ada kategori ditemukan';
  @override String get categoryAdded => 'Kategori ditambahkan';
  @override String get categoryAddError => 'Gagal menambahkan kategori';
  @override String get categoryUpdated => 'Kategori diperbarui';
  @override String get categoryUpdateError => 'Gagal memperbarui kategori';
  @override String get categoryDeleted => 'Kategori dihapus';
  @override String get categoryDeleteError => 'Gagal menghapus kategori';
  @override String get categoryCannotDeleteTitle => 'Kategori Tidak Dapat Dihapus';
  @override String categoryCannotDeleteContent(int count) =>
      'Kategori ini digunakan dalam $count transaksi. Anda tidak dapat menghapusnya selama masih tercatat dalam riwayat transaksi.';

  // Profile Selector Modal
  @override String get profileSwitchTitle => 'Ganti Profil';
  @override String get profileAddNew => 'Tambah Profil Baru';
  @override String get profileAddNewAdTitle => 'Tambah Profil Baru';
  @override String get profileAddNewAdContent => 'Tonton iklan singkat untuk membuat profil baru.';
  @override String get profileAddNewAdWatch => 'Tonton Iklan';
  @override String get profileAdNotCompleted => 'Iklan tidak selesai. Silakan coba lagi.';
  @override String get profileErrorDeleting => 'Gagal menghapus profil';

  // Add Profile Dialog
  @override String get profileNew => 'Profil Baru';
  @override String get profileChooseAvatar => 'Pilih Avatar';
  @override String get profileName => 'Nama Profil';
  @override String get profileNameHint => 'cth. Pribadi, Bisnis, Keluarga';
  @override String get profileNameEmpty => 'Mohon masukkan nama profil';
  @override String get profileNameExists => 'Profil dengan nama ini sudah ada';
  @override String profileCreated(String name) => 'Profil "$name" berhasil dibuat!';

  // Backup Screen
  @override String get backupTitle => 'Cadangan & Pemulihan';
  @override String get backupManual => 'Cadangan Manual';
  @override String get backupExport => 'Ekspor Database';
  @override String get backupExportSubtitle => 'Simpan data Anda ke dalam file';
  @override String get backupImport => 'Impor Database';
  @override String get backupImportSubtitle => 'Pulihkan data dari file cadangan';
  @override String get backupRestoreConfirmTitle => 'Pulihkan Database?';
  @override String get backupRestoreConfirmContent =>
      'Ini akan menimpa data Anda saat ini dengan file cadangan. Tindakan ini tidak dapat dibatalkan. Apakah Anda yakin?';
  @override String get backupRestoreConfirmButton => 'Pulihkan';
  @override String get backupExportSuccess => 'Database berhasil diekspor';
  @override String get backupExportFailed => 'Ekspor gagal';
  @override String get backupImportSuccess => 'Database berhasil dipulihkan!';
  @override String get backupImportFailed => 'Impor gagal';
  @override String get backupSelectBackup => 'Pilih Cadangan untuk Dipulihkan';
  @override String get backupDriveConfirmTitle => 'Pulihkan dari Drive?';
  @override String get backupDriveConfirmContent =>
      'Ini akan menimpa data Anda saat ini dengan cadangan yang dipilih. Tindakan ini tidak dapat dibatalkan.';
  @override String get backupUploadSuccess => 'Berhasil diunggah ke Drive!';
  @override String get backupUploadFailed => 'Pengunggahan gagal';
  @override String get backupRestoreSuccess => 'Berhasil dipulihkan!';
  @override String get backupRestoreFailed => 'Pemulihan gagal';
  @override String get backupLoadFailed => 'Gagal memuat cadangan';
  @override String get backupNoneOnDrive => 'Tidak ada cadangan di Drive';
  @override String get backupGoogleSignInFailed => 'Masuk Google gagal';
  @override String get backupGoogleDrive => 'Cadangan Cloud (Google Drive)';
  @override String get backupConnectDrive => 'Hubungkan Google Drive';
  @override String get backupToDrive => 'Cadangkan ke Drive';
  @override String get backupToDriveSubtitle => 'Simpan data saat ini ke cloud';
  @override String get backupRestoreFromDrive => 'Pulihkan dari Drive';
  @override String get backupRestoreFromDriveSubtitle => 'Pulihkan data dari cadangan cloud';
  @override String get backupDisconnect => 'Putuskan';
  @override String get backupDailyAutoInfo => 'Hubungkan akun Google Anda untuk mengaktifkan cadangan otomatis harian. Data Anda akan dicadangkan secara otomatis setiap kali Anda membuka aplikasi (sekali per hari). Hingga 14 file cadangan akan disimpan.';
  @override String get backupCloudEnable => 'Aktifkan Backup Cloud';
  @override String get backupCloudEnableSubtitle => 'Backup harian otomatis ke Google Drive';

  // Date Range Filter Modal
  @override String get filterByDateRange => 'Filter berdasarkan tanggal';
  @override String get filterClear => 'Hapus';
  @override String get filterDateFrom => 'Dari Tanggal';
  @override String get filterDateFromPlaceholder => 'Pilih tanggal awal';
  @override String get filterDateTo => 'Sampai Tanggal';
  @override String get filterDateToPlaceholder => 'Pilih tanggal akhir';
  @override String get filterDateToAfterFrom => 'Tanggal Akhir harus setelah Tanggal Awal';
  @override String get filterEmptyHint => 'Tanggal Awal kosong = transaksi pertama\nTanggal Akhir kosong = hari ini';
  @override String get filterApply => 'Terapkan Filter';

  // Transaction History Screen
  @override String get txnCustomRange => 'Rentang Khusus';
  @override String get txnNoTransactions => 'Tidak ada transaksi';
  @override String get txnNoTransactionsHint => 'Ketuk + untuk mencatat transaksi pertama';
  @override String get txnNoAccountHint => 'Tambahkan akun dompet terlebih dahulu, lalu catat transaksi';
  @override String get txnZeroBalanceHint => 'Saldo akun Anda nol. Tambahkan pemasukan atau atur saldo awal di pengaturan akun';
  @override String get txnFilterDebt => 'Hutang';
  @override String get txnFilterAdjustment => 'Penyesuaian';
  @override String get txnDaySummaryTxn => 'Transaksi';

  // Debt Payoff Card (Phase 6)
  @override String get debtPayoffTitle => 'Ringkasan Pelunasan';
  @override String get debtPayoffTotalRemaining => 'Total Sisa';
  @override String get debtPayoffOverdue => 'Terlambat';
  @override String get debtPayoffDueSoon => 'Segera Jatuh Tempo';
  @override String get debtPayoffNoDeadline => 'Tanpa Tenggat';
  @override String get debtPayoffNextDue => 'Jatuh tempo berikutnya';
  @override String get debtPayoffPaid => 'terbayar';
  @override String get debtPayoffCollected => 'terkumpul';

  // Coach Mark Tour - Transactions Screen
  @override String get tourRecurringTitle => 'Transaksi Berulang';
  @override String get tourRecurringDesc => 'Lihat dan kelola transaksi berulang Anda di sini.';
  @override String get tourDateFilterTitle => 'Filter Tanggal';
  @override String get tourDateFilterDesc => 'Filter transaksi berdasarkan rentang tanggal tertentu.';
  @override String get tourMonthNavTitle => 'Ganti Bulan';
  @override String get tourMonthNavDesc => 'Ketuk panah atau geser untuk berpindah bulan.';
  @override String get tourSearchTitle => 'Cari & Filter';
  @override String get tourSearchDesc => 'Cari berdasarkan kata kunci atau filter berdasarkan kategori dan jenis transaksi.';
  @override String get tourAddTitle => 'Tambah Transaksi';
  @override String get tourAddDesc => 'Ketuk di sini untuk mencatat pemasukan atau pengeluaran baru.';
  @override String get tourNavbarTitle => 'Navigasi';
  @override String get tourNavbarDesc => 'Pindah antara Dashboard, Transaksi, Akun, Laporan, dan Pengaturan.';
  @override String get tourWalletInitTitle => 'Atur Saldo Awal';
  @override String get tourWalletInitDesc => 'Ketuk ikon Dompet di sini untuk menambahkan akun dan mengatur saldo awalnya sebelum mencatat transaksi.';

  // Coach Mark Tour - Dashboard Screen
  @override String get tourDashTabsTitle => 'Dua Tampilan Sekaligus';
  @override String get tourDashTabsDesc => "Ketuk 'Laporan' untuk mengakses analitik lengkap dan rincian bulanan.";
  @override String get tourDashSummaryRowsTitle => 'Ketuk Baris untuk Detail';
  @override String get tourDashSummaryRowsDesc => 'Ketuk baris ringkasan untuk melihat rincian per mata uang dengan kurs terkini.';
  @override String get tourDashFinHealthTitle => 'Skor Keuangan Anda';
  @override String get tourDashFinHealthDesc => 'Kartu ini menilai kesehatan keuangan Anda \u2014 ketuk untuk memahami setiap faktor.';
  @override String get tourDashPieChartTitle => 'Diagram Lingkaran Interaktif';
  @override String get tourDashPieChartDesc => 'Tekan lama irisan untuk melihat jumlah dan persentase tepat tiap kategori.';
  @override String get tourDashPullRefreshTitle => 'Perbarui Data';
  @override String get tourDashPullRefreshDesc => 'Tarik ke bawah untuk memperbarui semua saldo.';
  @override String get tourDashExportTitle => 'Ekspor Laporan';
  @override String get tourDashExportDesc => 'Pindah ke tab Laporan dan ketuk ikon unduhan untuk mengekspor laporan keuangan.';
  @override String get tourDashReportsSubTabsTitle => 'Dua Tampilan Analitik';
  @override String get tourDashReportsSubTabsDesc => "'Analitik Mendalam' menampilkan grafik; 'Detail Bulanan' menampilkan setiap bulan.";
  @override String get tourDashMonthlyCardTitle => 'Ketuk Bulan untuk Laporan';
  @override String get tourDashMonthlyCardDesc => 'Ketuk kartu bulan untuk membuka laporan mendalam.';
  @override String get tourDashScrollMoreTitle => 'Lebih Banyak Riwayat';
  @override String get tourDashScrollMoreDesc => 'Gulir ke bawah untuk memuat bulan-bulan sebelumnya.';

  // Coach Mark Tour - Accounts Screen
  @override String get tourAccFiltersTitle => 'Filter Tersembunyi';
  @override String get tourAccFiltersDesc => 'Ketuk Filter \u25be untuk membuka pencarian dan filter akun.';
  @override String get tourAccFilterDotTitle => 'Indikator Filter Aktif';
  @override String get tourAccFilterDotDesc => 'Titik emas berarti ada filter yang aktif.';
  @override String get tourAccCurrencyTitle => 'Filter Mata Uang';
  @override String get tourAccCurrencyDesc => 'Pilih mata uang untuk menampilkan akun tertentu.';
  @override String get tourAccTypeTitle => 'Filter Jenis Akun';
  @override String get tourAccTypeDesc => 'Ketuk chip untuk menyaring akun berdasarkan jenis.';
  @override String get tourAccTotalTitle => 'Semua Akun Digabung';
  @override String get tourAccTotalDesc => 'Saldo ini diperbarui saat Anda mengubah filter.';
  @override String get tourAccTapEditTitle => 'Ketuk untuk Edit';
  @override String get tourAccTapEditDesc => 'Ketuk kartu akun untuk mengubah detail akun.';

  // Coach Mark Tour - Wealth Screen
  @override String get tourWealthTabsTitle => 'Tiga Alat Kekayaan';
  @override String get tourWealthTabsDesc => 'Geser atau ketuk tab untuk Anggaran, Tujuan, dan Utang.';
  @override String get tourWealthBudgetFilterTitle => 'Filter Anggaran';
  @override String get tourWealthBudgetFilterDesc => 'Ketuk Filter \u25be untuk menyaring anggaran.';
  @override String get tourWealthPeriodCollapseTitle => 'Ciutkan Grup Anggaran';
  @override String get tourWealthPeriodCollapseDesc => 'Ketuk header periode untuk menciutkan atau memperluas grup.';
  @override String get tourWealthPeriodBarTitle => 'Bilah Ringkasan Periode';
  @override String get tourWealthPeriodBarDesc => 'Bilah progres menampilkan pengeluaran gabungan.';
  @override String get tourWealthBudgetTapTitle => 'Ketuk untuk Edit Anggaran';
  @override String get tourWealthBudgetTapDesc => 'Ketuk kartu anggaran untuk mengubah detail.';
  @override String get tourWealthGoalTapTitle => 'Ketuk Tujuan untuk Edit';
  @override String get tourWealthGoalTapDesc => 'Ketuk kartu tujuan untuk memperbarui target.';
  @override String get tourWealthGoalLongPressTitle => 'Tekan Lama untuk Rincian';
  @override String get tourWealthGoalLongPressDesc => 'Tekan lama kartu tujuan untuk melihat kontribusi akun.';
  @override String get tourWealthDebtPayoffTitle => 'Proyeksi Pelunasan Utang';
  @override String get tourWealthDebtPayoffDesc => 'Kartu ini memproyeksikan kapan Anda bebas utang.';
  @override String get tourWealthDebtGroupTitle => 'Ciutkan berdasarkan Orang';
  @override String get tourWealthDebtGroupDesc => 'Ketuk nama orang untuk menciutkan utang mereka.';
  @override String get tourWealthDebtTapTitle => 'Ketuk untuk Catat Pembayaran';
  @override String get tourWealthDebtTapDesc => 'Ketuk kartu utang untuk mencatat pembayaran.';

  // Coach Mark Tour - Settings Screen
  @override String get tourSettingsBellTitle => 'Lonceng Pengumuman';
  @override String get tourSettingsBellDesc => 'Ketuk lonceng untuk membaca pengumuman. Titik merah berarti pesan belum dibaca.';
  @override String get tourSettingsProfileTitle => 'Ganti Profil';
  @override String get tourSettingsProfileDesc => 'Ketuk profil untuk beralih atau membuat profil baru.';
  @override String get tourSettingsBackupTitle => 'Cadangkan Data';
  @override String get tourSettingsBackupDesc => 'Gunakan Backup & Restore untuk mengekspor atau memulihkan data.';
  @override String get tourSettingsLockTitle => 'Lindungi dengan PIN';
  @override String get tourSettingsLockDesc => 'Aktifkan Kunci Aplikasi agar PIN diperlukan.';
  @override String get tourSettingsBioTitle => 'Biometrik Butuh PIN Dulu';
  @override String get tourSettingsBioDesc => 'Sidik jari hanya aktif setelah PIN diatur.';
  @override String get tourSettingsThemeTitle => 'Ubah Tema';
  @override String get tourSettingsThemeDesc => 'Ketuk Tema untuk memilih tampilan aplikasi.';
  @override String get tourSettingsCatsTitle => 'Kategori Kustom';
  @override String get tourSettingsCatsDesc => 'Tambah, ubah, atau hapus kategori transaksi.';
  @override String get tourSettingsFeedbackTitle => 'Kirim Masukan';
  @override String get tourSettingsFeedbackDesc => 'Tulis pesan langsung kepada tim pengembang.';

  // Coach Mark Tour - Report Details Screen
  @override String get tourReportTabsTitle => 'Tiga Sudut Laporan';
  @override String get tourReportTabsDesc => 'Grafik, Kategori, dan Judul transaksi.';
  @override String get tourReportSegmentTitle => 'Ganti Pengeluaran vs Pemasukan';
  @override String get tourReportSegmentDesc => 'Ketuk kontrol untuk beralih antara diagram Pengeluaran dan Pemasukan.';
  @override String get tourReportPieLongTitle => 'Tekan Lama untuk Detail';
  @override String get tourReportPieLongDesc => 'Tekan lama irisan untuk melihat jumlah dan persentase.';
  @override String get tourReportCategoryTitle => 'Ketuk Kategori untuk Riwayat';
  @override String get tourReportCategoryDesc => 'Ketuk kategori untuk melihat riwayat bulanan.';
  @override String get tourReportTitleRowTitle => 'Ketuk Judul untuk Riwayat';
  @override String get tourReportTitleRowDesc => 'Ketuk judul untuk melihat riwayat pengeluaran lengkap.';

  // Coach Mark Tour - Account Transaction History Screen
  @override String get tourAccHistTypeTitle => 'Filter berdasarkan Jenis';
  @override String get tourAccHistTypeDesc => 'Ketuk chip untuk menampilkan jenis transaksi tertentu.';
  @override String get tourAccHistSearchTitle => 'Cari Transaksi';
  @override String get tourAccHistSearchDesc => 'Ketik untuk memfilter transaksi secara real time.';
  @override String get tourAccHistScrollTitle => 'Lebih Banyak di Bawah';
  @override String get tourAccHistScrollDesc => 'Gulir ke bawah untuk memuat 20 transaksi berikutnya.';
  @override String get tourAccHistTapTitle => 'Ketuk untuk Edit';
  @override String get tourAccHistTapDesc => 'Ketuk baris transaksi untuk membuka formulir lengkap.';

  // Coach Mark Tour - Recurring List Screen
  @override String get tourRecurringSearchTitle => 'Cari Berulang';
  @override String get tourRecurringSearchDesc => 'Ketik untuk menyaring aturan berulang.';
  @override String get tourRecurringInactiveTitle => 'Aturan Tidak Aktif Ada';
  @override String get tourRecurringInactiveDesc => 'Kartu redup dijeda \u2014 tidak diposting sampai diaktifkan.';
  @override String get tourRecurringNextRunTitle => 'Jadwal Berikutnya';
  @override String get tourRecurringNextRunDesc => 'Setiap aturan aktif menampilkan tanggal transaksi berikutnya.';
  @override String get tourRecurringTapTitle => 'Ketuk untuk Edit atau Jeda';
  @override String get tourRecurringTapDesc => 'Ketuk kartu untuk mengubah atau mengaktifkan/menonaktifkan.';

  // Coach Mark Tour - Wallet Screen
  @override String get tourWalletBalanceTitle => 'Total Saldo';
  @override String get tourWalletBalanceDesc => 'Lihat total saldo dari semua akun yang difilter, dikonversi ke mata uang dasar kamu.';
  @override String get tourWalletFabTitle => 'Tambah Akun';
  @override String get tourWalletFabDesc => 'Ketuk di sini untuk membuat akun baru — tunai, bank, e-wallet, atau investasi.';
  @override String get tourWalletCardTitle => 'Edit Akun';
  @override String get tourWalletCardDesc => 'Ketuk kartu akun mana saja untuk melihat riwayat transaksi atau mengubah detailnya.';

  // Financial Health Score (Phase 7)
  @override String get healthScoreTitle => 'Kesehatan Keuangan';
  @override String get healthScoreLabel => 'Skor Kesehatan';
  @override String get healthScoreSavings => 'Tingkat Tabungan';
  @override String get healthScoreBudget => 'Kepatuhan Anggaran';
  @override String get healthScoreDebt => 'Beban Utang';
  @override String get healthScoreTrend => 'Tren Pengeluaran';
  @override String get healthScoreGradeA => 'Sangat Baik';
  @override String get healthScoreGradeB => 'Baik';
  @override String get healthScoreGradeC => 'Cukup';
  @override String get healthScoreGradeD => 'Perlu Perbaikan';
  @override String get healthScoreGradeF => 'Kritis';
  @override String get healthScoreTapToExpand => 'Ketuk untuk detail';

  // Financial Health Score – methodology sheet
  @override String get healthScoreMethodologyTitle => 'Bagaimana cara menghitung ini?';
  @override String get healthScoreFormulaLabel => 'Skor Keseluruhan';
  @override String get healthScoreFormulaDesc => '(Tabungan + Anggaran + Utang + Tren) ÷ 4\nSetiap komponen dinilai 0–100 dengan bobot sama 25%.';
  @override String get healthScoreGradeScaleLabel => 'Skala Nilai';
  @override String get healthScoreWeight => 'Bobot 25%';
  @override String get healthScoreSavingsDesc => 'Rata-rata tingkat tabungan selama 3 bulan terakhir.\nTingkat tabungan = (Pemasukan − Pengeluaran) ÷ Pemasukan × 100';
  @override String get healthScoreSavingsFormula => '< 0% → 0  •  0–4% → 10  •  5–9% → 30\n10–19% → 55  •  20–29% → 75  •  ≥ 30% → 100';
  @override String get healthScoreBudgetDesc => 'Berapa banyak anggaran bulanan yang berhasil dipatuhi, dirata-rata selama 3 bulan terakhir.\nSkor = (1 − terlampaui ÷ total) × 100';
  @override String get healthScoreBudgetNote => '* Hanya anggaran bulanan yang dihitung. Bulan tanpa anggaran berkontribusi nilai netral 70.';
  @override String get healthScoreDebtDesc => 'Total utang yang belum lunas dibandingkan dengan 3× rata-rata penghasilan bulanan.';
  @override String get healthScoreDebtFormula => 'Rasio = Utang ÷ (Rata-rata penghasilan × 3)\n≤ 0,5× → 90  •  ≤ 1× → 70  •  ≤ 2× → 40\n≤ 3× → 20  •  > 3× → 5  •  Tanpa utang → 100';
  @override String get healthScoreTrendDesc => 'Pengeluaran bulan ini dibandingkan rata-rata hingga 3 bulan sebelumnya.';
  @override String get healthScoreTrendFormula => '< 90% → 100  •  90–99% → 80  •  100–109% → 60\n110–129% → 35  •  ≥ 130% → 10';
  @override String get healthScoreThresholdLabel => 'Ambang skor';
  @override String get healthScoreCurrentScore => 'Skor kamu';

  // Share Achievement Feature
  @override String get shareAchievement => 'Bagikan Pencapaian';
  @override String get achievementsTitle => 'Pencapaian';
  @override String get shareCaption_savingsStreak =>
      'Tiga bulan berturut-turut pengeluaran lebih kecil dari pemasukan. Kebiasaan kecil, hasil konsisten. Dipantau lewat Richer. #Richer #KeuanganPribadi #StreakTabungan';
  @override String get shareCaption_financeChampion =>
      'Lima bulan berturut-turut — pemasukan selalu lebih besar dari pengeluaran. Konsistensi ini ternyata memuaskan banget. #Richer #FinanceChampion #KebiasaanUang';
  @override String get shareCaption_budgetChampion =>
      'Semua anggaran bulan ini berhasil dijaga. Ternyata menentukan batas dan benar-benar mengikutinya adalah dua hal yang sangat berbeda. #Richer #TujuanAnggaran #DisiplinKeuangan';
  @override String get shareCaption_budgetDisciplined =>
      'Tiga bulan disiplin dengan anggaran. Membangun kebiasaan keuangan yang lebih baik, satu bulan dalam satu waktu. #Richer #DisiplinAnggaran #KebiasaanUang';
  @override String get shareCaption_gradeA =>
      'Skor kesehatan keuanganku baru saja mencapai Nilai A. Tingkat tabungan, beban utang, kepatuhan anggaran, tren pengeluaran — semua hijau. #Richer #KesehatanKeuangan #NilaiA';
  @override String get shareCaption_gradeB =>
      'Nilai B untuk cek kesehatan keuanganku. Masih ada satu dua komponen yang perlu ditingkatkan, tapi arahnya sudah benar. Progres lambat tetap progres. #Richer #KesehatanKeuangan #PerjalananUang';
  @override String get shareCaption_spendingUnderControl =>
      'Pengeluaranku terus turun 3 bulan berturut-turut. Bukan karena menyiksa diri — hanya lebih disengaja dalam pengeluaran. #Richer #BelanjaCerdas #KebebasanFinansial';

  // Premium Gate Modal
  @override String get premiumGateButtonBuyLifetime => 'Beli Premium Seumur Hidup';
  @override String get premiumGateButtonMaybeLater => 'Nanti Saja';
  @override String get premiumGateTagline => 'Bayar sekali. Tanpa langganan.';
  @override String get premiumGateRestorePurchase => 'Pulihkan Pembelian';
  @override String get premiumGateBudgetTitle => 'Batas Anggaran Tercapai';
  @override String get premiumGateBudgetDesc => 'Tier gratis hanya mendukung 3 anggaran. Upgrade untuk anggaran tak terbatas.';
  @override String get premiumGateGoalTitle => 'Batas Target Tercapai';
  @override String get premiumGateGoalDesc => 'Tier gratis hanya mendukung 3 target. Upgrade untuk target tak terbatas.';
  @override String get premiumGateAccountTitle => 'Batas Akun Tercapai';
  @override String get premiumGateAccountDesc => 'Tier gratis hanya mendukung 5 akun. Upgrade untuk akun tak terbatas.';
  @override String get premiumGateExportTitle => 'Fitur Premium';
  @override String get premiumGateExportDesc => 'Ekspor CSV hanya tersedia untuk pengguna premium.';
  @override String get premiumGateDeepAnalyticsTitle => 'Analitik Mendalam';
  @override String get premiumGateDeepAnalyticsDesc => 'Buka wawasan keuangan mendalam dan analisis tren dengan premium.';
  @override String get premiumGateProfileTitle => 'Batas Profil Tercapai';
  @override String get premiumGateProfileDesc => 'Tier gratis hanya mendukung 1 profil. Upgrade untuk mengelola banyak profil.';
  @override String get premiumGateCloudBackupDesc => 'Backup cloud ke Google Drive adalah fitur premium.';

  // Premium Benefits Modal
  @override String get premiumBenefitsTitle => 'Keuntungan Premium';
  @override String get premiumBenefitsSeeWhat => 'Lihat apa yang kamu dapatkan';
  @override String get premiumBenefitsModalTitle => 'Yang Kamu Dapatkan';
  @override String get premiumBenefitsModalSubtitle => 'Beli sekali. Milik selamanya.';
  @override String get premiumBenefitsClose => 'Tutup';
  @override String get premiumFeatureWallets => 'Dompet';
  @override String get premiumFeatureGoals => 'Tujuan';
  @override String get premiumFeatureBudgets => 'Kategori Anggaran';
  @override String get premiumFeatureProfiles => 'Profil';
  @override String get premiumFeatureAnalytics => 'Analitik Mendalam';
  @override String get premiumFeatureCloudBackup => 'Backup Harian Google Drive (opsional)';
  @override String get premiumFreeLimit5 => 'Maks. 5';
  @override String get premiumFreeLimit3 => 'Maks. 3';
  @override String get premiumFreeLimit1 => 'Hanya 1';
  @override String get premiumFreeLocked => 'Terkunci';
  @override String get premiumUnlimited => 'Tak Terbatas';
}
