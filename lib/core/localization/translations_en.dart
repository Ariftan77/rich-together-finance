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
  @override String get commonOthers => 'Others';
  @override String get filterAll => 'All';
  @override String get commonShare => 'Share';

  // Transaction Entry
  @override String get entryTitleAdd => 'Add Transaction';
  @override String get entryTitleEdit => 'Edit Transaction';
  @override String get entryAmount => 'AMOUNT';
  @override String get entryTypeIncome => 'Income';
  @override String get entryTypeExpense => 'Expense';
  @override String get entryTypeTransfer => 'Transfer';
  @override String get entryTypeAdjustmentIn => 'Adjustment +';
  @override String get entryTypeAdjustmentOut => 'Adjustment -';
  @override String get entryTypeDebtIn => 'Borrowed';
  @override String get entryTypeDebtOut => 'Lent';
  @override String get entryTypeDebtPaymentOut => 'Debt Payment';
  @override String get entryTypeDebtPaymentIn => 'Debt Received';
  @override String get entryCategoryCreated => 'Category created successfully';
  @override String get entryCategory => 'Category';
  @override String get entryAccount => 'Account';
  @override String get entryFromAccount => 'From Account';
  @override String get entryToAccount => 'To Account';
  @override String get entryTitle => 'Title';
  @override String get entryTitleHint => 'Enter title...';
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
  @override String get accountInitialBalance => 'Initial Balance';
  @override String get accountInitialBalanceHint => 'Sets the starting balance directly — no transaction recorded';
  @override String get accountAdjustBalance => 'Adjust Balance';
  @override String get accountAdjustBalanceHint => 'Creates an adjustment transaction to reach this balance';
  @override String get accountInitialBalanceApplied => 'Initial balance updated';
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
  @override String get settingsCardShadow => 'Card Shadow';
  @override String get settingsPremium => 'Premium';

  @override String get settingsAboutApp => 'About Richer';
  
  // About Screen
  @override String get aboutTagline => 'Your personal finance companion';
  @override String get aboutFeatures => 'Features';
  @override String get aboutFeatureExpense => 'Expense Tracking';
  @override String get aboutFeatureBudget => 'Budget Management';
  @override String get aboutFeatureAnalytics => 'Analytics & Reports';
  @override String get aboutFeatureMultiProfile => 'Multi-Profile Support';
  @override String get aboutFeatureOffline => 'Offline & Secure';
  @override String get aboutFeatureGoals => 'Financial Goals';
  @override String get aboutFeatureDebts => 'Debt Tracking';
  @override String get aboutFeatureRecurring => 'Recurring Transactions';
  @override String get aboutFeatureMultiCurrency => 'Multi-Currency';
  @override String get aboutFeatureSync => 'Cloud Sync & Backup';
  @override String get aboutFeatureInvestment => 'Manage Investment';
  @override String get aboutFeatureEncrypted => 'Encrypted Database';
  @override String get aboutComingSoon => 'Coming Soon';
  @override String get aboutDeveloper => 'Developer';
  @override String get aboutContact => 'Contact';
  @override String get aboutCopyright => '© 2026 Richer - Money Management. All rights reserved.';
  @override String get aboutEncryptionWarning => 'When you export a backup, the resulting file is DECRYPTED so you can restore it on another device. Keep your backup files in a safe place.';

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
  @override String get helpFaq5Answer => 'Your data is stored entirely on your device and never sent to external servers. We recommend securing your device with a strong screen lock to protect your financial data.';
  @override String get helpFaq6Question => 'How do I backup my data?';
  @override String get helpFaq6Answer => 'Go to Settings > Data Management > Backup & Restore. You can export your database to a file and share it via email, messaging, or cloud storage.';
  @override String get helpFaq7Question => 'Can I use the app offline?';
  @override String get helpFaq7Answer => 'Absolutely! Richer - Money Management works 100% offline. Internet is only needed for optional features like exchange rate updates.';
  @override String get helpFaq8Question => 'Is my database encrypted?';
  @override String get helpFaq8Answer => 'Yes — your data is stored in a local SQLite database encrypted with SQLCipher (AES-256). Your data is never transmitted externally and stays entirely private on your device.';
  @override String get helpContactSupport => 'Contact our support team';
  @override String get helpContactEmail => 'axiomtech.dev@gmail.com';

  // Privacy Policy
  @override String get privacyTitle => 'Privacy Policy';
  @override String get privacyLastUpdated => 'Last updated: March 2026';
  @override String get privacyDataCollectionTitle => 'Data Collection';
  @override String get privacyDataCollectionContent => 'Richer - Money Management is designed with your privacy in mind. All your financial data is stored locally on your device. We do not collect, transmit, or store any of your personal financial information on external servers.';
  @override String get privacyLocalStorageTitle => 'Local Storage';
  @override String get privacyLocalStorageContent => 'Your data is stored securely on your device using an SQLite database. The app operates fully offline, meaning your data never leaves your phone unless you explicitly choose to export a backup.';
  @override String get privacyEncryptionTitle => 'Data Security';
  @override String get privacyEncryptionContent => 'Your financial data is stored locally on your device in an SQLite database encrypted with military-grade SQLCipher encryption. Your data stays entirely private and secure on this device.';
  @override String get privacyBackupTitle => 'Optional Backup';
  @override String get privacyBackupContent => 'When you export a backup, your data is saved to a portable file that you can use to restore on any device. You are responsible for keeping your backup files safe. We do not have access to your backup files.';
  @override String get privacyAnalyticsTitle => 'No Third-Party Analytics';
  @override String get privacyAnalyticsContent => 'We do not use third-party analytics services that track your behavior or collect personal information.';
  @override String get privacyDeletionTitle => 'Data Deletion';
  @override String get privacyDeletionContent => 'You can delete all your data at any time from the Settings menu. Deleting the app will also remove all locally stored data.';
  @override String get privacyContactTitle => 'Contact';
  @override String get privacyContactContent => 'If you have questions about this Privacy Policy, please contact us at privacy@richtogether.app';

  // Terms of Service
  @override String get termsTitle => 'Terms of Service';
  @override String get termsLastUpdated => 'Last updated: March 2026';
  @override String get termsAcceptanceTitle => '1. Acceptance of Terms';
  @override String get termsAcceptanceContent => 'By using Richer - Money Management, you agree to these Terms of Service. If you do not agree, please do not use this application.';
  @override String get termsUsageTitle => '2. Use of the App';
  @override String get termsUsageContent => 'Richer - Money Management is a personal finance tracking tool designed for individual use. You are responsible for maintaining the confidentiality of your data and any PINs or passwords you set.';
  @override String get termsAccuracyTitle => '3. Data Accuracy';
  @override String get termsAccuracyContent => 'The app provides tools for tracking your finances, but we do not guarantee the accuracy of calculations. You should verify all financial information independently.';
  @override String get termsAdviceTitle => '4. Not Financial Advice';
  @override String get termsAdviceContent => 'Richer - Money Management is not a substitute for professional financial advice. The app is for informational purposes only. Consult a qualified financial advisor for investment decisions.';
  @override String get termsLiabilityTitle => '5. Limitation of Liability';
  @override String get termsLiabilityContent => 'We are not liable for any financial losses, data loss, or damages arising from the use of this application.';
  @override String get termsUpdatesTitle => '6. Updates';
  @override String get termsUpdatesContent => 'We may update these terms from time to time. Continued use of the app constitutes acceptance of the updated terms.';
  @override String get termsSecurityTitle => '7. Data Security';
  @override String get termsSecurityContent => 'Your data is stored locally on your device in an encrypted SQLite database. You are responsible for the safekeeping of any exported backup files.';
  @override String get termsContactTitle => '8. Contact';
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
  @override String get settingsSendFeedback => 'Send Feedback';
  @override String get settingsSendFeedbackHint => 'Tell us what you think or report a bug...';
  @override String get settingsSendFeedbackSuccess => 'Feedback sent successfully!';
  @override String get settingsSendFeedbackError => 'Failed to send feedback: ';
  @override String get settingsSendFeedbackEmpty => 'Feedback cannot be empty';

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
  @override String get goalSelectAccounts => 'Select Accounts';
  @override String get goalAllAccounts => 'All Accounts';
  @override String get goalNoAccountsAvailable => 'No accounts available';
  @override String get goalSearchAccounts => 'Search accounts...';
  @override String get goalClearAll => 'Clear all';
  @override String get goalAccountsSelected => 'accounts selected';

  // Debts
  @override String get debtTitle => 'Debts';
  @override String get debtTitleAdd => 'New Debt';
  @override String get debtTitleEdit => 'Edit Debt';
  @override String get debtPayable => 'I Owe';
  @override String get debtReceivable => 'Owed to Me';
  @override String get debtPersonName => 'Person Name';
  @override String get debtPersonNameHint => 'Who?';
  @override String get debtCreatedDate => 'Created Date';
  @override String get debtDueDate => 'Due Date';
  @override String get debtSettle => 'Settle';
  @override String get debtSettleGroup => 'Settle All';
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
  @override String get recurringName => 'Title';
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
  @override String budgetPeriodLimit(String period) => '$period Limit';
  @override String get budgetNoBudgets => 'No budgets set';
  @override String get budgetNoBudgetsHint => 'Tap + to create a spending limit';

  // Dashboard & Reports
  @override String get chartCashflow => 'Cash Flow';
  @override String get chartSpending => 'Spending by Category';
  @override String get chartSavingsRate => 'Savings Rate Trend';
  @override String get savingsRateLabel => 'Savings Rate';
  @override String get savingsRateVsPrev => 'vs prev. month';
  @override String get deepAnalyticsTab => 'Deep Analytics';
  @override String get monthlyDetailsTab => 'Monthly Details';
  @override String get monthOverMonthTitle => 'Month Comparison';
  @override String get monthOverMonthThisMonth => 'This Month';
  @override String get monthOverMonthLastMonth => 'Last Month';
  @override String get monthOverMonthLastYear => 'Last Year';
  @override String get ytdTopCategoriesTitle => 'Top Spending (YTD)';
  @override String get categoryTrendTitle => 'Category Trend';
  @override String get sectionTrends => 'Trends';
  @override String get sectionSpendingAnalysis => 'Spending Analysis';
  @override String get sectionBehaviorPatterns => 'Behavior Patterns';
  @override String get dowSpendingTitle => 'Spending by Day of Week';
  @override String get dowMon => 'Mon';
  @override String get dowTue => 'Tue';
  @override String get dowWed => 'Wed';
  @override String get dowThu => 'Thu';
  @override String get dowFri => 'Fri';
  @override String get dowSat => 'Sat';
  @override String get dowSun => 'Sun';
  @override String get recurringSplitTitle => 'Committed vs Discretionary';
  @override String get recurringSplitCommitted => 'Committed';
  @override String get recurringSplitDiscretionary => 'Discretionary';
  @override String get recurringSplitNoData => 'No recurring expenses';
  @override String get budgetPerfTitle => 'Budget Performance';
  @override String get budgetPerfExceeded => 'budgets exceeded';
  @override String get budgetPerfNoBudgets => 'Set up budgets to see performance';
  @override String get reportTabIncomeExpr => 'Income'; // Wait, this might be duplicate or needed
  @override String get reportTabCashflow => 'Cash Flow';
  @override String get reportTabSpending => 'Spending';
  @override String get reportNoData => 'No data available for this period';
  @override String get reportNet => 'Net Income';
  @override String get dashboardBalanceCurrency => 'Balance by Currency';
  @override String get close => 'Close';

  @override String get walletTitle => 'My Accounts';
  @override String get walletNoAccounts => 'No accounts yet.\nTap + to add one.';
  @override String get walletSearch => 'Search accounts...';
  @override String get walletNoResults => 'No accounts found';

  // Settings
  @override String get settingsTapToSwitch => 'Tap to switch profile';
  @override String get settingsConnectSupabase => 'Connect to Supabase';
  @override String get settingsLockApp => 'Lock App';
  @override String get settingsLockAppSubtitleOn => 'PIN/Biometric required';
  @override String get settingsLockAppSubtitleOff => 'App is unlocked';
  @override String get settingsBiometric => 'Biometric Login';
  @override String get settingsChangePin => 'Change PIN';
  @override String get settingsAboutTitle => 'About Richer';
  @override String get settingsRateUs => 'Rate Us';
  @override String get settingsJoinCommunity => 'Join Community';
  @override String get settingsWhatsNew => "What's New";
  @override String get settingsNoAnnouncements => "You're all caught up!";
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
  @override String get settingsClearDataContent => 'This will permanently delete ALL your data including all profiles, transactions, accounts, and categories. This action cannot be undone.';
  @override String get settingsClearDataConfirmPrompt => 'Type "Confirm" to proceed:';
  @override String get settingsClearDataConfirmKeyword => 'Confirm';
  @override String get settingsClearEverything => 'Clear Everything';
  @override String get settingsClearSuccess => 'All data cleared successfully';
  @override String get settingsClearError => 'Error clearing data';
  @override String get deleteProfileTitle => 'Delete Profile';
  @override String get deleteProfileContent => 'This will permanently delete this profile and ALL its data including transactions, accounts, categories, budgets, and goals.\n\nThis action cannot be undone.';
  @override String get deleteProfileButton => 'Delete Profile';
  @override String get deleteProfileSuccess => 'Profile deleted successfully';
  @override String get genericCancel => 'Cancel';
  @override String get genericVerify => 'Verify';
  @override String get genericSet => 'Set PIN';
  @override String get settingsVersion => 'Version';
  @override String get settingsNoProfile => 'No Profile';

  // Premium
  @override String get premiumRedeemVoucher => 'Redeem Voucher (Lifetime Premium)';
  @override String get premiumGetPremium => 'Get Premium (Lifetime)';
  @override String get premiumLifetimeSubtitle => 'Unlock everything.';
  @override String get premiumGetPremiumSubtitle => 'Unlock everything. Support Richer.';
  @override String get premiumSyncSubscription => 'Sync Subscription';
  @override String get premiumSyncSubtitle => 'Premium Feature + Cross-device sync — yearly';
  @override String get premiumRestorePurchase => 'Restore Purchase';
  @override String get premiumEnterVoucherCode => 'Enter voucher code';
  @override String get premiumRedeem => 'Redeem';
  @override String get premiumActivated => 'Premium activated! 🎉';
  @override String get premiumInvalidVoucher => 'Invalid voucher code.';
  @override String get premiumVoucherUsed => 'This voucher has already been used.';
  @override String get premiumNotSignedIn => 'Please sign in first.';
  @override String get premiumVoucherDisabled => 'Voucher redemption is not available.';
  @override String get premiumRestored => 'Restored premium for: ';
  @override String get premiumCheckingPlayStore => 'Checking Play Store for purchases...';
  @override String get premiumSignInGoogle => 'Sign in with Google to sync premium purchase forever.';
  @override String get premiumRestartAppToHideAds => 'Restart app to completely remove ads';
  @override String get premiumVoucherSuccessTitle => 'Lifetime Premium Activated';
  @override String get premiumVoucherSuccessBody => 'You\'re all set. Thank you so much — this truly means a lot. Enjoy every feature, and may good things always find their way to you.';
  @override String get premiumSignInRequired => 'Google Sign-In Required';
  @override String get premiumSignInFailed => 'Sign-In Failed';
  @override String get premiumSignInSuccess => 'Signed in successfully.';
  @override String get premiumSignOutSuccess => 'Signed out successfully.';
  @override String get premiumSignedInTryAgain => 'Signed in. Please tap the button again.';
  @override String get categoryTapToEditIcon => 'Tap to edit icon';

  // Report Details
  @override String get reportDetailChart => 'Chart';
  @override String get reportDetailCategory => 'Category';
  @override String get reportDetailTitle => 'Title';
  @override String get reportDetailByCategory => 'by Category';
  @override String get reportDetailByTitle => 'by Title';
  @override String get reportDetailDailyAvgExpense => 'Daily Avg Expense';
  @override String get reportDetailDailyAvgIncome => 'Daily Avg Income';

  // Export Report
  @override String get exportReport => 'Export Report';
  @override String get exportDateFrom => 'From Date';
  @override String get exportDateTo => 'To Date';
  @override String get exportSelectStartDate => 'Select start date';
  @override String get exportSelectEndDate => 'Select end date';
  @override String get exportButton => 'Export XLSX';
  @override String get exportSuccess => 'Report exported successfully';
  @override String get exportError => 'Failed to export report';
  @override String get exportNoData => 'No transactions found in this date range';
  @override String get exportGenerating => 'Generating report...';

  // Categories Screen
  @override String get categoriesTitle => 'Manage Categories';
  @override String get categoriesSearchHint => 'Search categories...';
  @override String get categoriesFilterExpense => 'Expense';
  @override String get categoriesFilterIncome => 'Income';
  @override String categoryUsedInTransactions(int count) =>
      count == 1 ? 'Used in 1 transaction' : 'Used in $count transactions';
  @override String get categoryNoneFound => 'No categories found';
  @override String get categoryAdded => 'Category added';
  @override String get categoryAddError => 'Error adding category';
  @override String get categoryUpdated => 'Category updated';
  @override String get categoryUpdateError => 'Error updating category';
  @override String get categoryDeleted => 'Category deleted';
  @override String get categoryDeleteError => 'Error deleting category';
  @override String get categoryCannotDeleteTitle => 'Cannot Delete Category';
  @override String categoryCannotDeleteContent(int count) =>
      'This category is used in $count transactions. You cannot delete it while it counts towards your records.';

  // Profile Selector Modal
  @override String get profileSwitchTitle => 'Switch Profile';
  @override String get profileAddNew => 'Add New Profile';
  @override String get profileAddNewAdTitle => 'Add New Profile';
  @override String get profileAddNewAdContent => 'Watch a short ad to create a new profile.';
  @override String get profileAddNewAdWatch => 'Watch Ad';
  @override String get profileAdNotCompleted => 'Ad not completed. Please try again.';
  @override String get profileErrorDeleting => 'Error deleting profile';

  // Add Profile Dialog
  @override String get profileNew => 'New Profile';
  @override String get profileChooseAvatar => 'Choose Avatar';
  @override String get profileName => 'Profile Name';
  @override String get profileNameHint => 'e.g., Personal, Business, Family';
  @override String get profileNameEmpty => 'Please enter a profile name';
  @override String get profileNameExists => 'A profile with this name already exists';
  @override String profileCreated(String name) => 'Profile "$name" created!';

  // Backup Screen
  @override String get backupTitle => 'Backup & Restore';
  @override String get backupManual => 'Manual Backup';
  @override String get backupExport => 'Export Database';
  @override String get backupExportSubtitle => 'Save your data to a file';
  @override String get backupImport => 'Import Database';
  @override String get backupImportSubtitle => 'Restore data from a file';
  @override String get backupRestoreConfirmTitle => 'Restore Database?';
  @override String get backupRestoreConfirmContent =>
      'This will overwrite your current data with the backup file. This action cannot be undone. Are you sure?';
  @override String get backupRestoreConfirmButton => 'Restore';
  @override String get backupExportSuccess => 'Database exported successfully';
  @override String get backupExportFailed => 'Export failed';
  @override String get backupImportSuccess => 'Database restored successfully!';
  @override String get backupImportFailed => 'Import failed';
  @override String get backupSelectBackup => 'Select Backup to Restore';
  @override String get backupDriveConfirmTitle => 'Restore from Drive?';
  @override String get backupDriveConfirmContent =>
      'This will overwrite your current data with the selected backup. This cannot be undone.';
  @override String get backupUploadSuccess => 'Uploaded to Drive successfully!';
  @override String get backupUploadFailed => 'Upload failed';
  @override String get backupRestoreSuccess => 'Restored successfully!';
  @override String get backupRestoreFailed => 'Restore failed';
  @override String get backupLoadFailed => 'Failed to load backups';
  @override String get backupNoneOnDrive => 'No backups found on Drive';
  @override String get backupGoogleSignInFailed => 'Google Sign-In failed';
  @override String get backupGoogleDrive => 'Cloud Backup (Google Drive)';
  @override String get backupConnectDrive => 'Connect Google Drive';
  @override String get backupToDrive => 'Backup to Drive';
  @override String get backupToDriveSubtitle => 'Save current data to cloud';
  @override String get backupRestoreFromDrive => 'Restore from Drive';
  @override String get backupRestoreFromDriveSubtitle => 'Restore data from cloud backup';
  @override String get backupDisconnect => 'Disconnect';
  @override String get backupDailyAutoInfo => 'Connect your Google account to enable automatic daily backup. Your data will be backed up silently each time you open the app (once per day). Up to 14 backup files are kept.';
  @override String get backupCloudEnable => 'Enable Cloud Backup';
  @override String get backupCloudEnableSubtitle => 'Auto daily backup to Google Drive';

  // Date Range Filter Modal
  @override String get filterByDateRange => 'Filter by Date Range';
  @override String get filterClear => 'Clear';
  @override String get filterDateFrom => 'Date From';
  @override String get filterDateFromPlaceholder => 'Select start date';
  @override String get filterDateTo => 'Date To';
  @override String get filterDateToPlaceholder => 'Select end date';
  @override String get filterDateToAfterFrom => 'Date To must be after Date From';
  @override String get filterEmptyHint => 'Empty Date From = first transaction\nEmpty Date To = today';
  @override String get filterApply => 'Apply Filter';

  // Transaction History Screen
  @override String get txnCustomRange => 'Custom Range';
  @override String get txnNoTransactions => 'Track your first expense';
  @override String get txnNoTransactionsHint => 'Tap + to log what you spent today. Even small ones — coffee, parking, snacks.';
  @override String get txnNoAccountHint => 'Tap + to log what you spent today. Even small ones — coffee, parking, snacks.';
  @override String get txnZeroBalanceHint => 'Tap + to log what you spent today. Even small ones — coffee, parking, snacks.';
  @override String get txnFilterDebt => 'Debt';
  @override String get txnFilterAdjustment => 'Adjustment';
  @override String get txnDaySummaryTxn => 'Txn';

  // Debt Payoff Card (Phase 6)
  @override String get debtPayoffTitle => 'Payoff Overview';
  @override String get debtPayoffTotalRemaining => 'Total Remaining';
  @override String get debtPayoffOverdue => 'Overdue';
  @override String get debtPayoffDueSoon => 'Due Soon';
  @override String get debtPayoffNoDeadline => 'No Deadline';
  @override String get debtPayoffNextDue => 'Next due';
  @override String get debtPayoffPaid => 'paid';
  @override String get debtPayoffCollected => 'collected';

  // Coach Mark Tour - Transactions Screen
  @override String get tourRecurringTitle => 'Recurring';
  @override String get tourRecurringDesc => 'View and manage your recurring transactions here.';
  @override String get tourDateFilterTitle => 'Date Filter';
  @override String get tourDateFilterDesc => 'Filter transactions by a custom date range.';
  @override String get tourMonthNavTitle => 'Switch Month';
  @override String get tourMonthNavDesc => 'Tap the arrows or swipe to browse previous and next months.';
  @override String get tourSearchTitle => 'Search & Filter';
  @override String get tourSearchDesc => 'Search by keyword or filter by category and transaction type.';
  @override String get tourAddTitle => 'Add Transaction';
  @override String get tourAddDesc => 'Tap here to record a new income or expense.';
  @override String get tourNavbarTitle => 'Navigation';
  @override String get tourNavbarDesc => 'Switch between Dashboard, Transactions, Accounts, Reports, and Settings.';
  @override String get tourWalletInitTitle => 'Set Initial Balance';
  @override String get tourWalletInitDesc => 'Tap the Wallet icon here to add your accounts and set their initial balance before recording transactions.';

  // Coach Mark Tour - Dashboard Screen
  @override String get tourDashTabsTitle => 'Two Views in One';
  @override String get tourDashTabsDesc => "Tap 'Reports' to access your full analytics and monthly breakdowns.";
  @override String get tourDashSummaryRowsTitle => 'Tap Rows for Detail';
  @override String get tourDashSummaryRowsDesc => 'Tap any summary row to see a currency-by-currency breakdown with live exchange rates.';
  @override String get tourDashFinHealthTitle => 'Your Financial Score';
  @override String get tourDashFinHealthDesc => 'This card grades your overall financial health — tap it to understand each factor.';
  @override String get tourDashPieChartTitle => 'Interactive Pie Chart';
  @override String get tourDashPieChartDesc => 'Long-press any slice or legend item to see the exact amount and percentage.';
  @override String get tourDashPullRefreshTitle => 'Refresh Data';
  @override String get tourDashPullRefreshDesc => 'Pull down on the dashboard to force-refresh all balances.';
  @override String get tourDashExportTitle => 'Export Reports';
  @override String get tourDashExportDesc => 'Switch to Reports tab and tap the download icon to export a financial report.';
  @override String get tourDashReportsSubTabsTitle => 'Two Analytics Views';
  @override String get tourDashReportsSubTabsDesc => "'Deep Analytics' shows trend charts; 'Monthly Details' lists every month.";
  @override String get tourDashMonthlyCardTitle => 'Tap Month for Full Report';
  @override String get tourDashMonthlyCardDesc => 'Tap any month card to open a deep-dive report with charts and categories.';
  @override String get tourDashScrollMoreTitle => 'More History Below';
  @override String get tourDashScrollMoreDesc => 'Scroll to the bottom to automatically load older months.';

  // Coach Mark Tour - Accounts Screen
  @override String get tourAccFiltersTitle => 'Hidden Filters';
  @override String get tourAccFiltersDesc => 'Tap Filter \u25be to expand search, currency, and account-type filters.';
  @override String get tourAccFilterDotTitle => 'Active Filter Indicator';
  @override String get tourAccFilterDotDesc => 'A gold dot means one or more filters are active.';
  @override String get tourAccCurrencyTitle => 'Filter by Currency';
  @override String get tourAccCurrencyDesc => 'Select currencies to show only accounts in those currencies.';
  @override String get tourAccTypeTitle => 'Filter by Account Type';
  @override String get tourAccTypeDesc => 'Tap a type chip to narrow accounts by category.';
  @override String get tourAccTotalTitle => 'All Accounts Combined';
  @override String get tourAccTotalDesc => 'This balance updates in real-time as you change filters.';
  @override String get tourAccTapEditTitle => 'Tap to Edit Account';
  @override String get tourAccTapEditDesc => 'Tap any account card to edit its name, type, currency, or balance.';

  // Coach Mark Tour - Wealth Screen
  @override String get tourWealthTabsTitle => 'Three Wealth Tools';
  @override String get tourWealthTabsDesc => 'Swipe or tap tabs for Budget, Goals, and Debt management.';
  @override String get tourWealthBudgetFilterTitle => 'Budget Filters';
  @override String get tourWealthBudgetFilterDesc => 'Tap Filter \u25be to narrow budgets by currency or period.';
  @override String get tourWealthPeriodCollapseTitle => 'Collapse Budget Groups';
  @override String get tourWealthPeriodCollapseDesc => 'Tap a period header to collapse or expand that group.';
  @override String get tourWealthPeriodBarTitle => 'Period Overview Bar';
  @override String get tourWealthPeriodBarDesc => 'The progress bar shows combined spending across all budgets in that period.';
  @override String get tourWealthBudgetTapTitle => 'Tap to Edit Budget';
  @override String get tourWealthBudgetTapDesc => 'Tap any budget card to change category, amount, or period.';
  @override String get tourWealthGoalTapTitle => 'Tap Goal to Edit';
  @override String get tourWealthGoalTapDesc => 'Tap a goal card to update its target, deadline, or linked accounts.';
  @override String get tourWealthGoalLongPressTitle => 'Long Press for Breakdown';
  @override String get tourWealthGoalLongPressDesc => 'Long-press a goal card to see which accounts contribute to its progress.';
  @override String get tourWealthDebtPayoffTitle => 'Debt Payoff Projection';
  @override String get tourWealthDebtPayoffDesc => 'This card projects when you will be debt-free based on current pace.';
  @override String get tourWealthDebtGroupTitle => 'Collapse by Person';
  @override String get tourWealthDebtGroupDesc => "Tap a person's name to collapse or expand their debts.";
  @override String get tourWealthDebtTapTitle => 'Tap Debt to Record Payment';
  @override String get tourWealthDebtTapDesc => 'Tap any debt card to record a payment or update the amount.';

  // Coach Mark Tour - Settings Screen
  @override String get tourSettingsBellTitle => 'Announcements Bell';
  @override String get tourSettingsBellDesc => 'Tap the bell to read app announcements. A red dot means unread messages.';
  @override String get tourSettingsProfileTitle => 'Switch Profiles';
  @override String get tourSettingsProfileDesc => 'Tap your profile to switch or create a new profile.';
  @override String get tourSettingsBackupTitle => 'Back Up Your Data';
  @override String get tourSettingsBackupDesc => 'Use Backup & Restore to export or restore your data.';
  @override String get tourSettingsLockTitle => 'Protect with PIN';
  @override String get tourSettingsLockDesc => 'Enable App Lock to require a PIN every time the app opens.';
  @override String get tourSettingsBioTitle => 'Biometric Requires PIN First';
  @override String get tourSettingsBioDesc => 'The fingerprint toggle only activates after PIN is set.';
  @override String get tourSettingsThemeTitle => 'Change App Theme';
  @override String get tourSettingsThemeDesc => 'Tap Theme to choose Default, Light, Dark, or System.';
  @override String get tourSettingsCatsTitle => 'Custom Categories';
  @override String get tourSettingsCatsDesc => 'Add, edit, or delete transaction categories and icons.';
  @override String get tourSettingsFeedbackTitle => 'Send Us Feedback';
  @override String get tourSettingsFeedbackDesc => 'Write a message directly to the development team.';

  // Coach Mark Tour - Report Details Screen
  @override String get tourReportTabsTitle => 'Three Report Angles';
  @override String get tourReportTabsDesc => 'Chart (pie), Category (ranked list), and Title (transaction names).';
  @override String get tourReportSegmentTitle => 'Switch Expense vs Income';
  @override String get tourReportSegmentDesc => 'Tap the segmented control to toggle between Expense and Income pie.';
  @override String get tourReportPieLongTitle => 'Long Press Pie for Details';
  @override String get tourReportPieLongDesc => 'Long-press any slice to see the exact amount and percentage.';
  @override String get tourReportCategoryTitle => 'Tap Category for History';
  @override String get tourReportCategoryDesc => 'Tap any category row to see all historical months for that category.';
  @override String get tourReportTitleRowTitle => 'Tap Title for History';
  @override String get tourReportTitleRowDesc => 'Tap any transaction title to see its full spending history.';

  // Coach Mark Tour - Account Transaction History Screen
  @override String get tourAccHistTypeTitle => 'Filter by Type';
  @override String get tourAccHistTypeDesc => 'Tap a chip to show only that transaction type.';
  @override String get tourAccHistSearchTitle => 'Search Transactions';
  @override String get tourAccHistSearchDesc => 'Type to filter transactions by name, category, or note in real time.';
  @override String get tourAccHistScrollTitle => 'More Transactions Below';
  @override String get tourAccHistScrollDesc => 'Scroll to the bottom to automatically load the next 20 transactions.';
  @override String get tourAccHistTapTitle => 'Tap to Edit Transaction';
  @override String get tourAccHistTapDesc => 'Tap any transaction row to open the full entry form.';

  // Coach Mark Tour - Recurring List Screen
  @override String get tourRecurringSearchTitle => 'Search Recurring';
  @override String get tourRecurringSearchDesc => 'Type to filter recurring rules by name, category, or account.';
  @override String get tourRecurringInactiveTitle => 'Inactive Rules Still Exist';
  @override String get tourRecurringInactiveDesc => "Dimmed cards are paused \u2014 they won't auto-post until re-enabled.";
  @override String get tourRecurringNextRunTitle => 'Scheduled Next Run';
  @override String get tourRecurringNextRunDesc => 'Each active rule shows the next date it will create a transaction.';
  @override String get tourRecurringTapTitle => 'Tap to Edit or Pause';
  @override String get tourRecurringTapDesc => 'Tap any recurring card to change amount, frequency, or toggle active/inactive.';

  // Coach Mark Tour - Wallet Screen
  @override String get tourWalletBalanceTitle => 'Total Balance';
  @override String get tourWalletBalanceDesc => 'See your combined balance across all filtered accounts, converted to your base currency.';
  @override String get tourWalletFabTitle => 'Add Account';
  @override String get tourWalletFabDesc => 'Tap here to create a new wallet — cash, bank, e-wallet, or investment account.';
  @override String get tourWalletCardTitle => 'Edit Account';
  @override String get tourWalletCardDesc => 'Tap any account card to view its transaction history or edit its details.';

  // Financial Health Score (Phase 7)
  @override String get healthScoreTitle => 'Financial Health';
  @override String get healthScoreLabel => 'Health Score';
  @override String get healthScoreSavings => 'Savings Rate';
  @override String get healthScoreBudget => 'Budget Adherence';
  @override String get healthScoreDebt => 'Debt Burden';
  @override String get healthScoreTrend => 'Expense Trend';
  @override String get healthScoreGradeA => 'Excellent';
  @override String get healthScoreGradeB => 'Good';
  @override String get healthScoreGradeC => 'Fair';
  @override String get healthScoreGradeD => 'Needs Work';
  @override String get healthScoreGradeF => 'Critical';
  @override String get healthScoreTapToExpand => 'Tap to see breakdown';

  // Financial Health Score – methodology sheet
  @override String get healthScoreMethodologyTitle => 'How is this calculated?';
  @override String get healthScoreFormulaLabel => 'Overall Score';
  @override String get healthScoreFormulaDesc => '(Savings + Budget + Debt + Trend) ÷ 4\nEach component is scored 0–100 and weighted equally at 25%.';
  @override String get healthScoreGradeScaleLabel => 'Grade Scale';
  @override String get healthScoreWeight => '25% weight';
  @override String get healthScoreSavingsDesc => 'Average savings rate over the last 3 months.\nSavings rate = (Income − Expense) ÷ Income × 100';
  @override String get healthScoreSavingsFormula => '< 0% → 0  •  0–4% → 10  •  5–9% → 30\n10–19% → 55  •  20–29% → 75  •  ≥ 30% → 100';
  @override String get healthScoreBudgetDesc => 'How many monthly budgets you stayed within, averaged over the last 3 months.\nScore = (1 − exceeded ÷ total) × 100';
  @override String get healthScoreBudgetNote => '* Only monthly budgets are counted. Months with no budgets contribute a neutral 70.';
  @override String get healthScoreDebtDesc => 'Total outstanding debt (money you owe) compared to 3× your average monthly income.';
  @override String get healthScoreDebtFormula => 'Ratio = Debt ÷ (Avg income × 3)\n≤ 0.5× → 90  •  ≤ 1× → 70  •  ≤ 2× → 40\n≤ 3× → 20  •  > 3× → 5  •  No debt → 100';
  @override String get healthScoreTrendDesc => 'Current month\'s expenses compared to the average of up to 3 previous months.';
  @override String get healthScoreTrendFormula => '< 90% → 100  •  90–99% → 80  •  100–109% → 60\n110–129% → 35  •  ≥ 130% → 10';
  @override String get healthScoreThresholdLabel => 'Score thresholds';
  @override String get healthScoreCurrentScore => 'Your score';

  // Share Achievement Feature
  @override String get shareAchievement => 'Share Achievement';
  @override String get achievementsTitle => 'Achievements';
  @override String get shareCaption_savingsStreak =>
      'Three months of spending less than I earn. Small habit, consistent results. Tracking it all in Richer. #Richer #PersonalFinance #SavingsStreak';
  @override String get shareCaption_financeChampion =>
      'Five months in a row — income beating expenses every single month. Didn\'t expect consistency to feel this good. #Richer #FinanceChampion #MoneyHabits';
  @override String get shareCaption_budgetChampion =>
      'Kept every budget this month. Turns out setting limits and actually following them are two very different skills. Getting better at both. #Richer #BudgetGoals #FinancialDiscipline';
  @override String get shareCaption_budgetDisciplined =>
      'Three months of staying disciplined with my budget. Building better money habits one month at a time. #Richer #BudgetDiscipline #MoneyHabits';
  @override String get shareCaption_gradeA =>
      'My financial health score just hit Grade A. Savings rate, debt load, budget adherence, expense trend — all green. Took a while to get here. #Richer #FinancialHealth #GradeA';
  @override String get shareCaption_gradeB =>
      'Grade B on my financial health check. There\'s a component or two still to work on, but the direction is right. Slow progress is still progress. #Richer #FinancialHealth #MoneyJourney';
  @override String get shareCaption_spendingUnderControl =>
      'My expenses have been going down for 3 months in a row. Not because I\'m depriving myself — just being more intentional. #Richer #SpendingSmarter #FinancialFreedom';

  // Premium Gate Modal
  @override String get premiumGateButtonBuyLifetime => 'Unlock Lifetime Premium';
  @override String get premiumGateButtonMaybeLater => 'Maybe Later';
  @override String get premiumGateTagline => 'One-time purchase. No subscriptions.';
  @override String get premiumGateRestorePurchase => 'Restore Purchase';
  @override String get premiumGateBudgetTitle => 'Budget Limit Reached';
  @override String get premiumGateBudgetDesc => 'Free tier allows up to 3 budgets. Upgrade to add unlimited budgets.';
  @override String get premiumGateGoalTitle => 'Goal Limit Reached';
  @override String get premiumGateGoalDesc => 'Free tier allows up to 3 goals. Upgrade to add unlimited goals.';
  @override String get premiumGateAccountTitle => 'Account Limit Reached';
  @override String get premiumGateAccountDesc => 'Free tier allows up to 5 accounts. Upgrade for unlimited accounts.';
  @override String get premiumGateExportTitle => 'Premium Feature';
  @override String get premiumGateExportDesc => 'CSV export is available for premium users only.';
  @override String get premiumGateDeepAnalyticsTitle => 'Deep Analytics';
  @override String get premiumGateDeepAnalyticsDesc => 'Unlock detailed financial insights and trend analysis with premium.';
  @override String get premiumGateProfileTitle => 'Profile Limit Reached';
  @override String get premiumGateProfileDesc => 'Free tier supports 1 profile. Upgrade to manage multiple profiles.';
  @override String get premiumGateCloudBackupDesc => 'Cloud backup to Google Drive is a premium feature.';

  // Premium Benefits Modal
  @override String get premiumBenefitsTitle => 'Premium Benefits';
  @override String get premiumBenefitsSeeWhat => 'See what you unlock';
  @override String get premiumBenefitsModalTitle => 'What You Unlock';
  @override String get premiumBenefitsModalSubtitle => 'One-time purchase. Yours forever.';
  @override String get premiumBenefitsClose => 'Close';
  @override String get premiumFeatureWallets => 'Wallets';
  @override String get premiumFeatureGoals => 'Goals';
  @override String get premiumFeatureBudgets => 'Budget Categories';
  @override String get premiumFeatureProfiles => 'Profiles';
  @override String get premiumFeatureAnalytics => 'Deep Analytics';
  @override String get premiumFeatureCloudBackup => 'Daily Backup Google Drive (optional)';
  @override String get premiumFreeLimit5 => 'Up to 5';
  @override String get premiumFreeLimit3 => 'Up to 3';
  @override String get premiumFreeLimit1 => '1 only';
  @override String get premiumFreeLocked => 'Locked';
  @override String get premiumUnlimited => 'Unlimited';

  // Apple Sign-In
  @override String get premiumSignInApple => 'Sign in with Apple to sync premium purchase forever.';
  @override String get signInRequired => 'Sign-In Required';
  @override String get signInRequiredDesc => 'Sign in to purchase and restore premium features.';
  @override String get premiumCheckingAppStore => 'Checking App Store for previous purchases...';
}
