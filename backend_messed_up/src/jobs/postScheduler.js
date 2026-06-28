const pool = require('../db/db');
const { notifyBranch } = require('../utils/notify');

const categoryLabels = {
  homework: '📚 New Homework',
  circular: '📢 New Circular',
  event:    '🎉 New Event',
  photos:   '📷 New Photos',
  holiday:  '🏖️ Holiday Notice',
};

async function publishScheduledPosts() {
  try {
    // Find all scheduled posts whose time has come
    const result = await pool.query(`
      UPDATE posts
      SET is_published = true
      WHERE is_scheduled = true
        AND is_published = false
        AND scheduled_at <= NOW()
      RETURNING *
    `);

    for (const post of result.rows) {
      console.log(`[Scheduler] Publishing post: ${post.title}`);

      // Send push notification now
      await notifyBranch(
        post.branch_id,
        post.class_id || null,
        categoryLabels[post.category] || 'New Post',
        post.title
      );

      // Log it
      await pool.query(
        `INSERT INTO teacher_logs (user_id, branch_id, action, meta, timestamp)
         VALUES ($1,$2,'publish_scheduled_post',$3,NOW())`,
        [
          post.posted_by,
          post.branch_id,
          JSON.stringify({ post_id: post.post_id, title: post.title })
        ]
      );
    }

    if (result.rows.length > 0) {
      console.log(`[Scheduler] Published ${result.rows.length} scheduled post(s)`);
    }
  } catch (err) {
    console.error('[Scheduler] Error:', err.message);
  }
}

module.exports = { publishScheduledPosts };
