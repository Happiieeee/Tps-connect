const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function audit() {
  try {
    console.log('--- Parents with phone 9606664929 ---');
    const parents = await pool.query(
      "SELECT user_id, name, email, phone, firebase_uid FROM users WHERE phone LIKE '%9606664929%'"
    );
    console.table(parents.rows);

    if (parents.rows.length > 0) {
      const parentIds = parents.rows.map(p => p.user_id);
      console.log('--- Linked Students ---');
      const students = await pool.query(
        `SELECT s.student_id, s.name as student_name, s.class_id, sp.parent_id, u.name as parent_name, u.phone
         FROM students s
         JOIN student_parents sp ON s.student_id = sp.student_id
         JOIN users u ON sp.parent_id = u.user_id
         WHERE sp.parent_id = ANY($1)`,
        [parentIds]
      );
      console.table(students.rows);
    }

    console.log('--- Recent Posts ---');
    const posts = await pool.query(
      "SELECT post_id, title, posted_by, branch_id, class_id, created_at FROM posts ORDER BY created_at DESC LIMIT 10"
    );
    console.table(posts.rows);

    console.log('--- Teacher superweb4929@gmail.com ---');
    const teacher = await pool.query(
      "SELECT user_id, name, email, branch_id, class_id FROM users WHERE email = 'superweb4929@gmail.com'"
    );
    console.table(teacher.rows);

  } catch (err) {
    console.error(err);
  } finally {
    await pool.end();
  }
}

audit();
