require('dotenv').config({path: '../.env'});
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
  })
});

const { notifyBranch } = require('../src/utils/notify');

async function sendTestNotification() {
  const branchId = '97ee32b9-5f26-428f-8bf2-9c11eb8a737a'; // Little Junior DPS Branch 1
  const classId = '6b9d45a0-c54e-4cdb-9037-206544653d12'; // Preschool

  // First check if 'usha' has the fcm token now
  const fcm = await pool.query(
    "SELECT name, phone, fcm_token FROM users WHERE role = 'parent' AND branch_id = $1",
    [branchId]
  );
  console.table(fcm.rows);

  const parent = fcm.rows.find(r => r.name === 'usha');
  if (!parent || !parent.fcm_token) {
    console.error('ERROR: FCM token is still missing for usha. Make sure to open the updated app and accept notification permissions.');
    process.exit(1);
  }

  console.log('Sending notification...');
  try {
    await notifyBranch(branchId, classId, '📚 New Homework', 'Please complete the English worksheets by tomorrow.', { sent_by: null });
    console.log('Notification sent successfully!');
  } catch (err) {
    console.error('Failed to send notification:', err);
  }

  await pool.end();
  await admin.app().delete();
}

sendTestNotification();
