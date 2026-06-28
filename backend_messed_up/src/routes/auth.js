const express = require('express');
const router = express.Router();
const pool = require('../db/db');
const verifyToken = require('../middleware/authVerify');
const requireRole = require('../middleware/roleCheck');
const admin = require('firebase-admin');

// GET /auth/me — called right after login, returns role and branchId
router.get('/me', verifyToken, async (req, res) => {
  console.log('[/auth/me] Checking profile for UID:', req.firebaseUid);
  try {
    // First try matching by firebase_uid (fast path — already linked)
    let result = await pool.query(
      `SELECT u.user_id, u.name, u.role, u.branch_id, u.phone,
              b.name as branch_name
       FROM users u
       LEFT JOIN branches b ON u.branch_id = b.branch_id
       WHERE u.firebase_uid = $1 AND u.is_active = true`,
      [req.firebaseUid]
    );

    console.log('[/auth/me] Initial UID match rows:', result.rows.length);

    // If not found by UID — try matching by phone number (parent first login)
    if (result.rows.length === 0) {
      console.log('[/auth/me] UID not found, trying phone/email lookup...');
      // Get phone number from Firebase token
      const firebaseUser = await admin.auth().getUser(req.firebaseUid);
      const phone = firebaseUser.phoneNumber;
      const email = firebaseUser.email;
      console.log('[/auth/me] Firebase metadata:', { phone, email });

      if (phone) {
        // Normalize — strip spaces, dashes, plus signs
        const normalized = phone.replace(/[\s\-+]/g, '');
        // Get the last 10 digits
        const right10 = normalized.slice(-10);

        result = await pool.query(
          `SELECT u.user_id, u.name, u.role, u.branch_id, u.phone,
                  b.name as branch_name
           FROM users u
           LEFT JOIN branches b ON u.branch_id = b.branch_id
           WHERE RIGHT(REPLACE(REPLACE(u.phone, ' ', ''), '-', ''), 10) = $1
             AND u.is_active = true`,
          [right10]
        );

        // Found by phone — save firebase_uid so next login is instant
        if (result.rows.length > 0) {
          await pool.query(
            'UPDATE users SET firebase_uid = $1 WHERE user_id = $2',
            [req.firebaseUid, result.rows[0].user_id]
          );
        }
      }

      // Try email match for staff (Google sign-in)
      if (result.rows.length === 0 && email) {
        result = await pool.query(
          `SELECT u.user_id, u.name, u.role, u.branch_id, u.phone,
                  b.name as branch_name
           FROM users u
           LEFT JOIN branches b ON u.branch_id = b.branch_id
           WHERE u.email = $1 AND u.is_active = true`,
          [email]
        );

        // Found by email — save firebase_uid
        if (result.rows.length > 0) {
          await pool.query(
            'UPDATE users SET firebase_uid = $1 WHERE user_id = $2',
            [req.firebaseUid, result.rows[0].user_id]
          );
        }
      }
    }

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Account not found in TPS. Contact your admin.' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Auth /me error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /auth/create-branch-admin — super admin only
router.post('/create-branch-admin', verifyToken, requireRole(['superadmin']), async (req, res) => {
  try {
    const { name, email, phone, branch_id } = req.body;

    if (!name || !email || !branch_id) {
      return res.status(400).json({ error: 'name, email, and branch_id are required' });
    }

    const branch = await pool.query('SELECT * FROM branches WHERE branch_id = $1', [branch_id]);
    if (branch.rows.length === 0) return res.status(404).json({ error: 'Branch not found' });

    const existing = await pool.query('SELECT user_id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) return res.status(409).json({ error: 'Email already in use' });

    const tempPassword = 'TPS@' + Math.random().toString(36).slice(2, 10);
    const firebaseUser = await admin.auth().createUser({
      email,
      password: tempPassword,
      displayName: name,
    });

    const result = await pool.query(
      `INSERT INTO users (name, email, phone, role, branch_id, firebase_uid, is_active)
       VALUES ($1, $2, $3, 'branchadmin', $4, $5, true)
       RETURNING user_id, name, email, role, branch_id`,
      [name, email, phone || null, branch_id, firebaseUser.uid]
    );

    // Send password reset so they can set their own password
    await admin.auth().generatePasswordResetLink(email);

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /auth/fcm-token — save device FCM token for push notifications
router.post('/fcm-token', verifyToken, async (req, res) => {
  try {
    const { fcm_token } = req.body;
    if (!fcm_token) return res.status(400).json({ error: 'fcm_token is required' });

    await pool.query(
      'UPDATE users SET fcm_token = $1 WHERE firebase_uid = $2',
      [fcm_token, req.firebaseUid]
    );
    res.json({ message: 'FCM token saved' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
