import 'package:flutter/material.dart';

class LeaveModel {
  final String leaveId;
  final String studentId;
  final String studentName;
  final String parentId;
  final String? parentName;
  final String branchId;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String status;
  final String? reviewerName;
  final DateTime createdAt;

  LeaveModel({
    required this.leaveId,
    required this.studentId,
    required this.studentName,
    required this.parentId,
    this.parentName,
    required this.branchId,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.status,
    this.reviewerName,
    required this.createdAt,
  });

  factory LeaveModel.fromJson(Map<String, dynamic> json) => LeaveModel(
        leaveId: json['leave_id'] ?? '',
        studentId: json['student_id'] ?? '',
        studentName: json['student_name'] ?? 'Unknown',
        parentId: json['parent_id'] ?? '',
        parentName: json['parent_name'],
        branchId: json['branch_id'] ?? '',
        fromDate: DateTime.parse(json['from_date']),
        toDate: DateTime.parse(json['to_date']),
        reason: json['reason'] ?? '',
        status: json['status'] ?? 'pending',
        reviewerName: json['reviewer_name'],
        createdAt: DateTime.parse(json['created_at']),
      );

  String get statusLabel {
    switch (status) {
      case 'approved':
        return '✅ Approved';
      case 'rejected':
        return '❌ Rejected';
      default:
        return '⏳ Pending';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
