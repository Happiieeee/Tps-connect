const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function fix() {
  try {
    const mainParentId = '12dcde4c-8d7d-4935-af2d-17f8890910db'; // The one with the UID
    const duplicateParentId = '7826b757-d70a-4970-b173-fe4e37966ce4';
    const nurseryA = 'a67a1978-3ba8-42ba-8017-c2caad16443d';
    const teacherId = 'c9150016-1740-4a61-a1f8-e5fbee12780a';
    const postId = '246db3e6-a2e8-4959-862b-08ee4865c130';

    console.log('--- Step 1: Merging Parents ---');
    // Move Joy to the main parent
    await pool.query(
      'UPDATE student_parents SET parent_id = $1 WHERE parent_id = $2',
      [mainParentId, duplicateParentId]
    );
    // Delete the duplicate
    await pool.query('DELETE FROM users WHERE user_id = $1', [duplicateParentId]);
    console.log('✅ Joy merged into the active parent account');

    console.log('\n--- Step 2: Fixing Teacher Class ---');
    await pool.query(
      'UPDATE users SET class_id = $1 WHERE user_id = $2',
      [nurseryA, teacherId]
    );
    console.log('✅ Teacher assigned to Nursery A');

    console.log('\n--- Step 3: Fixing Post Class ---');
    await pool.query(
      'UPDATE posts SET class_id = $1 WHERE post_id = $2',
      [nurseryA, postId]
    );
    console.log('✅ Post "test msg" moved to Nursery A');

  } catch (err) {
    console.error('❌ Error:', err);
  } finally {
    await pool.end();
  }
}

fix();
