const express = require('express');
const router = express.Router();
const pool = require('../db/db');
const verifyToken = require('../middleware/authVerify');
const requireRole = require('../middleware/roleCheck');
const { notifyParentsOfStudent } = require('../utils/notify');

// ─────────────────────────────────────────
// GET attendance for a class on a date
// ─────────────────────────────────────────
router.get('/class', verifyToken, requireRole(['superadmin', 'branchadmin', 'teacher']), async (req, res) => {
  try {
    const { class_id, date } = req.query;
    const { branch_id, role } = req.user;

    if (!class_id || !date) {
      return res.status(400).json({ error: 'class_id and date are required' });
    }

    if (role !== 'superadmin') {
      const cls = await pool.query(
        'SELECT * FROM classes WHERE class_id = $1 AND branch_id = $2',
        [class_id, branch_id]
      );
      if (cls.rows.length === 0) return res.status(403).json({ error: 'Forbidden' });
    }

    const result = await pool.query(
      `SELECT s.student_id, s.name, s.photo_url,
              a.attendance_id, a.status, a.marked_by
       FROM students s
       LEFT JOIN attendance a
         ON a.student_id = s.student_id AND a.date = $1
       WHERE s.class_id = $2 AND s.is_active = true
       ORDER BY s.name`,
      [date, class_id]
    );

    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─────────────────────────────────────────
// GET attendance for a single student (calendar / parent view)
// ─────────────────────────────────────────
router.get('/student/:student_id', verifyToken, requireRole(['superadmin', 'branchadmin', 'teacher', 'parent']), async (req, res) => {
  try {
    const { role, user_id, branch_id } = req.user;
    const { student_id } = req.params;
    const { month, year } = req.query;

    if (role === 'parent') {
      const link = await pool.query(
        'SELECT * FROM student_parents WHERE student_id = $1 AND parent_id = $2',
        [student_id, user_id]
      );
      if (link.rows.length === 0) return res.status(403).json({ error: 'Forbidden' });
    }

    if (role !== 'superadmin') {
      const student = await pool.query(
        'SELECT branch_id FROM students WHERE student_id = $1',
        [student_id]
      );
      if (student.rows[0]?.branch_id !== branch_id) {
        return res.status(403).json({ error: 'Forbidden' });
      }
    }

    let query = `SELECT date, status FROM attendance WHERE student_id = $1`;
    const params = [student_id];

    if (month && year) {
      query += ` AND EXTRACT(MONTH FROM date) = $2 AND EXTRACT(YEAR FROM date) = $3`;
      params.push(month, year);
    }

    query += ` ORDER BY date`;

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─────────────────────────────────────────
// POST mark attendance (single or bulk)
// ─────────────────────────────────────────
router.post('/mark', verifyToken, requireRole(['superadmin', 'branchadmin', 'teacher']), async (req, res) => {
  try {
    const { branch_id, role, user_id } = req.user;
    const { records, date, class_id } = req.body;

    if (!records || !date || !class_id) {
      return res.status(400).json({ error: 'records, date, and class_id are required' });
    }

    const now = new Date();
    const markDate = new Date(date);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Teachers cannot edit past attendance
    if (markDate < today && role === 'teacher') {
      return res.status(403).json({ error: 'Teachers cannot edit past attendance' });
    }

    // Lock attendance after 8pm IST for teachers
    const lockHour = 20;
    const nowIST = new Date(now.getTime() + (5.5 * 60 * 60 * 1000)); // UTC + 5:30
    if (markDate.toDateString() === now.toDateString() && nowIST.getUTCHours() >= lockHour && role === 'teacher') {
      return res.status(403).json({ error: 'Attendance is locked after 8:00 PM IST' });
    }

    if (role !== 'superadmin') {
      const cls = await pool.query(
        'SELECT * FROM classes WHERE class_id = $1 AND branch_id = $2',
        [class_id, branch_id]
      );
      if (cls.rows.length === 0) return res.status(403).json({ error: 'Forbidden' });
    }

    const results = [];
    for (const record of records) {
      const r = await pool.query(
        `INSERT INTO attendance (student_id, date, status, marked_by, branch_id)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (student_id, date)
         DO UPDATE SET status = $3, marked_by = $4, updated_at = NOW()
         RETURNING *`,
        [record.student_id, date, record.status, user_id, branch_id]
      );
      results.push(r.rows[0]);
    }

    // Log teacher action
    await pool.query(
      `INSERT INTO teacher_logs (user_id, branch_id, action, meta, timestamp)
       VALUES ($1, $2, 'mark_attendance', $3, NOW())`,
      [user_id, branch_id, JSON.stringify({ class_id, date, count: records.length })]
    );

    // Send absent alerts to parents (non-blocking)
    for (const record of records) {
      if (record.status === 'absent') {
        const student = await pool.query(
          'SELECT name FROM students WHERE student_id = $1',
          [record.student_id]
        );
        const studentName = student.rows[0]?.name || 'Your child';
        notifyParentsOfStudent(
          record.student_id,
          'Attendance Alert',
          `${studentName} has been marked absent today.`
        );
      }
    }

    res.json({ message: 'Attendance marked successfully', records: results });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─────────────────────────────────────────
// PUT edit a single attendance record (admin only)
// ─────────────────────────────────────────
router.put('/:attendance_id', verifyToken, requireRole(['superadmin', 'branchadmin']), async (req, res) => {
  try {
    const { branch_id, role } = req.user;
    const { status } = req.body;

    const existing = await pool.query(
      'SELECT * FROM attendance WHERE attendance_id = $1',
      [req.params.attendance_id]
    );

    if (existing.rows.length === 0) return res.status(404).json({ error: 'Record not found' });

    if (role === 'branchadmin' && existing.rows[0].branch_id !== branch_id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const result = await pool.query(
      `UPDATE attendance SET status = $1, updated_at = NOW()
       WHERE attendance_id = $2 RETURNING *`,
      [status, req.params.attendance_id]
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─────────────────────────────────────────
// GET monthly attendance report for a student
// ─────────────────────────────────────────
router.get('/report/student/:student_id', verifyToken, requireRole(['superadmin', 'branchadmin', 'teacher', 'parent']), async (req, res) => {
  try {
    const { role, user_id, branch_id } = req.user;
    const { student_id } = req.params;
    const { month, year } = req.query;

    if (!month || !year) {
      return res.status(400).json({ error: 'month and year are required' });
    }

    if (role === 'parent') {
      const link = await pool.query(
        'SELECT * FROM student_parents WHERE student_id = $1 AND parent_id = $2',
        [student_id, user_id]
      );
      if (link.rows.length === 0) return res.status(403).json({ error: 'Forbidden' });
    }

    const result = await pool.query(
      `SELECT
         COUNT(*) FILTER (WHERE status = 'present') AS days_present,
         COUNT(*) FILTER (WHERE status = 'absent') AS days_absent,
         COUNT(*) FILTER (WHERE status = 'on_leave') AS days_on_leave,
         COUNT(*) AS total_marked,
         ROUND(
           COUNT(*) FILTER (WHERE status = 'present')::numeric /
           NULLIF(COUNT(*), 0) * 100, 1
         ) AS attendance_percentage
       FROM attendance
       WHERE student_id = $1
         AND EXTRACT(MONTH FROM date) = $2
         AND EXTRACT(YEAR FROM date) = $3`,
      [student_id, month, year]
    );

    const daily = await pool.query(
      `SELECT date, status FROM attendance
       WHERE student_id = $1
         AND EXTRACT(MONTH FROM date) = $2
         AND EXTRACT(YEAR FROM date) = $3
       ORDER BY date`,
      [student_id, month, year]
    );

    res.json({ summary: result.rows[0], daily: daily.rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─────────────────────────────────────────
// GET branch-level attendance overview (admin)
// ─────────────────────────────────────────
router.get('/overview/branch', verifyToken, requireRole(['superadmin', 'branchadmin']), async (req, res) => {
  try {
    const { branch_id, role } = req.user;
    const { date, target_branch_id } = req.query;
    const targetBranch = role === 'superadmin' ? target_branch_id : branch_id;

    if (!date || !targetBranch) {
      return res.status(400).json({ error: 'date and branch_id are required' });
    }

    const result = await pool.query(
      `SELECT
         c.class_name,
         COUNT(s.student_id) AS total_students,
         COUNT(a.attendance_id) FILTER (WHERE a.status = 'present') AS present,
         COUNT(a.attendance_id) FILTER (WHERE a.status = 'absent') AS absent,
         COUNT(a.attendance_id) FILTER (WHERE a.status = 'on_leave') AS on_leave,
         COUNT(s.student_id) - COUNT(a.attendance_id) AS not_marked
       FROM classes c
       LEFT JOIN students s ON s.class_id = c.class_id AND s.is_active = true
       LEFT JOIN attendance a ON a.student_id = s.student_id AND a.date = $1
       WHERE c.branch_id = $2
       GROUP BY c.class_name
       ORDER BY c.class_name`,
      [date, targetBranch]
    );

    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
