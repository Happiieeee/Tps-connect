require('dotenv').config();
const pool = require('./src/db/db');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId:   process.env.FIREBASE_PROJECT_ID,
      privateKey:  process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    }),
  });
}

async function seed() {
  console.log('Seeding branches...');

  // Insert 3 branches
  const branches = [
    { name: 'Little Junior DPS Branch 1', code: 'LJDPS1' },
    { name: 'Little Junior DPS Branch 2', code: 'LJDPS2' },
    { name: 'Twinkling Petals Preschool Branch 1', code: 'TPPB1'  },
  ];

  const branchIds = [];
  for (const b of branches) {
    const existing = await pool.query(
      'SELECT branch_id FROM branches WHERE code = $1', [b.code]);
    if (existing.rows.length > 0) {
      console.log(`Branch already exists: ${b.name}`);
      branchIds.push(existing.rows[0].branch_id);
      continue;
    }
    const res = await pool.query(
      `INSERT INTO branches (name, code) VALUES ($1, $2) RETURNING branch_id`,
      [b.name, b.code]
    );
    branchIds.push(res.rows[0].branch_id);
    console.log(`Created branch: ${b.name}`);
  }

  // Create 2 super admins in Firebase + DB
  const superAdmins = [
    { name: 'Super Admin 1', email: 'superadmin1@tps.com', password: 'TpsAdmin@2026' },
    { name: 'Super Admin 2', email: 'superadmin2@tps.com', password: 'TpsAdmin@2026' },
  ];

  for (const sa of superAdmins) {
    try {
      // Create in Firebase
      let firebaseUser;
      try {
        firebaseUser = await admin.auth().getUserByEmail(sa.email);
        console.log(`Firebase user already exists: ${sa.email}`);
      } catch {
        firebaseUser = await admin.auth().createUser({
          email: sa.email, password: sa.password, displayName: sa.name,
        });
        console.log(`Created Firebase user: ${sa.email}`);
      }

      // Create in DB
      const existing = await pool.query(
        'SELECT user_id FROM users WHERE email = $1', [sa.email]);
      if (existing.rows.length > 0) {
        console.log(`DB user already exists: ${sa.email}`);
        continue;
      }

      await pool.query(
        `INSERT INTO users (name, email, role, firebase_uid, is_active)
         VALUES ($1, $2, 'superadmin', $3, true)`,
        [sa.name, sa.email, firebaseUser.uid]
      );
      console.log(`Created DB user: ${sa.email}`);
    } catch (err) {
      console.error(`Error creating ${sa.email}:`, err.message);
    }
  }

  console.log('\nDone! Branch IDs:');
  branchIds.forEach((id, i) => console.log(`  ${branches[i].name}: ${id}`));
  await pool.end();
}

seed();
