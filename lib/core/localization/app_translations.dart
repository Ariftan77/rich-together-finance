abstract class AppTranslations {
  // Navigation
  String get navDashboard;
  String get navTransactions;
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
  String get settingsLockApp;
  String get settingsBiometric;
  String get settingsChangePin;
  String get settingsAboutApp;
  String get settingsHelp;
  String get settingsPrivacy;
  String get settingsTerms;
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
}

