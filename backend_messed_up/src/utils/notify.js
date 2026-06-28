const admin = require('firebase-admin');
const pool = require('../db/db');

// Helper to save notification to DB
const saveToHistory = async ({ target_role, branch_id, class_id, title, body, sent_by }) => {
  try {
    await pool.query(
      `INSERT INTO notifications (target_role, branch_id, class_id, title, body, sent_by, sent_at)
       VALUES ($1, $2, $3, $4, $5, $6, NOW())`,
      [target_role || 'parent', branch_id || null, class_id || null, title, body, sent_by || null]
    );
  } catch (err) {
    console.error('Error saving notification to history:', err.message);
  }
};

// Send to a single user by firebase_uid
const sendNotification = async (firebaseUid, title, body, saveHistory = false, meta = {}) => {
  try {
    const result = await pool.query(
      'SELECT user_id, fcm_token, branch_id, role FROM users WHERE firebase_uid = $1',
      [firebaseUid]
    );
    if (!result.rows[0]) return;
    const user = result.rows[0];

    if (saveHistory) {
      await saveToHistory({
        target_role: user.role,
        branch_id: user.branch_id,
        title,
        body,
        sent_by: meta.sent_by
      });
    }

    if (!user.fcm_token) return;

    await admin.messaging().send({
      token: user.fcm_token,
      notification: { title, body },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  } catch (err) {
    console.error('Notification error:', err.message);
  }
};

// Notify all parents of a student
const notifyParentsOfStudent = async (studentId, title, body, meta = {}) => {
  try {
    const parents = await pool.query(
      `SELECT u.user_id, u.firebase_uid, u.branch_id FROM users u
       JOIN student_parents sp ON u.user_id = sp.parent_id
       WHERE sp.student_id = $1`,
      [studentId]
    );

    // Save to history once for the branch if needed, or per parent
    // For simplicity and accuracy in history, we save one record per parent or one general record
    // Usually history is viewed per parent. Let's save one record if it's a specific student event.
    if (parents.rows.length > 0) {
      await saveToHistory({
        target_role: 'parent',
        branch_id: parents.rows[0].branch_id,
        title,
        body,
        sent_by: meta.sent_by
      });
    }

    for (const parent of parents.rows) {
      await sendNotification(parent.firebase_uid, title, body, false); // Already saved to history above
    }
  } catch (err) {
    console.error('Notify parents error:', err.message);
  }
};

// Notify all parents in a branch (or specific class)
const notifyBranch = async (branchId, classId, title, body, meta = {}) => {
  try {
    await saveToHistory({
      target_role: 'parent',
      branch_id: branchId,
      class_id: classId,
      title,
      body,
      sent_by: meta.sent_by
    });

    let query;
    let params;

    if (classId) {
      query = `
        SELECT DISTINCT u.fcm_token FROM users u
        JOIN student_parents sp ON u.user_id = sp.parent_id
        JOIN students s ON sp.student_id = s.student_id
        WHERE s.class_id = $1 AND u.fcm_token IS NOT NULL
      `;
      params = [classId];
    } else {
      query = `
        SELECT DISTINCT u.fcm_token FROM users u
        JOIN student_parents sp ON u.user_id = sp.parent_id
        JOIN students s ON sp.student_id = s.student_id
        WHERE s.branch_id = $1 AND u.fcm_token IS NOT NULL
      `;
      params = [branchId];
    }

    const result = await pool.query(query, params);
    const tokens = result.rows.map(r => r.fcm_token).filter(Boolean);
    if (tokens.length === 0) return;

    const chunks = [];
    for (let i = 0; i < tokens.length; i += 500) {
      chunks.push(tokens.slice(i, i + 500));
    }

    for (const chunk of chunks) {
      await admin.messaging().sendEachForMulticast({
        tokens: chunk,
        notification: { title, body },
        android: { priority: 'high' },
      });
    }
  } catch (err) {
    console.error('Notify branch error:', err.message);
  }
};

// Broadcast to all parents across all branches (super admin)
const notifyAll = async (title, body, meta = {}) => {
  try {
    await saveToHistory({
      target_role: 'parent',
      title,
      body,
      sent_by: meta.sent_by
    });

    const result = await pool.query(
      `SELECT fcm_token FROM users
       WHERE role = 'parent' AND fcm_token IS NOT NULL`
    );

    const tokens = result.rows.map(r => r.fcm_token).filter(Boolean);
    if (tokens.length === 0) return;

    const chunks = [];
    for (let i = 0; i < tokens.length; i += 500) {
      chunks.push(tokens.slice(i, i + 500));
    }

    for (const chunk of chunks) {
      await admin.messaging().sendEachForMulticast({
        tokens: chunk,
        notification: { title, body },
        android: { priority: 'high' },
      });
    }
  } catch (err) {
    console.error('Notify all error:', err.message);
  }
};

module.exports = {
  sendNotification,
  notifyParentsOfStudent,
  notifyBranch,
  notifyAll,
};
