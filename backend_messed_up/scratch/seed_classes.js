require('dotenv').config();
const { Pool } = require('pg');

const p = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function run() {
  try {
    // 1. Seed default classes into all branches
    const seed = await p.query(`
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
    console.log('✅ Classes seeded. Rows inserted:', seed.rowCount);

    // 2. Verify
    const result = await p.query(`
      SELECT b.name as branch, c.class_name
      FROM classes c
      JOIN branches b ON c.branch_id = b.branch_id
      ORDER BY b.name, c.class_name
    `);
    console.log('\n📋 All classes in DB:');
    console.table(result.rows);

  } catch (err) {
    console.error('❌ Error:', err.message);
  } finally {
    await p.end();
  }
}

run();
