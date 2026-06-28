const express     = require('express');
const router      = express.Router();
const pool        = require('../db/db');
const admin       = require('firebase-admin');
const verifyToken = require('../middleware/authVerify');
const requireRole = require('../middleware/roleCheck');

// ─────────────────────────────────────────
// GET all branches with stats
// ─────────────────────────────────────────
router.get('/branches', verifyToken, requireRole(['superadmin']), async (req, res) => {
  try {
    const result = await pool.query(`
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
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─────────────────────────────────────────
// GET single branch detail
// ─────────────────────────────────────────
router.get('/branches/:id', verifyToken, requireRole(['superadmin']), async (req, res) => {
  try {
    const [branch, teachers, students, admins] = await Promise.all([
      pool.query('SELECT * FROM branches WHERE branch_id = $1', [req.params.id]),
      pool.query(
        `SELECT user_id, name, email, phone, is_active FROM users
         WHERE branch_id = $1 AND role = 'teacher' ORDER BY name`,
        [req.params.id]
      ),
      pool.query(
        `SELECT s.student_id, s.name, c.class_name FROM students s
         LEFT JOIN classes c ON s.class_id = c.class_id
         WHERE s.branch_id = $1 ORDER BY s.name`,
        [req.params.id]
      ),
      pool.query(
        `SELECT user_id, name, email, is_active FROM users
         WHERE branch_id = $1 AND role = 'branchadmin' ORDER BY name`,
        [req.params.id]
      ),
    ]);

    if (branch.rows.length === 0)
      return res.status(404).json({ error: 'Branch not found' });

    res.json({
      branch:   branch.rows[0],
      admins:   admins.rows,
      teachers: teachers.rows,
      students: students.rows,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─────────────────────────────────────────
// POST create branch admin
// ─────────────────────────────────────────
router.post('/branches/:id/admins', verifyToken, requireRole(['superadmin']), async (req, res) => {
  try {
    const { name, email, password, phone } = req.body;
    const branchId = req.params.id;

    if (!name || !email || !password)
      return res.status(400).json({ error: 'name, email, password required' });

    // Create in Firebase
    const firebaseUser = await admin.auth().createUser({
      email, password, displayName: name,
    });

    // Create in DB
    const result = await pool.query(
      `INSERT INTO users (name, email, phone, role, branch_id, firebase_uid, is_active)
       VALUES ($1, $2, $3, 'branchadmin', $4, $5, true) RETURNING *`,
      [name, email, phone || null, branchId, firebaseUser.uid]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    if (err.code === 'auth/email-already-exists')
      return res.status(400).json({ error: 'Email already in use' });
    res.status(500).json({ error: 'Server error' });
  }
});

// ─────────────────────────────────────────
// POST create branch
// ─────────────────────────────────────────
router.post('/branches', verifyToken, requireRole(['superadmin']), async (req, res) => {
  try {
    const { name, code } = req.body;
    if (!name || !code)
      return res.status(400).json({ error: 'name and code required' });

    const result = await pool.query(
      `INSERT INTO branches (name, code) VALUES ($1, $2) RETURNING *`,
      [name, code.toUpperCase()]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505')
      return res.status(400).json({ error: 'Branch code already exists' });
    res.status(500).json({ error: 'Server error' });
  }
});

// ─────────────────────────────────────────
// PUT toggle user active/inactive
// ─────────────────────────────────────────
router.put('/users/:id/toggle', verifyToken, requireRole(['superadmin']), async (req, res) => {
  try {
    const existing = await pool.query(
      'SELECT * FROM users WHERE user_id = $1', [req.params.id]);
    if (existing.rows.length === 0)
      return res.status(404).json({ error: 'User not found' });

    const user       = existing.rows[0];
    const newStatus  = !user.is_active;

    // Disable/enable in Firebase too
    await admin.auth().updateUser(user.firebase_uid, { disabled: !newStatus });

    const result = await pool.query(
      `UPDATE users SET is_active = $1 WHERE user_id = $2 RETURNING *`,
      [newStatus, req.params.id]
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─────────────────────────────────────────
// GET all super admins
// ─────────────────────────────────────────
router.get('/superadmins', verifyToken, requireRole(['superadmin']), async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT user_id, name, email, is_active, created_at
       FROM users WHERE role = 'superadmin' ORDER BY name`
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

// ─────────────────────────────────────────
// GET global stats (across all branches)
// ─────────────────────────────────────────
router.get('/stats', verifyToken, requireRole(['superadmin']), async (req, res) => {
  try {
    const [students, teachers, parents, branches, pendingLeaves, todayAtt] =
      await Promise.all([
        pool.query(`SELECT COUNT(*) FROM students`),
        pool.query(`SELECT COUNT(*) FROM users WHERE role = 'teacher' AND is_active = true`),
        pool.query(`SELECT COUNT(*) FROM users WHERE role = 'parent'  AND is_active = true`),
        pool.query(`SELECT COUNT(*) FROM branches`),
        pool.query(`SELECT COUNT(*) FROM leave_requests WHERE status = 'pending'`),
        pool.query(`
          SELECT
            COUNT(*) FILTER (WHERE status = 'present')  as present,
            COUNT(*) FILTER (WHERE status = 'absent')   as absent,
            COUNT(*) FILTER (WHERE status = 'on_leave') as on_leave
          FROM attendance WHERE date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Kolkata')::date
        `),
      ]);

    res.json({
      total_students:  parseInt(students.rows[0].count),
      total_teachers:  parseInt(teachers.rows[0].count),
      total_parents:   parseInt(parents.rows[0].count),
      total_branches:  parseInt(branches.rows[0].count),
      pending_leaves:  parseInt(pendingLeaves.rows[0].count),
      today_present:   parseInt(todayAtt.rows[0].present  || 0),
      today_absent:    parseInt(todayAtt.rows[0].absent   || 0),
      today_on_leave:  parseInt(todayAtt.rows[0].on_leave || 0),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
