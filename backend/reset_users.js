require('dotenv').config();
const { Pool } = require('pg');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
  }),
});

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function resetUsers() {
  try {
    console.log('1. Deleting all users from Firebase...');
    const listUsersResult = await admin.auth().listUsers(1000);
    const uids = listUsersResult.users.map((user) => user.uid);
    if (uids.length > 0) {
      await admin.auth().deleteUsers(uids);
      console.log(`Deleted ${uids.length} users from Firebase.`);
    } else {
      console.log('No users found in Firebase.');
    }

    console.log('2. Deleting all users from PostgreSQL (CASCADE)...');
    await pool.query('TRUNCATE TABLE users CASCADE');
    console.log('PostgreSQL users table truncated.');

    // We need a branch for the branchadmin and teacher
    console.log('Ensuring at least one branch exists...');
    const branchRes = await pool.query('SELECT branch_id FROM branches LIMIT 1');
    let branch_id;
    if (branchRes.rows.length === 0) {
      const newBranch = await pool.query("INSERT INTO branches (name, address, contact_email) VALUES ('Main Branch', '123 Main St', 'info@main.com') RETURNING branch_id");
      branch_id = newBranch.rows[0].branch_id;
    } else {
      branch_id = branchRes.rows[0].branch_id;
    }

    console.log('3. Creating new users...');
    const newUsers = [
      { name: 'Super Admin', email: 'admin1@gmail.com', pass: 'admin1@123', role: 'superadmin', branch_id: null },
      { name: 'Branch Admin', email: 'badmin1@gmail.com', pass: 'badmin1@123', role: 'branchadmin', branch_id: branch_id },
      { name: 'Teacher', email: 'teacher@gmail.com', pass: 'teacher1@123', role: 'teacher', branch_id: branch_id },
    ];

    for (const u of newUsers) {
      const firebaseUser = await admin.auth().createUser({
        email: u.email,
        password: u.pass,
        displayName: u.name,
      });

      await pool.query(
        `INSERT INTO users (name, email, role, branch_id, firebase_uid, is_active)
         VALUES ($1, $2, $3, $4, $5, true)`,
        [u.name, u.email, u.role, u.branch_id, firebaseUser.uid]
      );
      console.log(`Created ${u.role}: ${u.email}`);
    }

    console.log('✅ All users reset successfully!');
  } catch (error) {
    console.error('Error during reset:', error);
  } finally {
    await pool.end();
    process.exit(0);
  }
}

resetUsers();
