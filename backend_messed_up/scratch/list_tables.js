const { Pool } = require('pg');
require('dotenv').config({path: '../.env'});
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
async function run() {
  const res = await pool.query("SELECT table_name FROM information_schema.tables WHERE table_schema='public'");
  console.table(res.rows);
  await pool.end();
}
run();
