# database_schema.md

> **Note to AI:** All tables MUST use `ENGINE=InnoDB`. All monetary values MUST use `DECIMAL(15,2)` or higher precision. 

## Tables

### `users`
- `id` (INT, PK, Auto Increment)
- `email` (VARCHAR(255), UNIQUE, NOT NULL)
- `created_at` (TIMESTAMP, DEFAULT CURRENT_TIMESTAMP)

### `wallets` (Stores user's cash balance)
- `id` (INT, PK, Auto Increment)
- `user_id` (INT, FK -> users.id)
- `balance` (DECIMAL(15,2), DEFAULT 0.00)
- *Constraint:* balance >= 0 (CHECK constraint to prevent negative balances)

### `assets` (The stocks/crypto available to trade)
- `id` (INT, PK, Auto Increment)
- `ticker_symbol` (VARCHAR(10), UNIQUE, NOT NULL)
- `name` (VARCHAR(100), NOT NULL)

### `portfolios` (What the user actually owns)
- `id` (INT, PK, Auto Increment)
- `user_id` (INT, FK -> users.id)
- `asset_id` (INT, FK -> assets.id)
- `quantity` (DECIMAL(15,4), DEFAULT 0.0000)

### `transaction_ledger` (Immutable log of all financial movements)
- `id` (INT, PK, Auto Increment)
- `user_id` (INT, FK -> users.id)
- `transaction_type` (ENUM: 'DEPOSIT', 'WITHDRAWAL', 'BUY', 'SELL')
- `asset_id` (INT, NULLABLE, FK -> assets.id)
- `amount` (DECIMAL(15,2), NOT NULL - positive for credit, negative for debit)
- `created_at` (TIMESTAMP, DEFAULT CURRENT_TIMESTAMP)