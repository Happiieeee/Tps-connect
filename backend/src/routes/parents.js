const express = require('express');
const router = express.Router();
const pool = require('../db/db');
const verifyToken = require('../middleware/authVerify');
const requireRole = require('../middleware/roleCheck');
const admin = require('firebase-admin');

// POST create a parent account and link to student
router.post('/', verifyToken, requireRole(['superadmin', 'branchadmin']), async (req, res) => {
  try {
    const { branch_id, role } = req.user;
    const { name, email, password, phone, student_id, target_branch_id } = req.body;

    if (!name || !email || !student_id) {
      return res.status(400).json({ error: 'name, email, and student_id are required' });
    }

    const student = await pool.query('SELECT * FROM students WHERE student_id = $1', [student_id]);
    if (student.rows.length === 0) return res.status(404).json({ error: 'Student not found' });

    const assignedBranch = role === 'superadmin' ? target_branch_id : branch_id;
    if (role === 'branchadmin' && student.rows[0].branch_id !== branch_id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    let parentUser = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    let parentId;

    if (parentUser.rows.length === 0) {
      const userPassword = password || ('TPS@' + Math.random().toString(36).slice(2, 10));
      const firebaseUser = await admin.auth().createUser({
        email,
        password: userPassword,
        displayName: name,
      });

      const newParent = await pool.query(
        `INSERT INTO users (name, email, phone, role, branch_id, firebase_uid, is_active)
         VALUES ($1, $2, $3, 'parent', $4, $5, true)
         RETURNING user_id`,
        [name, email, phone || null, assignedBranch, firebaseUser.uid]
      );
      parentId = newParent.rows[0].user_id;

      // Send password reset so parent sets their own password
      await admin.auth().generatePasswordResetLink(email);
    } else {
      // Only allow re-using existing accounts with role='parent'
      if (parentUser.rows[0].role !== 'parent') {
        return res.status(409).json({ error: 'This email belongs to a non-parent account and cannot be linked as a parent.' });
      }
      parentId = parentUser.rows[0].user_id;
    }

    const existingLinks = await pool.query(
      'SELECT * FROM student_parents WHERE student_id = $1',
      [student_id]
    );

    if (existingLinks.rows.length >= 2) {
      return res.status(400).json({ error: 'Student already has 2 linked parents' });
    }

    const alreadyLinked = existingLinks.rows.find(r => r.parent_id === parentId);
    if (alreadyLinked) {
      return res.status(409).json({ error: 'Parent already linked to this student' });
    }

    await pool.query(
      'INSERT INTO student_parents (student_id, parent_id) VALUES ($1, $2)',
      [student_id, parentId]
    );

    res.status(201).json({ message: 'Parent account created and linked successfully', parent_id: parentId });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET children linked to the logged-in parent
router.get('/children', verifyToken, requireRole(['parent']), async (req, res) => {
  try {
    const { user_id } = req.user;
    const result = await pool.query(
      `SELECT s.student_id, s.name, s.dob, s.photo_url, s.class_id,
              s.admission_date, s.emergency_contact, s.medical_notes,
              c.class_name, b.name as branch_name
       FROM students s
       JOIN student_parents sp ON s.student_id = sp.student_id
       LEFT JOIN classes c ON s.class_id = c.class_id
       LEFT JOIN branches b ON s.branch_id = b.branch_id
       WHERE sp.parent_id = $1
       ORDER BY s.name`,
      [user_id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET parents linked to a student
router.get('/student/:student_id', verifyToken, requireRole(['superadmin', 'branchadmin']), async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.user_id, u.name, u.email, u.phone
       FROM users u
       JOIN student_parents sp ON u.user_id = sp.parent_id
       WHERE sp.student_id = $1`,
      [req.params.student_id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
