import { useState, useEffect } from 'react';
import { auth } from '../../config/firebase.js';
import { useAuth } from '../../contexts/AuthContext.jsx';
import { useToast } from '../../components/Toast.jsx';
import api from '../../services/api.js';
import Modal from '../../components/Modal.jsx';
import {
  IconHome,
  IconCalendar,
  IconPlus,
  IconUser,
  IconLogOut,
  IconChevronLeft,
  IconSend,
  IconTrash,
} from '../../components/Icons.jsx';
import { getInitials, formatDate, formatTimeAgo } from '../../utils/helpers.js';

export default function BranchAdminDashboard() {
  const { profile } = useAuth();
  const toast = useToast();

  const [view, setView] = useState('home'); // 'home' | 'students' | 'teachers' | 'classes' | 'leaves' | 'attendance' | 'broadcast' | 'posts' | 'logs' | 'profile'
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);

  // Admin-level attendance taking states
  const [selectedAttendanceClass, setSelectedAttendanceClass] = useState(null);
  const todayAdmin = new Date();
  const [adminAttendanceDate, setAdminAttendanceDate] = useState(
    `${todayAdmin.getFullYear()}-${String(todayAdmin.getMonth() + 1).padStart(2, '0')}-${String(todayAdmin.getDate()).padStart(2, '0')}`
  );
  const [adminAttendanceStudents, setAdminAttendanceStudents] = useState([]);
  const [adminAttendanceRecords, setAdminAttendanceRecords] = useState({});
  const [adminStudentsLoading, setAdminStudentsLoading] = useState(false);
  const [adminSavingAttendance, setAdminSavingAttendance] = useState(false);

  // Fetch students & previous attendance for selected class & date in admin attendance sub-view
  useEffect(() => {
    if (!selectedAttendanceClass) return;

    async function loadClassAttendance() {
      try {
        setAdminStudentsLoading(true);
        // 1. Fetch class students
        const stData = await api.get(`/students?class_id=${selectedAttendanceClass.class_id}`);
        setAdminAttendanceStudents(stData);

        // 2. Fetch existing attendance records for date
        const attData = await api.get(`/attendance/class?class_id=${selectedAttendanceClass.class_id}&date=${adminAttendanceDate}`);

        const initialRecords = {};
        stData.forEach((s) => {
          const match = attData.find((a) => a.student_id === s.student_id);
          initialRecords[s.student_id] = match?.status || 'present'; // default present
        });
        setAdminAttendanceRecords(initialRecords);
      } catch (err) {
        toast.error('Failed to load class roll call roster.');
        console.error(err);
      } finally {
        setAdminStudentsLoading(false);
      }
    }
    loadClassAttendance();
  }, [selectedAttendanceClass, adminAttendanceDate]);

  const handleAdminStatusChange = (studentId, status) => {
    setAdminAttendanceRecords((prev) => ({
      ...prev,
      [studentId]: status
    }));
  };

  const handleAdminSaveAttendance = async () => {
    if (!selectedAttendanceClass) return;
    try {
      setAdminSavingAttendance(true);
      const recordsArray = Object.entries(adminAttendanceRecords).map(([student_id, status]) => ({
        student_id,
        status,
      }));

      await api.post('/attendance/mark', {
        class_id: selectedAttendanceClass.class_id,
        date: adminAttendanceDate,
        records: recordsArray,
      });

      toast.success(`Attendance for ${selectedAttendanceClass.class_name} saved successfully.`);
      
      // Reload stats & overview
      const todayStr = new Date().toISOString().split('T')[0];
      const att = await api.get(`/attendance/overview/branch?date=${todayStr}`);
      setAttendanceOverview(att);

      // Return to main overview sub-view
      setSelectedAttendanceClass(null);
    } catch (err) {
      toast.error(err.message || 'Failed to submit attendance.');
    } finally {
      setAdminSavingAttendance(false);
    }
  };

  const formatLogDescription = (log) => {
    const action = log.action.toUpperCase();
    const meta = log.meta || {};
    
    switch (action) {
      case 'MARK_ATTENDANCE':
        const dateStr = meta.date ? formatDate(meta.date) : 'today';
        const count = meta.count || (meta.students ? meta.students.length : 0);
        return `Marked roll-call attendance for ${count} students on ${dateStr}.`;
      case 'CREATE_POST':
        const cat = meta.category ? meta.category.charAt(0).toUpperCase() + meta.category.slice(1) : 'Announcement';
        return `Published a new ${cat}: "${meta.title || 'Untitled'}".`;
      case 'CREATE_BRANCH_ADMIN':
        return `Created a new Branch Administrator account for ${meta.name || 'user'}.`;
      case 'CREATE_TEACHER':
      case 'ADD_TEACHER':
        return `Registered new teacher "${meta.name || 'Faculty'}" for class.`;
      case 'CREATE_STUDENT':
      case 'ADD_STUDENT':
        return `Registered new student profile "${meta.name || 'Child'}".`;
      case 'LINK_PARENT':
        return `Linked parent "${meta.parent_name || 'Parent'}" to student profile.`;
      case 'CREATE_CLASS':
        return `Created new preschool grade section "${meta.class_name || 'Class'}".`;
      case 'DELETE_CLASS':
        return `Removed grade class section.`;
      case 'DEACTIVATE_STUDENT':
        return `Deactivated student profile.`;
      case 'DEACTIVATE_TEACHER':
        return `Deactivated teacher profile.`;
      case 'REVIEW_LEAVE':
        return `Reviewed leave request: set status to "${meta.status || 'reviewed'}".`;
      case 'SEND_BROADCAST':
      case 'BROADCAST_FCM':
        return `Sent branch-wide push alert: "${meta.title || 'Broadcast'}".`;
      default:
        return `${log.action.replace(/_/g, ' ').toLowerCase()}`;
    }
  };

  // Common collections
  const [students, setStudents] = useState([]);
  const [teachers, setTeachers] = useState([]);
  const [classes, setClasses] = useState([]);
  const [leaves, setLeaves] = useState([]);
  const [attendanceOverview, setAttendanceOverview] = useState([]);
  const [logs, setLogs] = useState([]);

  // Loading flags
  const [subLoading, setSubLoading] = useState(false);

  // Modal open states
  const [showAddStudent, setShowAddStudent] = useState(false);
  const [showLinkParent, setShowLinkParent] = useState(false);
  const [showAddTeacher, setShowAddTeacher] = useState(false);
  const [showAddClass, setShowAddClass] = useState(false);

  // Form Fields - Student
  const [studentName, setStudentName] = useState('');
  const [studentDob, setStudentDob] = useState('');
  const [studentPhoto, setStudentPhoto] = useState('');
  const [studentClassId, setStudentClassId] = useState('');
  const [studentEmergency, setStudentEmergency] = useState('');
  const [studentMedical, setStudentMedical] = useState('');

  // Parent linking fields
  const [activeStudentId, setActiveStudentId] = useState('');
  const [parentName, setParentName] = useState('');
  const [parentEmail, setParentEmail] = useState('');
  const [parentPhone, setParentPhone] = useState('');

  // Form Fields - Teacher
  const [teacherName, setTeacherName] = useState('');
  const [teacherEmail, setTeacherEmail] = useState('');
  const [teacherPhone, setTeacherPhone] = useState('');
  const [teacherPassword, setTeacherPassword] = useState('');
  const [teacherClassId, setTeacherClassId] = useState('');

  // Form Fields - Class
  const [className, setClassName] = useState('');

  // Form Fields - Broadcast
  const [broadcastTitle, setBroadcastTitle] = useState('');
  const [broadcastBody, setBroadcastBody] = useState('');
  const [broadcastClassId, setBroadcastClassId] = useState('');
  const [sendingBroadcast, setSendingBroadcast] = useState(false);

  // Form Fields - Post (Schedule)
  const [postTitle, setPostTitle] = useState('');
  const [postCategory, setPostCategory] = useState('homework');
  const [postContent, setPostContent] = useState('');
  const [postClassId, setPostClassId] = useState('');
  const [postScheduledAt, setPostScheduledAt] = useState('');
  const [publishingPost, setPublishingPost] = useState(false);

  // Fetch branch stats on load
  const loadStats = async () => {
    try {
      setLoading(true);
      const data = await api.get('/reports/branch-stats');
      setStats(data);
    } catch (err) {
      console.error('Failed to load branch stats:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadStats();
  }, []);

  // Sync view state with browser history for back button optimization
  useEffect(() => {
    if (view !== 'home' && (!window.history.state || window.history.state.view !== view)) {
      window.history.pushState({ view }, '');
    }
  }, [view]);

  useEffect(() => {
    const handlePopState = (event) => {
      if (event.state && event.state.view) {
        setView(event.state.view);
      } else {
        setView('home');
      }
    };
    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, []);

  // View switch triggers loader
  useEffect(() => {
    if (view === 'home') {
      loadStats();
      return;
    }

    async function loadViewData() {
      try {
        setSubLoading(true);
        if (view === 'students') {
          const st = await api.get('/students');
          setStudents(st);
          const cl = await api.get('/classes');
          setClasses(cl);
        } else if (view === 'teachers') {
          const tc = await api.get('/teachers');
          setTeachers(tc);
          const cl = await api.get('/classes');
          setClasses(cl);
        } else if (view === 'classes') {
          const cl = await api.get('/classes');
          setClasses(cl);
        } else if (view === 'leaves') {
          const lv = await api.get('/leaves');
          setLeaves(lv);
        } else if (view === 'attendance') {
          const todayStr = new Date().toISOString().split('T')[0];
          const att = await api.get(`/attendance/overview/branch?date=${todayStr}`);
          setAttendanceOverview(att);
          const cl = await api.get('/classes');
          setClasses(cl);
        } else if (view === 'broadcast') {
          const cl = await api.get('/classes');
          setClasses(cl);
        } else if (view === 'posts') {
          const cl = await api.get('/classes');
          setClasses(cl);
        } else if (view === 'logs') {
          const lg = await api.get('/logs');
          setLogs(lg);
        }
      } catch (err) {
        toast.error(`Failed to load data for ${view}`);
        console.error(err);
      } finally {
        setSubLoading(false);
      }
    }
    loadViewData();
  }, [view]);

  // Actions handlers
  const handleAddStudent = async (e) => {
    e.preventDefault();
    if (!studentName || !studentClassId) {
      toast.error('Name and class selection are required.');
      return;
    }
    try {
      setSubLoading(true);
      await api.post('/students', {
        name: studentName,
        dob: studentDob || null,
        photo_url: studentPhoto || null,
        class_id: studentClassId,
        emergency_contact: studentEmergency || null,
        medical_notes: studentMedical || null,
      });
      toast.success('Student added successfully.');
      setShowAddStudent(false);
      // Reset fields
      setStudentName('');
      setStudentDob('');
      setStudentPhoto('');
      setStudentClassId('');
      setStudentEmergency('');
      setStudentMedical('');
      // Reload
      const st = await api.get('/students');
      setStudents(st);
    } catch (err) {
      toast.error(err.message || 'Failed to add student.');
    } finally {
      setSubLoading(false);
    }
  };

  const handleLinkParent = async (e) => {
    e.preventDefault();
    if (!parentName || !parentEmail || !parentPhone) {
      toast.error('All parent fields are required.');
      return;
    }
    try {
      setSubLoading(true);
      await api.post('/parents', {
        name: parentName,
        email: parentEmail,
        phone: parentPhone,
        student_id: activeStudentId,
      });
      toast.success('Parent account created and linked successfully.');
      setShowLinkParent(false);
      setParentName('');
      setParentEmail('');
      setParentPhone('');
    } catch (err) {
      toast.error(err.message || 'Failed to link parent.');
    } finally {
      setSubLoading(false);
    }
  };

  const handleAddTeacher = async (e) => {
    e.preventDefault();
    if (!teacherName || !teacherEmail || !teacherPassword) {
      toast.error('Name, email, and password are required.');
      return;
    }
    try {
      setSubLoading(true);
      await api.post('/teachers', {
        name: teacherName,
        email: teacherEmail,
        phone: teacherPhone || null,
        password: teacherPassword,
        class_id: teacherClassId || null,
      });
      toast.success('Teacher added successfully.');
      setShowAddTeacher(false);
      setTeacherName('');
      setTeacherEmail('');
      setTeacherPhone('');
      setTeacherPassword('');
      setTeacherClassId('');
      // Reload
      const tc = await api.get('/teachers');
      setTeachers(tc);
    } catch (err) {
      toast.error(err.message || 'Failed to add teacher.');
    } finally {
      setSubLoading(false);
    }
  };

  const handleAddClass = async (e) => {
    e.preventDefault();
    if (!className.trim()) return;
    try {
      setSubLoading(true);
      await api.post('/classes', { class_name: className });
      toast.success('Class created successfully.');
      setShowAddClass(false);
      setClassName('');
      const cl = await api.get('/classes');
      setClasses(cl);
    } catch (err) {
      toast.error(err.message || 'Failed to create class.');
    } finally {
      setSubLoading(false);
    }
  };

  const handleDeleteClass = async (id) => {
    if (!confirm('Are you sure you want to delete this class?')) return;
    try {
      setSubLoading(true);
      await api.delete(`/classes/${id}`);
      toast.success('Class deleted successfully.');
      setClasses((prev) => prev.filter((c) => c.class_id !== id));
    } catch (err) {
      toast.error(err.message || 'Failed to delete class.');
    } finally {
      setSubLoading(false);
    }
  };

  const handleReviewLeave = async (id, status) => {
    try {
      setSubLoading(true);
      await api.put(`/leaves/${id}`, { status });
      toast.success(`Leave request ${status} successfully.`);
      const lv = await api.get('/leaves');
      setLeaves(lv);
    } catch (err) {
      toast.error(err.message || 'Failed to review leave.');
    } finally {
      setSubLoading(false);
    }
  };

  const handleSendBroadcast = async (e) => {
    e.preventDefault();
    if (!broadcastTitle || !broadcastBody) return;
    try {
      setSendingBroadcast(true);
      await api.post('/notifications/broadcast', {
        title: broadcastTitle,
        body: broadcastBody,
        class_id: broadcastClassId || null,
      });
      toast.success('Broadcast sent successfully.');
      setBroadcastTitle('');
      setBroadcastBody('');
      setBroadcastClassId('');
    } catch (err) {
      toast.error(err.message || 'Failed to send broadcast.');
    } finally {
      setSendingBroadcast(false);
    }
  };

  const handleSchedulePost = async (e) => {
    e.preventDefault();
    if (!postTitle || !postContent) return;
    try {
      setPublishingPost(true);
      await api.post('/posts', {
        title: postTitle,
        category: postCategory,
        content: postContent,
        class_id: postClassId || null,
        scheduled_at: postScheduledAt || null,
      });
      toast.success(postScheduledAt ? 'Post scheduled successfully.' : 'Post published successfully.');
      setPostTitle('');
      setPostContent('');
      setPostClassId('');
      setPostScheduledAt('');
      setView('home');
    } catch (err) {
      toast.error(err.message || 'Failed to schedule post.');
    } finally {
      setPublishingPost(false);
    }
  };

  const handleDeactivateStudent = async (id) => {
    if (!confirm('Are you sure you want to deactivate this student?')) return;
    try {
      setSubLoading(true);
      await api.delete(`/students/${id}`);
      toast.success('Student deactivated successfully.');
      setStudents((prev) => prev.filter((s) => s.student_id !== id));
    } catch (err) {
      toast.error(err.message);
    } finally {
      setSubLoading(false);
    }
  };

  const handleDeactivateTeacher = async (id) => {
    if (!confirm('Are you sure you want to deactivate this teacher?')) return;
    try {
      setSubLoading(true);
      await api.delete(`/teachers/${id}`);
      toast.success('Teacher deactivated successfully.');
      setTeachers((prev) =>
        prev.map((t) => (t.user_id === id ? { ...t, is_active: false } : t))
      );
    } catch (err) {
      toast.error(err.message);
    } finally {
      setSubLoading(false);
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
      {/* Header */}
      <header className="app-header-glass">
        <div className="flex items-center gap-12 w-full">
          {view !== 'home' && (
            <button
              onClick={() => setView('home')}
              style={{ background: 'none', border: 'none', color: 'white', display: 'flex', alignItems: 'center', cursor: 'pointer' }}
            >
              <IconChevronLeft size={24} />
            </button>
          )}
          <div>
            <h1 style={{ fontSize: '18px', fontWeight: 'bold' }}>
              {view === 'home'
                ? 'TPS Admin'
                : view.charAt(0).toUpperCase() + view.slice(1).replace('_', ' ')}
            </h1>
            <p style={{ fontSize: '11px', opacity: 0.8 }}>
              {profile?.branch_name || 'Branch Administration'}
            </p>
          </div>
        </div>
      </header>

      {/* Main Page Area */}
      <main className="page-content" style={{ paddingBottom: '30px' }}>
        {/* ── HOME TAB ── */}
        {view === 'home' && !stats && (
          <div className="card text-center fade-in" style={{ padding: '40px 24px', margin: '20px', background: 'white', borderRadius: '12px', border: '1px solid var(--accent-border)' }}>
            <div style={{ fontSize: '48px', marginBottom: '16px' }}>⚠️</div>
            <h3 style={{ fontSize: '18px', fontWeight: 'bold', marginBottom: '8px', color: 'var(--text-dark)' }}>Failed to Load Dashboard</h3>
            <p style={{ color: 'var(--text-light)', fontSize: '14px', marginBottom: '16px' }}>
              We couldn't retrieve the stats for this branch. Please check your network connection or contact support.
            </p>
            <button className="btn btn-primary" onClick={loadStats}>
              Retry Loading
            </button>
          </div>
        )}
        {view === 'home' && stats && (
          <div className="flex flex-col gap-16 fade-in">
            {/* Quick Stats Grid */}
            <div className="section-header">
              <span className="section-title">Branch Performance</span>
            </div>
            <div className="stat-grid cols-3">
              <div className="stat-card">
                <div className="stat-value">{stats.total_students}</div>
                <div className="stat-label">Students</div>
              </div>
              <div className="stat-card">
                <div className="stat-value">{stats.total_teachers}</div>
                <div className="stat-label">Teachers</div>
              </div>
              <div className="stat-card" style={{ cursor: 'pointer' }} onClick={() => setView('leaves')}>
                <div className="stat-value" style={{ color: stats.pending_leaves > 0 ? 'var(--error)' : 'var(--success)' }}>
                  {stats.pending_leaves}
                </div>
                <div className="stat-label">Pending Leaves</div>
              </div>
            </div>

            <div className="section-header mt-8">
              <span className="section-title">Attendance Today</span>
            </div>
            <div className="stat-grid cols-3">
              <div className="stat-card" style={{ background: 'var(--success-light)' }}>
                <div className="stat-value" style={{ color: 'var(--success)' }}>{stats.today_present}</div>
                <div className="stat-label">Present</div>
              </div>
              <div className="stat-card" style={{ background: 'var(--error-bg)' }}>
                <div className="stat-value" style={{ color: 'var(--error)' }}>{stats.today_absent}</div>
                <div className="stat-label">Absent</div>
              </div>
              <div className="stat-card" style={{ background: 'var(--warning-light)' }}>
                <div className="stat-value" style={{ color: 'var(--warning)' }}>{stats.today_on_leave}</div>
                <div className="stat-label">On Leave</div>
              </div>
            </div>

            {/* Menu options */}
            <div className="section-header mt-12">
              <span className="section-title">Management Hub</span>
            </div>
            <div className="quick-actions">
              <button className="quick-action" onClick={() => setView('students')}>
                <div className="quick-action-icon" style={{ background: 'var(--success-light)', color: 'var(--success)' }}>🧒</div>
                <span>Students</span>
              </button>
              <button className="quick-action" onClick={() => setView('teachers')}>
                <div className="quick-action-icon" style={{ background: 'var(--info-light)', color: 'var(--info)' }}>👩‍🏫</div>
                <span>Teachers</span>
              </button>
              <button className="quick-action" onClick={() => setView('classes')}>
                <div className="quick-action-icon" style={{ background: 'var(--primary-light)', color: 'white' }}>🏫</div>
                <span>Classes</span>
              </button>
              <button className="quick-action" onClick={() => setView('leaves')}>
                <div className="quick-action-icon" style={{ background: 'var(--warning-light)', color: 'var(--warning)' }}>📋</div>
                <span>Leaves</span>
              </button>
              <button className="quick-action" onClick={() => setView('attendance')}>
                <div className="quick-action-icon" style={{ background: 'var(--accent-light)', color: 'var(--primary)' }}>📊</div>
                <span>Attendance Logs</span>
              </button>
              <button className="quick-action" onClick={() => setView('broadcast')}>
                <div className="quick-action-icon" style={{ background: '#e1f5fe', color: '#0288d1' }}>📢</div>
                <span>Broadcast FCM</span>
              </button>
              <button className="quick-action" onClick={() => setView('posts')}>
                <div className="quick-action-icon" style={{ background: '#efebe9', color: '#5d4037' }}>✍️</div>
                <span>Schedule Post</span>
              </button>
              <button className="quick-action" onClick={() => setView('logs')}>
                <div className="quick-action-icon" style={{ background: '#eceff1', color: '#455a64' }}>📝</div>
                <span>Audit Logs</span>
              </button>
            </div>

            <button
              id="logout-btn"
              className="btn btn-outline flex items-center justify-center gap-8 mt-12 w-full"
              onClick={() => auth.signOut()}
              style={{ borderColor: 'var(--error)', color: 'var(--error)' }}
            >
              <IconLogOut size={18} /> Log Out
            </button>
          </div>
        )}

        {/* ── STUDENTS VIEW ── */}
        {view === 'students' && (
          <div className="flex flex-col gap-16 fade-in">
            <div className="section-header">
              <span className="section-title">Students Registry</span>
              <button className="btn btn-primary btn-sm flex items-center gap-4" onClick={() => setShowAddStudent(true)}>
                <IconPlus size={14} /> Add Student
              </button>
            </div>

            {subLoading ? (
              <div className="loading-container"><div className="spinner spinner-sm" /></div>
            ) : students.length === 0 ? (
              <div className="empty-state">
                <div className="empty-state-icon">🧒</div>
                <div className="empty-state-title">No Students Registered</div>
                <div className="empty-state-text">Start by adding your first student profile.</div>
              </div>
            ) : (
              <div className="flex flex-col gap-8">
                {students.map((student) => (
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
                      <div className="list-item-subtitle">
                        Class: {student.class_name || 'Unassigned'} • DOB: {formatDate(student.dob) || 'N/A'}
                      </div>
                    </div>
                    <div className="flex gap-4">
                      <button
                        className="btn btn-outline btn-sm"
                        style={{ padding: '4px 8px', fontSize: '11px' }}
                        onClick={() => {
                          setActiveStudentId(student.student_id);
                          setShowLinkParent(true);
                        }}
                      >
                        🔗 Link Parent
                      </button>
                      <button
                        className="btn-icon"
                        style={{ color: 'var(--error)', border: 'none', background: 'none' }}
                        onClick={() => handleDeactivateStudent(student.student_id)}
                      >
                        <IconTrash size={18} />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}

            {/* Modal - Add Student */}
            <Modal open={showAddStudent} onClose={() => setShowAddStudent(false)} title="Register Student">
              <form onSubmit={handleAddStudent} className="flex flex-col gap-16">
                <div className="input-group">
                  <label htmlFor="student-name">Full Name</label>
                  <input
                    id="student-name"
                    type="text"
                    className="input"
                    value={studentName}
                    onChange={(e) => setStudentName(e.target.value)}
                    required
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="student-dob">Date of Birth</label>
                  <input
                    id="student-dob"
                    type="date"
                    className="input"
                    value={studentDob}
                    onChange={(e) => setStudentDob(e.target.value)}
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="student-photo">Photo URL (Optional)</label>
                  <input
                    id="student-photo"
                    type="url"
                    className="input"
                    value={studentPhoto}
                    onChange={(e) => setStudentPhoto(e.target.value)}
                    placeholder="https://example.com/photo.jpg"
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="student-class">Assign Class</label>
                  <select
                    id="student-class"
                    className="input"
                    value={studentClassId}
                    onChange={(e) => setStudentClassId(e.target.value)}
                    required
                  >
                    <option value="">Select a class...</option>
                    {classes.map((c) => (
                      <option key={c.class_id} value={c.class_id}>
                        {c.class_name}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="input-group">
                  <label htmlFor="student-emergency">Emergency Phone</label>
                  <input
                    id="student-emergency"
                    type="tel"
                    className="input"
                    value={studentEmergency}
                    onChange={(e) => setStudentEmergency(e.target.value)}
                    placeholder="Parent mobile contact"
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="student-medical">Medical Notes</label>
                  <textarea
                    id="student-medical"
                    className="input"
                    value={studentMedical}
                    onChange={(e) => setStudentMedical(e.target.value)}
                    placeholder="Allergies, chronic conditions..."
                  />
                </div>
                <button type="submit" className="btn btn-primary" disabled={subLoading}>
                  Register Child
                </button>
              </form>
            </Modal>

            {/* Modal - Link Parent */}
            <Modal open={showLinkParent} onClose={() => setShowLinkParent(false)} title="Link Parent Account">
              <form onSubmit={handleLinkParent} className="flex flex-col gap-16">
                <div className="input-group">
                  <label htmlFor="parent-name">Parent Name</label>
                  <input
                    id="parent-name"
                    type="text"
                    className="input"
                    value={parentName}
                    onChange={(e) => setParentName(e.target.value)}
                    required
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="parent-email">Parent Email</label>
                  <input
                    id="parent-email"
                    type="email"
                    className="input"
                    value={parentEmail}
                    onChange={(e) => setParentEmail(e.target.value)}
                    required
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="parent-phone">Parent Phone</label>
                  <input
                    id="parent-phone"
                    type="tel"
                    className="input"
                    value={parentPhone}
                    onChange={(e) => setParentPhone(e.target.value)}
                    placeholder="e.g. 9876543210"
                    required
                  />
                </div>
                <button type="submit" className="btn btn-primary" disabled={subLoading}>
                  Create & Link Parent
                </button>
              </form>
            </Modal>
          </div>
        )}

        {/* ── TEACHERS VIEW ── */}
        {view === 'teachers' && (
          <div className="flex flex-col gap-16 fade-in">
            <div className="section-header">
              <span className="section-title">Teachers Registry</span>
              <button className="btn btn-primary btn-sm flex items-center gap-4" onClick={() => setShowAddTeacher(true)}>
                <IconPlus size={14} /> Add Teacher
              </button>
            </div>

            {subLoading ? (
              <div className="loading-container"><div className="spinner spinner-sm" /></div>
            ) : teachers.length === 0 ? (
              <div className="empty-state">
                <div className="empty-state-icon">👩‍🏫</div>
                <div className="empty-state-title">No Teachers Found</div>
                <div className="empty-state-text">Add your faculty members.</div>
              </div>
            ) : (
              <div className="flex flex-col gap-8">
                {teachers.map((teacher) => (
                  <div key={teacher.user_id} className="list-item" style={{ opacity: teacher.is_active ? 1 : 0.6 }}>
                    <div className="avatar">
                      {getInitials(teacher.name)}
                    </div>
                    <div className="list-item-content">
                      <div className="list-item-title">
                        {teacher.name} {!teacher.is_active && '(Deactivated)'}
                      </div>
                      <div className="list-item-subtitle">{teacher.email} • {teacher.phone || 'No phone'}</div>
                    </div>
                    {teacher.is_active && (
                      <button
                        className="btn-icon"
                        style={{ color: 'var(--error)', border: 'none', background: 'none' }}
                        onClick={() => handleDeactivateTeacher(teacher.user_id)}
                      >
                        Deactivate
                      </button>
                    )}
                  </div>
                ))}
              </div>
            )}

            {/* Modal - Add Teacher */}
            <Modal open={showAddTeacher} onClose={() => setShowAddTeacher(false)} title="Add Faculty Member">
              <form onSubmit={handleAddTeacher} className="flex flex-col gap-16">
                <div className="input-group">
                  <label htmlFor="teacher-name">Full Name</label>
                  <input
                    id="teacher-name"
                    type="text"
                    className="input"
                    value={teacherName}
                    onChange={(e) => setTeacherName(e.target.value)}
                    required
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="teacher-email">Work Email</label>
                  <input
                    id="teacher-email"
                    type="email"
                    className="input"
                    value={teacherEmail}
                    onChange={(e) => setTeacherEmail(e.target.value)}
                    required
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="teacher-phone">Phone Number</label>
                  <input
                    id="teacher-phone"
                    type="tel"
                    className="input"
                    value={teacherPhone}
                    onChange={(e) => setTeacherPhone(e.target.value)}
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="teacher-pass">Temporary Password</label>
                  <input
                    id="teacher-pass"
                    type="text"
                    className="input"
                    value={teacherPassword}
                    onChange={(e) => setTeacherPassword(e.target.value)}
                    placeholder="Minimum 6 characters"
                    required
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="teacher-class">Assigned Class</label>
                  <select
                    id="teacher-class"
                    className="input"
                    value={teacherClassId}
                    onChange={(e) => setTeacherClassId(e.target.value)}
                  >
                    <option value="">No Class Assigned</option>
                    {classes.map((c) => (
                      <option key={c.class_id} value={c.class_id}>
                        {c.class_name}
                      </option>
                    ))}
                  </select>
                </div>
                <button type="submit" className="btn btn-primary" disabled={subLoading}>
                  Register Teacher
                </button>
              </form>
            </Modal>
          </div>
        )}

        {/* ── CLASSES VIEW ── */}
        {view === 'classes' && (
          <div className="flex flex-col gap-16 fade-in">
            <div className="section-header">
              <span className="section-title">Preschool Classes</span>
              <button className="btn btn-primary btn-sm flex items-center gap-4" onClick={() => setShowAddClass(true)}>
                <IconPlus size={14} /> Add Class
              </button>
            </div>

            {subLoading ? (
              <div className="loading-container"><div className="spinner spinner-sm" /></div>
            ) : classes.length === 0 ? (
              <div className="empty-state">
                <div className="empty-state-icon">🏫</div>
                <div className="empty-state-title">No Classes Created</div>
                <div className="empty-state-text">Build your preschool grade structure.</div>
              </div>
            ) : (
              <div className="flex flex-col gap-8">
                {classes.map((cls) => (
                  <div key={cls.class_id} className="list-item">
                    <div className="list-item-content">
                      <div className="list-item-title" style={{ fontSize: '15px', fontWeight: 'bold' }}>
                        {cls.class_name}
                      </div>
                    </div>
                    <button
                      className="btn-icon"
                      style={{ color: 'var(--error)', border: 'none', background: 'none' }}
                      onClick={() => handleDeleteClass(cls.class_id)}
                    >
                      <IconTrash size={18} />
                    </button>
                  </div>
                ))}
              </div>
            )}

            {/* Modal - Add Class */}
            <Modal open={showAddClass} onClose={() => setShowAddClass(false)} title="Create Class">
              <form onSubmit={handleAddClass} className="flex flex-col gap-16">
                <div className="input-group">
                  <label htmlFor="class-name">Class / Section Name</label>
                  <input
                    id="class-name"
                    type="text"
                    className="input"
                    value={className}
                    onChange={(e) => setClassName(e.target.value)}
                    placeholder="e.g. Toddlers A, Pre-K B"
                    required
                  />
                </div>
                <button type="submit" className="btn btn-primary" disabled={subLoading}>
                  Create Class
                </button>
              </form>
            </Modal>
          </div>
        )}

        {/* ── LEAVE REQUESTS VIEW ── */}
        {view === 'leaves' && (
          <div className="flex flex-col gap-16 fade-in">
            <div className="section-header">
              <span className="section-title">Leave Inbox</span>
            </div>

            {subLoading ? (
              <div className="loading-container"><div className="spinner spinner-sm" /></div>
            ) : leaves.length === 0 ? (
              <div className="empty-state">
                <div className="empty-state-icon">📋</div>
                <div className="empty-state-title">All Caught Up!</div>
                <div className="empty-state-text">No active leave requests to review.</div>
              </div>
            ) : (
              <div className="flex flex-col gap-12">
                {leaves.map((leave) => (
                  <div key={leave.leave_id} className="card fade-in">
                    <div className="flex justify-between items-center mb-8">
                      <div>
                        <h4 className="font-bold" style={{ color: 'var(--text-dark)' }}>{leave.student_name}</h4>
                        <span className="text-xs" style={{ color: 'var(--text-hint)' }}>Applied by: {leave.parent_name}</span>
                      </div>
                      <span className={`badge badge-${leave.status}`}>
                        {leave.status}
                      </span>
                    </div>

                    <p className="text-sm font-semibold" style={{ color: 'var(--primary)', marginBottom: '6px' }}>
                      📅 {formatDate(leave.from_date)} to {formatDate(leave.to_date)}
                    </p>

                    <p className="text-sm bg-light" style={{ padding: '8px', borderRadius: '8px', background: 'var(--bg)', color: 'var(--text-mid)' }}>
                      <strong>Reason:</strong> {leave.reason}
                    </p>

                    {leave.status === 'pending' && (
                      <div className="flex gap-12 mt-12">
                        <button
                          className="btn btn-primary btn-sm"
                          style={{ flex: 1, background: 'var(--success)' }}
                          onClick={() => handleReviewLeave(leave.leave_id, 'approved')}
                        >
                          Approve
                        </button>
                        <button
                          className="btn btn-outline btn-sm"
                          style={{ flex: 1, borderColor: 'var(--error)', color: 'var(--error)' }}
                          onClick={() => handleReviewLeave(leave.leave_id, 'rejected')}
                        >
                          Reject
                        </button>
                      </div>
                    )}

                    {leave.reviewer_name && (
                      <div className="mt-8 pt-8 text-xs flex justify-between" style={{ borderTop: '1px solid var(--accent-light)', color: 'var(--text-hint)' }}>
                        <span>Reviewed by: {leave.reviewer_name}</span>
                        <span>{leave.reviewed_at ? formatDate(leave.reviewed_at) : ''}</span>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ── ATTENDANCE OVERVIEW VIEW ── */}
        {view === 'attendance' && (
          <div className="flex flex-col gap-16 fade-in">
            {selectedAttendanceClass ? (
              // ── Class Attendance Marking Sub-view ──
              <div className="flex flex-col gap-16 fade-in">
                <div className="flex items-center justify-between" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <button 
                    className="btn btn-outline btn-sm"
                    onClick={() => setSelectedAttendanceClass(null)}
                    style={{ padding: '6px 12px', fontSize: '13px' }}
                  >
                    ← Back to List
                  </button>
                  <span className="font-bold" style={{ color: 'var(--primary)', fontSize: '15px' }}>
                    Mark: {selectedAttendanceClass.class_name}
                  </span>
                </div>

                {/* Date selection card */}
                <div className="card flex items-center justify-between gap-12" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span className="text-sm font-semibold" style={{ color: 'var(--text-dark)' }}>
                    Attendance Date
                  </span>
                  <input
                    id="admin-att-date"
                    type="date"
                    className="input"
                    style={{ width: 'auto', padding: '8px 12px' }}
                    value={adminAttendanceDate}
                    onChange={(e) => setAdminAttendanceDate(e.target.value)}
                  />
                </div>

                {/* Roster Header */}
                <div className="section-header">
                  <span className="section-title">Class Roll Call</span>
                  <span className="text-xs" style={{ color: 'var(--text-hint)' }}>
                    {adminAttendanceStudents.length} students
                  </span>
                </div>

                {/* Students Roll Call List */}
                {adminStudentsLoading ? (
                  <div className="loading-container"><div className="spinner spinner-sm" /></div>
                ) : adminAttendanceStudents.length === 0 ? (
                  <div className="empty-state">
                    <div className="empty-state-icon">👤</div>
                    <div className="empty-state-title">No Students Found</div>
                    <div className="empty-state-text">Add students to this class first to mark attendance.</div>
                  </div>
                ) : (
                  <div className="flex flex-col gap-8">
                    {adminAttendanceStudents.map((student) => {
                      const status = adminAttendanceRecords[student.student_id] || 'present';
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
                              onClick={() => handleAdminStatusChange(student.student_id, 'present')}
                            >
                              P
                            </button>
                            <button
                              className={`att-btn${status === 'absent' ? ' absent-active' : ''}`}
                              onClick={() => handleAdminStatusChange(student.student_id, 'absent')}
                            >
                              A
                            </button>
                            <button
                              className={`att-btn${status === 'on_leave' ? ' leave-active' : ''}`}
                              onClick={() => handleAdminStatusChange(student.student_id, 'on_leave')}
                            >
                              L
                            </button>
                          </div>
                        </div>
                      );
                    })}

                    <button
                      id="admin-save-attendance-btn"
                      className="btn btn-primary mt-16"
                      onClick={handleAdminSaveAttendance}
                      disabled={adminSavingAttendance}
                    >
                      {adminSavingAttendance ? <div className="spinner spinner-sm" style={{ borderTopColor: 'white' }} /> : 'Save Attendance'}
                    </button>
                  </div>
                )}
              </div>
            ) : (
              // ── Attendance Overview & Class List Sub-view ──
              <div className="flex flex-col gap-16 fade-in">
                <div className="section-header">
                  <span className="section-title">Today's Class Roll Call Logs</span>
                </div>

                {subLoading ? (
                  <div className="loading-container"><div className="spinner spinner-sm" /></div>
                ) : attendanceOverview.length === 0 ? (
                  <div className="empty-state">
                    <div className="empty-state-icon">📊</div>
                    <div className="empty-state-title">No attendance records today</div>
                    <div className="empty-state-text">Teachers haven't submitted attendance logs yet today.</div>
                  </div>
                ) : (
                  <div className="flex flex-col gap-12">
                    {attendanceOverview.map((item, idx) => (
                      <div key={idx} className="card fade-in">
                        <h3 className="font-bold text-sm" style={{ color: 'var(--text-dark)', marginBottom: '8px' }}>
                          {item.class_name}
                        </h3>
                        <div className="flex justify-between text-xs" style={{ color: 'var(--text-mid)' }}>
                          <span>Present: <strong style={{ color: 'var(--success)' }}>{item.present}</strong></span>
                          <span>Absent: <strong style={{ color: 'var(--error)' }}>{item.absent}</strong></span>
                          <span>Leave: <strong style={{ color: 'var(--warning)' }}>{item.on_leave}</strong></span>
                          <span>Unmarked: <strong>{item.not_marked}</strong></span>
                        </div>
                      </div>
                    ))}
                  </div>
                )}

                {/* Class directory to take attendance */}
                <div className="section-header mt-12">
                  <span className="section-title">Take or Update Attendance</span>
                </div>
                {classes.length === 0 ? (
                  <div className="card text-center" style={{ padding: '16px', color: 'var(--text-hint)', fontSize: '13px' }}>
                    No classes available.
                  </div>
                ) : (
                  <div className="flex flex-col gap-8">
                    {classes.map((cls) => (
                      <button
                        key={cls.class_id}
                        className="list-item card-interactive"
                        style={{ border: '1px solid var(--accent-border)', cursor: 'pointer', background: 'white', textAlign: 'left', display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}
                        onClick={() => setSelectedAttendanceClass(cls)}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                          <span style={{ fontSize: '20px' }}>🏫</span>
                          <div>
                            <div className="list-item-title" style={{ fontSize: '14px', fontWeight: 'bold' }}>{cls.class_name}</div>
                            <div className="list-item-subtitle" style={{ fontSize: '11px', color: 'var(--text-hint)' }}>Click to mark roll call</div>
                          </div>
                        </div>
                        <span style={{ color: 'var(--primary)', fontWeight: 'bold', fontSize: '16px' }}>✏️</span>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* ── BROADCAST FCM TAB ── */}
        {view === 'broadcast' && (
          <div className="flex flex-col gap-16 fade-in">
            <div className="section-header">
              <span className="section-title">Push Alert Dispatcher</span>
            </div>

            <form onSubmit={handleSendBroadcast} className="card flex flex-col gap-16">
              <div className="input-group">
                <label htmlFor="broadcast-target">Broadcast Audience</label>
                <select
                  id="broadcast-target"
                  className="input"
                  value={broadcastClassId}
                  onChange={(e) => setBroadcastClassId(e.target.value)}
                >
                  <option value="">Full Branch (All Classes)</option>
                  {classes.map((c) => (
                    <option key={c.class_id} value={c.class_id}>
                      Class: {c.class_name}
                    </option>
                  ))}
                </select>
              </div>

              <div className="input-group">
                <label htmlFor="broadcast-title">Notification Title</label>
                <input
                  id="broadcast-title"
                  type="text"
                  className="input"
                  placeholder="e.g. Weather Alert — School Closed"
                  value={broadcastTitle}
                  onChange={(e) => setBroadcastTitle(e.target.value)}
                  required
                />
              </div>

              <div className="input-group">
                <label htmlFor="broadcast-body">Message Body</label>
                <textarea
                  id="broadcast-body"
                  className="input"
                  placeholder="Type crucial emergency instructions or announcements..."
                  value={broadcastBody}
                  onChange={(e) => setBroadcastBody(e.target.value)}
                  style={{ minHeight: '100px' }}
                  required
                />
              </div>

              <button type="submit" className="btn btn-primary flex items-center justify-center gap-8" disabled={sendingBroadcast}>
                {sendingBroadcast ? <div className="spinner spinner-sm" style={{ borderTopColor: 'white' }} /> : <><IconSend size={18} /> Dispatch Notification</>}
              </button>
            </form>
          </div>
        )}

        {/* ── SCHEDULE POST TAB ── */}
        {view === 'posts' && (
          <div className="flex flex-col gap-16 fade-in">
            <div className="section-header">
              <span className="section-title">Announcements Scheduler</span>
            </div>

            <form onSubmit={handleSchedulePost} className="card flex flex-col gap-16">
              <div className="input-group">
                <label htmlFor="post-title">Announcement Title</label>
                <input
                  id="post-title"
                  type="text"
                  className="input"
                  value={postTitle}
                  onChange={(e) => setPostTitle(e.target.value)}
                  placeholder="Summary title..."
                  required
                />
              </div>

              <div className="input-group">
                <label htmlFor="post-cat">Category</label>
                <select
                  id="post-cat"
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
                <label htmlFor="post-class">Target Audience Class (Optional)</label>
                <select
                  id="post-class"
                  className="input"
                  value={postClassId}
                  onChange={(e) => setPostClassId(e.target.value)}
                >
                  <option value="">Branch-wide Announcement</option>
                  {classes.map((c) => (
                    <option key={c.class_id} value={c.class_id}>
                      {c.class_name}
                    </option>
                  ))}
                </select>
              </div>

              <div className="input-group">
                <label htmlFor="post-content">Message Content</label>
                <textarea
                  id="post-content"
                  className="input"
                  value={postContent}
                  onChange={(e) => setPostContent(e.target.value)}
                  style={{ minHeight: '120px' }}
                  required
                />
              </div>

              <div className="input-group">
                <label htmlFor="post-schedule">Schedule Release (Optional)</label>
                <input
                  id="post-schedule"
                  type="datetime-local"
                  className="input"
                  value={postScheduledAt}
                  onChange={(e) => setPostScheduledAt(e.target.value)}
                  placeholder="Release date-time..."
                />
                <span className="text-xs" style={{ color: 'var(--text-hint)' }}>
                  Leave empty to publish immediately.
                </span>
              </div>

              <button type="submit" className="btn btn-primary" disabled={publishingPost}>
                {publishingPost ? <div className="spinner spinner-sm" style={{ borderTopColor: 'white' }} /> : 'Submit Announcement'}
              </button>
            </form>
          </div>
        )}

        {/* ── AUDIT LOGS VIEW ── */}
        {view === 'logs' && (
          <div className="flex flex-col gap-16 fade-in">
            <div className="section-header">
              <span className="section-title">Teacher Activity Audits</span>
            </div>

            {subLoading ? (
              <div className="loading-container"><div className="spinner spinner-sm" /></div>
            ) : logs.length === 0 ? (
              <div className="empty-state">
                <div className="empty-state-icon">📝</div>
                <div className="empty-state-title">No Audit Logs</div>
                <div className="empty-state-text">No activity logs recorded in this branch yet.</div>
              </div>
            ) : (
              <div className="flex flex-col gap-8">
                {logs.map((log) => (
                  <div key={log.log_id} className="card fade-in" style={{ padding: '12px' }}>
                    <div className="flex justify-between items-center mb-4">
                      <span className="font-bold text-xs" style={{ color: 'var(--text-dark)' }}>
                        👤 {log.user_name} ({log.user_role})
                      </span>
                      <span className="text-xs" style={{ color: 'var(--text-hint)' }}>
                        {formatTimeAgo(log.timestamp)}
                      </span>
                    </div>
                    <p className="text-sm font-semibold" style={{ color: 'var(--primary)' }}>
                      ⚡ {formatLogDescription(log)}
                    </p>

                    {/* Marked Attendance student badges list */}
                    {log.action.toUpperCase() === 'MARK_ATTENDANCE' && log.meta?.students && (
                      <div style={{ marginTop: '8px', display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
                        {log.meta.students.map((st, sidx) => {
                          let bg = 'var(--success-light)';
                          let fg = 'var(--success)';
                          if (st.status === 'absent') {
                            bg = 'var(--error-bg)';
                            fg = 'var(--error)';
                          } else if (st.status === 'on_leave') {
                            bg = 'var(--warning-light)';
                            fg = 'var(--warning)';
                          }
                          return (
                            <span key={sidx} style={{ fontSize: '10px', padding: '2px 6px', borderRadius: '4px', background: bg, color: fg, fontWeight: 600 }}>
                              {st.name}: {st.status === 'present' ? 'P' : st.status === 'absent' ? 'A' : 'L'}
                            </span>
                          );
                        })}
                      </div>
                    )}

                    {/* Broadcast body formatter */}
                    {(log.action.toUpperCase() === 'SEND_BROADCAST' || log.action.toUpperCase() === 'BROADCAST_FCM') && log.meta?.body && (
                      <div style={{ marginTop: '6px', padding: '6px 10px', background: '#e1f5fe', borderRadius: '6px', color: '#0288d1', fontSize: '11px', fontStyle: 'italic' }}>
                        " {log.meta.body} "
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </main>
    </div>
  );
}
