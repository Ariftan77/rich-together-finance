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
  final String icon;

  const DefaultCategory({required this.name, required this.type, required this.icon});
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
  DefaultAccount(name: 'Tunai', type: AccountType.cash),
];

/// Indonesia-specific default categories.
const List<DefaultCategory> _indonesiaCategories = [
  // Expense
  DefaultCategory(name: 'Makanan dan Minuman', type: CategoryType.expense, icon: 'ph:forkKnife'),
  DefaultCategory(name: 'Belanja', type: CategoryType.expense, icon: 'ph:shoppingCart'),
  DefaultCategory(name: 'Transportasi', type: CategoryType.expense, icon: 'ph:bus'),
  DefaultCategory(name: 'Bensin', type: CategoryType.expense, icon: 'ph:gasPump'),
  DefaultCategory(name: 'Tagihan', type: CategoryType.expense, icon: 'ph:receipt'),
  DefaultCategory(name: 'Sewa', type: CategoryType.expense, icon: 'ph:house'),
  DefaultCategory(name: 'Kesehatan', type: CategoryType.expense, icon: 'ph:heartbeat'),
  DefaultCategory(name: 'Hiburan', type: CategoryType.expense, icon: 'ph:filmStrip'),
  DefaultCategory(name: 'Liburan', type: CategoryType.expense, icon: 'ph:airplane'),
  DefaultCategory(name: 'Lain-lain', type: CategoryType.expense, icon: 'ph:dotsThree'),
  // Income
  DefaultCategory(name: 'Gaji', type: CategoryType.income, icon: 'ph:wallet'),
  DefaultCategory(name: 'Bisnis', type: CategoryType.income, icon: 'ph:briefcase'),
  DefaultCategory(name: 'Sampingan', type: CategoryType.income, icon: 'ph:laptop'),
  DefaultCategory(name: 'Investasi', type: CategoryType.income, icon: 'ph:chartLineUp'),
  DefaultCategory(name: 'Lain-lain', type: CategoryType.income, icon: 'ph:dotsThree'),
];

/// Generic defaults for non-Indonesia countries.
const List<DefaultAccount> _genericAccounts = [
  DefaultAccount(name: 'Cash', type: AccountType.cash),
];

/// Generic default categories.
const List<DefaultCategory> _genericCategories = [
  // Expense
  DefaultCategory(name: 'Food & Drinks', type: CategoryType.expense, icon: 'ph:forkKnife'),
  DefaultCategory(name: 'Shopping', type: CategoryType.expense, icon: 'ph:shoppingCart'),
  DefaultCategory(name: 'Transportation', type: CategoryType.expense, icon: 'ph:bus'),
  DefaultCategory(name: 'Fuel', type: CategoryType.expense, icon: 'ph:gasPump'),
  DefaultCategory(name: 'Bills & Utilities', type: CategoryType.expense, icon: 'ph:receipt'),
  DefaultCategory(name: 'Rent', type: CategoryType.expense, icon: 'ph:house'),
  DefaultCategory(name: 'Health', type: CategoryType.expense, icon: 'ph:heartbeat'),
  DefaultCategory(name: 'Entertainment', type: CategoryType.expense, icon: 'ph:filmStrip'),
  DefaultCategory(name: 'Travel', type: CategoryType.expense, icon: 'ph:airplane'),
  DefaultCategory(name: 'Others', type: CategoryType.expense, icon: 'ph:dotsThree'),
  // Income
  DefaultCategory(name: 'Salary', type: CategoryType.income, icon: 'ph:wallet'),
  DefaultCategory(name: 'Business', type: CategoryType.income, icon: 'ph:briefcase'),
  DefaultCategory(name: 'Freelance', type: CategoryType.income, icon: 'ph:laptop'),
  DefaultCategory(name: 'Investment', type: CategoryType.income, icon: 'ph:chartLineUp'),
  DefaultCategory(name: 'Others', type: CategoryType.income, icon: 'ph:dotsThree'),
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
