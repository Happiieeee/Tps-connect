class AttendanceRecord {
  final String studentId;
  final String studentName;
  final String? photoUrl;
  final String? attendanceId;
  String status; // 'present' | 'absent' | 'on_leave' | 'not_marked'

  AttendanceRecord({
    required this.studentId,
    required this.studentName,
    this.photoUrl,
    this.attendanceId,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        studentId: json['student_id'] ?? '',
        studentName: json['name'] ?? '',
        photoUrl: json['photo_url'],
        attendanceId: json['attendance_id'],
        status: json['status'] ?? 'not_marked',
      );

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'status': status,
      };
}
