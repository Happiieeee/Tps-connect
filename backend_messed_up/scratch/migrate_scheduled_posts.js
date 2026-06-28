const { Pool } = require('pg');
require('dotenv').config({path: '../.env'});
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function run() {
  try {
    await pool.query(`
      ALTER TABLE posts
        ADD COLUMN IF NOT EXISTS is_scheduled   BOOLEAN DEFAULT false,
        ADD COLUMN IF NOT EXISTS scheduled_at   TIMESTAMPTZ,
        ADD COLUMN IF NOT EXISTS is_published   BOOLEAN DEFAULT true;
    `);
    
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_posts_scheduled
        ON posts(scheduled_at, is_published)
        WHERE is_scheduled = true;
    `);

    console.log('Database updated successfully for scheduled posts.');
  } catch (e) {
    console.error('Error updating DB:', e);
  } finally {
    await pool.end();
  }
}
run();
