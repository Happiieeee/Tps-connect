const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const app = express();

// Middlewares
app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());

// Routes
app.get('/', (req, res) => {
  res.json({ message: 'TPS API is running' });
});

// TODO: Register routes here
// app.use('/api/v1/auth', require('./routes/auth.routes'));

module.exports = app;
