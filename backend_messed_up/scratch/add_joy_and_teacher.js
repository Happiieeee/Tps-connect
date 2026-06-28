const { Pool } = require('pg');
const admin = require('firebase-admin');
require('dotenv').config();

// Init Firebase
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      privateKey: process.env.FIREBASE_PRIVATE_KEY ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n') : undefined,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    }),
  });
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function run() {
  try {
    const branchId = '704dc63c-2408-48f9-a2cf-9b1adeb7a428'; // Twinkling Petals
    const classId = 'a67a1978-3ba8-42ba-8017-c2caad16443d';  // Nursery A

    console.log('--- Step 1: Adding Teacher ---');
    const teacherEmail = 'superweb4929@gmail.com';
    const teacherPass = '123@123';
    
    // Create Firebase User for Teacher
    let teacherUid;
    try {
      const fbUser = await admin.auth().createUser({
        email: teacherEmail,
        password: teacherPass,
        displayName: 'Twinkling Teacher',
      });
      teacherUid = fbUser.uid;
      console.log('✅ Firebase teacher created:', teacherUid);
    } catch (e) {
      if (e.code === 'auth/email-already-exists') {
        const existing = await admin.auth().getUserByEmail(teacherEmail);
        teacherUid = existing.uid;
        console.log('ℹ️ Teacher already exists in Firebase, using UID:', teacherUid);
      } else throw e;
    }

    // Insert Teacher into DB
    await pool.query(
      `INSERT INTO users (name, email, phone, role, branch_id, firebase_uid, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, true)
       ON CONFLICT (email) DO UPDATE SET firebase_uid = EXCLUDED.firebase_uid, role = 'teacher', branch_id = $5`,
      ['Twinkling Teacher', teacherEmail, null, 'teacher', branchId, teacherUid]
    );
    console.log('✅ Teacher added to database');

    console.log('\n--- Step 2: Adding Parent and Student Joy ---');
    const parentPhone = '+919606664929';
    const parentEmail = 'joy_parent@gmail.com'; // Placeholder
    
    // Create Firebase User for Parent (Phone)
    // Note: Usually parents are created by phone in the app, 
    // but we can pre-create a DB record.
    
    const parentResult = await pool.query(
      `INSERT INTO users (name, email, phone, role, branch_id, is_active)
       VALUES ($1, $2, $3, $4, $5, true)
       ON CONFLICT (email) DO UPDATE SET phone = $3
       RETURNING user_id`,
      ['Joy Parent', parentEmail, parentPhone, 'parent', branchId]
    );
    const parentId = parentResult.rows[0].user_id;
    console.log('✅ Parent record created:', parentId);

    // Create Student Joy
    const studentResult = await pool.query(
      `INSERT INTO students (name, branch_id, class_id, admission_date)
       VALUES ($1, $2, $3, NOW())
       RETURNING student_id`,
      ['Joy', branchId, classId]
    );
    const studentId = studentResult.rows[0].student_id;
    console.log('✅ Student Joy created:', studentId);

    // Link Parent to Student
    await pool.query(
      'INSERT INTO student_parents (student_id, parent_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [studentId, parentId]
    );
    console.log('✅ Parent linked to Joy');

  } catch (err) {
    console.error('❌ Error:', err);
  } finally {
    await pool.end();
  }
}

run();
