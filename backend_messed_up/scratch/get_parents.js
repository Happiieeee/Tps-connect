const { Pool } = require('pg');
require('dotenv').config({path: '../.env'});
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
async function run() {
  const res = await pool.query(`
    SELECT u.name as parent_name, u.phone, u.created_at, b.name as branch, s.name as student_name
    FROM users u
    LEFT JOIN branches b ON u.branch_id = b.branch_id
    LEFT JOIN student_parents sp ON u.user_id = sp.parent_id
    LEFT JOIN students s ON sp.student_id = s.student_id
    WHERE u.role = 'parent'
  `);
  console.table(res.rows);
  await pool.end();
}
run();
