const { Pool } = require('pg');
require('dotenv').config({path: '../.env'});
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
async function run() {
  const q = "SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_schema = 'public' AND table_name IN ('users', 'students', 'student_parents', 'classes', 'branches') ORDER BY table_name, ordinal_position;";
  const res = await pool.query(q);
  console.table(res.rows);
  await pool.end();
}
run();
