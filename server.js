const express = require('express');
const pool = require('./db');
require('dotenv').config();

const app = express();
app.use(express.json());

// Enable basic CORS and serve static files (for Phase 4 frontend)
app.use(express.static('public'));

// ============================================================================
// 1. GET /api/assets - List all available tradable assets
// ============================================================================
app.get('/api/assets', async (req, res) => {
    try {
        const [assets] = await pool.query('SELECT * FROM assets ORDER BY id ASC');
        res.json({ success: true, assets });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

// ============================================================================
// 2. GET /api/user/:id - Fetch full user financial profile (Wallet, Portfolio, Ledger)
// ============================================================================
app.get('/api/user/:id', async (req, res) => {
    const userId = parseInt(req.params.id, 10);
    try {
        // User basic info
        const [users] = await pool.query('SELECT id, email, created_at FROM users WHERE id = ?', [userId]);
        if (users.length === 0) {
            return res.status(404).json({ success: false, error: 'User not found' });
        }

        // Wallet balance
        const [wallets] = await pool.query('SELECT balance FROM wallets WHERE user_id = ?', [userId]);
        const balance = wallets.length > 0 ? wallets[0].balance : '0.00';

        // Portfolio holdings
        const [holdings] = await pool.query(`
            SELECT p.asset_id, a.ticker_symbol, a.name, p.quantity
            FROM portfolios p
            JOIN assets a ON p.asset_id = a.id
            WHERE p.user_id = ? AND p.quantity > 0
            ORDER BY a.id ASC
        `, [userId]);

        // Recent transaction ledger (last 10)
        const [ledger] = await pool.query(`
            SELECT tl.id, tl.transaction_type, tl.amount, tl.created_at, a.ticker_symbol
            FROM transaction_ledger tl
            LEFT JOIN assets a ON tl.asset_id = a.id
            WHERE tl.user_id = ?
            ORDER BY tl.id DESC
            LIMIT 10
        `, [userId]);

        res.json({
            success: true,
            user: users[0],
            balance,
            holdings,
            ledger
        });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

// ============================================================================
// 3. POST /api/deposit - Cash Deposit Transaction
// ============================================================================
app.post('/api/deposit', async (req, res) => {
    const { userId, amount } = req.body;
    const numAmount = parseFloat(amount);

    if (!userId || isNaN(numAmount) || numAmount <= 0) {
        return res.status(400).json({ success: false, error: 'Invalid userId or deposit amount (must be > 0).' });
    }

    const connection = await pool.getConnection();
    try {
        await connection.beginTransaction();

        // 1. Increment wallet balance
        await connection.query(
            'UPDATE wallets SET balance = balance + ? WHERE user_id = ?',
            [numAmount, userId]
        );

        // 2. Append deposit to transaction ledger
        await connection.query(
            'INSERT INTO transaction_ledger (user_id, transaction_type, asset_id, amount) VALUES (?, "DEPOSIT", NULL, ?)',
            [userId, numAmount]
        );

        await connection.commit();

        // Fetch updated balance to return to client
        const [updatedWallet] = await connection.query('SELECT balance FROM wallets WHERE user_id = ?', [userId]);

        res.json({
            success: true,
            message: `Successfully deposited $${numAmount.toFixed(2)}`,
            newBalance: updatedWallet[0].balance
        });
    } catch (err) {
        await connection.rollback();
        res.status(500).json({ success: false, error: err.message });
    } finally {
        connection.release();
    }
});

// ============================================================================
// 4. POST /api/buy - Buy Asset Order (Pessimistic Row Lock on Wallet)
// ============================================================================
app.post('/api/buy', async (req, res) => {
    const { userId, assetId, quantity, pricePerUnit } = req.body;
    const numQty = parseFloat(quantity);
    const numPrice = parseFloat(pricePerUnit);

    if (!userId || !assetId || isNaN(numQty) || numQty <= 0 || isNaN(numPrice) || numPrice <= 0) {
        return res.status(400).json({ success: false, error: 'Invalid parameters for buy order.' });
    }

    const totalCost = parseFloat((numQty * numPrice).toFixed(2));
    const connection = await pool.getConnection();

    try {
        await connection.beginTransaction();

        // Step 1: Pessimistic Lock on User's Wallet (FOR UPDATE)
        const [wallets] = await connection.query(
            'SELECT balance FROM wallets WHERE user_id = ? FOR UPDATE',
            [userId]
        );

        if (wallets.length === 0) {
            throw new Error('Wallet not found for this user.');
        }

        const currentBalance = parseFloat(wallets[0].balance);
        if (currentBalance < totalCost) {
            throw new Error(`Insufficient funds: Balance is $${currentBalance.toFixed(2)}, required is $${totalCost.toFixed(2)}`);
        }

        // Step 2: Deduct cost from wallet
        await connection.query(
            'UPDATE wallets SET balance = balance - ? WHERE user_id = ?',
            [totalCost, userId]
        );

        // Step 3: Credit shares to portfolio (Upsert)
        await connection.query(`
            INSERT INTO portfolios (user_id, asset_id, quantity)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE quantity = quantity + ?
        `, [userId, assetId, numQty, numQty]);

        // Step 4: Record debit in transaction ledger (Negative amount)
        await connection.query(
            'INSERT INTO transaction_ledger (user_id, transaction_type, asset_id, amount) VALUES (?, "BUY", ?, ?)',
            [userId, assetId, -totalCost]
        );

        await connection.commit();

        const [finalWallet] = await connection.query('SELECT balance FROM wallets WHERE user_id = ?', [userId]);

        res.json({
            success: true,
            message: `Successfully purchased ${numQty} shares/units of asset #${assetId} for $${totalCost.toFixed(2)}`,
            newBalance: finalWallet[0].balance
        });
    } catch (err) {
        await connection.rollback();
        res.status(400).json({ success: false, error: err.message });
    } finally {
        connection.release();
    }
});

// ============================================================================
// 5. POST /api/sell - Sell Asset Order (Pessimistic Row Lock on Portfolio)
// ============================================================================
app.post('/api/sell', async (req, res) => {
    const { userId, assetId, quantity, pricePerUnit } = req.body;
    const numQty = parseFloat(quantity);
    const numPrice = parseFloat(pricePerUnit);

    if (!userId || !assetId || isNaN(numQty) || numQty <= 0 || isNaN(numPrice) || numPrice <= 0) {
        return res.status(400).json({ success: false, error: 'Invalid parameters for sell order.' });
    }

    const totalProceeds = parseFloat((numQty * numPrice).toFixed(2));
    const connection = await pool.getConnection();

    try {
        await connection.beginTransaction();

        // Step 1: Pessimistic Lock on User's Portfolio Holding (FOR UPDATE)
        const [holdings] = await connection.query(
            'SELECT quantity FROM portfolios WHERE user_id = ? AND asset_id = ? FOR UPDATE',
            [userId, assetId]
        );

        if (holdings.length === 0 || parseFloat(holdings[0].quantity) < numQty) {
            const currentQty = holdings.length > 0 ? parseFloat(holdings[0].quantity) : 0;
            throw new Error(`Insufficient holdings: You own ${currentQty}, but tried to sell ${numQty}`);
        }

        // Step 2: Deduct asset quantity from portfolio
        await connection.query(
            'UPDATE portfolios SET quantity = quantity - ? WHERE user_id = ? AND asset_id = ?',
            [numQty, userId, assetId]
        );

        // Step 3: Credit cash proceeds to wallet
        await connection.query(
            'UPDATE wallets SET balance = balance + ? WHERE user_id = ?',
            [totalProceeds, userId]
        );

        // Step 4: Record credit in transaction ledger (Positive amount)
        await connection.query(
            'INSERT INTO transaction_ledger (user_id, transaction_type, asset_id, amount) VALUES (?, "SELL", ?, ?)',
            [userId, assetId, totalProceeds]
        );

        await connection.commit();

        const [finalWallet] = await connection.query('SELECT balance FROM wallets WHERE user_id = ?', [userId]);

        res.json({
            success: true,
            message: `Successfully sold ${numQty} shares/units of asset #${assetId} for $${totalProceeds.toFixed(2)}`,
            newBalance: finalWallet[0].balance
        });
    } catch (err) {
        await connection.rollback();
        res.status(400).json({ success: false, error: err.message });
    } finally {
        connection.release();
    }
});

// Start Server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 ApexTrade API server running on http://localhost:${PORT}`);
});
