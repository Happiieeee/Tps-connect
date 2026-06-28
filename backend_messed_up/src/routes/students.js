const express = require('express');
const router = express.Router();
const pool = require('../db/db');
const verifyToken = require('../middleware/authVerify');
const requireRole = require('../middleware/roleCheck');

// GET all students in a branch
router.get('/', verifyToken, requireRole(['superadmin', 'branchadmin', 'teacher']), async (req, res) => {
  try {
    const { branch_id, role } = req.user;
    const targetBranch = role === 'superadmin' ? req.query.branch_id : branch_id;
    const { class_id } = req.query;

    let query = `SELECT s.student_id, s.name, s.dob, s.photo_url, s.class_id,
              s.admission_date, s.emergency_contact, s.medical_notes,
              c.class_name
       FROM students s
       LEFT JOIN classes c ON s.class_id = c.class_id
       WHERE s.branch_id = $1 AND s.is_active = true`;
    const params = [targetBranch];

    if (class_id) {
      params.push(class_id);
      query += ` AND s.class_id = $${params.length}`;
    }

    query += ` ORDER BY s.name`;

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET single student profile
router.get('/:id', verifyToken, requireRole(['superadmin', 'branchadmin', 'teacher', 'parent']), async (req, res) => {
  try {
    const { branch_id, role, user_id } = req.user;

    // Parent can only view their own child
    if (role === 'parent') {
      const link = await pool.query(
        'SELECT * FROM student_parents WHERE student_id = $1 AND parent_id = $2',
        [req.params.id, user_id]
      );
      if (link.rows.length === 0) {
        return res.status(403).json({ error: 'Forbidden' });
      }
    }

    const result = await pool.query(
      `SELECT s.*, c.class_name, b.name as branch_name
       FROM students s
       LEFT JOIN classes c ON s.class_id = c.class_id
       LEFT JOIN branches b ON s.branch_id = b.branch_id
       WHERE s.student_id = $1`,
      [req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Student not found' });
    }

    if (role !== 'superadmin' && result.rows[0].branch_id !== branch_id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST create a student
router.post('/', verifyToken, requireRole(['superadmin', 'branchadmin']), async (req, res) => {
  try {
    const { branch_id, role } = req.user;
    const {
      name, dob, photo_url, class_id,
      admission_date, emergency_contact,
      medical_notes, target_branch_id
    } = req.body;

    const assignedBranch = role === 'superadmin' ? target_branch_id : branch_id;

    if (!name || !class_id || !assignedBranch) {
      return res.status(400).json({ error: 'name, class_id, and branch_id are required' });
    }

    const result = await pool.query(
      `INSERT INTO students 
        (name, dob, photo_url, branch_id, class_id, admission_date, emergency_contact, medical_notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [name, dob || null, photo_url || null, assignedBranch,
       class_id, admission_date || null, emergency_contact || null, medical_notes || null]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PUT update a student
router.put('/:id', verifyToken, requireRole(['superadmin', 'branchadmin']), async (req, res) => {
  try {
    const { branch_id, role } = req.user;
    const { name, dob, photo_url, class_id, emergency_contact, medical_notes } = req.body;

    const student = await pool.query('SELECT * FROM students WHERE student_id = $1', [req.params.id]);
    if (student.rows.length === 0) return res.status(404).json({ error: 'Student not found' });

    if (role === 'branchadmin' && student.rows[0].branch_id !== branch_id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const result = await pool.query(
      `UPDATE students 
       SET name=$1, dob=$2, photo_url=$3, class_id=$4,
           emergency_contact=$5, medical_notes=$6, updated_at=NOW()
       WHERE student_id=$7
       RETURNING *`,
      [name, dob, photo_url, class_id, emergency_contact, medical_notes, req.params.id]
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE soft-delete a student (deactivate)
router.delete('/:id', verifyToken, requireRole(['branchadmin', 'superadmin']), async (req, res) => {
  try {
    const { branch_id, role } = req.user;

    const student = await pool.query('SELECT * FROM students WHERE student_id = $1', [req.params.id]);
    if (student.rows.length === 0) return res.status(404).json({ error: 'Student not found' });

    if (role === 'branchadmin' && student.rows[0].branch_id !== branch_id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    await pool.query(
      'UPDATE students SET is_active = false, updated_at = NOW() WHERE student_id = $1',
      [req.params.id]
    );
    res.json({ message: 'Student deactivated successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE permanently remove a student
router.delete('/:id/permanent', verifyToken, requireRole(['superadmin', 'branchadmin']), async (req, res) => {
  try {
    const { branch_id, role } = req.user;

    const student = await pool.query('SELECT * FROM students WHERE student_id = $1', [req.params.id]);
    if (student.rows.length === 0) return res.status(404).json({ error: 'Student not found' });

    if (role === 'branchadmin' && student.rows[0].branch_id !== branch_id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Delete linked records first
    await pool.query('DELETE FROM student_parents WHERE student_id = $1', [req.params.id]);
    await pool.query('DELETE FROM attendance WHERE student_id = $1', [req.params.id]);
    await pool.query('DELETE FROM leaves WHERE student_id = $1', [req.params.id]);
    
    // Delete student
    await pool.query('DELETE FROM students WHERE student_id = $1', [req.params.id]);

    res.json({ message: 'Student permanently deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
