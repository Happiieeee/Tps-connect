const express     = require('express');
const router      = express.Router();
const pool        = require('../db/db');
const PDFDocument = require('pdfkit');
const verifyToken = require('../middleware/authVerify');
const requireRole = require('../middleware/roleCheck');

// GET /reports/attendance?student_id=&month=4&year=2026
router.get('/attendance', verifyToken,
  requireRole(['superadmin', 'branchadmin', 'teacher', 'parent']),
  async (req, res) => {
    try {
      const { student_id, month, year } = req.query;
      const { role, user_id } = req.user;

      if (!student_id || !month || !year)
        return res.status(400).json({ error: 'student_id, month, year required' });

      // Parent — verify ownership
      if (role === 'parent') {
        const check = await pool.query(
          `SELECT 1 FROM student_parents WHERE student_id=$1 AND parent_id=$2`,
          [student_id, user_id]
        );
        if (check.rows.length === 0)
          return res.status(403).json({ error: 'Forbidden' });
      }

      const studentRes = await pool.query(
        `SELECT s.name, c.class_name, b.name as branch_name
         FROM students s
         JOIN classes c ON s.class_id = c.class_id
         JOIN branches b ON s.branch_id = b.branch_id
         WHERE s.student_id = $1`,
        [student_id]
      );
      if (studentRes.rows.length === 0)
        return res.status(404).json({ error: 'Student not found' });

      const student = studentRes.rows[0];

      const attRes = await pool.query(
        `SELECT date, status FROM attendance
         WHERE student_id = $1
         AND EXTRACT(MONTH FROM date) = $2
         AND EXTRACT(YEAR  FROM date) = $3
         ORDER BY date`,
        [student_id, month, year]
      );

      const rows     = attRes.rows;
      const present  = rows.filter(r => r.status === 'present').length;
      const absent   = rows.filter(r => r.status === 'absent').length;
      const onLeave  = rows.filter(r => r.status === 'on_leave').length;
      const total    = rows.length;
      const pct      = total > 0 ? Math.round((present / total) * 100) : 0;
      const monthName = new Date(year, month - 1)
        .toLocaleString('default', { month: 'long' });

      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition',
        `attachment; filename="attendance_${student.name}_${monthName}_${year}.pdf"`);

      const doc = new PDFDocument({ margin: 50, size: 'A4' });
      doc.pipe(res);

      // Header
      doc.fontSize(22).fillColor('#1A73E8')
         .text('TPS - Attendance Report', { align: 'center' });
      doc.moveDown(0.3);
      doc.fontSize(13).fillColor('#5F6368')
         .text(`${monthName} ${year}`, { align: 'center' });
      doc.moveDown(1);
      doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#DADCE0').stroke();
      doc.moveDown(0.8);

      // Student info
      doc.fontSize(12).fillColor('#1F1F1F');
      doc.text(`Student:  ${student.name}`);
      doc.text(`Class:    ${student.class_name}`);
      doc.text(`Branch:   ${student.branch_name}`);
      doc.moveDown(1);

      // Summary boxes
      const boxY = doc.y;
      const boxes = [
        { label: 'Present',  value: present,  color: '#34A853' },
        { label: 'Absent',   value: absent,   color: '#EA4335' },
        { label: 'On Leave', value: onLeave,  color: '#F9AB00' },
        { label: 'Total',    value: total,    color: '#1A73E8' },
        { label: '%',        value: pct + '%',color: '#9334E6' },
      ];
      boxes.forEach((box, i) => {
        const x = 50 + i * 100;
        doc.rect(x, boxY, 88, 60).fillColor('#F8F9FA').fill();
        doc.fillColor(box.color).fontSize(22)
           .text(String(box.value), x, boxY + 8, { width: 88, align: 'center' });
        doc.fillColor('#5F6368').fontSize(10)
           .text(box.label, x, boxY + 36, { width: 88, align: 'center' });
      });

      doc.y = boxY + 80;
      doc.moveDown(1);

      // Daily table header
      doc.fontSize(13).fillColor('#1F1F1F').text('Daily Record', { underline: true });
      doc.moveDown(0.5);

      const colX = [50, 200, 370];
      doc.rect(50, doc.y, 495, 22).fillColor('#1A73E8').fill();
      doc.fillColor('#FFFFFF').fontSize(11);
      const hY = doc.y + 4;
      doc.text('Date',   colX[0] + 5, hY, { width: 140 });
      doc.text('Day',    colX[1] + 5, hY, { width: 160 });
      doc.text('Status', colX[2] + 5, hY, { width: 140 });
      doc.y = doc.y + 22;

      rows.forEach((row, i) => {
        const d    = new Date(row.date);
        const rowY = doc.y;
        doc.rect(50, rowY, 495, 18)
           .fillColor(i % 2 === 0 ? '#FFFFFF' : '#F8F9FA').fill();
        const sColor = row.status === 'present'  ? '#34A853'
                     : row.status === 'absent'   ? '#EA4335' : '#F9AB00';
        doc.fillColor('#1F1F1F').fontSize(10);
        doc.text(d.toLocaleDateString('en-IN'),  colX[0] + 5, rowY + 4, { width: 140 });
        doc.text(d.toLocaleDateString('en-IN', { weekday: 'long' }),
                 colX[1] + 5, rowY + 4, { width: 160 });
        doc.fillColor(sColor)
           .text(row.status.replace('_', ' ').toUpperCase(),
                 colX[2] + 5, rowY + 4, { width: 140 });
        doc.y = rowY + 18;
      });

      doc.moveDown(2);
      doc.fontSize(9).fillColor('#9AA0A6')
         .text(`Generated by TPS on ${new Date().toLocaleString('en-IN')}`,
               { align: 'center' });

      doc.end();
    } catch (err) {
      console.error(err);
      if (!res.headersSent)
        res.status(500).json({ error: 'Report generation failed' });
    }
  }
);

// GET /reports/branch-stats
router.get('/branch-stats', verifyToken,
  requireRole(['superadmin', 'branchadmin']),
  async (req, res) => {
    try {
      const { role, branch_id } = req.user;
      const targetBranch = role === 'superadmin' ? req.query.branch_id : branch_id;

      const [students, teachers, pendingLeaves, todayAtt] = await Promise.all([
        pool.query('SELECT COUNT(*) FROM students WHERE branch_id=$1', [targetBranch]),
        pool.query(`SELECT COUNT(*) FROM users WHERE role='teacher' AND branch_id=$1`, [targetBranch]),
        pool.query(`SELECT COUNT(*) FROM leave_requests WHERE branch_id=$1 AND status='pending'`, [targetBranch]),
        pool.query(
          `SELECT
             COUNT(*) FILTER (WHERE status='present')  as present,
             COUNT(*) FILTER (WHERE status='absent')   as absent,
             COUNT(*) FILTER (WHERE status='on_leave') as on_leave
           FROM attendance
           WHERE branch_id=$1 AND date=(CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Kolkata')::date`,
          [targetBranch]
        ),
      ]);

      res.json({
        total_students: parseInt(students.rows[0].count),
        total_teachers: parseInt(teachers.rows[0].count),
        pending_leaves: parseInt(pendingLeaves.rows[0].count),
        today_present:  parseInt(todayAtt.rows[0].present  || 0),
        today_absent:   parseInt(todayAtt.rows[0].absent   || 0),
        today_on_leave: parseInt(todayAtt.rows[0].on_leave || 0),
      });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Server error' });
    }
  }
);

module.exports = router;
