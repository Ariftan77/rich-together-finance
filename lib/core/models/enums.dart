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
  income,        // 0
  expense,       // 1
  transfer,      // 2
  adjustmentIn,  // 3 - balance adjustment (adds to balance)
  adjustmentOut, // 4 - balance adjustment (subtracts from balance)
  debtIn,        // 5 - debt transaction (borrowed money, adds to balance)
  debtOut,       // 6 - debt transaction (lent money, subtracts from balance)
  debtPaymentOut, // 7 - debt settlement (I pay back what I owe, subtracts from balance)
  debtPaymentIn,  // 8 - debt settlement (someone pays me back, adds to balance)
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
  myr,        // 3 - Malaysian Ringgit
  thb,        // 4 - Thai Baht
  sar,        // 5 - Saudi Arabian Riyal
  jpy,        // 6 - Japanese Yen
  cny,        // 7 - Chinese Yuan
  krw,        // 8 - South Korean Won
  aud,        // 9 - Australian Dollar
  khr,        // 10 - Cambodian Riel
  vnd,        // 11 - Vietnamese Dong
  php,        // 12 - Philippine Peso
  eur,        // 13 - Euro
  // --- extended currencies (index 14+) ---
  gbp,        // 14 - British Pound
  inr,        // 15 - Indian Rupee
  hkd,        // 16 - Hong Kong Dollar
  twd,        // 17 - New Taiwan Dollar
  cad,        // 18 - Canadian Dollar
  chf,        // 19 - Swiss Franc
  nzd,        // 20 - New Zealand Dollar
  brl,        // 21 - Brazilian Real
  aed,        // 22 - UAE Dirham
  tryLira,    // 23 - Turkish Lira ('try' is a Dart reserved word)
  mxn,        // 24 - Mexican Peso
  zar,        // 25 - South African Rand
  nok,        // 26 - Norwegian Krone
  sek,        // 27 - Swedish Krona
  dkk,        // 28 - Danish Krone
  pln,        // 29 - Polish Złoty
  czk,        // 30 - Czech Koruna
  huf,        // 31 - Hungarian Forint
  ron,        // 32 - Romanian Leu
  ils,        // 33 - Israeli Shekel
  pkr,        // 34 - Pakistani Rupee
  bdt,        // 35 - Bangladeshi Taka
  ngn,        // 36 - Nigerian Naira
  kes,        // 37 - Kenyan Shilling
  egp,        // 38 - Egyptian Pound
  npr,        // 39 - Nepalese Rupee
  lkr,        // 40 - Sri Lankan Rupee
  mmk,        // 41 - Myanmar Kyat
  lak,        // 42 - Lao Kip
  bnd,        // 43 - Brunei Dollar
  mop,        // 44 - Macanese Pataca
  qar,        // 45 - Qatari Riyal
  kwd,        // 46 - Kuwaiti Dinar
  omr,        // 47 - Omani Rial
  bhd,        // 48 - Bahraini Dinar
  jod,        // 49 - Jordanian Dinar
  rub,        // 50 - Russian Ruble
  uah,        // 51 - Ukrainian Hryvnia
  kzt,        // 52 - Kazakhstani Tenge
  mad,        // 53 - Moroccan Dirham
  iqd,        // 54 - Iraqi Dinar
  uzs,        // 55 - Uzbekistani Som
  tzs,        // 56 - Tanzanian Shilling
  ghs,        // 57 - Ghanaian Cedi
  etb,        // 58 - Ethiopian Birr
  tnd,        // 59 - Tunisian Dinar
  dzd,        // 60 - Algerian Dinar
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
      case TransactionType.adjustmentIn:
        return 'Adjustment +';
      case TransactionType.adjustmentOut:
        return 'Adjustment -';
      case TransactionType.debtIn:
        return 'Borrowed';
      case TransactionType.debtOut:
        return 'Lent';
      case TransactionType.debtPaymentOut:
        return 'Debt Payment';
      case TransactionType.debtPaymentIn:
        return 'Debt Received';
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
      case Currency.idr: return 'IDR';
      case Currency.usd: return 'USD';
      case Currency.sgd: return 'SGD';
      case Currency.myr: return 'MYR';
      case Currency.thb: return 'THB';
      case Currency.sar: return 'SAR';
      case Currency.jpy: return 'JPY';
      case Currency.cny: return 'CNY';
      case Currency.krw: return 'KRW';
      case Currency.aud: return 'AUD';
      case Currency.khr: return 'KHR';
      case Currency.vnd: return 'VND';
      case Currency.php: return 'PHP';
      case Currency.eur: return 'EUR';
      case Currency.gbp: return 'GBP';
      case Currency.inr: return 'INR';
      case Currency.hkd: return 'HKD';
      case Currency.twd: return 'TWD';
      case Currency.cad: return 'CAD';
      case Currency.chf: return 'CHF';
      case Currency.nzd: return 'NZD';
      case Currency.brl: return 'BRL';
      case Currency.aed: return 'AED';
      case Currency.tryLira: return 'TRY';
      case Currency.mxn: return 'MXN';
      case Currency.zar: return 'ZAR';
      case Currency.nok: return 'NOK';
      case Currency.sek: return 'SEK';
      case Currency.dkk: return 'DKK';
      case Currency.pln: return 'PLN';
      case Currency.czk: return 'CZK';
      case Currency.huf: return 'HUF';
      case Currency.ron: return 'RON';
      case Currency.ils: return 'ILS';
      case Currency.pkr: return 'PKR';
      case Currency.bdt: return 'BDT';
      case Currency.ngn: return 'NGN';
      case Currency.kes: return 'KES';
      case Currency.egp: return 'EGP';
      case Currency.npr: return 'NPR';
      case Currency.lkr: return 'LKR';
      case Currency.mmk: return 'MMK';
      case Currency.lak: return 'LAK';
      case Currency.bnd: return 'BND';
      case Currency.mop: return 'MOP';
      case Currency.qar: return 'QAR';
      case Currency.kwd: return 'KWD';
      case Currency.omr: return 'OMR';
      case Currency.bhd: return 'BHD';
      case Currency.jod: return 'JOD';
      case Currency.rub: return 'RUB';
      case Currency.uah: return 'UAH';
      case Currency.kzt: return 'KZT';
      case Currency.mad: return 'MAD';
      case Currency.iqd: return 'IQD';
      case Currency.uzs: return 'UZS';
      case Currency.tzs: return 'TZS';
      case Currency.ghs: return 'GHS';
      case Currency.etb: return 'ETB';
      case Currency.tnd: return 'TND';
      case Currency.dzd: return 'DZD';
    }
  }

  String get symbol {
    switch (this) {
      case Currency.idr: return 'Rp';
      case Currency.usd: return '\$';
      case Currency.sgd: return 'S\$';
      case Currency.myr: return 'RM';
      case Currency.thb: return '฿';
      case Currency.sar: return 'SR';
      case Currency.jpy: return '¥';
      case Currency.cny: return 'CN¥';
      case Currency.krw: return '₩';
      case Currency.aud: return 'A\$';
      case Currency.khr: return '៛';
      case Currency.vnd: return '₫';
      case Currency.php: return '₱';
      case Currency.eur: return '€';
      case Currency.gbp: return '£';
      case Currency.inr: return '₹';
      case Currency.hkd: return 'HK\$';
      case Currency.twd: return 'NT\$';
      case Currency.cad: return 'CA\$';
      case Currency.chf: return 'Fr';
      case Currency.nzd: return 'NZ\$';
      case Currency.brl: return 'R\$';
      case Currency.aed: return 'AED';
      case Currency.tryLira: return '₺';
      case Currency.mxn: return 'MX\$';
      case Currency.zar: return 'R';
      case Currency.nok: return 'kr';
      case Currency.sek: return 'kr';
      case Currency.dkk: return 'kr';
      case Currency.pln: return 'zł';
      case Currency.czk: return 'Kč';
      case Currency.huf: return 'Ft';
      case Currency.ron: return 'lei';
      case Currency.ils: return '₪';
      case Currency.pkr: return '₨';
      case Currency.bdt: return '৳';
      case Currency.ngn: return '₦';
      case Currency.kes: return 'KSh';
      case Currency.egp: return 'E£';
      case Currency.npr: return 'रू';
      case Currency.lkr: return 'Rs';
      case Currency.mmk: return 'K';
      case Currency.lak: return '₭';
      case Currency.bnd: return 'B\$';
      case Currency.mop: return 'P';
      case Currency.qar: return 'QR';
      case Currency.kwd: return 'KD';
      case Currency.omr: return 'OMR';
      case Currency.bhd: return 'BD';
      case Currency.jod: return 'JD';
      case Currency.rub: return '₽';
      case Currency.uah: return '₴';
      case Currency.kzt: return '₸';
      case Currency.mad: return 'MAD';
      case Currency.iqd: return 'IQD';
      case Currency.uzs: return 'UZS';
      case Currency.tzs: return 'TSh';
      case Currency.ghs: return 'GH₵';
      case Currency.etb: return 'Br';
      case Currency.tnd: return 'DT';
      case Currency.dzd: return 'DA';
    }
  }

  String get name {
    switch (this) {
      case Currency.idr: return 'Indonesian Rupiah';
      case Currency.usd: return 'US Dollar';
      case Currency.sgd: return 'Singapore Dollar';
      case Currency.myr: return 'Malaysian Ringgit';
      case Currency.thb: return 'Thai Baht';
      case Currency.sar: return 'Saudi Arabian Riyal';
      case Currency.jpy: return 'Japanese Yen';
      case Currency.cny: return 'Chinese Yuan';
      case Currency.krw: return 'South Korean Won';
      case Currency.aud: return 'Australian Dollar';
      case Currency.khr: return 'Cambodian Riel';
      case Currency.vnd: return 'Vietnamese Dong';
      case Currency.php: return 'Philippine Peso';
      case Currency.eur: return 'Euro';
      case Currency.gbp: return 'British Pound';
      case Currency.inr: return 'Indian Rupee';
      case Currency.hkd: return 'Hong Kong Dollar';
      case Currency.twd: return 'New Taiwan Dollar';
      case Currency.cad: return 'Canadian Dollar';
      case Currency.chf: return 'Swiss Franc';
      case Currency.nzd: return 'New Zealand Dollar';
      case Currency.brl: return 'Brazilian Real';
      case Currency.aed: return 'UAE Dirham';
      case Currency.tryLira: return 'Turkish Lira';
      case Currency.mxn: return 'Mexican Peso';
      case Currency.zar: return 'South African Rand';
      case Currency.nok: return 'Norwegian Krone';
      case Currency.sek: return 'Swedish Krona';
      case Currency.dkk: return 'Danish Krone';
      case Currency.pln: return 'Polish Złoty';
      case Currency.czk: return 'Czech Koruna';
      case Currency.huf: return 'Hungarian Forint';
      case Currency.ron: return 'Romanian Leu';
      case Currency.ils: return 'Israeli Shekel';
      case Currency.pkr: return 'Pakistani Rupee';
      case Currency.bdt: return 'Bangladeshi Taka';
      case Currency.ngn: return 'Nigerian Naira';
      case Currency.kes: return 'Kenyan Shilling';
      case Currency.egp: return 'Egyptian Pound';
      case Currency.npr: return 'Nepalese Rupee';
      case Currency.lkr: return 'Sri Lankan Rupee';
      case Currency.mmk: return 'Myanmar Kyat';
      case Currency.lak: return 'Lao Kip';
      case Currency.bnd: return 'Brunei Dollar';
      case Currency.mop: return 'Macanese Pataca';
      case Currency.qar: return 'Qatari Riyal';
      case Currency.kwd: return 'Kuwaiti Dinar';
      case Currency.omr: return 'Omani Rial';
      case Currency.bhd: return 'Bahraini Dinar';
      case Currency.jod: return 'Jordanian Dinar';
      case Currency.rub: return 'Russian Ruble';
      case Currency.uah: return 'Ukrainian Hryvnia';
      case Currency.kzt: return 'Kazakhstani Tenge';
      case Currency.mad: return 'Moroccan Dirham';
      case Currency.iqd: return 'Iraqi Dinar';
      case Currency.uzs: return 'Uzbekistani Som';
      case Currency.tzs: return 'Tanzanian Shilling';
      case Currency.ghs: return 'Ghanaian Cedi';
      case Currency.etb: return 'Ethiopian Birr';
      case Currency.tnd: return 'Tunisian Dinar';
      case Currency.dzd: return 'Algerian Dinar';
    }
  }

  String get flag {
    switch (this) {
      case Currency.idr: return '🇮🇩';
      case Currency.usd: return '🇺🇸';
      case Currency.sgd: return '🇸🇬';
      case Currency.myr: return '🇲🇾';
      case Currency.thb: return '🇹🇭';
      case Currency.sar: return '🇸🇦';
      case Currency.jpy: return '🇯🇵';
      case Currency.cny: return '🇨🇳';
      case Currency.krw: return '🇰🇷';
      case Currency.aud: return '🇦🇺';
      case Currency.khr: return '🇰🇭';
      case Currency.vnd: return '🇻🇳';
      case Currency.php: return '🇵🇭';
      case Currency.eur: return '🇪🇺';
      case Currency.gbp: return '🇬🇧';
      case Currency.inr: return '🇮🇳';
      case Currency.hkd: return '🇭🇰';
      case Currency.twd: return '🇹🇼';
      case Currency.cad: return '🇨🇦';
      case Currency.chf: return '🇨🇭';
      case Currency.nzd: return '🇳🇿';
      case Currency.brl: return '🇧🇷';
      case Currency.aed: return '🇦🇪';
      case Currency.tryLira: return '🇹🇷';
      case Currency.mxn: return '🇲🇽';
      case Currency.zar: return '🇿🇦';
      case Currency.nok: return '🇳🇴';
      case Currency.sek: return '🇸🇪';
      case Currency.dkk: return '🇩🇰';
      case Currency.pln: return '🇵🇱';
      case Currency.czk: return '🇨🇿';
      case Currency.huf: return '🇭🇺';
      case Currency.ron: return '🇷🇴';
      case Currency.ils: return '🇮🇱';
      case Currency.pkr: return '🇵🇰';
      case Currency.bdt: return '🇧🇩';
      case Currency.ngn: return '🇳🇬';
      case Currency.kes: return '🇰🇪';
      case Currency.egp: return '🇪🇬';
      case Currency.npr: return '🇳🇵';
      case Currency.lkr: return '🇱🇰';
      case Currency.mmk: return '🇲🇲';
      case Currency.lak: return '🇱🇦';
      case Currency.bnd: return '🇧🇳';
      case Currency.mop: return '🇲🇴';
      case Currency.qar: return '🇶🇦';
      case Currency.kwd: return '🇰🇼';
      case Currency.omr: return '🇴🇲';
      case Currency.bhd: return '🇧🇭';
      case Currency.jod: return '🇯🇴';
      case Currency.rub: return '🇷🇺';
      case Currency.uah: return '🇺🇦';
      case Currency.kzt: return '🇰🇿';
      case Currency.mad: return '🇲🇦';
      case Currency.iqd: return '🇮🇶';
      case Currency.uzs: return '🇺🇿';
      case Currency.tzs: return '🇹🇿';
      case Currency.ghs: return '🇬🇭';
      case Currency.etb: return '🇪🇹';
      case Currency.tnd: return '🇹🇳';
      case Currency.dzd: return '🇩🇿';
    }
  }

  String get countryName {
    switch (this) {
      case Currency.idr: return 'Indonesia';
      case Currency.usd: return 'United States';
      case Currency.sgd: return 'Singapore';
      case Currency.myr: return 'Malaysia';
      case Currency.thb: return 'Thailand';
      case Currency.sar: return 'Saudi Arabia';
      case Currency.jpy: return 'Japan';
      case Currency.cny: return 'China';
      case Currency.krw: return 'South Korea';
      case Currency.aud: return 'Australia';
      case Currency.khr: return 'Cambodia';
      case Currency.vnd: return 'Vietnam';
      case Currency.php: return 'Philippines';
      case Currency.eur: return 'Euro Zone';
      case Currency.gbp: return 'United Kingdom';
      case Currency.inr: return 'India';
      case Currency.hkd: return 'Hong Kong';
      case Currency.twd: return 'Taiwan';
      case Currency.cad: return 'Canada';
      case Currency.chf: return 'Switzerland';
      case Currency.nzd: return 'New Zealand';
      case Currency.brl: return 'Brazil';
      case Currency.aed: return 'United Arab Emirates';
      case Currency.tryLira: return 'Turkey';
      case Currency.mxn: return 'Mexico';
      case Currency.zar: return 'South Africa';
      case Currency.nok: return 'Norway';
      case Currency.sek: return 'Sweden';
      case Currency.dkk: return 'Denmark';
      case Currency.pln: return 'Poland';
      case Currency.czk: return 'Czech Republic';
      case Currency.huf: return 'Hungary';
      case Currency.ron: return 'Romania';
      case Currency.ils: return 'Israel';
      case Currency.pkr: return 'Pakistan';
      case Currency.bdt: return 'Bangladesh';
      case Currency.ngn: return 'Nigeria';
      case Currency.kes: return 'Kenya';
      case Currency.egp: return 'Egypt';
      case Currency.npr: return 'Nepal';
      case Currency.lkr: return 'Sri Lanka';
      case Currency.mmk: return 'Myanmar';
      case Currency.lak: return 'Laos';
      case Currency.bnd: return 'Brunei';
      case Currency.mop: return 'Macau';
      case Currency.qar: return 'Qatar';
      case Currency.kwd: return 'Kuwait';
      case Currency.omr: return 'Oman';
      case Currency.bhd: return 'Bahrain';
      case Currency.jod: return 'Jordan';
      case Currency.rub: return 'Russia';
      case Currency.uah: return 'Ukraine';
      case Currency.kzt: return 'Kazakhstan';
      case Currency.mad: return 'Morocco';
      case Currency.iqd: return 'Iraq';
      case Currency.uzs: return 'Uzbekistan';
      case Currency.tzs: return 'Tanzania';
      case Currency.ghs: return 'Ghana';
      case Currency.etb: return 'Ethiopia';
      case Currency.tnd: return 'Tunisia';
      case Currency.dzd: return 'Algeria';
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
