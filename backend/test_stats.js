const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function run() {
  try {
    console.log('Testing stats queries on remote database...');
    
    try {
      console.log('Altering branches table to add code column if not exists...');
      await pool.query(`ALTER TABLE branches ADD COLUMN IF NOT EXISTS code VARCHAR(10) UNIQUE`);
      console.log('Altered successfully!');
    } catch (err) {
      console.warn('Alter table skipped or failed:', err.message);
    }
    
    console.log('1. Querying students count...');
    const r1 = await pool.query(`SELECT COUNT(*) FROM students`);
    console.log('Students:', r1.rows);

    console.log('2. Querying teachers count...');
    const r2 = await pool.query(`SELECT COUNT(*) FROM users WHERE role = 'teacher' AND is_active = true`);
    console.log('Teachers:', r2.rows);

    console.log('3. Querying parents count...');
    const r3 = await pool.query(`SELECT COUNT(*) FROM users WHERE role = 'parent' AND is_active = true`);
    console.log('Parents:', r3.rows);

    console.log('4. Querying branches count...');
    const r4 = await pool.query(`SELECT COUNT(*) FROM branches`);
    console.log('Branches:', r4.rows);

    console.log('5. Querying leave_requests count...');
    const r5 = await pool.query(`SELECT COUNT(*) FROM leave_requests WHERE status = 'pending'`);
    console.log('Leave requests:', r5.rows);

    console.log('6. Querying attendance count...');
    const r6 = await pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE status = 'present')  as present,
        COUNT(*) FILTER (WHERE status = 'absent')   as absent,
        COUNT(*) FILTER (WHERE status = 'on_leave') as on_leave
      FROM attendance WHERE date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Kolkata')::date
    `);
    console.log('Attendance:', r6.rows);

    console.log('7. Querying branches list with stats...');
    const r7 = await pool.query(`
      SELECT
        b.branch_id, b.name, b.code,
        COUNT(DISTINCT s.student_id)  as total_students,
        COUNT(DISTINCT u.user_id)     FILTER (WHERE u.role = 'teacher')  as total_teachers,
        COUNT(DISTINCT p.user_id)     FILTER (WHERE p.role = 'parent')   as total_parents,
        COUNT(DISTINCT lr.leave_id)   FILTER (WHERE lr.status = 'pending') as pending_leaves
      FROM branches b
      LEFT JOIN students s  ON s.branch_id = b.branch_id
      LEFT JOIN users u     ON u.branch_id = b.branch_id AND u.role = 'teacher'
      LEFT JOIN student_parents sp ON sp.student_id = s.student_id
      LEFT JOIN users p     ON p.user_id = sp.parent_id AND p.role = 'parent'
      LEFT JOIN leave_requests lr ON lr.branch_id = b.branch_id
      GROUP BY b.branch_id, b.name, b.code
      ORDER BY b.name
    `);
    console.log('Branches list:', r7.rows);

    console.log('All stats queries completed successfully!');
    process.exit(0);
  } catch (err) {
    console.error('SQL query failed with error:', err.message, err.stack);
    process.exit(1);
  }
}

run();
