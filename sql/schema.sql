-- ============================================================================
-- ApexTrade - Database Schema
-- Storage Engine: InnoDB (Strict ACID compliance and row-level locking)
-- Character Set: utf8mb4 / utf8mb4_unicode_ci
-- ============================================================================

CREATE DATABASE IF NOT EXISTS apex_trade
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE apex_trade;

-- ----------------------------------------------------------------------------
-- 1. Users Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 2. Assets Table (Traded Stocks & Cryptocurrencies)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS assets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ticker_symbol VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 3. Wallets Table (User Cash Balances)
-- Notes:
--   - Uses DECIMAL(15, 2) to eliminate floating-point precision loss.
--   - CHECK constraint enforces balance >= 0 to prevent negative balances.
--   - UNIQUE(user_id) ensures 1-to-1 relationship between user and primary wallet.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS wallets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    CONSTRAINT chk_wallet_balance CHECK (balance >= 0),
    CONSTRAINT fk_wallet_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 4. Portfolios Table (User Asset Holdings)
-- Notes:
--   - Uses DECIMAL(15, 4) to support fractional share and crypto quantities.
--   - CHECK constraint ensures holding quantity cannot be negative.
--   - UNIQUE(user_id, asset_id) prevents duplicate holding rows per asset.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS portfolios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    asset_id INT NOT NULL,
    quantity DECIMAL(15, 4) NOT NULL DEFAULT 0.0000,
    CONSTRAINT chk_portfolio_qty CHECK (quantity >= 0),
    CONSTRAINT fk_portfolio_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_portfolio_asset FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE,
    CONSTRAINT uq_user_asset UNIQUE (user_id, asset_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 5. Transaction Ledger (Append-Only Immutable Financial Audit Trail)
-- Notes:
--   - Every deposit, withdrawal, purchase, and sale must be logged here.
--   - Amount is signed: positive for credit, negative for debit.
--   - Summing ledger entries for a user verifies their wallet balance integrity.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transaction_ledger (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    transaction_type ENUM('DEPOSIT', 'WITHDRAWAL', 'BUY', 'SELL') NOT NULL,
    asset_id INT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ledger_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_ledger_asset FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE SET NULL
) ENGINE=InnoDB;
