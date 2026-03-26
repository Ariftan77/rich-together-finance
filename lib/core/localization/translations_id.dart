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
  @override String get premiumRedeemVoucher => 'Tukar Voucher';
  @override String get premiumGetPremium => 'Dapatkan Premium';
  @override String get premiumLifetimeSubtitle => 'Seumur hidup — tanpa iklan, multi profil';
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
  @override String get premiumSignInRequired => 'Diperlukan untuk tukar voucher & pulihkan pembelian';
  @override String get premiumSignInFailed => 'Masuk gagal. Silakan coba lagi.';
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
}
