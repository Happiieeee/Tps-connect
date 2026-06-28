const express = require('express');
const router = express.Router();
const multer = require('multer');
const admin = require('firebase-admin');
const verifyToken = require('../middleware/authVerify');
const requireRole = require('../middleware/roleCheck');
const { v4: uuidv4 } = require('uuid');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB max
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/gif', 'application/pdf'];
    if (allowed.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only images and PDFs are allowed'));
    }
  },
});

// POST upload file to Firebase Storage
router.post('/', verifyToken, requireRole(['superadmin', 'branchadmin', 'teacher']),
  upload.single('file'),
  async (req, res) => {
    try {
      if (!req.file) return res.status(400).json({ error: 'No file provided' });

      try {
        const bucket = admin.storage().bucket();
        const fileName = `posts/${uuidv4()}-${req.file.originalname}`;
        const file = bucket.file(fileName);

        await file.save(req.file.buffer, {
          metadata: { contentType: req.file.mimetype },
          public: true,
        });

        const publicUrl = `https://storage.googleapis.com/${bucket.name}/${fileName}`;
        res.json({ url: publicUrl });
      } catch (storageErr) {
        console.error('Storage error:', storageErr.message);
        return res.status(503).json({
          error: 'File storage unavailable. Contact admin.',
          code: 'STORAGE_UNAVAILABLE'
        });
      }
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Upload failed' });
    }
  }
);

module.exports = router;
