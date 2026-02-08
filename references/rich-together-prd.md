# Rich Together — Product Requirements Document (PRD)

**Version:** 1.0  
**Last Updated:** January 31, 2026  
**Author:** Arif Tan  
**Status:** Ready for Development

---

## 1. Product Overview

### 1.1 Problem Statement

Managing personal finances across multiple accounts, currencies, and investment platforms is fragmented and time-consuming. Existing apps are either too simple (lacking portfolio tracking, multi-currency support) or too complex (overwhelming UI, excessive ads, subscription-locked features).

People who want to build wealth need:
- Clear visibility into where money goes
- Consolidated view of all assets in one place
- Actionable insights to make smarter financial decisions

### 1.2 Solution

**Rich Together** is an offline-first mobile app that consolidates expense tracking, budgeting, and portfolio management into a single, clean interface. It helps users understand their money flow, track net worth across currencies and asset classes, and make informed decisions to grow their wealth.

### 1.3 Vision Statement

> "A way to be rich — aware of spending, smart money management, protect and grow your money."

### 1.4 Target Users

| User Type | Description |
|-----------|-------------|
| Primary | Individuals already investing, with multiple accounts/currencies, need consolidation |
| Secondary | Beginners who want to start being smart with money |

The UI must be simple enough for beginners but powerful enough for experienced users.

### 1.5 Success Metrics (Post-Launch)

- Daily active usage (target: 5+ entries per day)
- User retention at 30 days
- Feature adoption rate (portfolio tracking usage)
- User feedback/ratings

---

## 2. Technical Architecture

### 2.1 Technology Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Framework | Flutter | Cross-platform (Android first, iOS later) |
| Language | Dart | Flutter native |
| Local Database | Drift (SQLite) | Type-safe, reactive, ACID compliant for financial data |
| State Management | Riverpod 2.0 | Clean architecture, easy testing, reactive |
| API Client | Dio | HTTP requests for price fetching |
| Charts | fl_chart | Native Flutter, performant |
| Authentication | local_auth | Biometric/PIN |
| Cloud Backup | Google Drive API | Optional sync |

### 2.2 Architecture Pattern

```
lib/
├── core/
│   ├── database/           # Drift setup, DAOs, migrations
│   │   ├── database.dart
│   │   ├── tables/
│   │   └── daos/
│   ├── providers/          # Riverpod providers (global)
│   ├── models/             # Shared data classes
│   ├── services/           # API clients, sync logic
│   │   ├── price_service.dart
│   │   ├── exchange_rate_service.dart
│   │   └── backup_service.dart
│   └── constants/          # App-wide constants, enums
├── features/
│   ├── accounts/
│   │   ├── data/           # Repository implementation
│   │   ├── domain/         # Business logic, use cases
│   │   └── presentation/   # Screens, widgets, controllers
│   ├── transactions/
│   ├── portfolio/
│   ├── budget/
│   ├── goals/
│   ├── debts/
│   ├── dashboard/
│   └── settings/
└── shared/
    ├── widgets/            # Reusable UI components
    ├── utils/              # Helpers, formatters, validators
    └── theme/              # App theming
```

### 2.3 Offline-First Strategy

```
┌─────────────────────────────────────────────────────────┐
│                     App (Offline)                        │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   Drift     │    │  Riverpod   │    │     UI      │  │
│  │  (SQLite)   │◄──►│  Providers  │◄──►│  Screens    │  │
│  └─────────────┘    └─────────────┘    └─────────────┘  │
│         │                                                │
│         ▼                                                │
│  ┌─────────────┐                                        │
│  │ Last Cached │  ◄── Used when offline                 │
│  │   Prices    │                                        │
│  └─────────────┘                                        │
└─────────────────────────────────────────────────────────┘
          │ Online only
          ▼
┌─────────────────────────────────────────────────────────┐
│                  External Services                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │ Price APIs  │  │  Exchange   │  │   Google    │      │
│  │ (Crypto/    │  │    Rate     │  │   Drive     │      │
│  │  Stock/Gold)│  │    API      │  │   Backup    │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
└─────────────────────────────────────────────────────────┘
```

**Behavior:**
- All features work 100% offline using local SQLite
- Price/exchange rate features require online (show last cached data with warning if offline)
- Google Drive backup is optional, user-initiated

---

## 3. Data Models

### 3.1 Entity Relationship Diagram

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│    Account      │       │   Transaction   │       │    Category     │
├─────────────────┤       ├─────────────────┤       ├─────────────────┤
│ id (PK)         │◄──┐   │ id (PK)         │   ┌──►│ id (PK)         │
│ name            │   │   │ account_id (FK) │───┘   │ name            │
│ type (enum)     │   │   │ category_id(FK) │───────│ type (enum)     │
│ currency (enum) │   └───│ type (enum)     │       │ icon            │
│ initial_balance │       │ amount          │       │ is_system       │
│ icon            │       │ to_account_id   │       └─────────────────┘
│ is_active       │       │ to_amount       │
└────────┬────────┘       │ exchange_rate   │       ┌─────────────────┐
         │                │ date            │       │     Budget      │
         │                │ note            │       ├─────────────────┤
         │                │ recurring_id    │       │ id (PK)         │
         │                └─────────────────┘       │ category_id(FK) │
         │                                          │ amount          │
         │                                          │ period (enum)   │
         │                                          │ start_date      │
         ▼                                          └─────────────────┘
┌─────────────────┐       ┌─────────────────┐
│    Holding      │       │   Investment    │
├─────────────────┤       │   Transaction   │       ┌─────────────────┐
│ id (PK)         │       ├─────────────────┤       │      Goal       │
│ account_id (FK) │───┐   │ id (PK)         │       ├─────────────────┤
│ asset_type(enum)│   │   │ holding_id (FK) │       │ id (PK)         │
│ ticker          │   └───│ type (enum)     │       │ name            │
│ exchange        │       │ quantity        │       │ target_amount   │
│ quantity        │       │ price_per_unit  │       │ target_currency │
│ avg_buy_price   │       │ total_amount    │       │ deadline        │
│ currency (enum) │       │ fee             │       │ is_achieved     │
└─────────────────┘       │ from_account_id │       └────────┬────────┘
                          │ date            │                │
┌─────────────────┐       └─────────────────┘                │
│   PriceCache    │                                          │
├─────────────────┤       ┌─────────────────┐                │
│ ticker          │       │  GoalAccounts   │◄───────────────┘
│ asset_type(enum)│       │  (Junction)     │
│ price           │       ├─────────────────┤
│ currency (enum) │       │ id (PK)         │
│ updated_at      │       │ goal_id (FK)    │────► Goal
└─────────────────┘       │ account_id (FK) │────► Account
                          │ contribution_amt│
┌─────────────────┐       └─────────────────┘
│  ExchangeRate   │
├─────────────────┤       ┌─────────────────┐       ┌─────────────────┐
│ from_curr (enum)│       │      Debt       │       │    Recurring    │
│ to_curr (enum)  │       ├─────────────────┤       ├─────────────────┤
│ rate            │       │ id (PK)         │       │ id (PK)         │
│ updated_at      │       │ type (enum)     │       │ name            │
└─────────────────┘       │ person_name     │       │ type (enum)     │
                          │ amount          │       │ amount          │
                          │ currency (enum) │       │ account_id (FK) │
                          │ due_date        │       │ category_id(FK) │
                          │ note            │       │ frequency (enum)│
                          │ is_settled      │       │ next_date       │
                          │ settled_acct_id │       │ is_active       │
                          └─────────────────┘       └─────────────────┘
```

**Key Relationships:**
- `Transaction` → `Account` (many-to-one): Each transaction belongs to one account
- `Transaction` → `Category` (many-to-one): Each transaction has one category
- `Holding` → `Account` (many-to-one): Holdings belong to investment accounts
- `InvestmentTransaction` → `Holding` (many-to-one): Investment txns modify holdings
- `Budget` → `Category` (one-to-one per period): One budget per category per period
- `Goal` ↔ `Account` (many-to-many via `GoalAccounts`): Goals can have multiple funding accounts
- `Debt` → `Account` (many-to-one): Settled debts link to settlement account
- `Recurring` → `Account` (many-to-one): Recurring transactions target one account

### 3.2 Enum Definitions

All enums stored as INTEGER in SQLite. Drift maps automatically.

```dart
/// Account types
enum AccountType {
  cash,       // 0 - Physical cash, petty cash
  bank,       // 1 - Bank accounts (BCA, Mandiri, etc.)
  eWallet,    // 2 - GoPay, OVO, Dana, ShopeePay
  investment, // 3 - Brokerage, Exchange accounts
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
```

### 3.3 Core Tables Definition

#### accounts
```sql
CREATE TABLE accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type INTEGER NOT NULL,        -- AccountType enum (0-3)
  currency INTEGER NOT NULL,    -- Currency enum (0-2)
  initial_balance REAL DEFAULT 0,
  icon TEXT,
  color TEXT,
  is_active INTEGER DEFAULT 1,  -- boolean: 0 or 1
  created_at INTEGER NOT NULL,  -- Unix timestamp
  updated_at INTEGER NOT NULL   -- Unix timestamp
);

CREATE INDEX idx_accounts_type ON accounts(type);
CREATE INDEX idx_accounts_is_active ON accounts(is_active);
```
*Note: balance is calculated from transactions, not stored.*

#### transactions
```sql
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  type INTEGER NOT NULL,        -- TransactionType enum (0-2)
  amount REAL NOT NULL,
  to_account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,  -- for transfers
  to_amount REAL,               -- for currency conversion transfers
  exchange_rate REAL,           -- recorded rate at time of transfer
  date INTEGER NOT NULL,        -- Unix timestamp
  note TEXT,
  recurring_id INTEGER REFERENCES recurring(id) ON DELETE SET NULL,
  created_at INTEGER NOT NULL   -- Unix timestamp
);

CREATE INDEX idx_transactions_account ON transactions(account_id);
CREATE INDEX idx_transactions_category ON transactions(category_id);
CREATE INDEX idx_transactions_type ON transactions(type);
CREATE INDEX idx_transactions_date ON transactions(date);
```

#### categories
```sql
CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type INTEGER NOT NULL,        -- CategoryType enum (0-1)
  icon TEXT NOT NULL,
  color TEXT,
  is_system INTEGER DEFAULT 0,  -- boolean: predefined categories
  parent_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,  -- for subcategories (future)
  sort_order INTEGER DEFAULT 0
);

CREATE INDEX idx_categories_type ON categories(type);
```

#### holdings
```sql
CREATE TABLE holdings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  asset_type INTEGER NOT NULL,  -- AssetType enum (0-3)
  ticker TEXT NOT NULL,         -- 'BTC', 'BBCA', 'ANTAM_5G'
  exchange TEXT,                -- 'IDX', 'BINANCE', null for physical
  quantity REAL NOT NULL,
  average_buy_price REAL NOT NULL,
  currency INTEGER NOT NULL,    -- Currency enum (0-2)
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  
  UNIQUE(account_id, asset_type, ticker)  -- prevent duplicate holdings
);

CREATE INDEX idx_holdings_account ON holdings(account_id);
CREATE INDEX idx_holdings_asset_type ON holdings(asset_type);
```

#### investment_transactions
```sql
CREATE TABLE investment_transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  holding_id INTEGER NOT NULL REFERENCES holdings(id) ON DELETE CASCADE,
  type INTEGER NOT NULL,        -- InvestmentTransactionType enum (0-1)
  quantity REAL NOT NULL,
  price_per_unit REAL NOT NULL,
  total_amount REAL NOT NULL,   -- quantity * price + fee
  fee REAL DEFAULT 0,
  from_account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,  -- cash source/destination
  date INTEGER NOT NULL,
  note TEXT,
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_inv_tx_holding ON investment_transactions(holding_id);
CREATE INDEX idx_inv_tx_date ON investment_transactions(date);
```

#### price_cache
```sql
CREATE TABLE price_cache (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ticker TEXT NOT NULL,
  asset_type INTEGER NOT NULL,  -- AssetType enum (0-3)
  price REAL NOT NULL,
  currency INTEGER NOT NULL,    -- Currency enum (0-2)
  updated_at INTEGER NOT NULL,
  
  UNIQUE(ticker, asset_type)
);

CREATE INDEX idx_price_cache_lookup ON price_cache(ticker, asset_type);
```

#### exchange_rates
```sql
CREATE TABLE exchange_rates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  from_currency INTEGER NOT NULL,  -- Currency enum (0-2)
  to_currency INTEGER NOT NULL,    -- Currency enum (0-2)
  rate REAL NOT NULL,
  updated_at INTEGER NOT NULL,
  
  UNIQUE(from_currency, to_currency)
);
```

#### budgets
```sql
CREATE TABLE budgets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  amount REAL NOT NULL,
  period INTEGER NOT NULL,      -- BudgetPeriod enum (0-2)
  start_date INTEGER NOT NULL,
  is_active INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL,
  
  UNIQUE(category_id, period)   -- one budget per category per period type
);

CREATE INDEX idx_budgets_category ON budgets(category_id);
```

#### goals
```sql
CREATE TABLE goals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  target_amount REAL NOT NULL,
  target_currency INTEGER NOT NULL,  -- Currency enum (0-2)
  deadline INTEGER,             -- Unix timestamp, nullable
  icon TEXT,
  color TEXT,
  is_achieved INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

#### goal_accounts (Junction Table)
```sql
-- Many-to-many: One goal can have multiple linked accounts
-- One account can contribute to multiple goals
CREATE TABLE goal_accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  goal_id INTEGER NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
  account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  contribution_amount REAL,     -- Optional: specific amount from this account
  
  UNIQUE(goal_id, account_id)   -- prevent duplicate links
);

CREATE INDEX idx_goal_accounts_goal ON goal_accounts(goal_id);
CREATE INDEX idx_goal_accounts_account ON goal_accounts(account_id);
```

**Goal-Account Relationship Example:**
```
Goal: Marriage Fund (Rp 100,000,000)
│
├── goal_accounts[0]: BCA Savings
│   └── contribution_amount: null (use full balance)
│
├── goal_accounts[1]: Mandiri Deposit  
│   └── contribution_amount: 50,000,000 (only count this much)
│
└── goal_accounts[2]: Cash Emergency
    └── contribution_amount: 10,000,000 (partial allocation)

Total toward goal = sum of (contribution_amount ?? account.balance)
```

#### debts
```sql
CREATE TABLE debts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type INTEGER NOT NULL,        -- DebtType enum (0-1)
  person_name TEXT NOT NULL,
  amount REAL NOT NULL,
  currency INTEGER NOT NULL,    -- Currency enum (0-2)
  due_date INTEGER,             -- Unix timestamp, nullable
  note TEXT,
  is_settled INTEGER DEFAULT 0,
  settled_date INTEGER,
  settled_account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX idx_debts_type ON debts(type);
CREATE INDEX idx_debts_is_settled ON debts(is_settled);
```

#### recurring
```sql
CREATE TABLE recurring (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type INTEGER NOT NULL,        -- TransactionType enum (0-1, income or expense only)
  amount REAL NOT NULL,
  account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  frequency INTEGER NOT NULL,   -- RecurringFrequency enum (0-3)
  next_date INTEGER NOT NULL,   -- Unix timestamp
  end_date INTEGER,             -- Unix timestamp, nullable
  is_active INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_recurring_next_date ON recurring(next_date);
CREATE INDEX idx_recurring_is_active ON recurring(is_active);
```

### 3.3 Predefined Categories

#### Expense Categories
| Name | Icon | Color |
|------|------|-------|
| Food & Drinks | 🍔 | #FF6B6B |
| Transportation | 🚗 | #4ECDC4 |
| Shopping | 🛍️ | #FFE66D |
| Bills & Utilities | 📄 | #95E1D3 |
| Entertainment | 🎬 | #DDA0DD |
| Health | 💊 | #98D8C8 |
| Education | 📚 | #F7DC6F |
| Personal Care | 💇 | #BB8FCE |
| Home | 🏠 | #85C1E9 |
| Gifts & Donations | 🎁 | #F1948A |
| Travel | ✈️ | #7DCEA0 |
| Investment | 📈 | #5DADE2 |
| Other | 📦 | #BDC3C7 |

#### Income Categories
| Name | Icon | Color |
|------|------|-------|
| Salary | 💰 | #2ECC71 |
| Freelance | 💻 | #3498DB |
| Business | 🏪 | #9B59B6 |
| Investment Return | 📊 | #1ABC9C |
| Gift | 🎁 | #E74C3C |
| Refund | ↩️ | #F39C12 |
| Other | 📦 | #BDC3C7 |

---

## 4. Feature Specifications

### 4.1 Feature Priority Matrix

| Priority | Feature | MVP | v1.1 | v2.0 |
|----------|---------|-----|------|------|
| P0 | Account Management | ✅ | | |
| P0 | Transaction Entry (Income/Expense) | ✅ | | |
| P0 | Category Management | ✅ | | |
| P0 | Dashboard (Basic) | ✅ | | |
| P0 | Portfolio Tracking (Manual) | ✅ | | |
| P0 | Multi-currency Support | ✅ | | |
| P0 | PIN/Biometric Lock | ✅ | | |
| P1 | Budget Tracking (Simple Limits) | ✅ | | |
| P1 | Live Price Fetching | ✅ | | |
| P1 | Reports (Monthly/Category) | ✅ | | |
| P1 | Net Worth Calculation | ✅ | | |
| P1 | Transfer Between Accounts | ✅ | | |
| P2 | Goal Tracking | ✅ | | |
| P2 | Debt Tracking (Payable/Receivable) | ✅ | | |
| P2 | Recurring Transactions | ✅ | | |
| P2 | Excel Export | ✅ | | |
| P3 | Google Drive Backup | | ✅ | |
| P3 | 50/30/20 Budget Analysis | | ✅ | |
| P3 | Portfolio Performance Charts | | ✅ | |
| P4 | YNAB-style Envelope Budgeting | | | ✅ |
| P4 | Bank Integration (Indonesia) | | | ✅ |

### 4.2 Account Management

#### 4.2.1 Account Types

| Type | Description | Currency |
|------|-------------|----------|
| Cash Wallet | Physical cash, petty cash | Any |
| Bank Account | BCA, Mandiri, CIMB, etc. | IDR |
| E-Wallet | GoPay, OVO, Dana, ShopeePay | IDR |
| Foreign Bank | Wise, Payoneer | USD/SGD/etc |
| Investment | Brokerage, Exchange | Multiple |

#### 4.2.2 Account Features

- Create, edit, archive accounts
- Set initial balance
- View transaction history per account
- Balance is calculated (not stored) = initial_balance + sum(income) - sum(expense) + sum(transfer_in) - sum(transfer_out)

#### 4.2.3 Transfer Between Accounts

**Same currency:**
```
From: BCA (IDR) -500,000
To: Cash Wallet (IDR) +500,000
```

**Different currency:**
```
From: Wise (SGD) -100
To: BCA (IDR) +1,200,000
Exchange Rate: 12,000 (auto-calculated or manual input)
```

User can either:
1. Input exchange rate manually, amounts auto-calculate
2. Input both amounts, exchange rate auto-calculates

### 4.3 Transaction Management

#### 4.3.1 Transaction Types

| Type | Effect |
|------|--------|
| Income | +account balance |
| Expense | -account balance |
| Transfer | -from_account, +to_account |

#### 4.3.2 Quick Entry Flow

```
[Open App] → [Floating Action Button] → [Quick Entry Modal]

┌─────────────────────────────────┐
│  [Income] [Expense] [Transfer]  │  ← Toggle
├─────────────────────────────────┤
│  Amount: [___________] IDR      │  ← Large, focused
│                                 │
│  Category: [Food & Drinks ▼]    │
│  Account:  [BCA ▼]              │
│  Date:     [Today ▼]            │
│  Note:     [Optional...]        │
│                                 │
│  [Cancel]           [Save]      │
└─────────────────────────────────┘
```

**Design principle:** Optimized for 5+ entries per day. Most common case (expense from primary account) should require minimal taps.

#### 4.3.3 Recurring Transactions

- Auto-create transactions based on frequency
- User confirms or transaction auto-posts
- Frequencies: daily, weekly, monthly, yearly
- Examples: salary, rent, subscriptions, loan payments

### 4.4 Portfolio Tracking

#### 4.4.1 Asset Hierarchy

```
Portfolio
├── Crypto
│   ├── Binance (Exchange)
│   │   ├── BTC: 0.1 units
│   │   ├── ETH: 2 units
│   │   └── USDT: 500 units
│   └── Ledger (Cold Wallet)
│       └── BTC: 0.05 units
├── Stocks
│   ├── Stockbit (Exchange)
│   │   ├── BBCA: 100 lots
│   │   └── TLKM: 50 lots
│   └── IBKR (Exchange)
│       └── AAPL: 10 shares
└── Physical Assets
    ├── Gold
    │   ├── Antam 5g: 2 bars
    │   └── Antam 10g: 1 bar
    └── Silver
        └── UBS 100g: 1 bar
```

#### 4.4.2 Investment Transaction Flow

**Buy:**
```
1. Select asset (or create new holding)
2. Enter quantity
3. Enter price per unit
4. Enter fee (optional)
5. Select funding account (cash account)
6. Save

Effect:
- Creates investment_transaction record
- Updates holding (quantity, average_buy_price)
- Decreases funding account balance (as expense-type, category: Investment)
```

**Sell:**
```
1. Select existing holding
2. Enter quantity to sell
3. Enter sale price per unit
4. Enter fee (optional)
5. Select receiving account
6. Save

Effect:
- Creates investment_transaction record
- Updates holding (quantity)
- Increases receiving account balance (as income-type, category: Investment Return)
- Calculates P/L for display
```

#### 4.4.3 Price Display

```
┌─────────────────────────────────────────┐
│ BTC (Bitcoin)                           │
│ Quantity: 0.15                          │
│                                         │
│ Average Buy: $45,000                    │
│ Current Price: $98,500                  │  ← Live (or cached)
│ Current Value: $14,775                  │  ← Sell price
│                                         │
│ P/L: +$8,025 (+118.9%) 🟢              │
│                                         │
│ Last Updated: 5 mins ago               │
└─────────────────────────────────────────┘

[If offline]
│ Current Price: $95,000 ⚠️              │
│ ⚠️ Price from 2 hours ago              │
```

#### 4.4.4 Gold/Silver Pricing (Indonesian Market)

**Supported formats:**
- Antam: 0.5g, 1g, 2g, 3g, 5g, 10g, 25g, 50g, 100g, 250g, 500g, 1000g
- UBS: 1g, 2g, 5g, 10g, 25g, 50g, 100g
- Silver: 10g, 50g, 100g, 500g, 1kg

**Price display uses sell/buyback price** (what user would receive if selling today).

**Ticker format:**
```
ANTAM_5G    → Antam 5 gram gold
ANTAM_10G   → Antam 10 gram gold
UBS_5G      → UBS 5 gram gold
ANTAM_SILVER_100G → Antam 100 gram silver
```

### 4.5 Budget Management

#### 4.5.1 MVP: Simple Category Limits

```
┌─────────────────────────────────────────┐
│ Food & Drinks                           │
│ Budget: Rp 2,000,000 / month            │
│                                         │
│ ████████████░░░░░░░░ 65%               │
│ Spent: Rp 1,300,000                     │
│ Remaining: Rp 700,000                   │
│                                         │
│ [View Transactions]                     │
└─────────────────────────────────────────┘
```

#### 4.5.2 Budget Alerts

| Threshold | Alert |
|-----------|-------|
| 80% | Yellow warning: "Approaching limit" |
| 100% | Red warning: "Budget exceeded" |

Alerts shown:
- On dashboard
- When adding transaction in that category
- Daily summary notification (optional)

#### 4.5.3 Future: 50/30/20 Analysis (v1.1)

Auto-categorize spending into:
- Needs (50%): Bills, groceries, transport
- Wants (30%): Entertainment, dining out, shopping
- Savings (20%): Investment, emergency fund

Show deviation from ideal ratio.

### 4.6 Dashboard

#### 4.6.1 Dashboard Layout

```
┌─────────────────────────────────────────┐
│ Good Morning, Arif          [Settings] │
├─────────────────────────────────────────┤
│                                         │
│ NET WORTH                               │
│ Rp 150,000,000              ▲ 5.2%     │
│ as of today                            │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│ THIS MONTH                              │
│ Income:  Rp 15,000,000                 │
│ Expense: Rp 8,500,000                  │
│ ─────────────────────                  │
│ Balance: +Rp 6,500,000 🟢             │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│ BUDGET STATUS                           │
│ ████████░░░░░░░░░░░░ 45% used          │
│ 3 categories near limit ⚠️              │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│ PORTFOLIO PERFORMANCE                   │
│ Total Value: Rp 80,000,000             │
│ P/L: +Rp 12,500,000 (+18.5%) 🟢       │
│                                         │
│ [Crypto ▲5%] [Stocks ▲2%] [Gold ▲1%]  │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│ RECENT TRANSACTIONS                     │
│ Today - Grab Food    -Rp 45,000        │
│ Today - Transfer     -Rp 500,000       │
│ Yesterday - Salary   +Rp 15,000,000    │
│                                         │
│ [View All]                              │
└─────────────────────────────────────────┘
│          [+] FAB                        │
└─────────────────────────────────────────┘
```

### 4.7 Goals Tracking

```
┌─────────────────────────────────────────┐
│ 💒 Marriage Fund                        │
│                                         │
│ Target: Rp 100,000,000                 │
│ Deadline: December 2026                │
│                                         │
│ ████████████░░░░░░░░░░░░░ 48%         │
│                                         │
│ Saved: Rp 48,000,000                   │
│ Remaining: Rp 52,000,000               │
│                                         │
│ Linked: BCA Savings Account            │
│ Monthly needed: Rp 4,700,000           │  ← Auto-calculated
│                                         │
│ [Add Funds]  [Edit]                     │
└─────────────────────────────────────────┘
```

**Features:**
- Set target amount and deadline
- Link to specific account (optional)
- Auto-calculate monthly contribution needed
- Track progress over time

### 4.8 Debt Tracking

#### 4.8.1 Payable (I Owe)

```
┌─────────────────────────────────────────┐
│ 💸 PAYABLE (I Owe)                      │
├─────────────────────────────────────────┤
│                                         │
│ John - Dinner split                    │
│ Rp 150,000                             │
│ Due: Feb 5, 2026                       │
│                                         │
│ [Mark as Paid]                          │
│   → Select account: [BCA ▼]            │
│   → Confirm                             │
│                                         │
└─────────────────────────────────────────┘
```

When marked as paid:
- Creates expense transaction from selected account
- Marks debt as settled
- Records settled_date and settled_account_id

#### 4.8.2 Receivable (Owed to Me)

```
┌─────────────────────────────────────────┐
│ 💰 RECEIVABLE (Owed to Me)              │
├─────────────────────────────────────────┤
│                                         │
│ Sarah - Laptop repair                  │
│ Rp 500,000                             │
│ Due: Feb 10, 2026                      │
│                                         │
│ [Mark as Received]                      │
│   → Select account: [Cash ▼]           │
│   → Confirm                             │
│                                         │
└─────────────────────────────────────────┘
```

When marked as received:
- Creates income transaction to selected account
- Marks debt as settled

### 4.9 Reports & Export

#### 4.9.1 Report Types

| Report | Description |
|--------|-------------|
| Monthly Summary | Income vs Expense by month |
| Category Breakdown | Spending by category (pie chart) |
| Account Summary | Balance history per account |
| Portfolio Report | Holdings, P/L, allocation |
| Net Worth History | Total net worth over time |

#### 4.9.2 Excel Export

Export includes:
- All transactions (filterable by date range)
- Account balances
- Portfolio holdings with current values
- Budget vs actual

Format: .xlsx with multiple sheets

### 4.10 Security

#### 4.10.1 App Lock

- PIN (4-6 digits) required
- Biometric option (fingerprint/face)
- Lock after app goes to background
- Configurable timeout (immediate, 1 min, 5 min)

#### 4.10.2 Data Security

- All data stored locally (SQLite)
- No data sent to external servers (except price APIs)
- Optional Google Drive backup (encrypted)

---

## 5. External Integrations

### 5.1 Price APIs

#### 5.1.1 Cryptocurrency

**Primary:** CoinGecko API (free tier)
```
GET https://api.coingecko.com/api/v3/simple/price
?ids=bitcoin,ethereum
&vs_currencies=usd,idr
```

**Fallback:** Binance API
```
GET https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT
```

#### 5.1.2 Stocks

**Indonesian (IDX):**
- Option 1: Scraping from IDX website (fallback)
- Option 2: GoTo Financial API (if available)
- Option 3: Self-hosted scraper updating every 5 mins

**US Stocks:**
- Alpha Vantage (free tier: 25 calls/day)
- Yahoo Finance API (unofficial)

#### 5.1.3 Gold/Silver (Indonesian)

**Primary:** Scrape from:
- https://www.logammulia.com/id/harga-emas-702 (Antam)
- https://www.indogold.id/harga-emas (comparison)

**Data needed:**
- Sell price per gram weight
- Updated 1-2x per day (gold prices don't change frequently)

#### 5.1.4 Exchange Rates

**Primary:** Exchange Rate API (free tier)
```
GET https://api.exchangerate-api.com/v4/latest/IDR
```

**Fallback:** Open Exchange Rates

### 5.2 Google Drive Backup (v1.1)

- OAuth2 authentication
- Backup SQLite database file
- Manual trigger (not auto-sync)
- Restore from backup option

---

## 6. User Interface Guidelines

### 6.1 Design Principles

1. **Speed First:** Quick entry should be under 5 seconds
2. **Glanceable:** Key metrics visible without scrolling
3. **Minimal Taps:** Most actions within 3 taps
4. **Forgiving:** Easy to edit/delete mistakes
5. **Offline Obvious:** Clear indicators when data is stale

### 6.2 Color Palette

| Usage | Color | Hex |
|-------|-------|-----|
| Primary | Deep Blue | #1E3A5F |
| Secondary | Gold | #D4AF37 |
| Success/Income | Green | #2ECC71 |
| Danger/Expense | Red | #E74C3C |
| Warning | Orange | #F39C12 |
| Background | Off-white | #F8F9FA |
| Card | White | #FFFFFF |
| Text Primary | Dark Gray | #2C3E50 |
| Text Secondary | Gray | #7F8C8D |

### 6.3 Typography

| Element | Font | Size | Weight |
|---------|------|------|--------|
| Heading 1 | Inter | 24sp | Bold |
| Heading 2 | Inter | 20sp | SemiBold |
| Body | Inter | 16sp | Regular |
| Caption | Inter | 14sp | Regular |
| Amount (large) | Inter | 32sp | Bold |

### 6.4 Navigation Structure

```
[Dashboard] [Transactions] [Portfolio] [Budget] [More]
     │            │             │          │       │
     │            │             │          │       ├─ Goals
     │            │             │          │       ├─ Debts
     │            │             │          │       ├─ Reports
     │            │             │          │       ├─ Accounts
     │            │             │          │       └─ Settings
     │            │             │          │
     │            │             │          └─ Category budgets
     │            │             │             Budget overview
     │            │             │
     │            │             └─ Asset groups
     │            │                Holdings detail
     │            │                Add investment
     │            │
     │            └─ Transaction list
     │               Filters (date, category, account)
     │               Search
     │
     └─ Net worth
        This month summary
        Budget status
        Portfolio summary
        Recent transactions
```

---

## 7. Development Phases

### Phase 1: Foundation (Week 1-2)

**Goal:** Core data layer and basic UI shell

| Task | Priority |
|------|----------|
| Project setup (Flutter, dependencies) | P0 |
| Drift database setup with all tables | P0 |
| Riverpod providers structure | P0 |
| Account CRUD | P0 |
| Category management | P0 |
| Basic navigation shell | P0 |
| App lock (PIN/biometric) | P0 |

**Deliverable:** App opens, can create accounts and categories, data persists.

### Phase 2: Transactions (Week 3-4)

**Goal:** Full transaction management

| Task | Priority |
|------|----------|
| Transaction entry (income/expense) | P0 |
| Transfer between accounts | P1 |
| Currency conversion for transfers | P1 |
| Transaction list with filters | P0 |
| Account balance calculation | P0 |
| Quick entry FAB | P0 |
| Recurring transaction setup | P2 |
| Auto-create recurring transactions | P2 |

**Deliverable:** Can track all cash flow, transfer money between accounts.

### Phase 3: Portfolio (Week 5-6)

**Goal:** Investment tracking with live prices

| Task | Priority |
|------|----------|
| Holdings management | P0 |
| Investment buy/sell transactions | P0 |
| Price cache table | P0 |
| Crypto price API integration | P1 |
| Stock price API integration | P1 |
| Gold/silver price scraping | P1 |
| Portfolio value calculation | P0 |
| P/L calculation and display | P0 |
| Offline price cache with warning | P1 |

**Deliverable:** Can track all investments, see live values and P/L.

### Phase 4: Budget & Goals (Week 7)

**Goal:** Budget tracking and goal progress

| Task | Priority |
|------|----------|
| Budget CRUD per category | P1 |
| Budget vs actual calculation | P1 |
| Budget alerts (80%, 100%) | P1 |
| Goal CRUD | P2 |
| Goal progress tracking | P2 |
| Link goal to account | P2 |
| Debt tracking (payable/receivable) | P2 |
| Settle debt flow | P2 |

**Deliverable:** Full budgeting and goal tracking working.

### Phase 5: Dashboard & Reports (Week 8)

**Goal:** Unified dashboard and reporting

| Task | Priority |
|------|----------|
| Net worth calculation (all sources) | P0 |
| Dashboard layout | P0 |
| This month income/expense summary | P0 |
| Budget status widget | P1 |
| Portfolio summary widget | P0 |
| Monthly report | P1 |
| Category breakdown chart | P1 |
| Excel export | P2 |

**Deliverable:** Complete dashboard showing all key metrics.

### Phase 6: Polish (Week 9-10)

**Goal:** Production ready

| Task | Priority |
|------|----------|
| Error handling across app | P0 |
| Loading states | P0 |
| Empty states | P1 |
| Onboarding flow | P1 |
| Performance optimization | P1 |
| Edge case testing | P0 |
| UI polish and consistency | P1 |
| Beta testing | P1 |

**Deliverable:** MVP ready for release.

---

## 8. Out of Scope (MVP)

These features are explicitly NOT included in MVP:

| Feature | Reason | Target Version |
|---------|--------|----------------|
| Google Drive backup | Nice-to-have, not critical | v1.1 |
| Bank account linking | Complex integration, regulatory | v2.0 |
| YNAB-style envelope budgeting | Complex, needs user feedback | v2.0 |
| Multi-device sync | Requires backend | v2.0 |
| Shared expenses | Scope creep | v2.0 |
| Investment auto-import | API limitations | v2.0 |
| Tax reporting | Region-specific complexity | v2.0 |
| Dark mode | Nice-to-have | v1.1 |
| Widgets (home screen) | Nice-to-have | v1.1 |
| Notifications | Nice-to-have | v1.1 |

---

## 9. Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Price API rate limits | Can't fetch live prices | Medium | Cache aggressively, fallback APIs |
| Gold price scraping breaks | Stale gold prices | Medium | Multiple sources, manual override |
| Scope creep | Delayed launch | High | Strict adherence to Out of Scope list |
| Performance with large datasets | Slow app | Low | Pagination, indexed queries, lazy loading |
| Data loss (user error) | User frustration | Medium | Confirm dialogs, soft delete, export backup |

---

## 10. Glossary

| Term | Definition |
|------|------------|
| Holding | A specific investment asset (e.g., 0.1 BTC in Binance) |
| Net Worth | Total assets (cash + investments) minus liabilities (debts) |
| P/L | Profit/Loss = Current Value - Cost Basis |
| Cost Basis | Average purchase price × quantity |
| Payable | Money you owe to someone |
| Receivable | Money someone owes to you |
| Base Currency | IDR - all reporting converts to this |
| Drift | Flutter SQLite wrapper library with type-safe queries |
| Riverpod | Flutter state management library |
| Enum (in DB) | Stored as INTEGER (0, 1, 2...) for performance; Drift auto-converts |
| Junction Table | Table linking two entities in many-to-many relationship (e.g., goal_accounts) |
| Unix Timestamp | Seconds since 1970-01-01, stored as INTEGER for dates |

---

## 11. Appendix

### A. Currency Codes Supported (MVP)

| Code | Name |
|------|------|
| IDR | Indonesian Rupiah |
| USD | US Dollar |
| SGD | Singapore Dollar |

Additional currencies can be added post-MVP.

### B. Asset Tickers Convention

```
Crypto:    BTC, ETH, USDT, BNB (standard symbols)
Stocks:    BBCA.IDX, TLKM.IDX, AAPL.US
Gold:      ANTAM_1G, ANTAM_5G, ANTAM_10G, UBS_5G
Silver:    ANTAM_SILVER_100G, UBS_SILVER_1KG
```

### C. Database Migrations Strategy

- Version number in database
- Migration scripts for each version upgrade
- Backup before migration
- Rollback capability

---

**Document End**

*This PRD is the source of truth for Rich Together MVP development. All feature requests should be evaluated against this document. Updates require version increment and changelog entry.*
