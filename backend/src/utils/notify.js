const admin = require('firebase-admin');
const pool = require('../db/db');

// Send to a single user by firebase_uid
const sendNotification = async (firebaseUid, title, body) => {
  try {
    const result = await pool.query(
      'SELECT fcm_token FROM users WHERE firebase_uid = $1',
      [firebaseUid]
    );
    if (!result.rows[0]?.fcm_token) return;

    await admin.messaging().send({
      token: result.rows[0].fcm_token,
      notification: { title, body },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  } catch (err) {
    console.error('Notification error:', err.message);
  }
};

// Notify all parents of a student
const notifyParentsOfStudent = async (studentId, title, body) => {
  try {
    const parents = await pool.query(
      `SELECT u.firebase_uid FROM users u
       JOIN student_parents sp ON u.user_id = sp.parent_id
       JOIN students s ON sp.student_id = s.student_id
       WHERE sp.student_id = $1 AND u.is_active = true AND s.is_active = true`,
      [studentId]
    );
    for (const parent of parents.rows) {
      await sendNotification(parent.firebase_uid, title, body);
    }
  } catch (err) {
    console.error('Notify parents error:', err.message);
  }
};

// Notify all parents in a branch (or specific class)
const notifyBranch = async (branchId, classId, title, body) => {
  try {
    let query;
    let params;

    if (classId) {
      query = `
        SELECT DISTINCT u.fcm_token FROM users u
        JOIN student_parents sp ON u.user_id = sp.parent_id
        JOIN students s ON sp.student_id = s.student_id
        WHERE s.class_id = $1 AND u.fcm_token IS NOT NULL
          AND u.is_active = true AND s.is_active = true
      `;
      params = [classId];
    } else {
      query = `
        SELECT DISTINCT u.fcm_token FROM users u
        JOIN student_parents sp ON u.user_id = sp.parent_id
        JOIN students s ON sp.student_id = s.student_id
        WHERE s.branch_id = $1 AND u.fcm_token IS NOT NULL
          AND u.is_active = true AND s.is_active = true
      `;
      params = [branchId];
    }

    const result = await pool.query(query, params);
    const tokens = result.rows.map(r => r.fcm_token).filter(Boolean);
    if (tokens.length === 0) return;

    // FCM multicast in batches of 500
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
const notifyAll = async (title, body) => {
  try {
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
