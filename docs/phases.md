# phases.md

## Phase 0: Environment Setup [COMPLETED]
- [x] Determine user's OS and choose installation method (Docker vs. Native Installer).
- [x] Guide user through installing MySQL 8.0+.
- [x] Guide user through installing a GUI client (like DBeaver, MySQL Workbench, or a VS Code extension).
- [x] Verify connection to the database.

## Phase 1: Schema Construction [COMPLETED]
- [x] Create the database.
- [x] Create `users`, `assets`, and `wallets` tables with proper constraints.
- [x] Create `portfolios` and `transaction_ledger` tables.
- [x] Insert dummy data (3 users, 5 assets, some initial cash balances).

## Phase 2: Core Database Logic (The Hard Part) [COMPLETED]
- [x] Learn and write a standard transaction (BEGIN, COMMIT, ROLLBACK).
- [x] Write the SQL for a user depositing cash into their wallet.
- [x] Write the SQL for a "Buy" order using `SELECT ... FOR UPDATE` to lock the wallet.
- [x] Test the lock by simulating concurrent requests.
- [x] Write the SQL for a "Sell" order.

## Phase 3: Backend API (Node.js) [COMPLETED]
- [x] Initialize Node.js project.
- [x] Connect Node.js to MySQL using a connection pool.
- [x] Create REST endpoints (`/deposit`, `/buy`, `/sell`) that execute the SQL from Phase 2.

## Phase 4: Frontend Dashboard [COMPLETED]
- [x] Create a simple UI to display user balance.
- [x] Create buttons to trigger buy/sell endpoints.
- [x] Display the user's transaction ledger history.