require('dotenv').config();
const pool = require('./src/db/db');

async function migrate() {
  try {
    await pool.query('ALTER TABLE branches ADD COLUMN IF NOT EXISTS code VARCHAR(50) UNIQUE');
    console.log('Added code column to branches table');
  } catch (err) {
    console.error('Error adding column:', err.message);
  } finally {
    pool.end();
  }
}
migrate();
