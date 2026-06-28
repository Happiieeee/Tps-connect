require('dotenv').config({path: '../.env'});
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function wipeData() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    console.log('Starting data wipe...');

    // 1. student_parents
    let res = await client.query('DELETE FROM student_parents');
    console.log(`Deleted ${res.rowCount} rows from student_parents`);

    // 2. attendance
    res = await client.query('DELETE FROM attendance');
    console.log(`Deleted ${res.rowCount} rows from attendance`);

    // 3. leave_requests
    res = await client.query('DELETE FROM leave_requests');
    console.log(`Deleted ${res.rowCount} rows from leave_requests`);

    // 4. notifications
    res = await client.query('DELETE FROM notifications');
    console.log(`Deleted ${res.rowCount} rows from notifications`);

    // 5. teacher_logs
    res = await client.query('DELETE FROM teacher_logs');
    console.log(`Deleted ${res.rowCount} rows from teacher_logs`);

    // 6. posts
    res = await client.query('DELETE FROM posts');
    console.log(`Deleted ${res.rowCount} rows from posts`);

    // 7. students
    res = await client.query('DELETE FROM students');
    console.log(`Deleted ${res.rowCount} rows from students`);

    // 8. users (parents and students, preserving staff)
    res = await client.query(`DELETE FROM users WHERE role NOT IN ('superadmin', 'branchadmin', 'teacher')`);
    console.log(`Deleted ${res.rowCount} rows from users (parents/others)`);

    await client.query('COMMIT');
    console.log('Data wipe complete.');

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error during data wipe, rolled back:', err);
  } finally {
    client.release();
    await pool.end();
  }
}

wipeData();
