/**
 * @module config/db
 * @description Database configuration and MySQL connection pool setup for the application.
 */
const mysql = require('mysql2');

const pool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: 'BGMIVALORANT', //replace password with your actual database password
    database: 'accesco_app',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

/**
 * Promise-based MySQL connection pool to enable async/await database queries.
 * @type {mysql.PoolPromise}
 */
module.exports = pool.promise();