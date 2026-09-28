# ApexTrade

A financial trading backend and dashboard built with MySQL 8.0 (InnoDB) and Node.js. The project implements strict database-level constraints, ACID transactions, and pessimistic row locking to prevent race conditions, double-spending, and balance discrepancies.

## Key Architectural Decisions

- **Storage Engine:** MySQL 8.0 InnoDB for strict transaction support and row-level locking.
- **Fixed-Point Precision:** Uses `DECIMAL(15, 2)` for cash and `DECIMAL(15, 4)` for fractional assets to prevent floating-point rounding errors.
- **Integrity Constraints:** Database-level `CHECK (balance >= 0)` and `CHECK (quantity >= 0)` guarantee accounts and holdings cannot become negative.
- **Concurrency Control:** Trades use `SELECT ... FOR UPDATE` to exclusively lock rows during balance checks and updates, serializing concurrent requests.
- **Immutable Ledger:** Every deposit, purchase, and sale is recorded in an append-only `transaction_ledger` table. Account balances reconcile directly against the ledger sum with zero discrepancy.

## Project Structure

```
├── public/
│   └── index.html        # Web dashboard for user switching, trading, and ledger logs
├── sql/
│   ├── schema.sql        # Table definitions and constraints
│   ├── seed.sql          # Initial users, assets, and seed balances
│   └── transactions.sql  # Reference transactions and audit reconciliation queries
├── .env.example          # Environment variable template
├── .gitignore            # Ignores node_modules, .env, and docs
├── db.js                 # MySQL connection pool configuration
├── package.json          # Node.js dependencies and scripts
├── server.js             # Express API server with transactional endpoints
└── test_db.js            # Database connectivity test script
```

## Setup & Running

### 1. Database Setup
Import the SQL files into your local MySQL 8.0 instance:

```bash
mysql -u root -p < sql/schema.sql
mysql -u root -p < sql/seed.sql
```

### 2. Environment Configuration
Copy `.env.example` to `.env` and fill in your MySQL credentials:

```env
PORT=3000
DB_HOST=127.0.0.1
DB_PORT=3307
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=apex_trade
```

### 3. Install & Start
```bash
npm install
node test_db.js    # Verify database connection
npm start          # Run Express server
```

Access the frontend dashboard at `http://localhost:3000`.

## API Endpoints

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/assets` | Returns list of available tradable assets. |
| `GET` | `/api/user/:id` | Returns user info, wallet balance, holdings, and recent ledger entries. |
| `POST` | `/api/deposit` | Deposits funds into user wallet and appends ledger record. |
| `POST` | `/api/buy` | Locks wallet with `FOR UPDATE`, deducts funds, updates portfolio, and logs debit. |
| `POST` | `/api/sell` | Locks portfolio with `FOR UPDATE`, deducts shares, credits wallet, and logs credit. |

## Ledger Audit Query

Run this query in MySQL to verify that all wallet balances match the ledger history:

```sql
SELECT 
    w.user_id,
    w.balance AS wallet_balance,
    COALESCE(SUM(tl.amount), 0.00) AS ledger_sum,
    (w.balance - COALESCE(SUM(tl.amount), 0.00)) AS discrepancy
FROM wallets w
LEFT JOIN transaction_ledger tl ON w.user_id = tl.user_id
GROUP BY w.user_id, w.balance;
```
