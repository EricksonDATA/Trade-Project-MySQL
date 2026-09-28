-- ============================================================================
-- ApexTrade - Core Financial Transactions (Phase 2)
-- Storage Engine: InnoDB
-- Strict ACID compliance, row-level pessimistic locking, and ledger auditing.
-- ============================================================================

USE apex_trade;

-- ----------------------------------------------------------------------------
-- 1. Concept: Atomicity & Rollback Demonstration
-- If any part of a multi-statement trade fails, ROLLBACK restores the original state.
-- ----------------------------------------------------------------------------
START TRANSACTION;
UPDATE wallets SET balance = balance - 5000.00 WHERE user_id = 1;
-- Error simulated: abort everything
ROLLBACK;


-- ----------------------------------------------------------------------------
-- 2. Cash Deposit Transaction
-- Atomically increases wallet balance and logs a positive credit in ledger.
-- Example: Bob (user_id = 2) deposits $500.00
-- ----------------------------------------------------------------------------
START TRANSACTION;

UPDATE wallets 
SET balance = balance + 500.00 
WHERE user_id = 2;

INSERT INTO transaction_ledger (user_id, transaction_type, asset_id, amount)
VALUES (2, 'DEPOSIT', NULL, 500.00);

COMMIT;


-- ----------------------------------------------------------------------------
-- 3. Buy Order Transaction (Pessimistic Row Lock on Wallet)
-- Prevents double-spend race conditions by locking wallet balance with FOR UPDATE.
-- Example: Alice (user_id = 1) buys 2.0000 shares of AAPL (asset_id = 1) @ $150 = $300.00
-- ----------------------------------------------------------------------------
START TRANSACTION;

-- Step 3a: Acquire exclusive write lock on user's wallet
SELECT balance 
FROM wallets 
WHERE user_id = 1 
FOR UPDATE;

-- Step 3b: Deduct purchase cost from wallet
UPDATE wallets 
SET balance = balance - 300.00 
WHERE user_id = 1;

-- Step 3c: Upsert portfolio holdings (add to existing holding if present)
INSERT INTO portfolios (user_id, asset_id, quantity)
VALUES (1, 1, 2.0000)
ON DUPLICATE KEY UPDATE quantity = quantity + 2.0000;

-- Step 3d: Append audit entry in ledger (negative amount represents cash debit)
INSERT INTO transaction_ledger (user_id, transaction_type, asset_id, amount)
VALUES (1, 'BUY', 1, -300.00);

COMMIT;


-- ----------------------------------------------------------------------------
-- 4. Sell Order Transaction (Pessimistic Row Lock on Portfolio)
-- Prevents selling phantom shares by locking portfolio quantity with FOR UPDATE.
-- Example: Alice (user_id = 1) sells 1.0000 share of AAPL (asset_id = 1) @ $160 = $160.00
-- ----------------------------------------------------------------------------
START TRANSACTION;

-- Step 4a: Acquire exclusive write lock on the user's asset holding
SELECT quantity 
FROM portfolios 
WHERE user_id = 1 AND asset_id = 1 
FOR UPDATE;

-- Step 4b: Deduct sold quantity from portfolio
UPDATE portfolios 
SET quantity = quantity - 1.0000 
WHERE user_id = 1 AND asset_id = 1;

-- Step 4c: Credit cash proceeds to wallet
UPDATE wallets 
SET balance = balance + 160.00 
WHERE user_id = 1;

-- Step 4d: Append audit entry in ledger (positive amount represents cash credit)
INSERT INTO transaction_ledger (user_id, transaction_type, asset_id, amount)
VALUES (1, 'SELL', 1, 160.00);

COMMIT;


-- ----------------------------------------------------------------------------
-- 5. Financial Audit Reconciliation Query
-- Rule: The sum of all ledger records for any user MUST equal their current wallet balance.
-- ----------------------------------------------------------------------------
SELECT 
    w.user_id,
    w.balance AS current_wallet_balance,
    COALESCE(SUM(tl.amount), 0.00) AS ledger_sum,
    (w.balance - COALESCE(SUM(tl.amount), 0.00)) AS discrepancy
FROM wallets w
LEFT JOIN transaction_ledger tl ON w.user_id = tl.user_id
GROUP BY w.user_id, w.balance;
