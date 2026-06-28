const pool = require('../db/db');

const requireRole = (allowedRoles) => {
  return async (req, res, next) => {
    try {
      const result = await pool.query(
        'SELECT user_id, role, branch_id, name FROM users WHERE firebase_uid = $1 AND is_active = true',
        [req.firebaseUid]
      );

      if (result.rows.length === 0) {
        return res.status(403).json({ error: 'User not found or inactive' });
      }

      const user = result.rows[0];

      if (!allowedRoles.includes(user.role)) {
        return res.status(403).json({ error: 'Insufficient permissions' });
      }

      req.user = user;
      next();
    } catch (err) {
      res.status(500).json({ error: 'Server error' });
    }
  };
};

module.exports = requireRole;
