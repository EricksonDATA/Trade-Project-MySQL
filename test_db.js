const pool = require('./db');

async function testConnection() {
    try {
        console.log('Connecting to MySQL on port 3307...');
        const [rows] = await pool.query('SELECT COUNT(*) AS user_count FROM users;');
        console.log('✅ Connected successfully to apex_trade!');
        console.log(`Verified database access: found ${rows[0].user_count} users in table.`);
        process.exit(0);
    } catch (error) {
        console.error('❌ Connection failed:', error.message);
        process.exit(1);
    }
}

testConnection();
