const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
require('dotenv').config();

if (!process.env.DATABASE_URL) {
  console.error('Error: DATABASE_URL not set in env');
  process.exit(1);
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function main() {
  try {
    console.log('Connecting to PostgreSQL database on Render...');
    
    // Read DDL file
    const ddlPath = path.join(__dirname, '../docs/setup_database.sql');
    let sql = fs.readFileSync(ddlPath, 'utf8');

    // Run DDL script
    console.log('Running database setup script (setup_database.sql)...');
    await pool.query(sql);

    console.log('Database tables successfully initialized!');
    
    // Insert initial super admin automatically as a seed
    console.log('Inserting default superadmin user (Prathap)...');
    await pool.query(
      `INSERT INTO users (name, email, role, is_active)
       VALUES ($1, $2, $3, true)
       ON CONFLICT (email) DO NOTHING`,
      ['Prathap', 'prathap.v5214@gmail.com', 'superadmin']
    );
    console.log('Seeding complete!');
    
    process.exit(0);
  } catch (err) {
    console.error('Database initialization failed:', err);
    process.exit(1);
  }
}

main();
