# Rich Together — Architecture Implementation

> **Scope**: Core architecture only. UI/design implementation handled by design agent.

---

## Project Structure

```
lib/
├── main.dart                           # App entry with Riverpod
├── core/
│   ├── database/
│   │   ├── database.dart               # Main Drift database (12 tables)
│   │   ├── database.g.dart             # Generated code
│   │   ├── tables/                     # Table definitions
│   │   │   ├── accounts.dart
│   │   │   ├── transactions.dart
│   │   │   ├── categories.dart
│   │   │   ├── holdings.dart
│   │   │   ├── investment_transactions.dart
│   │   │   ├── price_cache.dart
│   │   │   ├── exchange_rates.dart
│   │   │   ├── budgets.dart
│   │   │   ├── goals.dart
│   │   │   ├── goal_accounts.dart
│   │   │   ├── debts.dart
│   │   │   └── recurring.dart
│   │   └── daos/                       # Data Access Objects
│   │       ├── account_dao.dart
│   │       ├── transaction_dao.dart
│   │       ├── category_dao.dart
│   │       ├── holding_dao.dart
│   │       ├── budget_dao.dart
│   │       ├── goal_dao.dart
│   │       ├── debt_dao.dart
│   │       └── recurring_dao.dart
│   ├── models/
│   │   └── enums.dart                  # All app enums with extensions
│   ├── providers/
│   │   ├── database_providers.dart     # Riverpod providers for DB/DAOs
│   │   └── api_providers.dart          # Dio + API config providers
│   └── services/
│       ├── price_service.dart          # Crypto/Stock price fetching
│       ├── exchange_rate_service.dart  # Currency conversion
│       └── net_worth_service.dart      # Net worth calculation
├── features/                           # Feature modules (UI pending)
│   ├── accounts/
│   ├── transactions/
│   ├── portfolio/
│   ├── budget/
│   ├── goals/
│   ├── debts/
│   ├── dashboard/
│   ├── settings/
│   └── auth/
└── shared/                             # Shared components (UI pending)
    ├── widgets/
    ├── utils/
    └── theme/
```

---

## Database Schema

### Tables (12 total)

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `accounts` | Bank, cash, e-wallet accounts | `name`, `type`, `currency`, `initialBalance` |
| `transactions` | Income/expense/transfer records | `accountId`, `categoryId`, `type`, `amount`, `date` |
| `categories` | Transaction categories | `name`, `type` (income/expense), `icon`, `isSystem` |
| `holdings` | Investment assets | `ticker`, `assetType`, `quantity`, `averageBuyPrice` |
| `investment_transactions` | Buy/sell investment records | `holdingId`, `type`, `quantity`, `pricePerUnit` |
| `price_cache` | Cached asset prices | `ticker`, `assetType`, `price`, `updatedAt` |
| `exchange_rates` | Currency conversion rates | `fromCurrency`, `toCurrency`, `rate` |
| `budgets` | Budget per category | `categoryId`, `amount`, `period` |
| `goals` | Financial goals | `name`, `targetAmount`, `deadline`, `isAchieved` |
| `goal_accounts` | Goal-Account junction | `goalId`, `accountId`, `contributionAmount` |
| `debts` | Payable/Receivable tracking | `personName`, `amount`, `type`, `isSettled` |
| `recurring` | Recurring transactions | `name`, `frequency`, `nextDate`, `isActive` |

### Enums

- `AccountType`: cash, bank, eWallet, investment
- `TransactionType`: income, expense, transfer
- `CategoryType`: income, expense
- `AssetType`: stock, crypto, gold, silver
- `InvestmentTransactionType`: buy, sell
- `BudgetPeriod`: weekly, monthly, yearly
- `DebtType`: payable, receivable
- `RecurringFrequency`: daily, weekly, monthly, yearly
- `Currency`: idr, usd, sgd

---

## Providers (Riverpod)

### Database Providers
```dart
databaseProvider       → AppDatabase (singleton)
accountDaoProvider     → AccountDao
transactionDaoProvider → TransactionDao
categoryDaoProvider    → CategoryDao
holdingDaoProvider     → HoldingDao
budgetDaoProvider      → BudgetDao
goalDaoProvider        → GoalDao
debtDaoProvider        → DebtDao
recurringDaoProvider   → RecurringDao
```

### Stream Providers (reactive)
```dart
accountsStreamProvider     → Stream<List<Account>>
transactionsStreamProvider → Stream<List<Transaction>>
categoriesStreamProvider   → Stream<List<Category>>
holdingsStreamProvider     → Stream<List<Holding>>
budgetsStreamProvider      → Stream<List<Budget>>
goalsStreamProvider        → Stream<List<Goal>>
debtsStreamProvider        → Stream<List<Debt>>
recurringStreamProvider    → Stream<List<RecurringData>>
```

---

## Core Services

### PriceService
- `getCachedPrice(ticker, assetType)` — Get cached price if fresh
- `fetchCryptoPrice(coinId)` — CoinGecko API
- `fetchStockPrice(symbol, apiKey)` — Alpha Vantage API
- `getPrice(ticker, assetType)` — Cache-first fetch

### ExchangeRateService
- `getRate(from, to)` — Get exchange rate
- `convert(amount, from, to)` — Convert currency
- `seedDefaultRates()` — Initialize with defaults

### NetWorthService
- `getTotalCashBalance(targetCurrency)` — Sum all account balances
- `getTotalPortfolioValue(targetCurrency)` — Sum all holdings
- `getNetWorth(targetCurrency)` — Total net worth
- `getNetWorthBreakdown()` — By category (cash, crypto, stocks, gold)

---

## API Configuration

| Service | Base URL | Key Required |
|---------|----------|--------------|
| CoinGecko | `api.coingecko.com/api/v3` | No (free tier) |
| Alpha Vantage | `alphavantage.co/query` | Yes |
| ExchangeRate-API | `v6.exchangerate-api.com/v6` | Yes |

---

## Predefined Data

### Categories (seeded on first run)

**Expense (13):** Food & Drinks, Transportation, Shopping, Bills & Utilities, Entertainment, Health, Education, Personal Care, Home, Gifts & Donations, Travel, Investment, Other

**Income (7):** Salary, Freelance, Business, Investment Return, Gift, Refund, Other

---

## Commands

```bash
# Run code generation (after modifying tables/DAOs)
dart run build_runner build --delete-conflicting-outputs

# Run app
flutter run

# Run tests
flutter test
```

---

## Remaining Work (Design Agent)

- [ ] Glassmorphism theme system (`shared/theme/`)
- [ ] Glass UI components (`shared/widgets/`)
- [ ] Bottom navigation shell
- [ ] All feature screens (accounts, transactions, portfolio, etc.)
- [ ] PIN/Biometric auth UI
