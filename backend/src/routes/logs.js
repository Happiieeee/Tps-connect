const express     = require('express');
const router      = express.Router();
const pool        = require('../db/db');
const verifyToken = require('../middleware/authVerify');
const requireRole = require('../middleware/roleCheck');

router.get('/', verifyToken,
  requireRole(['superadmin', 'branchadmin']),
  async (req, res) => {
    try {
      const { role, branch_id } = req.user;
      const { user_id, limit = 50 } = req.query;
      const targetBranch = role === 'superadmin' ? req.query.branch_id : branch_id;

      const result = await pool.query(
        `SELECT tl.*, u.name as user_name, u.role as user_role
         FROM teacher_logs tl
         JOIN users u ON tl.user_id = u.user_id
         WHERE tl.branch_id = $1
         ${user_id ? 'AND tl.user_id = $2' : ''}
         ORDER BY tl.timestamp DESC
         LIMIT $${user_id ? 3 : 2}`,
        user_id
          ? [targetBranch, user_id, parseInt(limit)]
          : [targetBranch, parseInt(limit)]
      );

      res.json(result.rows);
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Server error' });
    }
  }
);

module.exports = router;
