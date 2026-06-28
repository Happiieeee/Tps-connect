const { Pool } = require('pg');
require('dotenv').config({path: require('path').resolve(__dirname, '../.env')});
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function run() {
  // Just posts
  const posts = await pool.query(`
    SELECT p.post_id, p.title, p.branch_id, p.class_id, p.is_published, p.is_scheduled,
           p.category, p.created_at, b.name as branch_name, c.class_name
    FROM posts p
    LEFT JOIN branches b ON p.branch_id = b.branch_id
    LEFT JOIN classes c ON p.class_id = c.class_id
    ORDER BY p.created_at DESC
  `);
  console.log('Total posts:', posts.rows.length);
  posts.rows.forEach(p => {
    console.log(`  [${p.is_published ? 'PUB' : 'UNPUB'}] "${p.title}" | branch: ${p.branch_name} (${p.branch_id}) | class: ${p.class_name || 'ALL'} (${p.class_id || 'null'}) | category: ${p.category} | scheduled: ${p.is_scheduled}`);
  });

  // The parent from the screenshot: Prathap, Nursery, Little Junior DPS Branch 2
  // Branch 2 = 753353a2-7688-423b-88cd-9b320958187e
  // Nursery in Branch 2 = 558564b3-120b-4dfa-bd1f-a3a4fe3ff155
  
  // Check: is the notification "sample all" linked to a post?
  console.log('\n=== Looking for "sample all" post ===');
  const sampleAll = await pool.query(`SELECT * FROM posts WHERE title = 'sample all'`);
  console.log('Found:', sampleAll.rows.length);
  sampleAll.rows.forEach(p => {
    console.log(JSON.stringify(p, null, 2));
  });

  await pool.end();
}
run().catch(e => { console.error(e); process.exit(1); });
