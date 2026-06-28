class StudentModel {
  final String studentId;
  final String name;
  final String? dob;
  final String? photoUrl;
  final String branchId;
  final String classId;
  final String? className;
  final String? admissionDate;
  final String? emergencyContact;
  final String? medicalNotes;

  StudentModel({
    required this.studentId,
    required this.name,
    this.dob,
    this.photoUrl,
    required this.branchId,
    required this.classId,
    this.className,
    this.admissionDate,
    this.emergencyContact,
    this.medicalNotes,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) => StudentModel(
        studentId: json['student_id'] ?? '',
        name: json['name'] ?? '',
        dob: json['dob'],
        photoUrl: json['photo_url'],
        branchId: json['branch_id'] ?? '',
        classId: json['class_id'] ?? '',
        className: json['class_name'],
        admissionDate: json['admission_date'],
        emergencyContact: json['emergency_contact'],
        medicalNotes: json['medical_notes'],
      );

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'name': name,
        'dob': dob,
        'photo_url': photoUrl,
        'branch_id': branchId,
        'class_id': classId,
        'class_name': className,
        'admission_date': admissionDate,
        'emergency_contact': emergencyContact,
        'medical_notes': medicalNotes,
      };
}
