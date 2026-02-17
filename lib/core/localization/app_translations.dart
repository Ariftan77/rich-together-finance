abstract class AppTranslations {
  // Navigation
  String get navDashboard;
  String get navTransactions;
  String get navWallet;
  String get navSettings;
  String get navReports;
  
  String get dashboardTitle;
  String get dashboardOverview;
  String get dashboardTotalBalance;
  String get dashboardNetWorth;
  String get dashboardIncome;
  String get dashboardExpense;
  String get recentTransactions;
  String get viewAll;
  String get noTransactions;
  // Common
  String get ok;
  String get cancel;
  String get save;
  String get delete;
  String get edit;
  String get search;
  String get error;
  String get success;
  String get loading;
  String get commonSearch;
  String get commonToday;
  String get commonYesterday;
  String get commonThisMonth;
  String get commonPastDue;
  String get commonDueToday;
  String get commonDaysLeft;
  String get commonTarget;
  String get commonOf;
  String get commonPaid;
  String get commonAmount;
  String get commonMax;
  String get filterAll;

  // Transaction Entry
  String get entryTitleAdd;
  String get entryTitleEdit;
  String get entryAmount;
  String get entryTypeIncome;
  String get entryTypeExpense;
  String get entryTypeTransfer;
  String get entryCategoryCreated;
  String get entryCategory;
  String get entryAccount;
  String get entryFromAccount;
  String get entryToAccount;
  String get entryNote;
  String get entryNoteHint;
  String get entryDate;
  String get entrySaveButton;
  
  String get entrySelectCategory;
  String get entrySearchCategory;
  String get entrySearchAccount;
  String get entryNoAccounts;
  String get entryAddCategory;

  
  String get entrySelectAccount;
  String get entryAddNote;
  String get entryEditNote;
  
  // Transaction Feedback
  String transactionCreated(String amount);
  String transactionUpdated(String amount);
  String get errorInsufficientFunds;
  String get errorSelectCategory;
  String get errorSelectAccount;
  String get errorSelectDestAccount;
  String get errorInvalidAmount;
  String get errorNoActiveProfile;
  String get errorEnterCategoryName;
  String get errorLoadingCashFlow;
  String get errorLoadingCategories;
  
  String get accountTitleAdd;
  String get accountTitleEdit;
  String get accountNameExists;
  String get accountNoProfile;
  String get accountAdjustmentRequired;
  String get accountAdjustmentApplied;
  String get accountBalanceAdjustment;
  String get accountAdjustmentHint;
  String get accountApply;
  String get accountViewHistory;
  String get accountEditDetails;
  String get accountNameHint;
  String get accountBalanceHint;
  String get accountStartingBalanceHint;
  String get accountBalanceRequired;
  String get accountType;
  String get accountCurrency;
  String get accountSave;
  
  // Settings
  String get settingsTheme;
  String get settingsLanguage;
  String get settingsProfile;
  String get settingsPreferences;
  String get settingsSecurity;
  String get settingsAbout;
  String get settingsSyncBackup;
  String get settingsManageCategories;
  String get settingsBackupRestore;
  String get settingsBaseCurrency;
  String get settingsShowDecimals;

  String get settingsAboutApp;
  
  // About Screen
  String get aboutTagline;
  String get aboutFeatures;
  String get aboutFeatureExpense;
  String get aboutFeatureBudget;
  String get aboutFeatureAnalytics;
  String get aboutFeatureMultiProfile;
  String get aboutFeatureOffline;
  String get aboutDeveloper;
  String get aboutContact;
  String get aboutCopyright;

  // Help & FAQ
  String get helpTitle;
  String get helpFaq1Question;
  String get helpFaq1Answer;
  String get helpFaq2Question;
  String get helpFaq2Answer;
  String get helpFaq3Question;
  String get helpFaq3Answer;
  String get helpFaq4Question;
  String get helpFaq4Answer;
  String get helpFaq5Question;
  String get helpFaq5Answer;
  String get helpFaq6Question;
  String get helpFaq6Answer;
  String get helpFaq7Question;
  String get helpFaq7Answer;
  String get helpContactSupport;
  String get helpContactEmail;

  // Privacy Policy
  String get privacyTitle;
  String get privacyLastUpdated;
  String get privacyDataCollectionTitle;
  String get privacyDataCollectionContent;
  String get privacyLocalStorageTitle;
  String get privacyLocalStorageContent;
  String get privacyBackupTitle;
  String get privacyBackupContent;
  String get privacyAnalyticsTitle;
  String get privacyAnalyticsContent;
  String get privacyDeletionTitle;
  String get privacyDeletionContent;
  String get privacyContactTitle;
  String get privacyContactContent;

  // Terms of Service
  String get termsTitle;
  String get termsLastUpdated;
  String get termsAcceptanceTitle;
  String get termsAcceptanceContent;
  String get termsUsageTitle;
  String get termsUsageContent;
  String get termsAccuracyTitle;
  String get termsAccuracyContent;
  String get termsAdviceTitle;
  String get termsAdviceContent;
  String get termsLiabilityTitle;
  String get termsLiabilityContent;
  String get termsUpdatesTitle;
  String get termsUpdatesContent;
  String get termsContactTitle;
  String get termsContactContent;

  // Sync Screen
  String get syncTitle;
  String get syncSignIn;
  String get syncSignUp;
  String get syncFullName;
  String get syncEmail;
  String get syncPassword;
  String get syncNoAccount;
  String get syncHaveAccount;
  String get syncConnectedAs;
  String get syncBackedUp;
  String get syncNow;
  String get syncLogOut;
  String get syncLoggedIn;
  String get syncCompleted;
  String get syncFailed;
  String get syncStillNeedHelp;

  String get settingsClearData;

  // Wealth / Navigation
  String get navWealth;
  String get wealthBudget;
  String get wealthGoals;
  String get wealthInvestment;

  // Goals
  String get goalTitleAdd;
  String get goalTitleEdit;
  String get goalName;
  String get goalNameHint;
  String get goalTargetAmount;
  String get goalCurrency;
  String get goalDeadline;
  String get goalNoDeadline;
  String get goalLinkAccounts;
  String get goalSaved;
  String get goalRemaining;
  String get goalMonthlyNeeded;
  String get goalAchieved;
  String get goalMarkAchieved;
  String get goalNoGoals;
  String get goalNoGoalsHint;
  String get goalDeleted;

  // Debts
  String get debtTitle;
  String get debtTitleAdd;
  String get debtTitleEdit;
  String get debtPayable;
  String get debtReceivable;
  String get debtPersonName;
  String get debtPersonNameHint;
  String get debtDueDate;
  String get debtSettle;
  String get debtSettleAccount;
  String get debtNoDebts;
  String get debtNoDebtsHint;
  String get debtSettled;

  // Investment
  String get investmentPlaceholder;
  String get investmentPlaceholderHint;

  // Recurring
  String get recurringTitle;
  String get recurringTitleAdd;
  String get recurringTitleEdit;
  String get recurringFrequency;
  String get recurringInterval;
  String get recurringStartDate;
  String get recurringEndDate;
  String get recurringNoEndDate;
  String get recurringLastRun;
  String get recurringNextRun;
  String get recurringNoRecurring;
  String get recurringNoRecurringHint;
  String get recurringDaily;
  String get recurringWeekly;
  String get recurringMonthly;
  String get recurringYearly;

  // Budget
  String get budgetTitle;
  String get budgetTitleAdd;
  String get budgetTitleEdit;
  String get budgetAmount;
  String get budgetPeriod;
  String get budgetSpent;
  String get budgetRemaining;
  String get budgetExceeded;
  String get budgetLimit;
  String get budgetNoBudgets;
  String get budgetNoBudgetsHint;
  
  // Dashboard & Reports
  String get chartCashflow;
  String get chartSpending;
  String get reportTabIncomeExpr; // This one I added but didn't use yet.
  String get reportTabCashflow;
  String get reportTabSpending;
  String get reportNoData;
  String get reportNet;
  String get dashboardBalanceCurrency;
  String get close;

  // Wallet
  String get walletTitle;
  String get walletNoAccounts;

  // Settings
  String get settingsTapToSwitch;
  String get settingsConnectSupabase;
  String get settingsLockApp;
  String get settingsLockAppSubtitleOn;
  String get settingsLockAppSubtitleOff;
  String get settingsBiometric;
  String get settingsChangePin;
  String get settingsAboutTitle;
  String get settingsHelp;
  String get settingsPrivacy;
  String get settingsTerms;
  String get settingsSelectCurrency;
  String get settingsVerifyPin;
  String get settingsEnterCurrentPin;
  String get settingsSetNewPin;
  String get settingsEnterNewPin;
  String get settingsConfirmNewPin;
  String get settingsPinLengthError;
  String get settingsPinMatchError;
  String get settingsPinSetSuccess;
  String get settingsIncorrectPin;
  String get settingsClearDataTitle;
  String get settingsClearDataContent;
  String get settingsClearDataConfirmPrompt;
  String get settingsClearDataConfirmKeyword;
  String get settingsClearEverything;
  String get settingsClearSuccess;
  String get settingsClearError;
  String get genericCancel;
  String get genericVerify;
  String get genericSet;
  String get settingsVersion;
  String get settingsNoProfile;
}
