require('dotenv').config();
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function go() {
  // 1. All tables
  const tables = await pool.query(
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name"
  );
  console.log('=== TABLES ===');
  tables.rows.forEach(r => console.log('  ' + r.table_name));

  const expected = ['users','branches','classes','students','student_parents','attendance','posts','leave_requests','teacher_logs','notifications'];
  const found = tables.rows.map(r => r.table_name);
  const missing = expected.filter(t => !found.includes(t));
  console.log('\n=== MISSING TABLES ===');
  if (missing.length === 0) console.log('  None!');
  else missing.forEach(t => console.log('  MISSING: ' + t));

  // 2. Columns per table
  console.log('\n=== COLUMNS ===');
  for (const t of found) {
    const cols = await pool.query(
      "SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = $1 ORDER BY ordinal_position",
      [t]
    );
    console.log('\n[' + t + ']');
    cols.rows.forEach(c => console.log('  ' + c.column_name + ' (' + c.data_type + ') ' + (c.is_nullable === 'NO' ? 'NOT NULL' : 'nullable')));
  }

  // 3. Foreign keys
  console.log('\n=== FOREIGN KEYS ===');
  const fks = await pool.query(
    "SELECT tc.table_name, kcu.column_name, ccu.table_name AS foreign_table_name, ccu.column_name AS foreign_column_name FROM information_schema.table_constraints AS tc JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name JOIN information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = tc.constraint_name WHERE tc.constraint_type = 'FOREIGN KEY'"
  );
  fks.rows.forEach(r => console.log('  ' + r.table_name + '.' + r.column_name + ' -> ' + r.foreign_table_name + '.' + r.foreign_column_name));

  // 4. Row counts
  console.log('\n=== ROW COUNTS ===');
  for (const t of found) {
    const cnt = await pool.query('SELECT count(*) FROM "' + t + '"');
    console.log('  ' + t + ': ' + cnt.rows[0].count + ' rows');
  }

  // 5. Quick CRUD test
  console.log('\n=== CRUD TEST ===');
  try {
    await pool.query('SELECT 1 AS test');
    console.log('  SELECT: OK');
  } catch (e) { console.log('  SELECT: FAIL - ' + e.message); }

  await pool.end();
  process.exit(0);
}

go().catch(e => { console.error(e); process.exit(1); });
