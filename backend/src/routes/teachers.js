const express = require('express');
const router = express.Router();
const pool = require('../db/db');
const verifyToken = require('../middleware/authVerify');
const requireRole = require('../middleware/roleCheck');

// GET all teachers in a branch
router.get('/', verifyToken, requireRole(['superadmin', 'branchadmin']), async (req, res) => {
  try {
    const { branch_id, role } = req.user;
    const targetBranch = role === 'superadmin' ? req.query.branch_id : branch_id;

    if (!targetBranch) {
      return res.status(400).json({ error: 'branch_id required' });
    }

    const result = await pool.query(
      `SELECT user_id, name, email, phone, is_active 
       FROM users 
       WHERE role = 'teacher' AND branch_id = $1
       ORDER BY name`,
      [targetBranch]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST create a teacher
router.post('/', verifyToken, requireRole(['superadmin', 'branchadmin']), async (req, res) => {
  try {
    const { branch_id, role } = req.user;
    const { name, email, password, phone, class_id, target_branch_id } = req.body;

    const assignedBranch = role === 'superadmin' ? target_branch_id : branch_id;

    if (!name || !email || !password || !assignedBranch) {
      return res.status(400).json({ error: 'name, email, password, and branch_id are required' });
    }

    const existing = await pool.query('SELECT user_id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Email already in use' });
    }

    // Create Firebase user
    const admin = require('firebase-admin');
    const firebaseUser = await admin.auth().createUser({
      email, password, displayName: name,
    });

    const result = await pool.query(
      `INSERT INTO users (name, email, phone, role, branch_id, firebase_uid, class_id, is_active)
       VALUES ($1, $2, $3, 'teacher', $4, $5, $6, true)
       RETURNING user_id, name, email, role, branch_id, class_id`,
      [name, email, phone || null, assignedBranch, firebaseUser.uid, class_id || null]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    if (err.code === 'auth/email-already-exists')
      return res.status(409).json({ error: 'Email already exists in Firebase' });
    res.status(500).json({ error: 'Server error' });
  }
});

// PUT update a teacher
router.put('/:id', verifyToken, requireRole(['superadmin', 'branchadmin']), async (req, res) => {
  try {
    const { branch_id, role } = req.user;
    const { name, phone, is_active } = req.body;

    const teacher = await pool.query(
      'SELECT * FROM users WHERE user_id = $1 AND role = $2',
      [req.params.id, 'teacher']
    );

    if (teacher.rows.length === 0) {
      return res.status(404).json({ error: 'Teacher not found' });
    }

    if (role === 'branchadmin' && teacher.rows[0].branch_id !== branch_id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const existingTeacher = teacher.rows[0];
    const result = await pool.query(
      `UPDATE users SET name = COALESCE($1, name), phone = COALESCE($2, phone), is_active = COALESCE($3, is_active), updated_at = NOW()
       WHERE user_id = $4
       RETURNING user_id, name, email, phone, is_active`,
      [name ?? existingTeacher.name, phone ?? existingTeacher.phone,
       is_active ?? existingTeacher.is_active, req.params.id]
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE remove a teacher (soft delete)
router.delete('/:id', verifyToken, requireRole(['superadmin', 'branchadmin']), async (req, res) => {
  try {
    const { branch_id, role } = req.user;

    const teacher = await pool.query(
      'SELECT * FROM users WHERE user_id = $1 AND role = $2',
      [req.params.id, 'teacher']
    );

    if (teacher.rows.length === 0) {
      return res.status(404).json({ error: 'Teacher not found' });
    }

    if (role === 'branchadmin' && teacher.rows[0].branch_id !== branch_id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    await pool.query(
      'UPDATE users SET is_active = false, updated_at = NOW() WHERE user_id = $1',
      [req.params.id]
    );

    res.json({ message: 'Teacher deactivated successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE permanently remove a teacher
router.delete('/:id/permanent', verifyToken, requireRole(['superadmin', 'branchadmin']), async (req, res) => {
  try {
    const { branch_id, role } = req.user;

    const teacher = await pool.query(
      'SELECT * FROM users WHERE user_id = $1 AND role = $2',
      [req.params.id, 'teacher']
    );

    if (teacher.rows.length === 0) {
      return res.status(404).json({ error: 'Teacher not found' });
    }

    if (role === 'branchadmin' && teacher.rows[0].branch_id !== branch_id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Delete from Firebase if they have a uid
    if (teacher.rows[0].firebase_uid) {
      try {
        const admin = require('firebase-admin');
        await admin.auth().deleteUser(teacher.rows[0].firebase_uid);
      } catch (_) {}
    }

    // Delete from database
    await pool.query('DELETE FROM users WHERE user_id = $1', [req.params.id]);

    res.json({ message: 'Teacher permanently deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
