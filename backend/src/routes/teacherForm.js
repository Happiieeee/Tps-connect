const express = require('express');
const router = express.Router();
const pool = require('../db/db');

/**
 * Normalise any phone format to +91XXXXXXXXXX
 * Accepts: 9876543210 / 09876543210 / +919876543210 / 91 98765 43210 etc.
 */
function normalisePhone(raw) {
  if (!raw) return null;
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
 * Middleware to verify the teacher passcode.
 * Passed via 'X-Teacher-Passcode' header or 'passcode' query/body parameter.
 */
function verifyTeacherPasscode(req, res, next) {
  const code = req.headers['x-teacher-passcode'] || req.query.passcode || req.body.passcode;
  const correctCode = process.env.TEACHER_FORM_PASSCODE || 'TPS_TEACHER_2026';
  
  if (!code || code !== correctCode) {
    return res.status(401).json({ error: 'Access denied. Invalid or missing passcode.' });
  }
  next();
}

/**
 * GET /teacher-form/branches-classes
 * Fetches all branches and their respective classes.
 */
router.get('/branches-classes', verifyTeacherPasscode, async (req, res) => {
  try {
    const branchesRes = await pool.query('SELECT branch_id, name, code FROM branches ORDER BY name');
    const classesRes = await pool.query('SELECT class_id, class_name, branch_id FROM classes ORDER BY class_name');
    
    // Group classes under branches
    const branches = branchesRes.rows.map(b => ({
      ...b,
      classes: classesRes.rows.filter(c => c.branch_id === b.branch_id)
    }));

    res.json({ success: true, branches });
  } catch (err) {
    console.error('[teacherForm/branches-classes] error:', err);
    res.status(500).json({ error: 'Failed to fetch branches and classes.' });
  }
});

/**
 * GET /teacher-form/students
 * Fetches all active students across all branches along with their branch, class, and parent details.
 */
router.get('/students', verifyTeacherPasscode, async (req, res) => {
  try {
    const query = `
      SELECT DISTINCT ON (s.student_id)
             s.student_id, s.name AS student_name, s.dob, s.admission_date, s.emergency_contact, s.is_active,
             s.branch_id, s.class_id,
             b.name AS branch_name,
             c.class_name,
             p.user_id AS parent_id, p.name AS parent_name, p.phone AS parent_phone
      FROM students s
      JOIN branches b ON s.branch_id = b.branch_id
      JOIN classes c ON s.class_id = c.class_id
      LEFT JOIN student_parents sp ON s.student_id = sp.student_id
      LEFT JOIN users p ON sp.parent_id = p.user_id AND p.role = 'parent'
      WHERE s.is_active = true
      ORDER BY s.student_id, b.name, c.class_name, s.name
    `;
    const result = await pool.query(query);
    res.json({ success: true, students: result.rows });
  } catch (err) {
    console.error('[teacherForm/students] error:', err);
    res.status(500).json({ error: 'Failed to fetch students list.' });
  }
});

/**
 * POST /teacher-form/student
 * Body (JSON):
 *   student_name, branch_id, class_id, date_of_birth,
 *   admission_date, parent_name, phone, emergency_contact
 */
router.post('/student', verifyTeacherPasscode, async (req, res) => {
  const {
    student_name, branch_id, class_id, date_of_birth,
    admission_date, parent_name, phone, emergency_contact
  } = req.body;

  // ── Validation ────────────────────────────────
  const missing = [];
  if (!student_name)    missing.push('student_name');
  if (!branch_id)       missing.push('branch_id');
  if (!class_id)        missing.push('class_id');
  if (!date_of_birth)   missing.push('date_of_birth');
  if (!parent_name)     missing.push('parent_name');
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

  // ── Validate student duplication ──────────────
  const dupCheck = await pool.query(
    `SELECT s.student_id, sp.parent_id 
     FROM students s
     LEFT JOIN student_parents sp ON s.student_id = sp.student_id
     WHERE LOWER(s.name) = LOWER($1) AND s.dob = $2 AND s.branch_id = $3 AND s.class_id = $4 AND s.is_active = true`,
    [student_name.trim(), date_of_birth, branch_id, class_id]
  );
  if (dupCheck.rowCount > 0) {
    return res.status(409).json({
      exists: true,
      student_id: dupCheck.rows[0].student_id,
      parent_id: dupCheck.rows[0].parent_id,
      error: 'Student already exists in this class.'
    });
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
      // Update parent name and branch in case it changed
      await client.query(
        'UPDATE users SET name = $1, branch_id = $2, updated_at = NOW() WHERE user_id = $3',
        [parent_name.trim(), branch_id, parentId]
      );
    } else {
      const newParent = await client.query(
        `INSERT INTO users (name, phone, role, branch_id, is_active, created_at, updated_at)
         VALUES ($1, $2, 'parent', $3, true, NOW(), NOW())
         RETURNING user_id`,
        [parent_name.trim(), normPhone, branch_id]
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
    console.error('[teacherForm/student] create error:', err);
    return res.status(500).json({ error: 'Failed to add student. Please try again.' });
  } finally {
    client.release();
  }
});

/**
 * PUT /teacher-form/student/:id
 * Body (JSON):
 *   student_name, branch_id, class_id, date_of_birth,
 *   admission_date, parent_name, phone, emergency_contact, parent_id
 */
router.put('/student/:id', verifyTeacherPasscode, async (req, res) => {
  const studentId = req.params.id;
  const {
    student_name, branch_id, class_id, date_of_birth,
    admission_date, parent_name, phone, emergency_contact, parent_id
  } = req.body;

  // ── Validation ────────────────────────────────
  const missing = [];
  if (!student_name)    missing.push('student_name');
  if (!branch_id)       missing.push('branch_id');
  if (!class_id)        missing.push('class_id');
  if (!date_of_birth)   missing.push('date_of_birth');
  if (!parent_name)     missing.push('parent_name');
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

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Update Student Profile
    const admDate = admission_date && admission_date.trim() ? admission_date : new Date().toISOString().split('T')[0];
    const studentUpdate = await client.query(
      `UPDATE students 
       SET name = $1, dob = $2, branch_id = $3, class_id = $4, admission_date = $5, emergency_contact = $6, updated_at = NOW()
       WHERE student_id = $7
       RETURNING *`,
      [student_name.trim(), date_of_birth, branch_id, class_id, admDate, normEmerg, studentId]
    );

    if (studentUpdate.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Student not found.' });
    }

    // 2. Manage Parent Details
    let resolvedParentId = parent_id;

    // Check if another parent exists with the new phone number
    const existingParent = await client.query(
      'SELECT user_id FROM users WHERE phone = $1 AND role = $2',
      [normPhone, 'parent']
    );

    if (existingParent.rowCount > 0) {
      // Parent with this phone already exists: link them
      resolvedParentId = existingParent.rows[0].user_id;
      // Update their details to make sure they match
      await client.query(
        'UPDATE users SET name = $1, branch_id = $2, updated_at = NOW() WHERE user_id = $3',
        [parent_name.trim(), branch_id, resolvedParentId]
      );
    } else if (resolvedParentId) {
      // Parent exists in parameters, let's update their phone/details directly
      await client.query(
        'UPDATE users SET name = $1, phone = $2, branch_id = $3, updated_at = NOW() WHERE user_id = $4 AND role = $5',
        [parent_name.trim(), normPhone, branch_id, resolvedParentId, 'parent']
      );
    } else {
      // Parent doesn't exist at all: create them
      const newParent = await client.query(
        `INSERT INTO users (name, phone, role, branch_id, is_active, created_at, updated_at)
         VALUES ($1, $2, 'parent', $3, true, NOW(), NOW())
         RETURNING user_id`,
        [parent_name.trim(), normPhone, branch_id]
      );
      resolvedParentId = newParent.rows[0].user_id;
    }

    // 3. Link Student and Parent
    // Only update/insert the specific parent link being edited.
    // If parent_id was provided, replace that specific link; otherwise add the new parent.
    if (parent_id && resolvedParentId !== parent_id) {
      // Replace the old parent link with the new resolved parent
      await client.query(
        'UPDATE student_parents SET parent_id = $1 WHERE student_id = $2 AND parent_id = $3',
        [resolvedParentId, studentId, parent_id]
      );
      // If the old link didn't exist, insert the new one
      const linkCheck = await client.query(
        'SELECT 1 FROM student_parents WHERE student_id = $1 AND parent_id = $2',
        [studentId, resolvedParentId]
      );
      if (linkCheck.rowCount === 0) {
        await client.query(
          'INSERT INTO student_parents (student_id, parent_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
          [studentId, resolvedParentId]
        );
      }
    } else {
      // Just ensure the link exists (upsert without removing co-parents)
      await client.query(
        'INSERT INTO student_parents (student_id, parent_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [studentId, resolvedParentId]
      );
    }

    await client.query('COMMIT');

    return res.json({
      success: true,
      message: 'Student and parent details updated successfully.',
      student_id: studentId,
      parent_id: resolvedParentId
    });

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[teacherForm/student] update error:', err);
    return res.status(500).json({ error: 'Failed to update student details.' });
  } finally {
    client.release();
  }
});

/**
 * DELETE /teacher-form/student/:id
 * Soft-deactivates a student profile (sets is_active = false).
 * Secured by verifyTeacherPasscode.
 */
router.delete('/student/:id', verifyTeacherPasscode, async (req, res) => {
  const studentId = req.params.id;

  try {
    const student = await pool.query('SELECT * FROM students WHERE student_id = $1', [studentId]);
    if (student.rows.length === 0) {
      return res.status(404).json({ error: 'Student not found.' });
    }

    await pool.query(
      'UPDATE students SET is_active = false, updated_at = NOW() WHERE student_id = $1',
      [studentId]
    );

    res.json({ success: true, message: 'Student profile deactivated successfully.' });
  } catch (err) {
    console.error('[teacherForm/student] delete error:', err);
    res.status(500).json({ error: 'Failed to delete student profile.' });
  }
});

module.exports = router;
