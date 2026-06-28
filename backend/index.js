const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();

// Middleware
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',')
    : ['http://localhost:3000', 'http://localhost:5000'],
}));
app.use(helmet());
app.use(morgan('dev'));
app.use(express.json());

// Rate limiting on auth endpoints
app.use('/auth', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 50,
  message: { error: 'Too many requests, please try again later.' }
}));

// Health check
app.get('/health', (req, res) => res.json({ status: 'TPS API running', timestamp: new Date().toISOString() }));

// Routes
const authRoutes = require('./src/routes/auth');
const teacherRoutes = require('./src/routes/teachers');
const studentRoutes = require('./src/routes/students');
const parentRoutes = require('./src/routes/parents');
const classRoutes = require('./src/routes/classes');
const attendanceRoutes = require('./src/routes/attendance');
const postRoutes = require('./src/routes/posts');
const notificationRoutes = require('./src/routes/notifications');
const uploadRoutes = require('./src/routes/uploads');
const leaveRoutes = require('./src/routes/leaves');
const reportRoutes = require('./src/routes/reports');
const logRoutes = require('./src/routes/logs');
const superadminRoutes = require('./src/routes/superadmin');
const teacherFormRoutes = require('./src/routes/teacherForm');

app.use('/auth', authRoutes);
app.use('/teachers', teacherRoutes);
app.use('/students', studentRoutes);
app.use('/parents', parentRoutes);
app.use('/classes', classRoutes);
app.use('/attendance', attendanceRoutes);
app.use('/posts', postRoutes);
app.use('/notifications', notificationRoutes);
app.use('/uploads', uploadRoutes);
app.use('/leaves', leaveRoutes);
app.use('/reports', reportRoutes);
app.use('/logs', logRoutes);
app.use('/superadmin', superadminRoutes);
app.use('/teacher-form', teacherFormRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`TPS Server running on port ${PORT}`));
