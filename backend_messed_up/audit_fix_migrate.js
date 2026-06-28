require('dotenv').config();
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function go() {
  // Fix 6: Drop dead leaves table
  console.log('Fix 6: Dropping unused leaves table...');
  await pool.query('DROP TABLE IF EXISTS leaves CASCADE');
  console.log('  ✅ leaves table dropped');

  // Fix 9: Add is_active column to students (for soft delete)
  console.log('Fix 9: Adding is_active to students...');
  try {
    await pool.query('ALTER TABLE students ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true');
    console.log('  ✅ is_active column added to students');
  } catch (e) {
    console.log('  ⚠️ ' + e.message);
  }

  // Verify
  const tables = await pool.query(
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name"
  );
  console.log('\nRemaining tables:');
  tables.rows.forEach(r => console.log('  ' + r.table_name));

  await pool.end();
  process.exit(0);
}

go().catch(e => { console.error(e); process.exit(1); });
