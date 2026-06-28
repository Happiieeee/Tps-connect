import 'package:flutter/material.dart';
import '../utils/time_utils.dart';

class LeaveModel {
  final String  leaveId;
  final String  studentId;
  final String  studentName;
  final String? parentName;
  final String? reviewerName;  // who approved/rejected
  final String? reviewedAt;    // when
  final String  fromDate;
  final String  toDate;
  final String  reason;
  final String  status;
  final String  createdAt;

  LeaveModel({
    required this.leaveId,
    required this.studentId,
    required this.studentName,
    this.parentName,
    this.reviewerName,
    this.reviewedAt,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory LeaveModel.fromJson(Map<String, dynamic> j) => LeaveModel(
    leaveId:      j['leave_id'] ?? '',
    studentId:    j['student_id'] ?? '',
    studentName:  j['student_name'] ?? 'Unknown',
    parentName:   j['parent_name'],
    reviewerName: j['reviewer_name'],
    reviewedAt:   j['reviewed_at'],
    fromDate:     j['from_date'] ?? '',
    toDate:       j['to_date'] ?? '',
    reason:       j['reason'] ?? '',
    status:       j['status'] ?? 'pending',
    createdAt:    j['created_at'] ?? '',
  );

  DateTime get from => TimeUtils.toIST(fromDate);
  DateTime get to   => TimeUtils.toIST(toDate);
  int get durationDays => to.difference(from).inDays + 1;

  String get statusLabel {
    switch (status) {
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      default:         return 'Pending';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'approved': return const Color(0xFF3B6D11);
      case 'rejected': return const Color(0xFFE24B4A);
      default:         return const Color(0xFFEF9F27);
    }
  }

  Color get statusBg {
    switch (status) {
      case 'approved': return const Color(0xFFEAF3DE);
      case 'rejected': return const Color(0xFFfce8e8);
      default:         return const Color(0xFFfaeeda);
    }
  }
}
