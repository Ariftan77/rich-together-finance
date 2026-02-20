import 'app_translations.dart';

class AppTranslationsEn implements AppTranslations {
  // Navigation
  @override String get navDashboard => 'Dashboard';
  @override String get navTransactions => 'Transactions';
  @override String get navWallet => 'Wallet';
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
  @override String get commonPastDue => 'Past due';
  @override String get commonDueToday => 'Due today';
  @override String get commonDaysLeft => 'days left';
  @override String get commonTarget => 'Target';
  @override String get commonOf => 'of';
  @override String get commonPaid => 'Paid';
  @override String get commonAmount => 'Amount';
  @override String get commonMax => 'MAX';
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
  @override String get settingsNotifications => 'Notifications';
  @override String get settingsDailyReminder => 'Daily Reminder';
  @override String get settingsReminderTime => 'Reminder Time';
  @override String get notificationReminderTitle => '💰 Time to track!';
  @override String get notificationReminderBody => "Don't forget to record today's transactions.";
  @override String get settingsSyncBackup => 'Sync & Backup';
  @override String get settingsManageCategories => 'Manage Categories';
  @override String get settingsBackupRestore => 'Backup & Restore';
  @override String get settingsBaseCurrency => 'Base Currency';
  @override String get settingsShowDecimals => 'Show Decimals';
  @override String get settingsPremium => 'Premium';

  @override String get settingsAboutApp => 'About Rich Together';
  
  // About Screen
  @override String get aboutTagline => 'Your personal finance companion';
  @override String get aboutFeatures => 'Features';
  @override String get aboutFeatureExpense => 'Expense Tracking';
  @override String get aboutFeatureBudget => 'Budget Management';
  @override String get aboutFeatureAnalytics => 'Analytics & Reports';
  @override String get aboutFeatureMultiProfile => 'Multi-Profile Support';
  @override String get aboutFeatureOffline => 'Offline & Secure';
  @override String get aboutDeveloper => 'Developer';
  @override String get aboutContact => 'Contact';
  @override String get aboutCopyright => '© 2026 Rich Together. All rights reserved.';

  // Help & FAQ
  @override String get helpTitle => 'Help & FAQ';
  @override String get helpFaq1Question => 'How do I add a transaction?';
  @override String get helpFaq1Answer => 'Tap the + button on the Transactions screen, fill in the details (amount, category, account), and tap Save.';
  @override String get helpFaq2Question => 'How do I create multiple profiles?';
  @override String get helpFaq2Answer => 'Go to Settings, tap on your profile card, then select "Add New Profile". Each profile keeps its data completely separate.';
  @override String get helpFaq3Question => 'Can I track multiple currencies?';
  @override String get helpFaq3Answer => 'Yes! You can set different currencies for each account. Set your base currency in Settings to see consolidated totals.';
  @override String get helpFaq4Question => 'How do I set up recurring transactions?';
  @override String get helpFaq4Answer => 'When adding a transaction, tap "Make Recurring" and choose the frequency (daily, weekly, monthly, yearly).';
  @override String get helpFaq5Question => 'Is my data secure?';
  @override String get helpFaq5Answer => 'Yes! All data is stored locally on your device. We never send your financial data to external servers.';
  @override String get helpFaq6Question => 'How do I backup my data?';
  @override String get helpFaq6Answer => 'Go to Settings > Data Management > Backup. You can save to Google Drive or export to file.';
  @override String get helpFaq7Question => 'Can I use the app offline?';
  @override String get helpFaq7Answer => 'Absolutely! Rich Together works 100% offline. Internet is only needed for optional features like cloud backup.';
  @override String get helpContactSupport => 'Contact our support team';
  @override String get helpContactEmail => 'axiomtech.dev@gmail.com';

  // Privacy Policy
  @override String get privacyTitle => 'Privacy Policy';
  @override String get privacyLastUpdated => 'Last updated: February 2026';
  @override String get privacyDataCollectionTitle => 'Data Collection';
  @override String get privacyDataCollectionContent => 'Rich Together is designed with your privacy in mind. All your financial data is stored locally on your device. We do not collect, transmit, or store any of your personal financial information on external servers.';
  @override String get privacyLocalStorageTitle => 'Local Storage';
  @override String get privacyLocalStorageContent => 'Your data is stored securely on your device using encrypted SQLite database. The app operates fully offline, meaning your data never leaves your phone unless you explicitly choose to backup.';
  @override String get privacyBackupTitle => 'Optional Backup';
  @override String get privacyBackupContent => 'If you choose to use Google Drive backup, your data will be encrypted and stored in your personal Google Drive account. We do not have access to your backup files.';
  @override String get privacyAnalyticsTitle => 'No Third-Party Analytics';
  @override String get privacyAnalyticsContent => 'We do not use third-party analytics services that track your behavior or collect personal information.';
  @override String get privacyDeletionTitle => 'Data Deletion';
  @override String get privacyDeletionContent => 'You can delete all your data at any time from the Settings menu. Deleting the app will also remove all locally stored data.';
  @override String get privacyContactTitle => 'Contact';
  @override String get privacyContactContent => 'If you have questions about this Privacy Policy, please contact us at privacy@richtogether.app';

  // Terms of Service
  @override String get termsTitle => 'Terms of Service';
  @override String get termsLastUpdated => 'Last updated: February 2026';
  @override String get termsAcceptanceTitle => '1. Acceptance of Terms';
  @override String get termsAcceptanceContent => 'By using Rich Together, you agree to these Terms of Service. If you do not agree, please do not use this application.';
  @override String get termsUsageTitle => '2. Use of the App';
  @override String get termsUsageContent => 'Rich Together is a personal finance tracking tool designed for individual use. You are responsible for maintaining the confidentiality of your data and any PINs or passwords you set.';
  @override String get termsAccuracyTitle => '3. Data Accuracy';
  @override String get termsAccuracyContent => 'The app provides tools for tracking your finances, but we do not guarantee the accuracy of calculations. You should verify all financial information independently.';
  @override String get termsAdviceTitle => '4. Not Financial Advice';
  @override String get termsAdviceContent => 'Rich Together is not a substitute for professional financial advice. The app is for informational purposes only. Consult a qualified financial advisor for investment decisions.';
  @override String get termsLiabilityTitle => '5. Limitation of Liability';
  @override String get termsLiabilityContent => 'We are not liable for any financial losses, data loss, or damages arising from the use of this application.';
  @override String get termsUpdatesTitle => '6. Updates';
  @override String get termsUpdatesContent => 'We may update these terms from time to time. Continued use of the app constitutes acceptance of the updated terms.';
  @override String get termsContactTitle => '7. Contact';
  @override String get termsContactContent => 'For questions about these Terms of Service, contact us at legal@richtogether.app';

  // Sync Screen
  @override String get syncTitle => 'Sync & Backup';
  @override String get syncSignIn => 'Sign In';
  @override String get syncSignUp => 'Sign Up';
  @override String get syncFullName => 'Full Name';
  @override String get syncEmail => 'Email';
  @override String get syncPassword => 'Password';
  @override String get syncNoAccount => "Don't have an account? Sign Up";
  @override String get syncHaveAccount => 'Already have an account? Sign In';
  @override String get syncConnectedAs => 'Connected as';
  @override String get syncBackedUp => 'Your data is backed up to the cloud.';
  @override String get syncNow => 'Sync Now';
  @override String get syncLogOut => 'Log Out';
  @override String get syncLoggedIn => 'Logged in successfully!';
  @override String get syncCompleted => 'Sync completed!';
  @override String get syncFailed => 'Sync failed';
  @override String get syncStillNeedHelp => 'Still need help?';

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

  // Recurring
  @override String get recurringTitle => 'Recurring';
  @override String get recurringTitleAdd => 'New Recurring';
  @override String get recurringTitleEdit => 'Edit Recurring';
  @override String get recurringFrequency => 'Frequency';
  @override String get recurringInterval => 'Repeat Every';
  @override String get recurringStartDate => 'Start Date';
  @override String get recurringEndDate => 'End Date';
  @override String get recurringNoEndDate => 'No end date';
  @override String get recurringLastRun => 'Last run';
  @override String get recurringNextRun => 'Next run';
  @override String get recurringNoRecurring => 'No recurring transactions';
  @override String get recurringNoRecurringHint => 'Tap + to set up a recurring transaction';
  @override String get recurringDaily => 'Daily';
  @override String get recurringWeekly => 'Weekly';
  @override String get recurringMonthly => 'Monthly';
  @override String get recurringYearly => 'Yearly';

  // Budget
  @override String get budgetTitle => 'Budgets';
  @override String get budgetTitleAdd => 'New Budget';
  @override String get budgetTitleEdit => 'Edit Budget';
  @override String get budgetAmount => 'Limit Amount';
  @override String get budgetPeriod => 'Period';
  @override String get budgetSpent => 'Spent';
  @override String get budgetRemaining => 'Left';
  @override String get budgetExceeded => 'Over by';
  @override String get budgetLimit => 'Limit';
  @override String get budgetNoBudgets => 'No budgets set';
  @override String get budgetNoBudgetsHint => 'Tap + to create a spending limit';

  // Dashboard & Reports
  @override String get chartCashflow => 'Cash Flow';
  @override String get chartSpending => 'Spending by Category';
  @override String get reportTabIncomeExpr => 'Income'; // Wait, this might be duplicate or needed
  @override String get reportTabCashflow => 'Cash Flow';
  @override String get reportTabSpending => 'Spending';
  @override String get reportNoData => 'No data available for this period';
  @override String get reportNet => 'Net Income';
  @override String get dashboardBalanceCurrency => 'Balance by Currency';
  @override String get close => 'Close';

  @override String get walletTitle => 'My Accounts';
  @override String get walletNoAccounts => 'No accounts yet.\nTap + to add one.';

  // Settings
  @override String get settingsTapToSwitch => 'Tap to switch profile';
  @override String get settingsConnectSupabase => 'Connect to Supabase';
  @override String get settingsLockApp => 'Lock App';
  @override String get settingsLockAppSubtitleOn => 'PIN/Biometric required';
  @override String get settingsLockAppSubtitleOff => 'App is unlocked';
  @override String get settingsBiometric => 'Biometric Login';
  @override String get settingsChangePin => 'Change PIN';
  @override String get settingsAboutTitle => 'About Rich Together';
  @override String get settingsHelp => 'Help & FAQ';
  @override String get settingsPrivacy => 'Privacy Policy';
  @override String get settingsTerms => 'Terms of Service';
  @override String get settingsSelectCurrency => 'Select Currency';
  @override String get settingsVerifyPin => 'Verify Current PIN';
  @override String get settingsEnterCurrentPin => 'Enter current PIN';
  @override String get settingsSetNewPin => 'Set New PIN';
  @override String get settingsEnterNewPin => 'Enter new PIN (6 digits)';
  @override String get settingsConfirmNewPin => 'Confirm new PIN';
  @override String get settingsPinLengthError => 'PIN must be 6 digits';
  @override String get settingsPinMatchError => 'PINs do not match';
  @override String get settingsPinSetSuccess => 'PIN set & App Lock Enabled';
  @override String get settingsIncorrectPin => 'Incorrect PIN';
  @override String get settingsClearDataTitle => 'Clear All Data?';
  @override String get settingsClearDataContent => 'This will permanently delete ALL your data (transactions, accounts, categories). This action cannot be undone.';
  @override String get settingsClearDataConfirmPrompt => 'Type "Confirm" to proceed:';
  @override String get settingsClearDataConfirmKeyword => 'Confirm';
  @override String get settingsClearEverything => 'Clear Everything';
  @override String get settingsClearSuccess => 'All data cleared successfully';
  @override String get settingsClearError => 'Error clearing data';
  @override String get genericCancel => 'Cancel';
  @override String get genericVerify => 'Verify';
  @override String get genericSet => 'Set PIN';
  @override String get settingsVersion => 'Version';
  @override String get settingsNoProfile => 'No Profile';

  // Premium
  @override String get premiumRedeemVoucher => 'Redeem Voucher';
  @override String get premiumGetPremium => 'Get Premium';
  @override String get premiumLifetimeSubtitle => 'Lifetime — no ads, multi profile';
  @override String get premiumSyncSubscription => 'Sync Subscription';
  @override String get premiumSyncSubtitle => 'Cross-device sync — yearly';
  @override String get premiumRestorePurchase => 'Restore Purchase';
  @override String get premiumEnterVoucherCode => 'Enter voucher code';
  @override String get premiumRedeem => 'Redeem';
  @override String get premiumActivated => 'Premium activated! 🎉';
  @override String get premiumInvalidVoucher => 'Invalid voucher code.';
  @override String get premiumVoucherUsed => 'This voucher has already been used.';
  @override String get premiumNotSignedIn => 'Please sign in first.';
  @override String get premiumVoucherDisabled => 'Voucher redemption is not available.';
  @override String get premiumRestored => 'Premium restored: ';
  @override String get premiumCheckingPlayStore => 'Checking Play Store purchases...';
  @override String get premiumSignInGoogle => 'Sign in with Google';
  @override String get premiumSignInRequired => 'Required for voucher redemption & purchase restore';
  @override String get premiumSignInFailed => 'Sign in failed. Please try again.';
  @override String get premiumSignedInTryAgain => 'Signed in! Please try again to redeem your voucher.';
}

