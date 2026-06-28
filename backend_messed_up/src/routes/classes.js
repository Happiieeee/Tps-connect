const express = require('express');
const router = express.Router();
const pool = require('../db/db');
const verifyToken = require('../middleware/authVerify');
const requireRole = require('../middleware/roleCheck');

// GET classes for a branch
router.get('/', verifyToken, requireRole(['superadmin', 'branchadmin', 'teacher', 'parent']), async (req, res) => {
  try {
    const { branch_id, role } = req.user;
    const targetBranch = role === 'superadmin' ? req.query.branch_id : branch_id;

    const result = await pool.query(
      'SELECT * FROM classes WHERE branch_id = $1 ORDER BY class_name',
      [targetBranch]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST create a class
router.post('/', verifyToken, requireRole(['superadmin', 'branchadmin']), async (req, res) => {
  try {
    const { branch_id, role } = req.user;
    const { class_name, target_branch_id } = req.body;
    const assignedBranch = role === 'superadmin' ? target_branch_id : branch_id;

    if (!class_name || !assignedBranch) {
      return res.status(400).json({ error: 'class_name and branch_id are required' });
    }

    const result = await pool.query(
      'INSERT INTO classes (branch_id, class_name) VALUES ($1, $2) RETURNING *',
      [assignedBranch, class_name]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE a class
router.delete('/:id', verifyToken, requireRole(['superadmin', 'branchadmin']), async (req, res) => {
  try {
    const cls = await pool.query('SELECT * FROM classes WHERE class_id = $1', [req.params.id]);
    if (cls.rows.length === 0) return res.status(404).json({ error: 'Class not found' });

    const { branch_id, role } = req.user;
    if (role === 'branchadmin' && cls.rows[0].branch_id !== branch_id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    await pool.query('DELETE FROM classes WHERE class_id = $1', [req.params.id]);
    res.json({ message: 'Class deleted successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
