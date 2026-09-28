const mysql = require('mysql2/promise');
require('dotenv').config();

// Create a MySQL Connection Pool
// Why a Pool? Instead of opening and closing an expensive TCP connection on every API request,
// a pool maintains reusable active connections ready to process transactions concurrently.
const pool = mysql.createPool({
    host: process.env.DB_HOST || '127.0.0.1',
    port: parseInt(process.env.DB_PORT, 10) || 3307,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'apex_trade',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

module.exports = pool;
