-- ============================================================================
-- ApexTrade - Seed Data
-- ============================================================================

USE apex_trade;

-- ----------------------------------------------------------------------------
-- 1. Insert Users
-- ----------------------------------------------------------------------------
INSERT INTO users (id, email) VALUES
(1, 'alice@apex.com'),
(2, 'bob@apex.com'),
(3, 'charlie@apex.com');

-- ----------------------------------------------------------------------------
-- 2. Insert Assets (Stocks & Cryptocurrencies)
-- ----------------------------------------------------------------------------
INSERT INTO assets (id, ticker_symbol, name) VALUES
(1, 'AAPL', 'Apple Inc.'),
(2, 'GOOGL', 'Alphabet Inc.'),
(3, 'TSLA', 'Tesla Inc.'),
(4, 'BTC', 'Bitcoin'),
(5, 'ETH', 'Ethereum');

-- ----------------------------------------------------------------------------
-- 3. Initialize User Wallets
-- ----------------------------------------------------------------------------
INSERT INTO wallets (user_id, balance) VALUES
(1, 10000.00),
(2, 5000.00),
(3, 250.00);

-- ----------------------------------------------------------------------------
-- 4. Record Initial Deposits in the Ledger
-- Rule: Money never appears out of thin air. Wallet balance must match ledger!
-- ----------------------------------------------------------------------------
INSERT INTO transaction_ledger (user_id, transaction_type, asset_id, amount) VALUES
(1, 'DEPOSIT', NULL, 10000.00),
(2, 'DEPOSIT', NULL, 5000.00),
(3, 'DEPOSIT', NULL, 250.00);
