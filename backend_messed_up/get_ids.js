require('dotenv').config();
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
async function run() {
  try {
    const res = await pool.query(`
      SELECT b.name AS branch_name, b.branch_id, c.class_name, c.class_id
      FROM classes c
      JOIN branches b ON c.branch_id = b.branch_id
      ORDER BY b.name, c.class_name
    `);
    
    const branches = {};
    for (const row of res.rows) {
      if (!branches[row.branch_name]) {
        branches[row.branch_name] = { id: row.branch_id, classes: [] };
      }
      branches[row.branch_name].classes.push({ name: row.class_name, id: row.class_id });
    }

    for (const [bName, bData] of Object.entries(branches)) {
      console.log('\n### 🏢 ' + bName);
      console.log('**Branch ID:** `' + bData.id + '`\n');
      console.log('| Class Name | Class ID |');
      console.log('| :--- | :--- |');
      for (const c of bData.classes) {
        console.log('| **' + c.name + '** | `' + c.id + '` |');
      }
    }

  } finally {
    await pool.end();
  }
}
run();
