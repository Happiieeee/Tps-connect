require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function run() {
  try {
    const ids = ['1beb9d91-6ad1-40dc-a83d-7ef87d03d2bb', 'e1afe058-2c1f-425c-a939-02339aab508e', '58bc2e89-bc03-4402-aecc-e82e6ea18430'];
    
    for (const id of ids) {
      console.log(`Deleting branch ${id}...`);
      await pool.query('DELETE FROM student_parents WHERE student_id IN (SELECT student_id FROM students WHERE branch_id = $1)', [id]);
      await pool.query('DELETE FROM attendance WHERE student_id IN (SELECT student_id FROM students WHERE branch_id = $1)', [id]);
      await pool.query('DELETE FROM leave_requests WHERE branch_id = $1', [id]);
      await pool.query('DELETE FROM users WHERE branch_id = $1', [id]);
      await pool.query('DELETE FROM students WHERE branch_id = $1', [id]);
      await pool.query('DELETE FROM classes WHERE branch_id = $1', [id]);
      await pool.query('DELETE FROM branches WHERE branch_id = $1', [id]);
      console.log(`Successfully deleted ${id}`);
    }
  } catch (err) {
    console.error(err);
  } finally {
    await pool.end();
  }
}

run();
