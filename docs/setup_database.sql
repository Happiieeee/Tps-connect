-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Branches
CREATE TABLE branches (
  branch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100),
  location TEXT,
  admin_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Users
CREATE TABLE users (
  user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100),
  email VARCHAR(150) UNIQUE,
  phone VARCHAR(20),
  role VARCHAR(20) CHECK (role IN ('superadmin','branchadmin','teacher','parent')),
  branch_id UUID REFERENCES branches(branch_id),
  firebase_uid VARCHAR,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Classes
CREATE TABLE classes (
  class_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id UUID REFERENCES branches(branch_id),
  class_name VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Students
CREATE TABLE students (
  student_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100),
  dob DATE,
  photo_url TEXT,
  branch_id UUID REFERENCES branches(branch_id),
  class_id UUID REFERENCES classes(class_id),
  admission_date DATE,
  emergency_contact VARCHAR(20),
  medical_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Student-Parent Link
CREATE TABLE student_parents (
  student_id UUID REFERENCES students(student_id),
  parent_id UUID REFERENCES users(user_id),
  PRIMARY KEY (student_id, parent_id)
);

-- Attendance
CREATE TABLE attendance (
  attendance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES students(student_id),
  date DATE,
  status VARCHAR(10) CHECK (status IN ('present','absent','on_leave')),
  marked_by UUID REFERENCES users(user_id),
  branch_id UUID REFERENCES branches(branch_id),
  UNIQUE (student_id, date),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Posts
CREATE TABLE posts (
  post_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id UUID REFERENCES branches(branch_id),
  class_id UUID REFERENCES classes(class_id),
  posted_by UUID REFERENCES users(user_id),
  category VARCHAR(20) CHECK (category IN ('homework','circular','event','photos','holiday')),
  title VARCHAR(200),
  content TEXT,
  file_urls TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Leaves
CREATE TABLE leaves (
  leave_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES students(student_id),
  requested_by UUID REFERENCES users(user_id),
  from_date DATE,
  to_date DATE,
  reason TEXT,
  status VARCHAR(10) CHECK (status IN ('pending','approved','rejected')),
  reviewed_by UUID REFERENCES users(user_id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Teacher Logs
CREATE TABLE teacher_logs (
  log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(user_id),
  branch_id UUID REFERENCES branches(branch_id),
  action VARCHAR(100),
  meta JSONB,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Notifications
CREATE TABLE notifications (
  notif_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_role VARCHAR(20),
  branch_id UUID REFERENCES branches(branch_id),
  class_id UUID REFERENCES classes(class_id),
  title VARCHAR(200),
  body TEXT,
  sent_by UUID REFERENCES users(user_id),
  sent_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed Initial Super Admin
-- INSERT INTO users (name, email, role, is_active) VALUES ('Prathap', 'prathap.v5214@gmail.com', 'superadmin', true);

