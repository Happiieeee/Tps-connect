import 'package:flutter/material.dart';
import '../features/auth/login_screen.dart';
import '../features/branch_admin/branch_admin_dashboard_screen.dart';
import '../features/teacher/teacher_dashboard_screen.dart';
import '../features/parent/parent_dashboard_screen.dart';
import '../features/parent/post_feed_screen.dart';
import '../features/superadmin/superadmin_dashboard_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/login': (context) => const LoginScreen(),
  '/super-admin': (context) => const SuperAdminDashboardScreen(),
  '/branch-admin': (context) => const BranchAdminDashboardScreen(),
  '/teacher': (context) => const TeacherDashboardScreen(),
  '/parent': (context) => const ParentDashboardScreen(),
  '/parent/feed': (context) => const PostFeedScreen(),
};
