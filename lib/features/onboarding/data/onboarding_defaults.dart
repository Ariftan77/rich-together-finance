import '../../../core/models/enums.dart';

/// Represents a single default wallet account to be seeded at onboarding.
class DefaultAccount {
  final String name;
  final AccountType type;

  const DefaultAccount({required this.name, required this.type});
}

/// Represents a single default category to be seeded at onboarding.
class DefaultCategory {
  final String name;
  final CategoryType type;

  const DefaultCategory({required this.name, required this.type});
}

/// Holds the full set of defaults for a given country/region.
class OnboardingDefaults {
  final List<DefaultAccount> accounts;
  final List<DefaultCategory> categories;

  const OnboardingDefaults({
    required this.accounts,
    required this.categories,
  });
}

/// Country identifier used to select the correct defaults.
enum OnboardingCountry {
  indonesia,
  other,
}

extension OnboardingCountryX on OnboardingCountry {
  String get displayName {
    switch (this) {
      case OnboardingCountry.indonesia:
        return 'Indonesia';
      case OnboardingCountry.other:
        return 'Other';
    }
  }

  String get flag {
    switch (this) {
      case OnboardingCountry.indonesia:
        return '🇮🇩';
      case OnboardingCountry.other:
        return '🌍';
    }
  }
}

/// Indonesia-specific default accounts.
const List<DefaultAccount> _indonesiaAccounts = [
  DefaultAccount(name: 'Mandiri', type: AccountType.bank),
  DefaultAccount(name: 'BCA', type: AccountType.bank),
  DefaultAccount(name: 'BNI', type: AccountType.bank),
  DefaultAccount(name: 'BRI', type: AccountType.bank),
  DefaultAccount(name: 'Superbank', type: AccountType.bank),
  DefaultAccount(name: 'Neobank', type: AccountType.bank),
  DefaultAccount(name: 'Seabank', type: AccountType.bank),
  DefaultAccount(name: 'Krom', type: AccountType.bank),
  DefaultAccount(name: 'GoPay', type: AccountType.eWallet),
  DefaultAccount(name: 'Dana', type: AccountType.eWallet),
  DefaultAccount(name: 'OVO', type: AccountType.eWallet),
  DefaultAccount(name: 'ShopeePay', type: AccountType.eWallet),
  DefaultAccount(name: 'Tunai', type: AccountType.cash),
];

/// Indonesia-specific default categories.
const List<DefaultCategory> _indonesiaCategories = [
  // Expense
  DefaultCategory(name: 'Laundry', type: CategoryType.expense),
  DefaultCategory(name: 'Bahan Makanan', type: CategoryType.expense),
  DefaultCategory(name: 'Liburan', type: CategoryType.expense),
  DefaultCategory(name: 'Pakaian', type: CategoryType.expense),
  DefaultCategory(name: 'Makanan', type: CategoryType.expense),
  DefaultCategory(name: 'Minuman', type: CategoryType.expense),
  DefaultCategory(name: 'Cemilan', type: CategoryType.expense),
  DefaultCategory(name: 'Berdana', type: CategoryType.expense),
  DefaultCategory(name: 'Bensin', type: CategoryType.expense),
  DefaultCategory(name: 'Obat', type: CategoryType.expense),
  DefaultCategory(name: 'Pemeliharaan Kendaraan', type: CategoryType.expense),
  DefaultCategory(name: 'Parkir', type: CategoryType.expense),
  DefaultCategory(name: 'Ojek Online', type: CategoryType.expense),
  DefaultCategory(name: 'Transportasi Umum', type: CategoryType.expense),
  DefaultCategory(name: 'Perawatan', type: CategoryType.expense),
  DefaultCategory(name: 'Skincare', type: CategoryType.expense),
  DefaultCategory(name: 'Sewa Rumah', type: CategoryType.expense),
  DefaultCategory(name: 'KPR Rumah', type: CategoryType.expense),
  DefaultCategory(name: 'Kos', type: CategoryType.expense),
  DefaultCategory(name: 'Lain-lain', type: CategoryType.expense),
  // Income
  DefaultCategory(name: 'Gaji', type: CategoryType.income),
  DefaultCategory(name: 'Sampingan', type: CategoryType.income),
  DefaultCategory(name: 'Bisnis', type: CategoryType.income),
  DefaultCategory(name: 'Lain-lain', type: CategoryType.income),
];

/// Generic defaults for non-Indonesia countries.
const List<DefaultAccount> _genericAccounts = [
  DefaultAccount(name: 'Bank', type: AccountType.bank),
  DefaultAccount(name: 'Cash', type: AccountType.cash),
  DefaultAccount(name: 'Digital Wallet', type: AccountType.eWallet),
  DefaultAccount(name: 'Credit Card', type: AccountType.creditCard),
];

/// Generic default categories.
const List<DefaultCategory> _genericCategories = [
  // Expense
  DefaultCategory(name: 'Laundry', type: CategoryType.expense),
  DefaultCategory(name: 'Food', type: CategoryType.expense),
  DefaultCategory(name: 'Drink', type: CategoryType.expense),
  DefaultCategory(name: 'Snack', type: CategoryType.expense),
  DefaultCategory(name: 'Fuel', type: CategoryType.expense),
  DefaultCategory(name: 'Rent', type: CategoryType.expense),
  DefaultCategory(name: 'Mortgage Payment', type: CategoryType.expense),
  DefaultCategory(name: 'Medicine', type: CategoryType.expense),
  DefaultCategory(name: 'Maintenance Vehicle', type: CategoryType.expense),
  DefaultCategory(name: 'Skincare', type: CategoryType.expense),
  DefaultCategory(name: 'Travelling', type: CategoryType.expense),
  DefaultCategory(name: 'Transportation', type: CategoryType.expense),
  DefaultCategory(name: 'Others', type: CategoryType.expense),
  // Income
  DefaultCategory(name: 'Salary', type: CategoryType.income),
  DefaultCategory(name: 'Freelance', type: CategoryType.income),
  DefaultCategory(name: 'Business', type: CategoryType.income),
  DefaultCategory(name: 'Others', type: CategoryType.income),
];

/// Returns the full set of defaults for [country].
OnboardingDefaults getOnboardingDefaults(OnboardingCountry country) {
  switch (country) {
    case OnboardingCountry.indonesia:
      return const OnboardingDefaults(
        accounts: _indonesiaAccounts,
        categories: _indonesiaCategories,
      );
    case OnboardingCountry.other:
      return const OnboardingDefaults(
        accounts: _genericAccounts,
        categories: _genericCategories,
      );
  }
}

/// The phosphor icon string used for all default categories.
/// "ph:money" renders as a cash/money icon via [CategoryIconWidget].
const String kDefaultCategoryIcon = 'ph:money';

/// Transparent background color for default category icons.
const String kDefaultCategoryColor = 'transparent';
