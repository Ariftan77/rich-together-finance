import 'app_translations.dart';

class AppTranslationsId implements AppTranslations {
  // Navigation
  @override String get navDashboard => 'Beranda';
  @override String get navTransactions => 'Transaksi';
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
  @override String get settingsLockApp => 'Kunci Aplikasi';
  @override String get settingsBiometric => 'Login Biometrik';
  @override String get settingsChangePin => 'Ganti PIN';
  @override String get settingsAboutApp => 'Tentang Rich Together';
  @override String get settingsHelp => 'Bantuan & FAQ';
  @override String get settingsPrivacy => 'Kebijakan Privasi';
  @override String get settingsTerms => 'Syarat Layanan';
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
  @override String get investmentPlaceholderHint => 'Segera hadir — lacak portofolio Anda di sini';
}

