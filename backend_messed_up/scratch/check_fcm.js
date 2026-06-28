require('dotenv').config({path: '../.env'});
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function run() {
  // Get branch admin for Little Junior DPS Branch 1
  const res = await pool.query(
    "SELECT user_id, name, email, phone FROM users WHERE role = 'branchadmin' AND branch_id = $1",
    ['97ee32b9-5f26-428f-8bf2-9c11eb8a737a']
  );
  console.table(res.rows);

  // Also check fcm tokens for parents in that branch
  const fcm = await pool.query(
    "SELECT name, phone, fcm_token FROM users WHERE role = 'parent' AND branch_id = $1",
    ['97ee32b9-5f26-428f-8bf2-9c11eb8a737a']
  );
  console.log('\nParents with FCM tokens:');
  console.table(fcm.rows);

  await pool.end();
}
run();
