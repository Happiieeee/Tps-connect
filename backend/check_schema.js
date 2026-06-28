require('dotenv').config();
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function run() {
  const r1 = await pool.query(`SELECT column_name FROM information_schema.columns WHERE table_name = 'users' ORDER BY ordinal_position`);
  console.log('users columns:', r1.rows.map(x => x.column_name));

  const r2 = await pool.query(`SELECT column_name FROM information_schema.columns WHERE table_name = 'classes' ORDER BY ordinal_position`);
  console.log('classes columns:', r2.rows.map(x => x.column_name));

  // Check if there's a teacher_classes or class_teacher table
  const r3 = await pool.query(`SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%class%' OR table_name LIKE '%teacher%'`);
  console.log('related tables:', r3.rows.map(x => x.table_name));

  // Delete xyz1
  const xyz = await pool.query("SELECT user_id, firebase_uid FROM users WHERE email = 'teacher1@tps.com'");
  console.log('xyz1 user:', xyz.rows);

  process.exit(0);
}
run();
