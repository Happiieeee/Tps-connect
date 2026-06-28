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
  IconSearch,
} from '../../components/Icons.jsx';
import { getInitials, formatDate, formatTimeAgo } from '../../utils/helpers.js';

export default function SuperAdminDashboard() {
  const { profile } = useAuth();
  const toast = useToast();

  const [view, setView] = useState('home'); // 'home' | 'branch_detail' | 'leaves' | 'broadcast' | 'users' | 'profile'
  const [globalStats, setGlobalStats] = useState(null);
  const [branches, setBranches] = useState([]);
  const [loading, setLoading] = useState(true);
  const [subLoading, setSubLoading] = useState(false);

  // Branch Detail View State
  const [activeBranchId, setActiveBranchId] = useState(null);
  const [branchDetail, setBranchDetail] = useState(null);
  const [detailTab, setDetailTab] = useState('classes'); // 'classes' | 'staff' | 'students' | 'logs'

  // Central Management lists
  const [pendingLeaves, setPendingLeaves] = useState([]);
  const [allUsers, setAllUsers] = useState([]);
  const [userSearchQuery, setUserSearchQuery] = useState('');

  // Modals
  const [showAddBranch, setShowAddBranch] = useState(false);
  const [showAddClass, setShowAddClass] = useState(false);
  const [showAddAdmin, setShowAddAdmin] = useState(false);
  const [showAddTeacher, setShowAddTeacher] = useState(false);

  // Forms - Branch
  const [branchName, setBranchName] = useState('');
  const [branchCode, setBranchCode] = useState('');

  // Forms - Class
  const [className, setClassName] = useState('');

  // Forms - Admins
  const [adminName, setAdminName] = useState('');
  const [adminEmail, setAdminEmail] = useState('');
  const [adminPassword, setAdminPassword] = useState('');
  const [adminPhone, setAdminPhone] = useState('');

  // Forms - Teacher
  const [teacherName, setTeacherName] = useState('');
  const [teacherEmail, setTeacherEmail] = useState('');
  const [teacherPhone, setTeacherPhone] = useState('');
  const [teacherPassword, setTeacherPassword] = useState('');
  const [teacherClassId, setTeacherClassId] = useState('');

  // Forms - Broadcast
  const [broadcastTitle, setBroadcastTitle] = useState('');
  const [broadcastBody, setBroadcastBody] = useState('');
  const [broadcastBranchId, setBroadcastBranchId] = useState('');
  const [sendingBroadcast, setSendingBroadcast] = useState(false);

  // Fetch global stats & branches
  const loadStats = async () => {
    try {
      setLoading(true);
      const [gStats, bList] = await Promise.all([
        api.get('/superadmin/stats'),
        api.get('/superadmin/branches'),
      ]);
      setGlobalStats(gStats);
      setBranches(bList);
    } catch (err) {
      console.error('Failed to load global stats:', err);
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

  // View state changes loader
  useEffect(() => {
    if (view === 'home') {
      loadStats();
      return;
    }

    async function loadViewData() {
      try {
        setSubLoading(true);
        if (view === 'branch_detail' && activeBranchId) {
          const detail = await api.get(`/superadmin/branches/${activeBranchId}`);
          setBranchDetail(detail);
        } else if (view === 'leaves') {
          const lv = await api.get('/leaves?status=pending');
          setPendingLeaves(lv);
        } else if (view === 'users') {
          // Note: In real app, /users might need pagination. Here we get logs/users listing
          // We can compile a user list or show active superadmins
          const sa = await api.get('/superadmin/superadmins');
          setAllUsers(sa);
        }
      } catch (err) {
        toast.error(`Failed to load data for ${view}`);
        console.error(err);
      } finally {
        setSubLoading(false);
      }
    }
    loadViewData();
  }, [view, activeBranchId]);

  // Actions - Branch
  const handleAddBranch = async (e) => {
    e.preventDefault();
    if (!branchName || !branchCode) return;
    try {
      setSubLoading(true);
      await api.post('/superadmin/branches', { name: branchName, code: branchCode });
      toast.success('Branch created successfully.');
      setShowAddBranch(false);
      setBranchName('');
      setBranchCode('');
      loadStats();
    } catch (err) {
      toast.error(err.message || 'Failed to create branch.');
    } finally {
      setSubLoading(false);
    }
  };

  // Actions - Class (inside branch detail)
  const handleAddClass = async (e) => {
    e.preventDefault();
    if (!className.trim() || !activeBranchId) return;
    try {
      setSubLoading(true);
      await api.post('/classes', { class_name: className, target_branch_id: activeBranchId });
      toast.success('Class created successfully.');
      setShowAddClass(false);
      setClassName('');
      // Reload branch detail
      const detail = await api.get(`/superadmin/branches/${activeBranchId}`);
      setBranchDetail(detail);
    } catch (err) {
      toast.error(err.message || 'Failed to create class.');
    } finally {
      setSubLoading(false);
    }
  };

  const handleDeleteClass = async (classId) => {
    if (!confirm('Are you sure you want to delete this class?')) return;
    try {
      setSubLoading(true);
      await api.delete(`/classes/${classId}`);
      toast.success('Class deleted successfully.');
      setBranchDetail((prev) => ({
        ...prev,
        classes: prev.classes.filter((c) => c.class_id !== classId),
      }));
    } catch (err) {
      toast.error(err.message || 'Failed to delete class.');
    } finally {
      setSubLoading(false);
    }
  };

  // Actions - Admin creation
  const handleAddAdmin = async (e) => {
    e.preventDefault();
    if (!adminName || !adminEmail || !adminPassword || !activeBranchId) return;
    try {
      setSubLoading(true);
      await api.post(`/superadmin/branches/${activeBranchId}/admins`, {
        name: adminName,
        email: adminEmail,
        password: adminPassword,
        phone: adminPhone || null,
      });
      toast.success('Branch Administrator provisioned.');
      setShowAddAdmin(false);
      setAdminName('');
      setAdminEmail('');
      setAdminPassword('');
      setAdminPhone('');
      const detail = await api.get(`/superadmin/branches/${activeBranchId}`);
      setBranchDetail(detail);
    } catch (err) {
      toast.error(err.message || 'Failed to provision admin.');
    } finally {
      setSubLoading(false);
    }
  };

  // Actions - Teacher creation
  const handleAddTeacher = async (e) => {
    e.preventDefault();
    if (!teacherName || !teacherEmail || !teacherPassword || !activeBranchId) return;
    try {
      setSubLoading(true);
      await api.post('/teachers', {
        name: teacherName,
        email: teacherEmail,
        phone: teacherPhone || null,
        password: teacherPassword,
        class_id: teacherClassId || null,
        target_branch_id: activeBranchId,
      });
      toast.success('Teacher created successfully.');
      setShowAddTeacher(false);
      setTeacherName('');
      setTeacherEmail('');
      setTeacherPhone('');
      setTeacherPassword('');
      setTeacherClassId('');
      const detail = await api.get(`/superadmin/branches/${activeBranchId}`);
      setBranchDetail(detail);
    } catch (err) {
      toast.error(err.message || 'Failed to create teacher.');
    } finally {
      setSubLoading(false);
    }
  };

  // Review Leaves
  const handleReviewLeave = async (id, status) => {
    try {
      setSubLoading(true);
      await api.put(`/leaves/${id}`, { status });
      toast.success(`Leave request ${status} successfully.`);
      setPendingLeaves((prev) => prev.filter((l) => l.leave_id !== id));
    } catch (err) {
      toast.error(err.message || 'Failed to review leave.');
    } finally {
      setSubLoading(false);
    }
  };

  // Dispatch global notifications
  const handleSendBroadcast = async (e) => {
    e.preventDefault();
    if (!broadcastTitle || !broadcastBody) return;
    try {
      setSendingBroadcast(true);
      await api.post('/notifications/broadcast', {
        title: broadcastTitle,
        body: broadcastBody,
        target_branch_id: broadcastBranchId || null,
      });
      toast.success('Broadcast notification dispatched successfully.');
      setBroadcastTitle('');
      setBroadcastBody('');
      setBroadcastBranchId('');
    } catch (err) {
      toast.error(err.message || 'Failed to send broadcast.');
    } finally {
      setSendingBroadcast(false);
    }
  };

  // Toggle user status
  const handleToggleUser = async (id) => {
    try {
      setSubLoading(true);
      const res = await api.put(`/superadmin/users/${id}/toggle`);
      toast.success(`User status toggled successfully.`);
      setAllUsers((prev) =>
        prev.map((u) => (u.user_id === id ? { ...u, is_active: res.is_active } : u))
      );
    } catch (err) {
      toast.error(err.message || 'Failed to toggle status.');
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
              {view === 'home' ? 'TPS SuperAdmin' : view === 'branch_detail' ? `${branchDetail?.branch?.name || 'Branch Detail'}` : view.toUpperCase()}
            </h1>
            <p style={{ fontSize: '11px', opacity: 0.8 }}>Preschool Franchise Management Hub</p>
          </div>
        </div>
      </header>

      {/* Content Area */}
      <main className="page-content" style={{ paddingBottom: '30px' }}>
        {/* ── HOME VIEW ── */}
        {view === 'home' && globalStats && (
          <div className="flex flex-col gap-16 fade-in">
            {/* Global Stats Grid */}
            <div className="section-header">
              <span className="section-title">Franchise Global Stats</span>
            </div>
            <div className="stat-grid cols-4">
              <div className="stat-card">
                <div className="stat-value">{globalStats.total_students}</div>
                <div className="stat-label">Students</div>
              </div>
              <div className="stat-card">
                <div className="stat-value">{globalStats.total_teachers}</div>
                <div className="stat-label">Teachers</div>
              </div>
              <div className="stat-card">
                <div className="stat-value">{globalStats.total_branches}</div>
                <div className="stat-label">Branches</div>
              </div>
              <div className="stat-card" style={{ cursor: 'pointer' }} onClick={() => setView('leaves')}>
                <div className="stat-value" style={{ color: globalStats.pending_leaves > 0 ? 'var(--error)' : 'var(--success)' }}>
                  {globalStats.pending_leaves}
                </div>
                <div className="stat-label">Leaves</div>
              </div>
            </div>

            {/* Quick action menu */}
            <div className="section-header mt-8">
              <span className="section-title">Quick Actions</span>
            </div>
            <div className="quick-actions" style={{ gridTemplateColumns: 'repeat(3, 1fr)' }}>
              <button className="quick-action" onClick={() => setView('leaves')}>
                <div className="quick-action-icon" style={{ background: 'var(--warning-light)', color: 'var(--warning)' }}>📋</div>
                <span>Leaves Review</span>
              </button>
              <button className="quick-action" onClick={() => setView('broadcast')}>
                <div className="quick-action-icon" style={{ background: '#e3f2fd', color: '#1e88e5' }}>📢</div>
                <span>Franchise Broadcast</span>
              </button>
              <button className="quick-action" onClick={() => setView('users')}>
                <div className="quick-action-icon" style={{ background: '#eceff1', color: '#37474f' }}>👤</div>
                <span>Super Admins</span>
              </button>
            </div>

            {/* Branches list */}
            <div className="section-header mt-12">
              <span className="section-title">Franchise Branches</span>
              <button className="btn btn-primary btn-sm flex items-center gap-4" onClick={() => setShowAddBranch(true)}>
                <IconPlus size={14} /> Add Branch
              </button>
            </div>

            <div className="flex flex-col gap-10">
              {branches.map((b) => (
                <div
                  key={b.branch_id}
                  className="card card-interactive flex justify-between items-center"
                  style={{ cursor: 'pointer', border: '1px solid var(--accent-border)' }}
                  onClick={() => {
                    setActiveBranchId(b.branch_id);
                    setView('branch_detail');
                  }}
                >
                  <div className="flex-col">
                    <h3 className="font-bold text-sm" style={{ color: 'var(--text-dark)' }}>
                      {b.name} ({b.code})
                    </h3>
                    <p className="text-xs" style={{ color: 'var(--text-light)', marginTop: '2px' }}>
                      🧑‍🎓 {b.total_students} Students • 👩‍🏫 {b.total_teachers} Teachers
                    </p>
                  </div>
                  <div className="flex items-center gap-8">
                    {b.pending_leaves > 0 && (
                      <span className="badge badge-absent text-xs">
                        {b.pending_leaves} Pending Leave
                      </span>
                    )}
                    <span style={{ color: 'var(--primary)', fontSize: '18px' }}>›</span>
                  </div>
                </div>
              ))}
            </div>

            <button
              id="logout-btn"
              className="btn btn-outline flex items-center justify-center gap-8 mt-12 w-full"
              onClick={() => auth.signOut()}
              style={{ borderColor: 'var(--error)', color: 'var(--error)' }}
            >
              <IconLogOut size={18} /> Log Out
            </button>

            {/* Modal - Add Branch */}
            <Modal open={showAddBranch} onClose={() => setShowAddBranch(false)} title="Register Franchise Branch">
              <form onSubmit={handleAddBranch} className="flex flex-col gap-16">
                <div className="input-group">
                  <label htmlFor="branch-name">Branch Location Name</label>
                  <input
                    id="branch-name"
                    type="text"
                    className="input"
                    value={branchName}
                    onChange={(e) => setBranchName(e.target.value)}
                    placeholder="e.g. Pune Central, Mumbai Bandra"
                    required
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="branch-code">Branch Code (Unique Prefix)</label>
                  <input
                    id="branch-code"
                    type="text"
                    maxLength={5}
                    className="input"
                    value={branchCode}
                    onChange={(e) => setBranchCode(e.target.value)}
                    placeholder="e.g. PUNEC, BNDRA"
                    required
                  />
                </div>
                <button type="submit" className="btn btn-primary" disabled={subLoading}>
                  Establish Branch
                </button>
              </form>
            </Modal>
          </div>
        )}

        {/* ── BRANCH DETAIL VIEW (4 Tabs) ── */}
        {view === 'branch_detail' && branchDetail && (
          <div className="flex flex-col gap-16 fade-in">
            {/* Custom 4 Tabs bar */}
            <div className="tabs">
              <button
                className={`tab${detailTab === 'classes' ? ' active' : ''}`}
                onClick={() => setDetailTab('classes')}
              >
                Classes
              </button>
              <button
                className={`tab${detailTab === 'staff' ? ' active' : ''}`}
                onClick={() => setDetailTab('staff')}
              >
                Staff
              </button>
              <button
                className={`tab${detailTab === 'students' ? ' active' : ''}`}
                onClick={() => setDetailTab('students')}
              >
                Students
              </button>
              <button
                className={`tab${detailTab === 'logs' ? ' active' : ''}`}
                onClick={() => setDetailTab('logs')}
              >
                Logs
              </button>
            </div>

            {subLoading ? (
              <div className="loading-container"><div className="spinner spinner-sm" /></div>
            ) : (
              <div className="fade-in">
                {/* ── TAB: CLASSES ── */}
                {detailTab === 'classes' && (
                  <div className="flex flex-col gap-12">
                    <div className="section-header">
                      <span className="section-title">Branch Classes</span>
                      <button className="btn btn-primary btn-sm flex items-center gap-4" onClick={() => setShowAddClass(true)}>
                        <IconPlus size={12} /> New Class
                      </button>
                    </div>

                    {branchDetail.classes.length === 0 ? (
                      <p className="text-sm text-hint">No classes created in this branch yet.</p>
                    ) : (
                      <div className="flex flex-col gap-8">
                        {branchDetail.classes.map((cls) => (
                          <div key={cls.class_id} className="list-item">
                            <div className="list-item-content">
                              <span className="font-semibold text-sm">{cls.class_name}</span>
                            </div>
                            <button
                              className="btn-icon"
                              style={{ color: 'var(--error)', border: 'none', background: 'none' }}
                              onClick={() => handleDeleteClass(cls.class_id)}
                            >
                              <IconTrash size={16} />
                            </button>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                )}

                {/* ── TAB: STAFF & ADMINS ── */}
                {detailTab === 'staff' && (
                  <div className="flex flex-col gap-16">
                    {/* Branch Admins list */}
                    <div className="flex flex-col gap-8">
                      <div className="section-header">
                        <span className="section-title">Branch Administrators</span>
                        <button className="btn btn-primary btn-sm flex items-center gap-4" onClick={() => setShowAddAdmin(true)}>
                          <IconPlus size={12} /> Provision Admin
                        </button>
                      </div>
                      {branchDetail.admins.length === 0 ? (
                        <p className="text-sm text-hint">No branch administrators assigned.</p>
                      ) : (
                        branchDetail.admins.map((admin) => (
                          <div key={admin.user_id} className="list-item">
                            <div className="list-item-content">
                              <div className="list-item-title">{admin.name}</div>
                              <div className="list-item-subtitle">{admin.email}</div>
                            </div>
                          </div>
                        ))
                      )}
                    </div>

                    {/* Teachers list */}
                    <div className="flex flex-col gap-8">
                      <div className="section-header">
                        <span className="section-title">Faculty (Teachers)</span>
                        <button className="btn btn-outline btn-sm flex items-center gap-4" onClick={() => setShowAddTeacher(true)}>
                          <IconPlus size={12} /> Add Teacher
                        </button>
                      </div>
                      {branchDetail.teachers.length === 0 ? (
                        <p className="text-sm text-hint">No teachers provisioned in this branch.</p>
                      ) : (
                        branchDetail.teachers.map((teacher) => (
                          <div key={teacher.user_id} className="list-item" style={{ opacity: teacher.is_active ? 1 : 0.5 }}>
                            <div className="list-item-content">
                              <div className="list-item-title">{teacher.name}</div>
                              <div className="list-item-subtitle">{teacher.email} • Assigned Class: {teacher.class_name || 'N/A'}</div>
                            </div>
                          </div>
                        ))
                      )}
                    </div>
                  </div>
                )}

                {/* ── TAB: STUDENTS & ATTENDANCE ── */}
                {detailTab === 'students' && (
                  <div className="flex flex-col gap-16">
                    {/* Students registry list */}
                    <div className="flex flex-col gap-8">
                      <div className="section-header">
                        <span className="section-title">Enrolled Students</span>
                      </div>
                      {branchDetail.students.length === 0 ? (
                        <p className="text-sm text-hint">No student records found.</p>
                      ) : (
                        branchDetail.students.map((student) => (
                          <div key={student.student_id} className="list-item">
                            <div className="list-item-content">
                              <div className="list-item-title">{student.name}</div>
                              <div className="list-item-subtitle">Class: {student.class_name || 'Unassigned'}</div>
                            </div>
                          </div>
                        ))
                      )}
                    </div>

                    {/* Today's marked attendance */}
                    <div className="flex flex-col gap-8">
                      <div className="section-header">
                        <span className="section-title">Today's Attendance Logs</span>
                      </div>
                      {branchDetail.attendance_today.length === 0 ? (
                        <p className="text-sm text-hint">No daily roll call marked today yet.</p>
                      ) : (
                        branchDetail.attendance_today.map((att, idx) => (
                          <div key={idx} className="list-item">
                            <div className="list-item-content">
                              <div className="list-item-title">{att.student_name} ({att.class_name})</div>
                              <div className="list-item-subtitle">Marked {att.status.toUpperCase()} by {att.marked_by_name}</div>
                            </div>
                            <span className={`badge badge-${att.status}`}>{att.status}</span>
                          </div>
                        ))
                      )}
                    </div>
                  </div>
                )}

                {/* ── TAB: TEACHER LOGS ── */}
                {detailTab === 'logs' && (
                  <div className="flex flex-col gap-12">
                    <div className="section-header">
                      <span className="section-title">Branch Teacher Logs</span>
                    </div>
                    {branchDetail.logs.length === 0 ? (
                      <p className="text-sm text-hint">No audit events logged in this branch.</p>
                    ) : (
                      <div className="flex flex-col gap-8">
                        {branchDetail.logs.map((log) => (
                          <div key={log.log_id} className="card" style={{ padding: '10px' }}>
                            <div className="flex justify-between items-center mb-4">
                              <span className="font-bold text-xs" style={{ color: 'var(--text-dark)' }}>
                                {log.user_name} ({log.role})
                              </span>
                              <span className="text-xs" style={{ color: 'var(--text-hint)' }}>
                                {formatTimeAgo(log.timestamp)}
                              </span>
                            </div>
                            <p className="text-sm font-semibold" style={{ color: 'var(--primary)' }}>
                              ⚡ {log.action.replace('_', ' ').toUpperCase()}
                            </p>
                            {log.meta && (
                              <div className="text-xs mt-4 bg-light" style={{ padding: '6px', borderRadius: '4px', background: 'var(--bg)', color: 'var(--text-mid)', fontFamily: 'monospace' }}>
                                {JSON.stringify(log.meta)}
                              </div>
                            )}
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                )}
              </div>
            )}

            {/* Modal - Add Class inside branch */}
            <Modal open={showAddClass} onClose={() => setShowAddClass(false)} title="Create Class">
              <form onSubmit={handleAddClass} className="flex flex-col gap-16">
                <div className="input-group">
                  <label htmlFor="class-name">Class Location Name</label>
                  <input
                    id="class-name"
                    type="text"
                    className="input"
                    value={className}
                    onChange={(e) => setClassName(e.target.value)}
                    placeholder="e.g. Nursery A, Toddlers B"
                    required
                  />
                </div>
                <button type="submit" className="btn btn-primary" disabled={subLoading}>
                  Create Class
                </button>
              </form>
            </Modal>

            {/* Modal - Add Admin inside branch */}
            <Modal open={showAddAdmin} onClose={() => setShowAddAdmin(false)} title="Provision Administrator">
              <form onSubmit={handleAddAdmin} className="flex flex-col gap-16">
                <div className="input-group">
                  <label htmlFor="admin-name">Administrator Name</label>
                  <input
                    id="admin-name"
                    type="text"
                    className="input"
                    value={adminName}
                    onChange={(e) => setAdminName(e.target.value)}
                    required
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="admin-email">Work Email</label>
                  <input
                    id="admin-email"
                    type="email"
                    className="input"
                    value={adminEmail}
                    onChange={(e) => setAdminEmail(e.target.value)}
                    required
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="admin-phone">Contact Phone</label>
                  <input
                    id="admin-phone"
                    type="tel"
                    className="input"
                    value={adminPhone}
                    onChange={(e) => setAdminPhone(e.target.value)}
                  />
                </div>
                <div className="input-group">
                  <label htmlFor="admin-pass">Temporary Password</label>
                  <input
                    id="admin-pass"
                    type="text"
                    className="input"
                    value={adminPassword}
                    onChange={(e) => setAdminPassword(e.target.value)}
                    placeholder="Min 6 characters"
                    required
                  />
                </div>
                <button type="submit" className="btn btn-primary" disabled={subLoading}>
                  Provision Account
                </button>
              </form>
            </Modal>

            {/* Modal - Add Teacher inside branch */}
            <Modal open={showAddTeacher} onClose={() => setShowAddTeacher(false)} title="Register Teacher">
              <form onSubmit={handleAddTeacher} className="flex flex-col gap-16">
                <div className="input-group">
                  <label htmlFor="teacher-name">Faculty Name</label>
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
                    {branchDetail.classes.map((c) => (
                      <option key={c.class_id} value={c.class_id}>
                        {c.class_name}
                      </option>
                    ))}
                  </select>
                </div>
                <button type="submit" className="btn btn-primary" disabled={subLoading}>
                  Create Faculty Member
                </button>
              </form>
            </Modal>
          </div>
        )}

        {/* ── ALL PENDING LEAVES VIEW ── */}
        {view === 'leaves' && (
          <div className="flex flex-col gap-16 fade-in">
            <div className="section-header">
              <span className="section-title">Franchise Global Leaves</span>
            </div>

            {subLoading ? (
              <div className="loading-container"><div className="spinner spinner-sm" /></div>
            ) : pendingLeaves.length === 0 ? (
              <div className="empty-state">
                <div className="empty-state-icon">📋</div>
                <div className="empty-state-title">No Leaves Pending</div>
                <div className="empty-state-text">Everything has been approved or rejected.</div>
              </div>
            ) : (
              <div className="flex flex-col gap-12">
                {pendingLeaves.map((leave) => (
                  <div key={leave.leave_id} className="card fade-in">
                    <div className="flex justify-between items-center mb-8">
                      <div>
                        <h4 className="font-bold">{leave.student_name}</h4>
                        <p className="text-xs text-hint">Branch: {leave.branch_id}</p>
                      </div>
                      <span className="badge badge-pending">pending</span>
                    </div>

                    <p className="text-sm font-semibold" style={{ color: 'var(--primary)', marginBottom: '6px' }}>
                      📅 {formatDate(leave.from_date)} to {formatDate(leave.to_date)}
                    </p>

                    <p className="text-sm bg-light" style={{ padding: '8px', borderRadius: '8px', background: 'var(--bg)', color: 'var(--text-mid)' }}>
                      <strong>Reason:</strong> {leave.reason}
                    </p>

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
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ── FRANCHISE BROADCAST VIEW ── */}
        {view === 'broadcast' && (
          <div className="flex flex-col gap-16 fade-in">
            <div className="section-header">
              <span className="section-title">Franchise-wide Broadcasts</span>
            </div>

            <form onSubmit={handleSendBroadcast} className="card flex flex-col gap-16">
              <div className="input-group">
                <label htmlFor="broadcast-branch">Target Branch Audience</label>
                <select
                  id="broadcast-branch"
                  className="input"
                  value={broadcastBranchId}
                  onChange={(e) => setBroadcastBranchId(e.target.value)}
                >
                  <option value="">Global Network (All Branches)</option>
                  {branches.map((b) => (
                    <option key={b.branch_id} value={b.branch_id}>
                      {b.name}
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
                  value={broadcastTitle}
                  onChange={(e) => setBroadcastTitle(e.target.value)}
                  placeholder="Notification Header Summary..."
                  required
                />
              </div>

              <div className="input-group">
                <label htmlFor="broadcast-body">Dispatch Message Details</label>
                <textarea
                  id="broadcast-body"
                  className="input"
                  value={broadcastBody}
                  onChange={(e) => setBroadcastBody(e.target.value)}
                  placeholder="Detail critical alerts or circulars..."
                  style={{ minHeight: '120px' }}
                  required
                />
              </div>

              <button type="submit" className="btn btn-primary flex items-center justify-center gap-8" disabled={sendingBroadcast}>
                {sendingBroadcast ? <div className="spinner spinner-sm" style={{ borderTopColor: 'white' }} /> : <><IconSend size={18} /> Global Dispatch</>}
              </button>
            </form>
          </div>
        )}

        {/* ── MANAGE SUPER ADMINS VIEW ── */}
        {view === 'users' && (
          <div className="flex flex-col gap-16 fade-in">
            <div className="section-header">
              <span className="section-title">Franchise Super Admins</span>
            </div>

            {subLoading ? (
              <div className="loading-container"><div className="spinner spinner-sm" /></div>
            ) : allUsers.length === 0 ? (
              <p className="text-sm text-hint">No other super admins registered.</p>
            ) : (
              <div className="flex flex-col gap-8">
                {allUsers.map((user) => (
                  <div key={user.user_id} className="list-item" style={{ opacity: user.is_active ? 1 : 0.5 }}>
                    <div className="avatar">
                      {getInitials(user.name)}
                    </div>
                    <div className="list-item-content">
                      <div className="list-item-title">{user.name}</div>
                      <div className="list-item-subtitle">{user.email} • Role: Super Admin</div>
                    </div>
                    <button
                      className="btn btn-sm btn-outline"
                      style={{ borderColor: user.is_active ? 'var(--error)' : 'var(--success)', color: user.is_active ? 'var(--error)' : 'var(--success)' }}
                      onClick={() => handleToggleUser(user.user_id)}
                    >
                      {user.is_active ? 'Deactivate' : 'Activate'}
                    </button>
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
