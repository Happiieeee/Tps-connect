import { useState, useEffect } from 'react';
import { auth } from '../../config/firebase.js';
import { useAuth } from '../../contexts/AuthContext.jsx';
import { useToast } from '../../components/Toast.jsx';
import api from '../../services/api.js';
import BottomNav from '../../components/BottomNav.jsx';
import Modal from '../../components/Modal.jsx';
import {
  IconHome,
  IconCalendar,
  IconClipboard,
  IconBell,
  IconUser,
  IconPlus,
  IconLogOut,
} from '../../components/Icons.jsx';
import {
  formatDate,
  formatDateShort,
  formatTimeAgo,
  getInitials,
  getCategoryEmoji,
  getCategoryLabel,
  MONTHS,
  DAYS,
} from '../../utils/helpers.js';

export default function ParentDashboard() {
  const { profile } = useAuth();
  const toast = useToast();

  const [activeTab, setActiveTab] = useState('home');
  const [children, setChildren] = useState([]);
  const [selectedChild, setSelectedChild] = useState(null);
  const [loading, setLoading] = useState(true);

  // Home Stats & Details
  const [childStats, setChildStats] = useState(null);

  // Feed Tab
  const [posts, setPosts] = useState([]);
  const [categoryFilter, setCategoryFilter] = useState('');
  const [feedLoading, setFeedLoading] = useState(false);

  // Attendance Tab
  const [calendarYear, setCalendarYear] = useState(new Date().getFullYear());
  const [calendarMonth, setCalendarMonth] = useState(new Date().getMonth() + 1); // 1-indexed
  const [attendanceRecords, setAttendanceRecords] = useState([]);
  const [attendanceSummary, setAttendanceSummary] = useState(null);
  const [attendanceLoading, setAttendanceLoading] = useState(false);

  // Leave Tab
  const [leaves, setLeaves] = useState([]);
  const [leaveLoading, setLeaveLoading] = useState(false);
  const [showApplyModal, setShowApplyModal] = useState(false);
  const [fromDate, setFromDate] = useState('');
  const [toDate, setToDate] = useState('');
  const [leaveReason, setLeaveReason] = useState('');
  const [submittingLeave, setSubmittingLeave] = useState(false);

  // Notifications Tab
  const [notifications, setNotifications] = useState([]);
  const [notificationsLoading, setNotificationsLoading] = useState(false);

  // Fetch children on load
  useEffect(() => {
    async function loadChildren() {
      try {
        setLoading(true);
        const data = await api.get('/parents/children');
        setChildren(data);
        if (data.length > 0) {
          setSelectedChild(data[0]);
        }
      } catch (err) {
        toast.error('Failed to load children data.');
        console.error(err);
      } finally {
        setLoading(false);
      }
    }
    loadChildren();
  }, []);

  // Sync activeTab state with browser history for back button optimization
  useEffect(() => {
    if (activeTab !== 'home' && (!window.history.state || window.history.state.activeTab !== activeTab)) {
      window.history.pushState({ activeTab }, '');
    }
  }, [activeTab]);

  useEffect(() => {
    const handlePopState = (event) => {
      if (event.state && event.state.activeTab) {
        setActiveTab(event.state.activeTab);
      } else {
        setActiveTab('home');
      }
    };
    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, []);

  // Fetch child stats and basic dashboard summary + pre-load posts
  useEffect(() => {
    if (!selectedChild) return;

    async function loadStats() {
      try {
        const month = new Date().getMonth() + 1;
        const year = new Date().getFullYear();
        const res = await api.get(`/attendance/report/student/${selectedChild.student_id}?month=${month}&year=${year}`);
        setChildStats(res.summary);
      } catch (err) {
        console.error('Failed to load child stats:', err);
      }
    }
    loadStats();
    loadPosts(''); // Pre-load posts for Home tab recent posts section
  }, [selectedChild]);

  // Fetch posts feed
  const loadPosts = async (cat) => {
    try {
      setFeedLoading(true);
      const url = cat ? `/posts?category=${cat}` : '/posts';
      const data = await api.get(url);
      setPosts(data);
    } catch (err) {
      toast.error('Failed to load posts feed.');
      console.error(err);
    } finally {
      setFeedLoading(false);
    }
  };

  useEffect(() => {
    if (activeTab === 'feed') {
      loadPosts(categoryFilter);
    }
  }, [activeTab, categoryFilter]);

  // Fetch attendance records
  const loadAttendance = async () => {
    if (!selectedChild) return;
    try {
      setAttendanceLoading(true);
      const data = await api.get(`/attendance/report/student/${selectedChild.student_id}?month=${calendarMonth}&year=${calendarYear}`);
      setAttendanceRecords(data.daily || []);
      setAttendanceSummary(data.summary || null);
    } catch (err) {
      toast.error('Failed to load attendance calendar.');
      console.error(err);
    } finally {
      setAttendanceLoading(false);
    }
  };

  useEffect(() => {
    if (activeTab === 'attendance' && selectedChild) {
      loadAttendance();
    }
  }, [activeTab, selectedChild, calendarMonth, calendarYear]);

  // Fetch leaves
  const loadLeaves = async () => {
    try {
      setLeaveLoading(true);
      const data = await api.get('/leaves');
      setLeaves(data);
    } catch (err) {
      toast.error('Failed to load leave history.');
      console.error(err);
    } finally {
      setLeaveLoading(false);
    }
  };

  useEffect(() => {
    if (activeTab === 'leaves') {
      loadLeaves();
    }
  }, [activeTab]);

  // Fetch notifications
  const loadNotifications = async () => {
    try {
      setNotificationsLoading(true);
      const data = await api.get('/notifications/history');
      setNotifications(data);
    } catch (err) {
      toast.error('Failed to load notification history.');
      console.error(err);
    } finally {
      setNotificationsLoading(false);
    }
  };

  useEffect(() => {
    if (activeTab === 'notifications') {
      loadNotifications();
    }
  }, [activeTab]);

  // Apply Leave Handler
  const handleApplyLeave = async (e) => {
    e.preventDefault();
    if (!selectedChild) return;
    if (!fromDate || !toDate || !leaveReason.trim()) {
      toast.error('Please fill in all fields.');
      return;
    }

    try {
      setSubmittingLeave(true);
      await api.post('/leaves', {
        student_id: selectedChild.student_id,
        from_date: fromDate,
        to_date: toDate,
        reason: leaveReason,
      });
      toast.success('Leave request submitted successfully.');
      setShowApplyModal(false);
      setFromDate('');
      setToDate('');
      setLeaveReason('');
      loadLeaves();
    } catch (err) {
      toast.error(err.message || 'Failed to submit leave.');
    } finally {
      setSubmittingLeave(false);
    }
  };

  // Nav items definition
  const navItems = [
    { key: 'home', label: 'Home', icon: <IconHome /> },
    { key: 'feed', label: 'Feed', icon: <IconClipboard /> },
    { key: 'attendance', label: 'Calendar', icon: <IconCalendar /> },
    { key: 'leaves', label: 'Leaves', icon: <IconClipboard /> },
    { key: 'notifications', label: 'Alerts', icon: <IconBell /> },
    { key: 'profile', label: 'Profile', icon: <IconUser /> },
  ];

  // Helper to construct calendar matrix
  const getDaysInMonth = (year, month) => {
    const date = new Date(year, month - 1, 1);
    const days = [];
    // Pad first week
    const firstDayIdx = date.getDay();
    for (let i = 0; i < firstDayIdx; i++) {
      days.push({ day: null, dateStr: null });
    }
    const totalDays = new Date(year, month, 0).getDate();
    for (let i = 1; i <= totalDays; i++) {
      const d = new Date(year, month - 1, i);
      const dateStr = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
      days.push({ day: i, dateStr });
    }
    return days;
  };

  const handlePrevMonth = () => {
    if (calendarMonth === 1) {
      setCalendarMonth(12);
      setCalendarYear((y) => y - 1);
    } else {
      setCalendarMonth((m) => m - 1);
    }
  };

  const handleNextMonth = () => {
    if (calendarMonth === 12) {
      setCalendarMonth(1);
      setCalendarYear((y) => y + 1);
    } else {
      setCalendarMonth((m) => m + 1);
    }
  };

  if (loading) {
    return (
      <div className="page-shell">
        <div className="loading-container">
          <div className="spinner" />
        </div>
      </div>
    );
  }

  return (
    <div className="page-shell">
      {/* Dynamic Header */}
      <header className="app-header-glass">
        <div className="flex justify-between items-center w-full">
          <div>
            <h1 style={{ fontSize: '18px', fontWeight: 'bold' }}>TPS Connect</h1>
            <p style={{ fontSize: '11px', opacity: 0.8 }}>Parent Portal</p>
          </div>
          {children.length > 1 && (
            <select
              value={selectedChild?.student_id || ''}
              onChange={(e) => {
                const child = children.find((c) => c.student_id === e.target.value);
                setSelectedChild(child);
              }}
              style={{
                background: 'rgba(255,255,255,0.2)',
                color: 'white',
                border: '1px solid rgba(255,255,255,0.4)',
                borderRadius: '8px',
                padding: '4px 8px',
                fontSize: '13px',
                outline: 'none',
              }}
            >
              {children.map((c) => (
                <option key={c.student_id} value={c.student_id} style={{ color: 'var(--text-dark)' }}>
                  {c.name}
                </option>
              ))}
            </select>
          )}
        </div>
      </header>

      {/* Main Page Content */}
      <main className="page-content">
        {/* ── HOME TAB ── */}
        {activeTab === 'home' && selectedChild && (
          <div className="flex flex-col gap-16 fade-in">
            {/* Child Card */}
            <div className="card card-glass flex items-center gap-16">
              <div className="avatar avatar-lg">
                {selectedChild.photo_url ? (
                  <img src={selectedChild.photo_url} alt={selectedChild.name} />
                ) : (
                  getInitials(selectedChild.name)
                )}
              </div>
              <div className="flex-col">
                <h2 style={{ fontSize: '18px', fontWeight: 'bold', color: 'var(--text-dark)' }}>
                  {selectedChild.name}
                </h2>
                <p className="text-sm" style={{ color: 'var(--text-light)' }}>
                  {selectedChild.class_name || 'No Class Assigned'} • {selectedChild.branch_name}
                </p>
              </div>
            </div>

            {/* Attendance Quick Stats */}
            <div className="section-header">
              <span className="section-title">This Month's Summary</span>
            </div>

            <div className="stat-grid cols-3">
              <div className="stat-card">
                <div className="stat-value">{childStats?.attendance_percentage || '0'}%</div>
                <div className="stat-label">Attendance</div>
              </div>
              <div className="stat-card">
                <div className="stat-value">{childStats?.days_present || 0}</div>
                <div className="stat-label">Present</div>
              </div>
              <div className="stat-card">
                <div className="stat-value">{childStats?.days_absent || 0}</div>
                <div className="stat-label">Absent</div>
              </div>
            </div>

            {/* Quick Actions */}
            <div className="section-header mt-12">
              <span className="section-title">Quick Actions</span>
            </div>
            <div className="quick-actions">
              <button className="quick-action" onClick={() => setActiveTab('attendance')}>
                <div className="quick-action-icon" style={{ background: 'var(--success-light)', color: 'var(--success)' }}>📅</div>
                <span>View Attendance</span>
              </button>
              <button className="quick-action" onClick={() => { setActiveTab('leaves'); setShowApplyModal(true); }}>
                <div className="quick-action-icon" style={{ background: 'var(--warning-light)', color: 'var(--warning)' }}>📋</div>
                <span>Apply Leave</span>
              </button>
            </div>

            {/* Recent Announcements */}
            <div className="section-header mt-12 flex justify-between items-center" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span className="section-title">Recent Announcements</span>
              <button 
                onClick={() => setActiveTab('feed')}
                style={{ background: 'none', border: 'none', color: 'var(--primary)', fontSize: '13px', fontWeight: '600', cursor: 'pointer' }}
              >
                View All
              </button>
            </div>

            {feedLoading ? (
              <div className="loading-container" style={{ padding: '20px 0' }}><div className="spinner spinner-sm" /></div>
            ) : posts.length === 0 ? (
              <div className="card text-center" style={{ padding: '24px', color: 'var(--text-light)', fontSize: '14px', background: 'white', border: '1px solid var(--accent-border)' }}>
                No recent announcements.
              </div>
            ) : (
              <div className="flex flex-col gap-12" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                {posts.slice(0, 3).map((post) => (
                  <div key={post.post_id} className="post-card fade-in" style={{ padding: '16px', background: 'white', border: '1px solid var(--accent-border)', borderRadius: 'var(--radius-md)' }}>
                    <div className="flex justify-between items-center mb-8" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                      <span className={`post-category ${post.category}`} style={{ fontSize: '11px', padding: '2px 6px' }}>
                        {getCategoryEmoji(post.category)} {getCategoryLabel(post.category)}
                      </span>
                      <span className="text-xs" style={{ color: 'var(--text-hint)' }}>
                        {formatTimeAgo(post.created_at)}
                      </span>
                    </div>
                    <h3 className="font-bold mb-4" style={{ color: 'var(--text-dark)', fontSize: '14px', margin: '4px 0 8px 0', fontWeight: 'bold' }}>
                      {post.title}
                    </h3>
                    <p className="text-xs" style={{ color: 'var(--text-mid)', overflow: 'hidden', textOverflow: 'ellipsis', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', whiteSpace: 'pre-line', fontSize: '12.5px', lineHeight: '1.4' }}>
                      {post.content}
                    </p>
                    <div className="mt-12 pt-8" style={{ marginTop: '12px', paddingTop: '8px', borderTop: '1px solid var(--accent-light)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '11px', color: 'var(--text-light)' }}>
                      <span>By {post.author_name || 'School Admin'}</span>
                      {post.class_name && (
                        <span className="badge badge-info text-xs" style={{ fontSize: '10px', padding: '2px 6px' }}>{post.class_name}</span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ── FEED TAB ── */}
        {activeTab === 'feed' && (
          <div className="flex flex-col gap-16 fade-in">
            {/* Category Filter Chips */}
            <div className="chip-group">
              <button className={`chip${categoryFilter === '' ? ' active' : ''}`} onClick={() => setCategoryFilter('')}>
                All Posts
              </button>
              {['homework', 'circular', 'event', 'photos', 'holiday'].map((cat) => (
                <button
                  key={cat}
                  className={`chip${categoryFilter === cat ? ' active' : ''}`}
                  onClick={() => setCategoryFilter(cat)}
                >
                  {getCategoryEmoji(cat)} {getCategoryLabel(cat)}
                </button>
              ))}
            </div>

            {/* Feed List */}
            {feedLoading ? (
              <div className="loading-container"><div className="spinner spinner-sm" /></div>
            ) : posts.length === 0 ? (
              <div className="empty-state">
                <div className="empty-state-icon">📝</div>
                <div className="empty-state-title">No announcements</div>
                <div className="empty-state-text">Check back later for updates from the school.</div>
              </div>
            ) : (
              <div className="flex flex-col gap-12">
                {posts.map((post) => (
                  <div key={post.post_id} className="post-card fade-in">
                    <div className="flex justify-between items-center mb-8">
                      <span className={`post-category ${post.category}`}>
                        {getCategoryEmoji(post.category)} {getCategoryLabel(post.category)}
                      </span>
                      <span className="text-xs" style={{ color: 'var(--text-hint)' }}>
                        {formatTimeAgo(post.created_at)}
                      </span>
                    </div>
                    <h3 className="font-bold mb-8" style={{ color: 'var(--text-dark)', fontSize: '15px' }}>
                      {post.title}
                    </h3>
                    <p className="text-sm" style={{ color: 'var(--text-mid)', whiteSpace: 'pre-line' }}>
                      {post.content}
                    </p>
                    {post.file_urls && post.file_urls.length > 0 && (
                      <div className="mt-8 flex gap-8 overflow-x-auto">
                        {post.file_urls.map((url, idx) => (
                          <a
                            key={idx}
                            href={url}
                            target="_blank"
                            rel="noopener noreferrer"
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: '6px',
                              padding: '6px 10px',
                              background: 'var(--bg)',
                              border: '1px solid var(--accent-border)',
                              borderRadius: '8px',
                              fontSize: '12px',
                              color: 'var(--primary)',
                            }}
                          >
                            📎 File {idx + 1}
                          </a>
                        ))}
                      </div>
                    )}
                    <div className="mt-12 pt-8" style={{ borderTop: '1px solid var(--accent-light)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span className="text-xs font-semibold" style={{ color: 'var(--text-light)' }}>
                        By {post.author_name || 'School Admin'}
                      </span>
                      {post.class_name && (
                        <span className="badge badge-info text-xs">{post.class_name}</span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ── ATTENDANCE CALENDAR TAB ── */}
        {activeTab === 'attendance' && selectedChild && (
          <div className="flex flex-col gap-16 fade-in">
            {/* Header Calendar controls */}
            <div className="card flex items-center justify-between">
              <button className="btn-icon" onClick={handlePrevMonth} style={{ background: 'none', border: 'none', color: 'var(--primary)' }}>
                ◀
              </button>
              <h3 className="font-bold" style={{ color: 'var(--text-dark)' }}>
                {MONTHS[calendarMonth - 1]} {calendarYear}
              </h3>
              <button className="btn-icon" onClick={handleNextMonth} style={{ background: 'none', border: 'none', color: 'var(--primary)' }}>
                ▶
              </button>
            </div>

            {/* Attendance Summary */}
            <div className="stat-grid cols-3">
              <div className="stat-card">
                <div className="stat-value" style={{ color: 'var(--success)' }}>
                  {attendanceSummary?.days_present || 0}
                </div>
                <div className="stat-label">Present</div>
              </div>
              <div className="stat-card">
                <div className="stat-value" style={{ color: 'var(--error)' }}>
                  {attendanceSummary?.days_absent || 0}
                </div>
                <div className="stat-label">Absent</div>
              </div>
              <div className="stat-card">
                <div className="stat-value" style={{ color: 'var(--warning)' }}>
                  {attendanceSummary?.days_on_leave || 0}
                </div>
                <div className="stat-label">On Leave</div>
              </div>
            </div>

            {/* Calendar Grid */}
            <div className="card">
              {attendanceLoading ? (
                <div className="loading-container"><div className="spinner spinner-sm" /></div>
              ) : (
                <div className="calendar-grid">
                  {/* Days headers */}
                  {DAYS.map((d) => (
                    <div key={d} className="calendar-day-header">
                      {d}
                    </div>
                  ))}
                  {/* Calendar Days */}
                  {getDaysInMonth(calendarYear, calendarMonth).map((cell, idx) => {
                    if (!cell.day) return <div key={idx} className="calendar-day empty" />;

                    // Find record
                    const rec = attendanceRecords.find(
                      (r) => new Date(r.date).toISOString().split('T')[0] === cell.dateStr
                    );

                    let statusClass = '';
                    if (rec?.status === 'present') statusClass = ' present';
                    else if (rec?.status === 'absent') statusClass = ' absent';
                    else if (rec?.status === 'on_leave') statusClass = ' on_leave';

                    // Is today
                    const isToday = new Date().toISOString().split('T')[0] === cell.dateStr;

                    return (
                      <div key={idx} className={`calendar-day${statusClass}${isToday ? ' today' : ''}`}>
                        {cell.day}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>

            {/* Legend */}
            <div className="flex gap-16 justify-center text-xs">
              <span className="flex items-center gap-4">
                <span className="status-dot present" /> Present
              </span>
              <span className="flex items-center gap-4">
                <span className="status-dot absent" /> Absent
              </span>
              <span className="flex items-center gap-4">
                <span className="status-dot on_leave" /> Leave
              </span>
            </div>
          </div>
        )}

        {/* ── LEAVE MANAGEMENT TAB ── */}
        {activeTab === 'leaves' && (
          <div className="flex flex-col gap-16 fade-in">
            <div className="section-header">
              <span className="section-title">Leave History</span>
              <button
                id="apply-leave-btn"
                className="btn btn-outline btn-sm flex items-center gap-4"
                onClick={() => setShowApplyModal(true)}
              >
                <IconPlus size={16} /> Apply Leave
              </button>
            </div>

            {leaveLoading ? (
              <div className="loading-container"><div className="spinner spinner-sm" /></div>
            ) : leaves.length === 0 ? (
              <div className="empty-state">
                <div className="empty-state-icon">📋</div>
                <div className="empty-state-title">No leave requests</div>
                <div className="empty-state-text">You haven't submitted any leave requests yet.</div>
              </div>
            ) : (
              <div className="flex flex-col gap-12">
                {leaves.map((leave) => (
                  <div key={leave.leave_id} className="card fade-in">
                    <div className="flex justify-between items-center mb-8">
                      <span className="font-bold text-sm" style={{ color: 'var(--text-dark)' }}>
                        {leave.student_name}
                      </span>
                      <span className={`badge badge-${leave.status}`}>
                        {leave.status}
                      </span>
                    </div>
                    <p className="text-sm font-semibold" style={{ color: 'var(--primary)' }}>
                      📅 {formatDateShort(leave.from_date)} to {formatDateShort(leave.to_date)}
                    </p>
                    <p className="text-sm mt-4" style={{ color: 'var(--text-mid)' }}>
                      <strong>Reason:</strong> {leave.reason}
                    </p>
                    {leave.reviewer_name && (
                      <div className="mt-8 pt-8 text-xs" style={{ borderTop: '1px solid var(--accent-light)', color: 'var(--text-light)' }}>
                        <strong>Reviewed By:</strong> {leave.reviewer_name}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}

            {/* Modal for applying leave */}
            <Modal open={showApplyModal} onClose={() => setShowApplyModal(false)} title="Apply Leave">
              <form onSubmit={handleApplyLeave} className="flex flex-col gap-16">
                <div className="input-group">
                  <label htmlFor="leave-student">Student</label>
                  <input
                    id="leave-student"
                    type="text"
                    className="input"
                    value={selectedChild?.name || ''}
                    disabled
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="leave-from">From Date</label>
                  <input
                    id="leave-from"
                    type="date"
                    className="input"
                    value={fromDate}
                    onChange={(e) => setFromDate(e.target.value)}
                    required
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="leave-to">To Date</label>
                  <input
                    id="leave-to"
                    type="date"
                    className="input"
                    value={toDate}
                    onChange={(e) => setToDate(e.target.value)}
                    required
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="leave-reason">Reason</label>
                  <textarea
                    id="leave-reason"
                    className="input"
                    value={leaveReason}
                    onChange={(e) => setLeaveReason(e.target.value)}
                    placeholder="Provide details about the absence"
                    required
                  />
                </div>
                <button id="submit-leave-btn" type="submit" className="btn btn-primary" disabled={submittingLeave}>
                  {submittingLeave ? <div className="spinner spinner-sm" style={{ borderTopColor: 'white' }} /> : 'Submit Request'}
                </button>
              </form>
            </Modal>
          </div>
        )}

        {/* ── NOTIFICATIONS HISTORY TAB ── */}
        {activeTab === 'notifications' && (
          <div className="flex flex-col gap-16 fade-in">
            <div className="section-header">
              <span className="section-title">Notification History</span>
            </div>

            {notificationsLoading ? (
              <div className="loading-container"><div className="spinner spinner-sm" /></div>
            ) : notifications.length === 0 ? (
              <div className="empty-state">
                <div className="empty-state-icon">🔔</div>
                <div className="empty-state-title">No notifications</div>
                <div className="empty-state-text">You haven't received any alerts or notifications yet.</div>
              </div>
            ) : (
              <div className="flex flex-col gap-12">
                {notifications.map((notif) => (
                  <div key={notif.notification_id} className="card fade-in">
                    <div className="flex justify-between items-center mb-4">
                      <span className="font-bold text-sm" style={{ color: 'var(--text-dark)' }}>
                        {notif.title}
                      </span>
                      <span className="text-xs" style={{ color: 'var(--text-hint)' }}>
                        {formatTimeAgo(notif.sent_at)}
                      </span>
                    </div>
                    <p className="text-sm" style={{ color: 'var(--text-mid)', whiteSpace: 'pre-line' }}>
                      {notif.body}
                    </p>
                    <div className="mt-8 text-xs font-semibold" style={{ color: 'var(--text-hint)', textAlign: 'right' }}>
                      Sent by: {notif.sent_by_name || 'Admin'}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ── PROFILE TAB ── */}
        {activeTab === 'profile' && profile && (
          <div className="flex flex-col gap-16 fade-in">
            <div className="card profile-section">
              <div className="avatar avatar-lg" style={{ width: '80px', height: '80px', fontSize: '32px' }}>
                {getInitials(profile.name)}
              </div>
              <h2 className="profile-name">{profile.name}</h2>
              <span className="profile-role">Parent Portfolio</span>
            </div>

            <div className="card flex flex-col">
              <div className="profile-item">
                <span className="text-sm font-semibold" style={{ width: '100px', color: 'var(--text-hint)' }}>
                  Email
                </span>
                <span className="text-sm" style={{ color: 'var(--text-dark)' }}>
                  {auth.currentUser?.email || 'N/A'}
                </span>
              </div>
              <div className="profile-item">
                <span className="text-sm font-semibold" style={{ width: '100px', color: 'var(--text-hint)' }}>
                  Mobile
                </span>
                <span className="text-sm" style={{ color: 'var(--text-dark)' }}>
                  {profile.phone || 'N/A'}
                </span>
              </div>
              <div className="profile-item">
                <span className="text-sm font-semibold" style={{ width: '100px', color: 'var(--text-hint)' }}>
                  Branch
                </span>
                <span className="text-sm" style={{ color: 'var(--text-dark)' }}>
                  {profile.branch_name || 'N/A'}
                </span>
              </div>
            </div>

            <button
              id="logout-btn"
              className="btn btn-outline flex items-center justify-center gap-8 mt-12"
              onClick={() => auth.signOut()}
              style={{ borderColor: 'var(--error)', color: 'var(--error)' }}
            >
              <IconLogOut size={18} /> Log Out
            </button>
          </div>
        )}
      </main>

      {/* Bottom Navigation */}
      <BottomNav items={navItems} active={activeTab} onNavigate={(key) => setActiveTab(key)} />
    </div>
  );
}
