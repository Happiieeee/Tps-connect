const { Pool } = require('pg');
require('dotenv').config({path: require('path').resolve(__dirname, '../.env')});
console.log('DB URL starts with:', (process.env.DATABASE_URL || 'MISSING').substring(0, 30));
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function run() {
  // 1. Show all posts
  console.log('\n=== ALL POSTS ===');
  const posts = await pool.query(`
    SELECT p.post_id, p.title, p.branch_id, p.class_id, p.is_published, p.is_scheduled,
           p.category, p.created_at, b.name as branch_name, c.class_name
    FROM posts p
    LEFT JOIN branches b ON p.branch_id = b.branch_id
    LEFT JOIN classes c ON p.class_id = c.class_id
    ORDER BY p.created_at DESC
  `);
  console.table(posts.rows);

  // 2. Show parent user with phone 9606664929 (the one from screenshots)
  console.log('\n=== PARENT USER (phone containing 9606664929) ===');
  const parent = await pool.query(`
    SELECT u.user_id, u.name, u.phone, u.role, u.branch_id, u.firebase_uid,
           b.name as branch_name
    FROM users u
    LEFT JOIN branches b ON u.branch_id = b.branch_id
    WHERE u.phone LIKE '%9606664929%' OR u.role = 'parent'
  `);
  console.table(parent.rows);

  // 3. Show student_parents links for this parent
  console.log('\n=== STUDENT_PARENTS LINKS ===');
  const links = await pool.query(`
    SELECT sp.*, s.name as student_name, s.branch_id as student_branch_id, 
           s.class_id as student_class_id, c.class_name, b.name as branch_name
    FROM student_parents sp
    JOIN students s ON sp.student_id = s.student_id
    LEFT JOIN classes c ON s.class_id = c.class_id
    LEFT JOIN branches b ON s.branch_id = b.branch_id
  `);
  console.table(links.rows);

  // 4. Show all branches and classes
  console.log('\n=== ALL BRANCHES ===');
  const branches = await pool.query('SELECT * FROM branches');
  console.table(branches.rows);

  console.log('\n=== ALL CLASSES ===');
  const classes = await pool.query('SELECT * FROM classes');
  console.table(classes.rows);

  // 5. Simulate the parent post query for each parent
  console.log('\n=== SIMULATED POST QUERY FOR EACH PARENT ===');
  for (const p of parent.rows) {
    if (p.role !== 'parent') continue;
    const result = await pool.query(`
      SELECT p.post_id, p.title, p.branch_id, p.class_id, p.is_published
      FROM posts p
      WHERE p.branch_id IN (
        SELECT s.branch_id FROM students s
        JOIN student_parents sp ON s.student_id = sp.student_id
        WHERE sp.parent_id = $1
      )
      AND (
        p.class_id IN (
          SELECT s.class_id FROM students s
          JOIN student_parents sp ON s.student_id = sp.student_id
          WHERE sp.parent_id = $1
        )
        OR p.class_id IS NULL
      )
      AND (p.is_published = true OR p.is_published IS NULL)
      ORDER BY p.created_at DESC
      LIMIT 50
    `, [p.user_id]);
    console.log(`\nPosts for parent "${p.name}" (user_id: ${p.user_id}):`);
    console.table(result.rows);

    // Also check what branch/class the sub-queries return
    const branchSub = await pool.query(`
      SELECT s.branch_id FROM students s
      JOIN student_parents sp ON s.student_id = sp.student_id
      WHERE sp.parent_id = $1
    `, [p.user_id]);
    console.log(`  -> Student branch_ids: ${JSON.stringify(branchSub.rows)}`);

    const classSub = await pool.query(`
      SELECT s.class_id FROM students s
      JOIN student_parents sp ON s.student_id = sp.student_id
      WHERE sp.parent_id = $1
    `, [p.user_id]);
    console.log(`  -> Student class_ids: ${JSON.stringify(classSub.rows)}`);
  }

  // 6. Check notifications
  console.log('\n=== RECENT NOTIFICATIONS ===');
  const notifs = await pool.query(`
    SELECT n.*, b.name as branch_name FROM notifications n
    LEFT JOIN branches b ON n.branch_id = b.branch_id
    ORDER BY n.sent_at DESC LIMIT 10
  `);
  console.table(notifs.rows);

  await pool.end();
}
run().catch(e => { console.error(e); process.exit(1); });
