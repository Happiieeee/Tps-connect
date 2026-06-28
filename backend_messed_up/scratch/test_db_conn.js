const { Client } = require('pg');
require('dotenv').config();

const configs = [
  { name: 'SSL True', ssl: true },
  { name: 'SSL Object (Reject False)', ssl: { rejectUnauthorized: false } },
  { name: 'No SSL', ssl: false }
];

async function test() {
  for (const config of configs) {
    console.log(`Testing: ${config.name}...`);
    const client = new Client({
      connectionString: process.env.DATABASE_URL,
      ssl: config.ssl,
      connectionTimeoutMillis: 10000
    });
    try {
      await client.connect();
      const res = await client.query('SELECT NOW()');
      console.log(`✅ Success with ${config.name}: ${res.rows[0].now}`);
      await client.end();
    } catch (err) {
      console.log(`❌ Failed with ${config.name}: ${err.message}`);
    }
  }
}

test();
