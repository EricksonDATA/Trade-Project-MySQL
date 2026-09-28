# ⚡ ApexTrade - ACID-Compliant Financial Trading Engine

A database-first, high-integrity financial trading platform built with **MySQL 8.0 (InnoDB)** and **Node.js / Express**. 

This system was engineered from the ground up to eliminate the three fatal flaws common in poorly designed financial software: **compounding floating-point errors**, **torn transactions**, and **double-spend concurrency race conditions**.

---

## 📖 The Origin Story

At 2:14 AM on a Tuesday, the fictional trading platform *ApexTrade* started bleeding digital money:
- A user had a wallet balance of **negative $40,000**.
- A user bought 500 shares of stock, but cash was never deducted.
- Total cash in the master audit ledger didn't match user wallet balances.

### The Root Causes:
1. **The Floating Point Phantom:** Previous developers stored balances using `FLOAT` instead of `DECIMAL`. Compounding binary approximation errors evaporated thousands of real dollars.
2. **The Double-Spend Disaster:** Malicious users spammed the "Buy" button ten times in a single millisecond. Simultaneous requests read stale balances without row-level locks, allowing them to purchase assets with money they didn't have.
3. **The Torn Transaction:** A server crashed mid-trade after deducting $1,000 but before inserting shares into the portfolio. Without atomic transactions, the user's money vanished.

---

## 🛡️ Architectural Defenses & Core Features

### 1. Zero Floating-Point Drift
- All fiat cash balances use **`DECIMAL(15, 2)`** (exact fixed-point cents up to \$999 Billion).
- All asset quantities use **`DECIMAL(15, 4)`** for fractional stock and cryptocurrency precision.

### 2. Database-Level Invariants
- **`CHECK (balance >= 0)`**: Enforces at the storage engine level that a wallet can never drop below zero.
- **`CHECK (quantity >= 0)`**: Enforces that a portfolio can never hold negative shares.
- **Foreign Keys with Cascading Constraints**: Prevents orphaned financial records.

### 3. ACID Transactions (Atomicity & Crash Recovery)
- Multi-step financial operations are bundled between `START TRANSACTION` and `COMMIT`.
- Any unexpected failure or error triggers an automatic `ROLLBACK`, guaranteeing zero torn transactions.

### 4. Concurrency Control with Pessimistic Row Locking (`SELECT ... FOR UPDATE`)
- During purchases and sales, the specific row in `wallets` or `portfolios` is locked exclusively using `SELECT ... FOR UPDATE`.
- Concurrent requests are queued by MySQL until the active transaction completes, making double-spending physically impossible.

### 5. Append-Only Immutable Transaction Ledger
- Every deposit, withdrawal, purchase, and sale is recorded in `transaction_ledger`.
- Rows are insert-only (never modified or deleted).
- Summing a user's ledger entries always matches their live wallet balance with **$0.00 discrepancy**.

---

## 🛠️ Tech Stack

- **Database:** MySQL 8.0+ (Strictly InnoDB engine)
- **Backend:** Node.js (v24+), Express
- **Database Driver:** `mysql2/promise` (Connection Pooling & Async/Await Transactions)
- **Environment Management:** `dotenv`
- **Frontend Dashboard:** Vanilla HTML5, Modern CSS3, JavaScript (Served via Express static files)

---

## 📁 Repository Structure

```
├── docs/
│   ├── ai_instructions.md    # Architecture and mentor directives
│   ├── database_schema.md    # Database specification
│   ├── phases.md             # Project roadmap & completion status
│   └── story.md              # Disaster story that inspired the architecture
├── public/
│   └── index.html            # Real-time financial trading web dashboard
├── sql/
│   ├── schema.sql            # DDL for database and tables with InnoDB constraints
│   ├── seed.sql              # Initial dummy seed data (Users, Assets, Wallets, Deposits)
│   └── transactions.sql      # Phase 2 transaction templates, locks, and audit queries
├── .env.example              # Environment variables template
├── .gitignore                # Ignores node_modules and local .env
├── db.js                     # MySQL connection pool configuration
├── package.json              # Project dependencies and npm scripts
├── README.md                 # Project documentation
├── server.js                 # Express REST API server with ACID endpoints
└── test_db.js                # Database connection pool verification script
```

---

## 🚀 Getting Started

### Prerequisites
- [MySQL Community Server 8.0+](https://dev.mysql.com/downloads/installer/) (Running on port `3306` or `3307`)
- [Node.js (v18+)](https://nodejs.org/)

### 1. Database Setup
1. Open **MySQL Workbench** or your preferred database client.
2. Run [`sql/schema.sql`](sql/schema.sql) to create the `apex_trade` database and all 5 InnoDB tables.
3. Run [`sql/seed.sql`](sql/seed.sql) to insert initial users (Alice, Bob, Charlie), assets, and initial balances.

### 2. Environment Configuration
Create a `.env` file in the root directory (or copy from `.env.example`):

```bash
cp .env.example .env
```

Update your credentials:
```env
PORT=3000
DB_HOST=127.0.0.1
DB_PORT=3307
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=apex_trade
```

### 3. Install Dependencies & Verify Connection
```bash
npm install
node test_db.js
```

### 4. Start the Application
```bash
npm start
```

Open your browser and navigate to:
👉 **`http://localhost:3000`**

---

## 🔌 API Reference

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/assets` | Retrieve all available tradable stocks and cryptocurrencies. |
| `GET` | `/api/user/:id` | Fetch user financial profile (Wallet balance, portfolio holdings, recent ledger history). |
| `POST` | `/api/deposit` | Atomically deposit cash into user wallet and credit ledger. |
| `POST` | `/api/buy` | Execute buy order with `SELECT ... FOR UPDATE` wallet lock, portfolio upsert, and ledger debit. |
| `POST` | `/api/sell` | Execute sell order with portfolio holdings lock, stock deduction, wallet credit, and ledger entry. |

---

## 🧪 Concurrency Lock Verification Query

To test lock contention and verify database integrity, run the audit reconciliation query from [`sql/transactions.sql`](sql/transactions.sql):

```sql
SELECT 
    w.user_id,
    w.balance AS current_wallet_balance,
    COALESCE(SUM(tl.amount), 0.00) AS ledger_sum,
    (w.balance - COALESCE(SUM(tl.amount), 0.00)) AS discrepancy
FROM wallets w
LEFT JOIN transaction_ledger tl ON w.user_id = tl.user_id
GROUP BY w.user_id, w.balance;
```
*Expected Result:* `discrepancy = 0.00` across all user accounts.
