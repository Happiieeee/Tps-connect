import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from './contexts/AuthContext.jsx';
import LandingPage from './pages/LandingPage.jsx';
import LoginScreen from './pages/auth/LoginScreen.jsx';
import ParentDashboard from './pages/parent/ParentDashboard.jsx';
import TeacherDashboard from './pages/teacher/TeacherDashboard.jsx';
import BranchAdminDashboard from './pages/branchadmin/BranchAdminDashboard.jsx';
import SuperAdminDashboard from './pages/superadmin/SuperAdminDashboard.jsx';

function ProtectedRoute({ children, allowedRoles }) {
  const { user, profile, loading } = useAuth();

  if (loading) {
    return (
      <div className="page-shell">
        <div className="loading-container">
          <div className="spinner" />
        </div>
      </div>
    );
  }

  if (!user) return <Navigate to="/login" replace />;
  // If user is logged in but profile failed to load (null), redirect to login
  if (!profile) return <Navigate to="/login" replace />;
  if (allowedRoles && !allowedRoles.includes(profile.role)) {
    return <Navigate to="/login" replace />;
  }
  return children;
}

function SplashRouter() {
  const { user, profile, loading } = useAuth();

  if (loading) {
    return (
      <div className="page-shell" style={{ justifyContent: 'center', alignItems: 'center' }}>
        <div style={{
          width: 56, height: 56,
          background: 'var(--primary)',
          borderRadius: 'var(--radius-lg)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: '0 4px 16px rgba(59,109,17,0.3)',
          marginBottom: 20,
        }}>
          <span style={{ color: 'white', fontWeight: 700, fontSize: 16 }}>TPS</span>
        </div>
        <div className="spinner" />
      </div>
    );
  }

  if (!user) return <Navigate to="/login" replace />;

  switch (profile?.role) {
    case 'superadmin': return <Navigate to="/super-admin" replace />;
    case 'branchadmin': return <Navigate to="/branch-admin" replace />;
    case 'teacher': return <Navigate to="/teacher" replace />;
    case 'parent': return <Navigate to="/parent" replace />;
    default: return <Navigate to="/login" replace />;
  }
}

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route path="/portal" element={<SplashRouter />} />
      <Route path="/login" element={<LoginScreen />} />
      <Route
        path="/parent/*"
        element={
          <ProtectedRoute allowedRoles={['parent']}>
            <ParentDashboard />
          </ProtectedRoute>
        }
      />
      <Route
        path="/teacher/*"
        element={
          <ProtectedRoute allowedRoles={['teacher']}>
            <TeacherDashboard />
          </ProtectedRoute>
        }
      />
      <Route
        path="/branch-admin/*"
        element={
          <ProtectedRoute allowedRoles={['branchadmin']}>
            <BranchAdminDashboard />
          </ProtectedRoute>
        }
      />
      <Route
        path="/super-admin/*"
        element={
          <ProtectedRoute allowedRoles={['superadmin']}>
            <SuperAdminDashboard />
          </ProtectedRoute>
        }
      />
    </Routes>
  );
}

