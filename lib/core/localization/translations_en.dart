import 'app_translations.dart';

class AppTranslationsEn implements AppTranslations {
  // Navigation
  @override String get navDashboard => 'Dashboard';
  @override String get navTransactions => 'Transactions';
  @override String get navPlanning => 'Planning';
  @override String get navSettings => 'Settings';
  @override String get navReports => 'Reports';
  
  @override String get dashboardTitle => 'My Dashboard';
  @override String get dashboardOverview => 'Overview';
  @override String get dashboardTotalBalance => 'Total Balance';
  @override String get dashboardNetWorth => 'Net Worth';
  @override String get dashboardIncome => 'Income';
  @override String get dashboardExpense => 'Expense';
  @override String get recentTransactions => 'Recent Transactions';
  @override String get viewAll => 'View All';
  @override String get noTransactions => 'No transactions yet';
  
  // Common
  @override String get ok => 'OK';
  @override String get cancel => 'Cancel';
  @override String get save => 'Save';
  @override String get delete => 'Delete';
  @override String get edit => 'Edit';
  @override String get search => 'Search';
  @override String get error => 'Error';
  @override String get success => 'Success';
  @override String get loading => 'Loading...';
  @override String get commonSearch => 'Search...';
  @override String get commonToday => 'Today';
  @override String get commonYesterday => 'Yesterday';
  @override String get commonThisMonth => 'This Month';
  @override String get filterAll => 'All';

  // Transaction Entry
  @override String get entryTitleAdd => 'Add Transaction';
  @override String get entryTitleEdit => 'Edit Transaction';
  @override String get entryAmount => 'AMOUNT';
  @override String get entryTypeIncome => 'Income';
  @override String get entryTypeExpense => 'Expense';
  @override String get entryTypeTransfer => 'Transfer';
  @override String get entryCategoryCreated => 'Category created successfully';
  @override String get entryCategory => 'Category';
  @override String get entryAccount => 'Account';
  @override String get entryFromAccount => 'From Account';
  @override String get entryToAccount => 'To Account';
  @override String get entryNote => 'Note';
  @override String get entryNoteHint => 'Add a note...';
  @override String get entryDate => 'Date';
  @override String get entrySaveButton => 'Save Transaction';
  
  @override String get entrySelectCategory => 'Select category';
  @override String get entrySearchCategory => 'Search categories...';
  @override String get entrySearchAccount => 'Search accounts...';
  @override String get entryNoAccounts => 'No accounts found';
  @override String get entryAddCategory => 'Add New Category'; // Or dynamic?

  
  @override String get entrySelectAccount => 'Select account';
  @override String get entryAddNote => 'Add Note';
  @override String get entryEditNote => 'Edit Note';
  
  // Transaction Feedback
  @override String transactionCreated(String amount) => 'Transaction of $amount created!';
  @override String transactionUpdated(String amount) => 'Transaction updated!';
  @override String get errorInsufficientFunds => 'Insufficient balance for this transaction';
  @override String get errorSelectCategory => 'Please select a category';
  @override String get errorSelectAccount => 'Please select an account';
  @override String get errorSelectDestAccount => 'Please select a destination account';
  @override String get errorInvalidAmount => 'Please enter a valid amount';
  @override String get errorNoActiveProfile => 'No active profile found';
  @override String get errorEnterCategoryName => 'Please enter a category name';
  @override String get errorLoadingCashFlow => 'Error loading cash flow: ';
  @override String get errorLoadingCategories => 'Error loading categories: ';
  
  @override String get accountTitleAdd => 'New Account';
  @override String get accountTitleEdit => 'Edit Account';
  @override String get accountNameExists => 'Account name already exists. Please use a different name.';
  @override String get accountNoProfile => 'No active profile. Please set up a profile first.';
  @override String get accountAdjustmentRequired => 'Please enter an adjustment amount';
  @override String get accountAdjustmentApplied => 'Adjustment applied';
  @override String get accountBalanceAdjustment => 'Balance Adjustment';
  @override String get accountAdjustmentHint => 'Enter positive for increase, negative for decrease';
  @override String get accountApply => 'Apply';
  @override String get accountViewHistory => 'View Transaction History';
  @override String get accountEditDetails => 'Edit Details';
  @override String get accountNameHint => 'Account Name';
  @override String get accountBalanceHint => 'Initial Balance';
  @override String get accountStartingBalanceHint => 'Starting Balance';
  @override String get accountBalanceRequired => 'Balance required';
  @override String get accountType => 'Type';
  @override String get accountCurrency => 'Currency';
  @override String get accountSave => 'Save Account';

  // Settings
  @override String get settingsTheme => 'Theme';
  @override String get settingsLanguage => 'Language';
  @override String get settingsProfile => 'Profile';
  @override String get settingsPreferences => 'Preferences';
  @override String get settingsSecurity => 'Security';
  @override String get settingsAbout => 'About';
  @override String get settingsSyncBackup => 'Sync & Backup';
  @override String get settingsManageCategories => 'Manage Categories';
  @override String get settingsBackupRestore => 'Backup & Restore';
  @override String get settingsBaseCurrency => 'Base Currency';
  @override String get settingsShowDecimals => 'Show Decimals';
  @override String get settingsLockApp => 'Lock App';
  @override String get settingsBiometric => 'Biometric Login';
  @override String get settingsChangePin => 'Change PIN';
  @override String get settingsAboutApp => 'About Rich Together';
  @override String get settingsHelp => 'Help & FAQ';
  @override String get settingsPrivacy => 'Privacy Policy';
  @override String get settingsTerms => 'Terms of Service';
  @override String get settingsClearData => 'Clear All Data';

  // Wealth / Navigation
  @override String get navWealth => 'Wealth';
  @override String get wealthBudget => 'Budget';
  @override String get wealthGoals => 'Goals';
  @override String get wealthInvestment => 'Investment';

  // Goals
  @override String get goalTitleAdd => 'New Goal';
  @override String get goalTitleEdit => 'Edit Goal';
  @override String get goalName => 'Goal Name';
  @override String get goalNameHint => 'e.g. Marriage Fund, Emergency Fund';
  @override String get goalTargetAmount => 'Target Amount';
  @override String get goalCurrency => 'Currency';
  @override String get goalDeadline => 'Deadline';
  @override String get goalNoDeadline => 'No deadline';
  @override String get goalLinkAccounts => 'Link Accounts';
  @override String get goalSaved => 'Saved';
  @override String get goalRemaining => 'Remaining';
  @override String get goalMonthlyNeeded => 'Monthly needed';
  @override String get goalAchieved => 'Achieved!';
  @override String get goalMarkAchieved => 'Mark as Achieved';
  @override String get goalNoGoals => 'No goals yet';
  @override String get goalNoGoalsHint => 'Tap + to create a financial goal';
  @override String get goalDeleted => 'Goal deleted';

  // Debts
  @override String get debtTitle => 'Debts';
  @override String get debtTitleAdd => 'New Debt';
  @override String get debtTitleEdit => 'Edit Debt';
  @override String get debtPayable => 'I Owe';
  @override String get debtReceivable => 'Owed to Me';
  @override String get debtPersonName => 'Person Name';
  @override String get debtPersonNameHint => 'Who?';
  @override String get debtDueDate => 'Due Date';
  @override String get debtSettle => 'Settle';
  @override String get debtSettleAccount => 'Settlement Account';
  @override String get debtNoDebts => 'No debts';
  @override String get debtNoDebtsHint => 'Tap + to add a debt record';
  @override String get debtSettled => 'Debt settled';

  // Investment
  @override String get investmentPlaceholder => 'Investment Tracking';
  @override String get investmentPlaceholderHint => 'Coming soon — track your portfolio here';
}

