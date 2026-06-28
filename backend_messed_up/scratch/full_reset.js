require('dotenv').config();
const { Pool } = require('pg');
const admin = require('firebase-admin');

// ── Firebase Admin init ──────────────────────────────────────────────────────
admin.initializeApp({
  credential: admin.credential.cert({
    projectId:   process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey:  process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
  }),
});

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function fullReset() {
  console.log('\n🔥 Starting full reset...\n');
  try {

    // ── STEP 1: Delete ALL Firebase users ───────────────────────────────────
    console.log('Step 1 — Deleting all Firebase users...');
    let pageToken;
    let totalDeleted = 0;
    do {
      const list = await admin.auth().listUsers(1000, pageToken);
      const uids = list.users.map(u => u.uid);
      if (uids.length > 0) {
        await admin.auth().deleteUsers(uids);
        totalDeleted += uids.length;
      }
      pageToken = list.pageToken;
    } while (pageToken);
    console.log(`   ✅ Deleted ${totalDeleted} Firebase user(s)`);

    // ── STEP 2: Wipe all transactional data (order matters for FK) ──────────
    console.log('\nStep 2 — Wiping all data (posts, attendance, leaves, logs, users)...');
    await pool.query('DELETE FROM notifications');
    await pool.query('DELETE FROM teacher_logs');
    await pool.query('DELETE FROM leave_requests');
    await pool.query('DELETE FROM attendance');
    await pool.query('DELETE FROM posts');
    await pool.query('DELETE FROM student_parents');
    await pool.query('DELETE FROM students');
    await pool.query('DELETE FROM users');
    console.log('   ✅ All transactional data wiped');

    // ── STEP 3: Clean duplicate classes from Twinkling Petals Branch 1 ──────
    console.log('\nStep 3 — Removing duplicate classes (lkg 1, Nursery A)...');
    const deleted = await pool.query(`
      DELETE FROM classes
      WHERE class_name IN ('lkg 1', 'Nursery A')
    `);
    console.log(`   ✅ Removed ${deleted.rowCount} duplicate class(es)`);

    // ── STEP 4: Ensure all branches have the 4 standard classes ────────────
    console.log('\nStep 4 — Ensuring all branches have standard classes...');
    const seedClasses = await pool.query(`
      INSERT INTO classes (branch_id, class_name)
      SELECT b.branch_id, c.class_name
      FROM branches b
      CROSS JOIN (VALUES ('Preschool'), ('Nursery'), ('LKG'), ('UKG')) AS c(class_name)
      WHERE NOT EXISTS (
        SELECT 1 FROM classes
        WHERE classes.branch_id = b.branch_id
        AND classes.class_name = c.class_name
      )
    `);
    console.log(`   ✅ Inserted ${seedClasses.rowCount} class row(s)`);

    // ── STEP 5: Get branch IDs ───────────────────────────────────────────────
    const branches = await pool.query('SELECT branch_id, name FROM branches ORDER BY name');
    console.log('\n   Available branches:');
    branches.rows.forEach((b, i) => console.log(`   [${i}] ${b.name} → ${b.branch_id}`));

    // Twinkling Petals Branch 1 is the target branch
    const twinklingBranch = branches.rows.find(b =>
      b.name.toLowerCase().includes('twinkling'));

    if (!twinklingBranch) {
      throw new Error('Could not find Twinkling Petals branch — check branch names above');
    }
    const branchId = twinklingBranch.branch_id;
    console.log(`\n   Using branch: ${twinklingBranch.name} (${branchId})`);

    // ── STEP 6: Create Firebase + DB users ──────────────────────────────────
    console.log('\nStep 5 — Creating users...');
    const users = [
      {
        name:     'Prathap V',
        email:    'prathap.v5214@gmail.com',
        password: 'Joyboy6767',
        role:     'superadmin',
        branchId: null,
      },
      {
        name:     'Branch Admin',
        email:    'pv561837@gmail.com',
        password: '123@123',
        role:     'branchadmin',
        branchId: branchId,
      },
      {
        name:     'Teacher',
        email:    'superweb4929@gmail.com',
        password: '123@123',
        role:     'teacher',
        branchId: branchId,
      },
    ];

    for (const u of users) {
      const fbUser = await admin.auth().createUser({
        email:       u.email,
        password:    u.password,
        displayName: u.name,
      });

      await pool.query(
        `INSERT INTO users (name, email, role, branch_id, firebase_uid, is_active)
         VALUES ($1, $2, $3, $4, $5, true)`,
        [u.name, u.email, u.role, u.branchId, fbUser.uid]
      );
      console.log(`   ✅ ${u.role}: ${u.email}`);
    }

    // ── STEP 7: Create student Joy and link to parent ────────────────────────
    console.log('\nStep 6 — Creating student Joy...');

    // Get LKG class_id for Twinkling Petals
    const classRes = await pool.query(
      `SELECT class_id FROM classes WHERE branch_id = $1 AND class_name = 'LKG' LIMIT 1`,
      [branchId]
    );
    if (classRes.rows.length === 0) throw new Error('LKG class not found for branch');
    const classId = classRes.rows[0].class_id;

    // Insert student
    const studentRes = await pool.query(
      `INSERT INTO students (name, class_id, branch_id, is_active)
       VALUES ($1, $2, $3, true) RETURNING student_id`,
      ['Joy', classId, branchId]
    );
    const studentId = studentRes.rows[0].student_id;
    console.log(`   ✅ Student Joy created (${studentId})`);

    // Create parent user in DB (phone OTP login — no password needed)
    const parentRes = await pool.query(
      `INSERT INTO users (name, phone, role, branch_id, is_active)
       VALUES ($1, $2, 'parent', $3, true) RETURNING user_id`,
      ['Parent of Joy', '9606664929', branchId]
    );
    const parentId = parentRes.rows[0].user_id;
    console.log(`   ✅ Parent user created (phone: 9606664929)`);

    // Link student to parent
    await pool.query(
      `INSERT INTO student_parents (student_id, parent_id) VALUES ($1, $2)`,
      [studentId, parentId]
    );
    console.log('   ✅ Student linked to parent');

    // ── STEP 8: Verify final state ───────────────────────────────────────────
    console.log('\nStep 7 — Verification:\n');
    const finalUsers = await pool.query(
      `SELECT name, email, phone, role, branch_id FROM users ORDER BY role`);
    console.table(finalUsers.rows);

    const finalClasses = await pool.query(
      `SELECT b.name as branch, c.class_name
       FROM classes c JOIN branches b ON c.branch_id = b.branch_id
       ORDER BY b.name, c.class_name`);
    console.log('\nClasses:');
    console.table(finalClasses.rows);

    const finalStudents = await pool.query(
      `SELECT s.name, c.class_name, b.name as branch
       FROM students s
       JOIN classes c ON s.class_id = c.class_id
       JOIN branches b ON s.branch_id = b.branch_id`);
    console.log('\nStudents:');
    console.table(finalStudents.rows);

    console.log('\n✅ Full reset complete!\n');
    console.log('Login credentials:');
    console.log('  Super Admin : prathap.v5214@gmail.com  | Joyboy6767');
    console.log('  Branch Admin: pv561837@gmail.com        | 123@123');
    console.log('  Teacher     : superweb4929@gmail.com    | 123@123');
    console.log('  Parent (OTP): 9606664929 (student: Joy, LKG)');

  } catch (err) {
    console.error('\n❌ Error:', err.message);
  } finally {
    await pool.end();
    process.exit(0);
  }
}

fullReset();
