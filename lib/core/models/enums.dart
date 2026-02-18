/// All enum definitions for Rich Together
/// These enums are stored as INTEGER in SQLite (Drift auto-converts)

/// Account types
enum AccountType {
  cash,       // 0 - Physical cash, petty cash
  bank,       // 1 - Bank accounts (BCA, Mandiri, etc.)
  eWallet,    // 2 - GoPay, OVO, Dana, ShopeePay
  investment, // 3 - Brokerage, Exchange accounts
  creditCard, // 4 - Credit cards (balance can go negative)
}

/// Transaction types
enum TransactionType {
  income,     // 0
  expense,    // 1
  transfer,   // 2
}

/// Category types (income or expense categories)
enum CategoryType {
  income,     // 0
  expense,    // 1
}

/// Asset types for portfolio
enum AssetType {
  stock,      // 0
  crypto,     // 1
  gold,       // 2
  silver,     // 3
}

/// Investment transaction types
enum InvestmentTransactionType {
  buy,        // 0
  sell,       // 1
}

/// Budget periods
enum BudgetPeriod {
  weekly,     // 0
  monthly,    // 1
  yearly,     // 2
}

/// Debt types
enum DebtType {
  payable,    // 0 - I owe someone
  receivable, // 1 - Someone owes me
}

/// Recurring frequency
enum RecurringFrequency {
  daily,      // 0
  weekly,     // 1
  monthly,    // 2
  yearly,     // 3
}

/// Supported currencies
enum Currency {
  idr,        // 0 - Indonesian Rupiah
  usd,        // 1 - US Dollar
  sgd,        // 2 - Singapore Dollar
}

/// Extension methods for enum display values
extension AccountTypeX on AccountType {
  String get displayName {
    switch (this) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank';
      case AccountType.eWallet:
        return 'E-Wallet';
      case AccountType.investment:
        return 'Investment';
      case AccountType.creditCard:
        return 'Credit Card';
    }
  }

  String get icon {
    switch (this) {
      case AccountType.cash:
        return 'wallet';
      case AccountType.bank:
        return 'account_balance';
      case AccountType.eWallet:
        return 'phone_android';
      case AccountType.investment:
        return 'trending_up';
      case AccountType.creditCard:
        return 'credit_card';
    }
  }

  bool get isCreditCard => this == AccountType.creditCard;
}

extension TransactionTypeX on TransactionType {
  String get displayName {
    switch (this) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.transfer:
        return 'Transfer';
    }
  }
}

extension CategoryTypeX on CategoryType {
  String get displayName {
    switch (this) {
      case CategoryType.income:
        return 'Income';
      case CategoryType.expense:
        return 'Expense';
    }
  }
}

extension AssetTypeX on AssetType {
  String get displayName {
    switch (this) {
      case AssetType.stock:
        return 'Stocks';
      case AssetType.crypto:
        return 'Crypto';
      case AssetType.gold:
        return 'Gold';
      case AssetType.silver:
        return 'Silver';
    }
  }

  String get icon {
    switch (this) {
      case AssetType.stock:
        return 'show_chart';
      case AssetType.crypto:
        return 'currency_bitcoin';
      case AssetType.gold:
        return 'diamond';
      case AssetType.silver:
        return 'diamond';
    }
  }
}

extension CurrencyX on Currency {
  String get code {
    switch (this) {
      case Currency.idr:
        return 'IDR';
      case Currency.usd:
        return 'USD';
      case Currency.sgd:
        return 'SGD';
    }
  }

  String get symbol {
    switch (this) {
      case Currency.idr:
        return 'Rp';
      case Currency.usd:
        return '\$';
      case Currency.sgd:
        return 'S\$';
    }
  }

  String get name {
    switch (this) {
      case Currency.idr:
        return 'Indonesian Rupiah';
      case Currency.usd:
        return 'US Dollar';
      case Currency.sgd:
        return 'Singapore Dollar';
    }
  }
}

extension BudgetPeriodX on BudgetPeriod {
  String get displayName {
    switch (this) {
      case BudgetPeriod.weekly:
        return 'Weekly';
      case BudgetPeriod.monthly:
        return 'Monthly';
      case BudgetPeriod.yearly:
        return 'Yearly';
    }
  }
}

extension DebtTypeX on DebtType {
  String get displayName {
    switch (this) {
      case DebtType.payable:
        return 'I Owe';
      case DebtType.receivable:
        return 'Owed to Me';
    }
  }
}

extension RecurringFrequencyX on RecurringFrequency {
  String get displayName {
    switch (this) {
      case RecurringFrequency.daily:
        return 'Daily';
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }
}
