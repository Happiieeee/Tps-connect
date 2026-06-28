const express = require('express');
const router = express.Router();
const pool = require('../db/db');
const verifyToken = require('../middleware/authVerify');
const requireRole = require('../middleware/roleCheck');
const { notifyBranch, notifyAll } = require('../utils/notify');

// POST send a broadcast notification
router.post('/broadcast', verifyToken, requireRole(['superadmin', 'branchadmin']), async (req, res) => {
  try {
    const { role, user_id, branch_id } = req.user;
    const { title, body, target_branch_id, class_id } = req.body;

    if (!title || !body) {
      return res.status(400).json({ error: 'title and body are required' });
    }

    const assignedBranch = role === 'superadmin' ? (target_branch_id || null) : branch_id;

    // Save notification record
    await pool.query(
      `INSERT INTO notifications (target_role, branch_id, class_id, title, body, sent_by, sent_at)
       VALUES ('parent', $1, $2, $3, $4, $5, NOW())`,
      [assignedBranch, class_id || null, title, body, user_id]
    );

    // Send FCM
    if (role === 'superadmin' && !target_branch_id) {
      await notifyAll(title, body);
    } else {
      await notifyBranch(assignedBranch, class_id || null, title, body);
    }

    res.json({ message: 'Notification sent successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET notification history
router.get('/history', verifyToken, requireRole(['superadmin', 'branchadmin', 'parent']), async (req, res) => {
  try {
    const { role, user_id, branch_id } = req.user;

    let query;
    let params;

    if (role === 'parent') {
      query = `
        SELECT n.*, u.name as sent_by_name FROM notifications n
        LEFT JOIN users u ON n.sent_by = u.user_id
        WHERE (n.branch_id IN (
          SELECT DISTINCT s.branch_id FROM students s
          JOIN student_parents sp ON s.student_id = sp.student_id
          WHERE sp.parent_id = $1
        ) OR n.branch_id IS NULL)
        AND (n.class_id IN (
          SELECT DISTINCT s.class_id FROM students s
          JOIN student_parents sp ON s.student_id = sp.student_id
          WHERE sp.parent_id = $1
        ) OR n.class_id IS NULL)
        ORDER BY n.sent_at DESC
        LIMIT 50
      `;
      params = [user_id];
    } else {
      const targetBranch = role === 'superadmin' ? req.query.branch_id : branch_id;
      query = `
        SELECT n.*, u.name as sent_by_name FROM notifications n
        LEFT JOIN users u ON n.sent_by = u.user_id
        WHERE n.branch_id = $1 OR n.branch_id IS NULL
        ORDER BY n.sent_at DESC
        LIMIT 50
      `;
      params = [targetBranch];
    }

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
