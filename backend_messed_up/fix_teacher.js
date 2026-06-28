require('dotenv').config();
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function run() {
  // Delete xyz1
  await pool.query("DELETE FROM users WHERE email = 'teacher1@tps.com'");
  console.log('Deleted xyz1');

  // Add class_id column to users table if it doesn't exist
  await pool.query(`
    ALTER TABLE users ADD COLUMN IF NOT EXISTS class_id UUID REFERENCES classes(class_id)
  `);
  console.log('Added class_id column to users');

  process.exit(0);
}
run().catch(e => { console.error(e); process.exit(1); });
