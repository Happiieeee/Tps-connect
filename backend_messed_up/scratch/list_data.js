const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function listData() {
  try {
    const branches = await pool.query('SELECT branch_id, name FROM branches');
    console.log('--- Branches ---');
    console.table(branches.rows);

    const classes = await pool.query('SELECT class_id, class_name, branch_id FROM classes');
    console.log('--- Classes ---');
    console.table(classes.rows);

    const users = await pool.query("SELECT user_id, name, email, phone, role FROM users WHERE phone = '9606664929' OR role = 'teacher'");
    console.log('--- Users (Relevant) ---');
    console.table(users.rows);

  } catch (err) {
    console.error(err);
  } finally {
    await pool.end();
  }
}

listData();
