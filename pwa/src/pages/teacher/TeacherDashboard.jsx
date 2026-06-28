import { useState, useEffect } from 'react';
import { auth } from '../../config/firebase.js';
import { useAuth } from '../../contexts/AuthContext.jsx';
import { useToast } from '../../components/Toast.jsx';
import api from '../../services/api.js';
import BottomNav from '../../components/BottomNav.jsx';
import {
  IconHome,
  IconCalendar,
  IconPlus,
  IconUser,
  IconLogOut,
} from '../../components/Icons.jsx';
import { getInitials } from '../../utils/helpers.js';

export default function TeacherDashboard() {
  const { profile } = useAuth();
  const toast = useToast();

  const [activeTab, setActiveTab] = useState('home');
  const [classes, setClasses] = useState([]);
  const [selectedClass, setSelectedClass] = useState(null);
  const [students, setStudents] = useState([]);
  const [studentsLoading, setStudentsLoading] = useState(false);
  const [loading, setLoading] = useState(true);

  // Attendance Tab
  const today = new Date();
  const [attendanceDate, setAttendanceDate] = useState(
    `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`
  );
  const [attendanceRecords, setAttendanceRecords] = useState({}); // student_id -> status ('present', 'absent', 'on_leave')
  const [savingAttendance, setSavingAttendance] = useState(false);
  const [attendanceStats, setAttendanceStats] = useState({ present: 0, absent: 0, on_leave: 0 });

  // Post Tab
  const [postTitle, setPostTitle] = useState('');
  const [postCategory, setPostCategory] = useState('homework');
  const [postContent, setPostContent] = useState('');
  const [uploadingFile, setUploadingFile] = useState(false);
  const [fileUrls, setFileUrls] = useState([]);
  const [publishingPost, setPublishingPost] = useState(false);

  // Fetch classes on load
  useEffect(() => {
    async function loadInitialData() {
      try {
        setLoading(true);
        const classData = await api.get('/classes');
        setClasses(classData);

        // Auto select teacher's assigned class if it exists in the list
        if (classData.length > 0) {
          const matched = classData.find((c) => c.class_id === profile?.class_id) || classData[0];
          setSelectedClass(matched);
        }
      } catch (err) {
        toast.error('Failed to load classes.');
        console.error(err);
      } finally {
        setLoading(false);
      }
    }
    loadInitialData();
  }, [profile]);

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

  // Fetch students when class changes
  useEffect(() => {
    if (!selectedClass) return;

    async function loadStudents() {
      try {
        setStudentsLoading(true);
        const data = await api.get(`/students?class_id=${selectedClass.class_id}`);
        setStudents(data);

        // Load today's or selected date's attendance if it exists
        const attData = await api.get(`/attendance/class?class_id=${selectedClass.class_id}&date=${attendanceDate}`);

        const initialRecords = {};
        let present = 0, absent = 0, on_leave = 0;

        // Populate initialRecords with existing records, default to 'present' if unmarked
        data.forEach((s) => {
          const match = attData.find((a) => a.student_id === s.student_id);
          const status = match?.status || 'present';
          initialRecords[s.student_id] = status;

          if (status === 'present') present++;
          else if (status === 'absent') absent++;
          else if (status === 'on_leave') on_leave++;
        });

        setAttendanceRecords(initialRecords);
        setAttendanceStats({ present, absent, on_leave });
      } catch (err) {
        toast.error('Failed to load class students.');
        console.error(err);
      } finally {
        setStudentsLoading(false);
      }
    }
    loadStudents();
  }, [selectedClass, attendanceDate]);

  // Handle Attendance Change
  const handleStatusChange = (studentId, status) => {
    setAttendanceRecords((prev) => {
      const updated = { ...prev, [studentId]: status };

      // Recompute stats
      let present = 0, absent = 0, on_leave = 0;
      students.forEach((s) => {
        const currStatus = updated[s.student_id] || 'present';
        if (currStatus === 'present') present++;
        else if (currStatus === 'absent') absent++;
        else if (currStatus === 'on_leave') on_leave++;
      });
      setAttendanceStats({ present, absent, on_leave });

      return updated;
    });
  };

  // Submit Attendance
  const submitAttendance = async () => {
    if (!selectedClass) return;
    try {
      setSavingAttendance(true);
      const recordsArray = Object.entries(attendanceRecords).map(([student_id, status]) => ({
        student_id,
        status,
      }));

      await api.post('/attendance/mark', {
        class_id: selectedClass.class_id,
        date: attendanceDate,
        records: recordsArray,
      });

      toast.success('Attendance updated successfully.');
    } catch (err) {
      toast.error(err.message || 'Failed to submit attendance.');
    } finally {
      setSavingAttendance(false);
    }
  };

  // Handle File Upload
  const handleFileUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;

    try {
      setUploadingFile(true);
      const data = await api.upload(file);
      setFileUrls((prev) => [...prev, data.url]);
      toast.success('File uploaded successfully.');
    } catch (err) {
      toast.error('File upload failed.');
      console.error(err);
    } finally {
      setUploadingFile(false);
    }
  };

  // Create Announcement/Post
  const handleCreatePost = async (e) => {
    e.preventDefault();
    if (!postTitle.trim() || !postContent.trim()) {
      toast.error('Please fill in title and content.');
      return;
    }

    try {
      setPublishingPost(true);
      await api.post('/posts', {
        title: postTitle,
        content: postContent,
        category: postCategory,
        class_id: selectedClass?.class_id || null,
        file_urls: fileUrls,
      });

      toast.success('Post published successfully.');
      setPostTitle('');
      setPostContent('');
      setFileUrls([]);
      setActiveTab('home');
    } catch (err) {
      toast.error(err.message || 'Failed to publish post.');
    } finally {
      setPublishingPost(false);
    }
  };

  const navItems = [
    { key: 'home', label: 'Home', icon: <IconHome /> },
    { key: 'attendance', label: 'Attendance', icon: <IconCalendar /> },
    { key: 'post', label: 'Announce', icon: <IconPlus /> },
    { key: 'profile', label: 'Profile', icon: <IconUser /> },
  ];

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
      {/* Header */}
      <header className="app-header-glass">
        <div className="flex justify-between items-center w-full">
          <div>
            <h1 style={{ fontSize: '18px', fontWeight: 'bold' }}>TPS Connect</h1>
            <p style={{ fontSize: '11px', opacity: 0.8 }}>Teacher Portal</p>
          </div>
          {classes.length > 0 && activeTab === 'attendance' && (
            <select
              value={selectedClass?.class_id || ''}
              onChange={(e) => {
                const cls = classes.find((c) => c.class_id === e.target.value);
                setSelectedClass(cls);
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
              {classes.map((c) => (
                <option key={c.class_id} value={c.class_id} style={{ color: 'var(--text-dark)' }}>
                  {c.class_name}
                </option>
              ))}
            </select>
          )}
        </div>
      </header>

      {/* Content */}
      <main className="page-content">
        {/* ── HOME TAB ── */}
        {activeTab === 'home' && (
          <div className="flex flex-col gap-16 fade-in">
            {/* Teacher Details */}
            <div className="card card-glass">
              <h2 style={{ fontSize: '20px', fontWeight: 'bold', color: 'var(--text-dark)' }}>
                Welcome back, {profile?.name}!
              </h2>
              <p className="text-sm" style={{ color: 'var(--text-light)', marginTop: '4px' }}>
                Assigned Class: {selectedClass?.class_name || 'No Class Assigned'} • {profile?.branch_name}
              </p>
            </div>

            {/* Quick Stats */}
            <div className="section-header">
              <span className="section-title">Today's Class Activity</span>
            </div>

            <div className="stat-grid cols-3">
              <div className="stat-card">
                <div className="stat-value">{students.length}</div>
                <div className="stat-label">Total Students</div>
              </div>
              <div className="stat-card">
                <div className="stat-value" style={{ color: 'var(--success)' }}>
                  {attendanceStats.present}
                </div>
                <div className="stat-label">Present</div>
              </div>
              <div className="stat-card">
                <div className="stat-value" style={{ color: 'var(--error)' }}>
                  {attendanceStats.absent}
                </div>
                <div className="stat-label">Absent</div>
              </div>
            </div>

            {/* Fast Actions */}
            <div className="section-header mt-12">
              <span className="section-title">Class Utilities</span>
            </div>
            <div className="quick-actions">
              <button className="quick-action" onClick={() => setActiveTab('attendance')}>
                <div className="quick-action-icon" style={{ background: 'var(--success-light)', color: 'var(--success)' }}>📅</div>
                <span>Mark Attendance</span>
              </button>
              <button className="quick-action" onClick={() => setActiveTab('post')}>
                <div className="quick-action-icon" style={{ background: 'var(--info-light)', color: 'var(--info)' }}>📢</div>
                <span>New Announcement</span>
              </button>
            </div>
          </div>
        )}

        {/* ── ATTENDANCE TAB ── */}
        {activeTab === 'attendance' && selectedClass && (
          <div className="flex flex-col gap-16 fade-in">
            {/* Date selector */}
            <div className="card flex items-center justify-between gap-12">
              <span className="text-sm font-semibold" style={{ color: 'var(--text-dark)' }}>
                Attendance Date
              </span>
              <input
                id="att-date"
                type="date"
                className="input"
                style={{ width: 'auto', padding: '8px 12px' }}
                value={attendanceDate}
                onChange={(e) => setAttendanceDate(e.target.value)}
              />
            </div>

            {/* Attendance Toggle Grid Header */}
            <div className="section-header">
              <span className="section-title">Class Roll Call</span>
              <span className="text-xs" style={{ color: 'var(--text-hint)' }}>
                {students.length} students
              </span>
            </div>

            {/* Students List */}
            {studentsLoading ? (
              <div className="loading-container"><div className="spinner spinner-sm" /></div>
            ) : students.length === 0 ? (
              <div className="empty-state">
                <div className="empty-state-icon">👤</div>
                <div className="empty-state-title">No students found</div>
                <div className="empty-state-text">Ask your administrator to add students to this class.</div>
              </div>
            ) : (
              <div className="flex flex-col gap-8">
                {students.map((student) => {
                  const status = attendanceRecords[student.student_id] || 'present';
                  return (
                    <div key={student.student_id} className="list-item">
                      <div className="avatar">
                        {student.photo_url ? (
                          <img src={student.photo_url} alt={student.name} />
                        ) : (
                          getInitials(student.name)
                        )}
                      </div>
                      <div className="list-item-content">
                        <div className="list-item-title">{student.name}</div>
                      </div>
                      <div className="attendance-toggle">
                        <button
                          className={`att-btn${status === 'present' ? ' present-active' : ''}`}
                          onClick={() => handleStatusChange(student.student_id, 'present')}
                        >
                          P
                        </button>
                        <button
                          className={`att-btn${status === 'absent' ? ' absent-active' : ''}`}
                          onClick={() => handleStatusChange(student.student_id, 'absent')}
                        >
                          A
                        </button>
                        <button
                          className={`att-btn${status === 'on_leave' ? ' leave-active' : ''}`}
                          onClick={() => handleStatusChange(student.student_id, 'on_leave')}
                        >
                          L
                        </button>
                      </div>
                    </div>
                  );
                })}

                <button
                  id="save-attendance-btn"
                  className="btn btn-primary mt-16"
                  onClick={submitAttendance}
                  disabled={savingAttendance}
                >
                  {savingAttendance ? <div className="spinner spinner-sm" style={{ borderTopColor: 'white' }} /> : 'Save Attendance'}
                </button>
              </div>
            )}
          </div>
        )}

        {/* ── CREATE ANNOUNCEMENT / POST TAB ── */}
        {activeTab === 'post' && (
          <div className="flex flex-col gap-16 fade-in">
            <div className="section-header">
              <span className="section-title">New Announcement</span>
            </div>

            <form onSubmit={handleCreatePost} className="card flex flex-col gap-16">
              <div className="input-group">
                <label htmlFor="post-title">Title</label>
                <input
                  id="post-title"
                  type="text"
                  className="input"
                  placeholder="e.g. Bring art materials tomorrow"
                  value={postTitle}
                  onChange={(e) => setPostTitle(e.target.value)}
                  required
                />
              </div>

              <div className="input-group">
                <label htmlFor="post-category">Category</label>
                <select
                  id="post-category"
                  className="input"
                  value={postCategory}
                  onChange={(e) => setPostCategory(e.target.value)}
                >
                  <option value="homework">📝 Homework</option>
                  <option value="circular">📋 Circular</option>
                  <option value="event">🎉 Event</option>
                  <option value="photos">📸 Photos</option>
                  <option value="holiday">🎄 Holiday</option>
                </select>
              </div>

              <div className="input-group">
                <label htmlFor="post-content">Message Details</label>
                <textarea
                  id="post-content"
                  className="input"
                  placeholder="Write clear instructions for parents..."
                  value={postContent}
                  onChange={(e) => setPostContent(e.target.value)}
                  style={{ minHeight: '120px' }}
                  required
                />
              </div>

              <div className="input-group">
                <label htmlFor="post-upload">Attachments (Optional)</label>
                <input
                  id="post-upload"
                  type="file"
                  onChange={handleFileUpload}
                  style={{ display: 'none' }}
                />
                <button
                  type="button"
                  className="btn btn-outline flex items-center justify-center gap-8 w-full"
                  onClick={() => document.getElementById('post-upload').click()}
                  disabled={uploadingFile}
                >
                  {uploadingFile ? <div className="spinner spinner-sm" /> : '📎 Upload File/Photo'}
                </button>
                {fileUrls.length > 0 && (
                  <div className="mt-8 text-xs text-hint flex flex-col gap-4">
                    {fileUrls.map((url, idx) => (
                      <span key={idx}>✅ File uploaded: File {idx + 1}</span>
                    ))}
                  </div>
                )}
              </div>

              <button id="publish-post-btn" type="submit" className="btn btn-primary" disabled={publishingPost}>
                {publishingPost ? <div className="spinner spinner-sm" style={{ borderTopColor: 'white' }} /> : 'Publish Announcement'}
              </button>
            </form>
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
              <span className="profile-role">Academic Teacher</span>
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
                  Assigned
                </span>
                <span className="text-sm" style={{ color: 'var(--text-dark)' }}>
                  {selectedClass?.class_name || 'N/A'}
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

      {/* Bottom Nav */}
      <BottomNav items={navItems} active={activeTab} onNavigate={(key) => setActiveTab(key)} />
    </div>
  );
}
