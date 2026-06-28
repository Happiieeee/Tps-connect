const express = require('express');
const router = express.Router();
const pool = require('../db/db');
const verifyToken = require('../middleware/authVerify');
const requireRole = require('../middleware/roleCheck');
const { notifyBranch } = require('../utils/notify');

// ─────────────────────────────────────────
// GET posts (parent feed — filtered by child's class)
// ─────────────────────────────────────────
router.get('/', verifyToken, requireRole(['superadmin', 'branchadmin', 'teacher', 'parent']), async (req, res) => {
  try {
    const { role, user_id, branch_id } = req.user;
    const { class_id, branch_id: queryBranch, category } = req.query;

    let query;
    let params;

    if (role === 'parent') {
      query = `
        SELECT p.*, u.name as author_name, c.class_name, b.name as branch_name
        FROM posts p
        LEFT JOIN users u ON p.posted_by = u.user_id
        LEFT JOIN classes c ON p.class_id = c.class_id
        LEFT JOIN branches b ON p.branch_id = b.branch_id
        WHERE p.branch_id IN (
          SELECT s.branch_id FROM students s
          JOIN student_parents sp ON s.student_id = sp.student_id
          WHERE sp.parent_id = $1
        )
        AND (
          p.class_id IN (
            SELECT s.class_id FROM students s
            JOIN student_parents sp ON s.student_id = sp.student_id
            WHERE sp.parent_id = $1
          )
          OR p.class_id IS NULL
        )
        ${category ? 'AND p.category = $2' : ''}
        ORDER BY p.created_at DESC
        LIMIT 50
      `;
      params = [user_id];
      if (category) params.push(category);
    } else {
      const targetBranch = role === 'superadmin' ? queryBranch : branch_id;
      const params2 = [targetBranch];
      let conditions = 'WHERE p.branch_id = $1';

      if (category) {
        params2.push(category);
        conditions += ` AND p.category = $${params2.length}`;
      }
      if (class_id) {
        params2.push(class_id);
        conditions += ` AND (p.class_id = $${params2.length} OR p.class_id IS NULL)`;
      }

      query = `
        SELECT p.*, u.name as author_name, c.class_name, b.name as branch_name
        FROM posts p
        LEFT JOIN users u ON p.posted_by = u.user_id
        LEFT JOIN classes c ON p.class_id = c.class_id
        LEFT JOIN branches b ON p.branch_id = b.branch_id
        ${conditions}
        ORDER BY p.created_at DESC
        LIMIT 50
      `;
      params = params2;
    }

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─────────────────────────────────────────
// GET single post
// ─────────────────────────────────────────
router.get('/:id', verifyToken, requireRole(['superadmin', 'branchadmin', 'teacher', 'parent']), async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT p.*, u.name as author_name, c.class_name
       FROM posts p
       LEFT JOIN users u ON p.posted_by = u.user_id
       LEFT JOIN classes c ON p.class_id = c.class_id
       WHERE p.post_id = $1`,
      [req.params.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Post not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─────────────────────────────────────────
// POST create a post
// ─────────────────────────────────────────
router.post('/', verifyToken, requireRole(['superadmin', 'branchadmin', 'teacher']), async (req, res) => {
  try {
    const { role, user_id, branch_id } = req.user;
    const { title, content, category, class_id, file_urls, target_branch_id } = req.body;

    if (!title || !category) {
      return res.status(400).json({ error: 'title and category are required' });
    }

    const validCategories = ['homework', 'circular', 'event', 'photos', 'holiday'];
    if (!validCategories.includes(category)) {
      return res.status(400).json({ error: 'Invalid category' });
    }

    const assignedBranch = role === 'superadmin' ? target_branch_id : branch_id;

    const result = await pool.query(
      `INSERT INTO posts (branch_id, class_id, posted_by, category, title, content, file_urls)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        assignedBranch,
        class_id || null,
        user_id,
        category,
        title,
        content || '',
        file_urls || []
      ]
    );

    const post = result.rows[0];

    // Log action
    await pool.query(
      `INSERT INTO teacher_logs (user_id, branch_id, action, meta, timestamp)
       VALUES ($1, $2, 'create_post', $3, NOW())`,
      [user_id, assignedBranch, JSON.stringify({ post_id: post.post_id, category, title })]
    );

    // Send push notification
    const categoryLabels = {
      homework: '📚 New Homework',
      circular: '📢 New Circular',
      event: '🎉 New Event',
      photos: '📷 New Photos',
      holiday: '🏖️ Holiday Notice',
    };

    notifyBranch(
      assignedBranch,
      class_id || null,
      categoryLabels[category] || 'New Post',
      title
    );

    res.status(201).json(post);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─────────────────────────────────────────
// PUT edit a post
// ─────────────────────────────────────────
router.put('/:id', verifyToken, requireRole(['superadmin', 'branchadmin', 'teacher']), async (req, res) => {
  try {
    const { role, user_id, branch_id } = req.user;
    const { title, content, file_urls } = req.body;

    const existing = await pool.query('SELECT * FROM posts WHERE post_id = $1', [req.params.id]);
    if (existing.rows.length === 0) return res.status(404).json({ error: 'Post not found' });

    const post = existing.rows[0];

    if (role === 'teacher' && post.posted_by !== user_id) {
      return res.status(403).json({ error: 'You can only edit your own posts' });
    }

    if (role === 'branchadmin' && post.branch_id !== branch_id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const result = await pool.query(
      `UPDATE posts SET title=COALESCE($1, title), content=COALESCE($2, content), file_urls=COALESCE($3, file_urls), updated_at=NOW()
       WHERE post_id=$4 RETURNING *`,
      [title ?? post.title, content ?? post.content, file_urls ?? post.file_urls, req.params.id]
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─────────────────────────────────────────
// DELETE a post
// ─────────────────────────────────────────
router.delete('/:id', verifyToken, requireRole(['superadmin', 'branchadmin', 'teacher']), async (req, res) => {
  try {
    const { role, user_id, branch_id } = req.user;

    const existing = await pool.query('SELECT * FROM posts WHERE post_id = $1', [req.params.id]);
    if (existing.rows.length === 0) return res.status(404).json({ error: 'Post not found' });

    const post = existing.rows[0];

    if (role === 'teacher' && post.posted_by !== user_id) {
      return res.status(403).json({ error: 'You can only delete your own posts' });
    }

    if (role === 'branchadmin' && post.branch_id !== branch_id) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    await pool.query('DELETE FROM posts WHERE post_id = $1', [req.params.id]);
    res.json({ message: 'Post deleted successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
