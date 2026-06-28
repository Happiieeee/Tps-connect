require('dotenv').config({path: '../.env'});
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

// Copy of the normalise function from public.js
function normalisePhone(raw) {
  let digits = raw.replace(/[^\d+]/g, '');
  if (digits.startsWith('+')) digits = digits.slice(1);
  if (digits.startsWith('91') && digits.length === 12) digits = digits.slice(2);
  if (digits.startsWith('0') && digits.length === 11) digits = digits.slice(1);
  if (digits.length !== 10) return null;
  return '+91' + digits;
}

async function testEnroll() {
  const payload = {
    student_name: 'Test Student',
    branch_id: '704dc63c-2408-48f9-a2cf-9b1adeb7a428',
    class_id: 'ce61fdc7-cdb8-4b55-b642-61666cb9bf82',
    date_of_birth: '2020-06-15',
    admission_date: '2026-05-10',
    parent_name: 'Test Parent',
    relation: 'Father',
    phone: '9876543210',
    emergency_contact: '+91 9876 543210'
  };

  // Test phone normalisation
  const normPhone = normalisePhone(payload.phone);
  const normEmerg = normalisePhone(payload.emergency_contact);
  console.log('Phone normalised:', normPhone);
  console.log('Emergency normalised:', normEmerg);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Verify branch/class combo
    const check = await client.query(
      'SELECT class_id FROM classes WHERE class_id = $1 AND branch_id = $2',
      [payload.class_id, payload.branch_id]
    );
    if (check.rowCount === 0) throw new Error('Invalid branch/class combo');

    // Upsert parent
    let parentId;
    const existing = await client.query(
      'SELECT user_id FROM users WHERE phone = $1 AND role = $2',
      [normPhone, 'parent']
    );

    if (existing.rowCount > 0) {
      parentId = existing.rows[0].user_id;
      await client.query('UPDATE users SET name = $1, branch_id = $2, updated_at = NOW() WHERE user_id = $3',
        [payload.parent_name, payload.branch_id, parentId]);
      console.log('Existing parent found:', parentId);
    } else {
      const r = await client.query(
        "INSERT INTO users (name, phone, role, branch_id, is_active, created_at, updated_at) VALUES ($1, $2, 'parent', $3, true, NOW(), NOW()) RETURNING user_id",
        [payload.parent_name, normPhone, payload.branch_id]
      );
      parentId = r.rows[0].user_id;
      console.log('New parent created:', parentId);
    }

    // Create student
    const admDate = payload.admission_date || new Date().toISOString().split('T')[0];
    const stuRes = await client.query(
      'INSERT INTO students (name, dob, branch_id, class_id, admission_date, emergency_contact, is_active, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, true, NOW(), NOW()) RETURNING student_id',
      [payload.student_name, payload.date_of_birth, payload.branch_id, payload.class_id, admDate, normEmerg]
    );
    const studentId = stuRes.rows[0].student_id;
    console.log('New student created:', studentId);

    // Link
    await client.query('INSERT INTO student_parents (student_id, parent_id) VALUES ($1, $2)', [studentId, parentId]);
    console.log('Linked student ↔ parent');

    await client.query('COMMIT');
    console.log('\n✅ SUCCESS! Enrollment test passed.');
    console.log({ student_id: studentId, parent_id: parentId, phone_stored: normPhone });

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ FAILED:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

testEnroll();
