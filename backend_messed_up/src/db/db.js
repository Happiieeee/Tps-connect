const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false
  },
  connectionTimeoutMillis: 10000, // Wait 10s for connection
  idleTimeoutMillis: 30000,       // Close idle clients after 30s
});

module.exports = pool;
