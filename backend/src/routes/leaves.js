const express     = require('express');
const router      = express.Router();
const pool        = require('../db/db');
const verifyToken = require('../middleware/authVerify');
const requireRole = require('../middleware/roleCheck');
const { sendNotification } = require('../utils/notify');

// GET leaves
router.get('/', verifyToken,
  requireRole(['superadmin', 'branchadmin', 'teacher', 'parent']),
  async (req, res) => {
    try {
      const { role, user_id, branch_id } = req.user;
      const { status, student_id } = req.query;

      let query, params;

      if (role === 'parent') {
        query = `
          SELECT lr.*, s.name as student_name, u.name as reviewer_name
          FROM leave_requests lr
          JOIN students s ON lr.student_id = s.student_id
          LEFT JOIN users u ON lr.reviewed_by = u.user_id
          WHERE lr.parent_id = $1
          ${status ? 'AND lr.status = $2' : ''}
          ORDER BY lr.created_at DESC LIMIT 50
        `;
        params = [user_id];
        if (status) params.push(status);
      } else {
        const targetBranch = role === 'superadmin' ? req.query.branch_id : branch_id;
        query = `
          SELECT lr.*, s.name as student_name,
                 p.name as parent_name, u.name as reviewer_name
          FROM leave_requests lr
          JOIN students s ON lr.student_id = s.student_id
          JOIN users p ON lr.parent_id = p.user_id
          LEFT JOIN users u ON lr.reviewed_by = u.user_id
          WHERE lr.branch_id = $1
          ${status ? 'AND lr.status = $2' : ''}
          ${student_id ? `AND lr.student_id = $${status ? 3 : 2}` : ''}
          ORDER BY lr.created_at DESC LIMIT 100
        `;
        params = [targetBranch];
        if (status) params.push(status);
        if (student_id) params.push(student_id);
      }

      const result = await pool.query(query, params);
      res.json(result.rows);
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Server error' });
    }
  }
);

// POST create leave (parent only)
router.post('/', verifyToken, requireRole(['parent']), async (req, res) => {
  try {
    const { user_id } = req.user;
    const { student_id, from_date, to_date, reason } = req.body;

    if (!student_id || !from_date || !to_date)
      return res.status(400).json({ error: 'student_id, from_date, to_date required' });

    // Verify parent owns this student
    const ownership = await pool.query(
      `SELECT s.branch_id FROM students s
       JOIN student_parents sp ON s.student_id = sp.student_id
       WHERE sp.student_id = $1 AND sp.parent_id = $2`,
      [student_id, user_id]
    );
    if (ownership.rows.length === 0)
      return res.status(403).json({ error: 'Forbidden' });

    const branchId = ownership.rows[0].branch_id;

    const result = await pool.query(
      `INSERT INTO leave_requests
         (student_id, parent_id, branch_id, from_date, to_date, reason)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [student_id, user_id, branchId, from_date, to_date, reason || '']
    );

    // Notify branch admins immediately
    const admins = await pool.query(
      `SELECT firebase_uid FROM users
       WHERE role = 'branchadmin' AND branch_id = $1`,
      [branchId]
    );
    for (const admin of admins.rows) {
      await sendNotification(
        admin.firebase_uid,
        '📋 New Leave Request',
        'A parent has submitted a leave request'
      );
    }

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PUT approve or reject (admin only)
router.put('/:id', verifyToken,
  requireRole(['branchadmin', 'superadmin']),
  async (req, res) => {
    try {
      const { user_id, branch_id, role } = req.user;
      const { status } = req.body;

      if (!['approved', 'rejected'].includes(status))
        return res.status(400).json({ error: 'status must be approved or rejected' });

      const existing = await pool.query(
        'SELECT * FROM leave_requests WHERE leave_id = $1', [req.params.id]
      );
      if (existing.rows.length === 0)
        return res.status(404).json({ error: 'Leave not found' });

      const leave = existing.rows[0];

      if (role === 'branchadmin' && leave.branch_id !== branch_id)
        return res.status(403).json({ error: 'Forbidden' });

      const result = await pool.query(
        `UPDATE leave_requests
         SET status=$1, reviewed_by=$2, reviewed_at=NOW()
         WHERE leave_id=$3 RETURNING *`,
        [status, user_id, req.params.id]
      );

      // Notify BOTH parents
      const parents = await pool.query(
        `SELECT DISTINCT u.firebase_uid FROM users u
         JOIN student_parents sp ON u.user_id = sp.parent_id
         WHERE sp.student_id = $1`,
        [leave.student_id]
      );
      const label = status === 'approved' ? '✅ Leave Approved' : '❌ Leave Rejected';
      for (const p of parents.rows) {
        await sendNotification(p.firebase_uid, label,
          `Your leave request has been ${status}`);
      }

      res.json(result.rows[0]);
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Server error' });
    }
  }
);

module.exports = router;
