const express = require('express');
const router = express.Router();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

/**
 * Normalise any phone format to +91XXXXXXXXXX
 * Accepts: 9876543210 / 09876543210 / +919876543210 / 91 98765 43210 etc.
 */
function normalisePhone(raw) {
  // Strip everything except digits and leading +
  let digits = raw.replace(/[^\d+]/g, '');
  // Remove leading + for processing
  if (digits.startsWith('+')) digits = digits.slice(1);
  // Strip country code 91 if already present (10-digit follows)
  if (digits.startsWith('91') && digits.length === 12) {
    digits = digits.slice(2);
  }
  // Strip leading 0
  if (digits.startsWith('0') && digits.length === 11) {
    digits = digits.slice(1);
  }
  if (digits.length !== 10) return null; // invalid
  return '+91' + digits;
}

/**
 * POST /public/enroll
 * Body (JSON):
 *   student_name, branch_id, class_id, date_of_birth,
 *   admission_date (optional), parent_name, relation, phone,
 *   emergency_contact
 */
router.post('/enroll', async (req, res) => {
  const {
    student_name, branch_id, class_id, date_of_birth,
    admission_date, parent_name, relation, phone, emergency_contact
  } = req.body;

  // ── Validation ────────────────────────────────
  const missing = [];
  if (!student_name)    missing.push('student_name');
  if (!branch_id)       missing.push('branch_id');
  if (!class_id)        missing.push('class_id');
  if (!date_of_birth)   missing.push('date_of_birth');
  if (!parent_name)     missing.push('parent_name');
  if (!relation)        missing.push('relation');
  if (!phone)           missing.push('phone');
  if (!emergency_contact) missing.push('emergency_contact');

  if (missing.length) {
    return res.status(400).json({ error: 'Missing required fields', fields: missing });
  }

  // ── Phone normalisation ───────────────────────
  const normPhone = normalisePhone(phone);
  if (!normPhone) {
    return res.status(400).json({ error: 'Invalid phone number. Please enter a 10-digit Indian mobile number.' });
  }

  const normEmerg = normalisePhone(emergency_contact);
  if (!normEmerg) {
    return res.status(400).json({ error: 'Invalid emergency contact number. Please enter a 10-digit Indian mobile number.' });
  }

  // ── Validate branch & class exist together ────
  const branchCheck = await pool.query(
    'SELECT class_id FROM classes WHERE class_id = $1 AND branch_id = $2',
    [class_id, branch_id]
  );
  if (branchCheck.rowCount === 0) {
    return res.status(400).json({ error: 'Invalid branch / class combination.' });
  }

  // ── Transaction: create student + parent ──────
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Upsert parent user (match by phone, create if not found)
    let parentId;
    const existing = await client.query(
      'SELECT user_id FROM users WHERE phone = $1 AND role = $2',
      [normPhone, 'parent']
    );

    if (existing.rowCount > 0) {
      parentId = existing.rows[0].user_id;
      // Update name in case it changed
      await client.query(
        'UPDATE users SET name = $1, branch_id = $2, updated_at = NOW() WHERE user_id = $3',
        [parent_name, branch_id, parentId]
      );
    } else {
      const newParent = await client.query(
        `INSERT INTO users (name, phone, role, branch_id, is_active, created_at, updated_at)
         VALUES ($1, $2, 'parent', $3, true, NOW(), NOW())
         RETURNING user_id`,
        [parent_name, normPhone, branch_id]
      );
      parentId = newParent.rows[0].user_id;
    }

    // 2. Create student
    const admDate = admission_date && admission_date.trim() ? admission_date : new Date().toISOString().split('T')[0];
    const newStudent = await client.query(
      `INSERT INTO students
         (name, dob, branch_id, class_id, admission_date, emergency_contact, is_active, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, true, NOW(), NOW())
       RETURNING student_id`,
      [student_name.trim(), date_of_birth, branch_id, class_id, admDate, normEmerg]
    );
    const studentId = newStudent.rows[0].student_id;

    // 3. Link parent ↔ student
    await client.query(
      'INSERT INTO student_parents (student_id, parent_id) VALUES ($1, $2)',
      [studentId, parentId]
    );

    await client.query('COMMIT');

    return res.status(201).json({
      success: true,
      message: 'Student enrolled successfully.',
      student_id: studentId,
      parent_id: parentId,
      phone_stored: normPhone
    });

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[public/enroll] error:', err);
    return res.status(500).json({ error: 'Enrollment failed. Please try again.' });
  } finally {
    client.release();
  }
});

module.exports = router;
