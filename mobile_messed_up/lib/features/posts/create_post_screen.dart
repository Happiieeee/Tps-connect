import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../core/services/api_service.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';

class CreatePostScreen extends StatefulWidget {
  final String branchId;
  final List<dynamic> classes;
  const CreatePostScreen({
    super.key,
    required this.branchId,
    required this.classes,
  });
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final titleController   = TextEditingController();
  final contentController = TextEditingController();
  String selectedCategory = 'homework';
  String? selectedClassId;
  List<String> uploadedFileUrls = [];
  bool isUploading = false;
  bool isPosting   = false;

  // Scheduling
  bool isScheduled       = false;
  DateTime? scheduledDate;
  TimeOfDay? scheduledTime;

  final categories = [
    {'value': 'homework', 'label': '📚 Homework'},
    {'value': 'circular', 'label': '📢 Circular'},
    {'value': 'event',    'label': '🎉 Event'},
    {'value': 'photos',   'label': '📷 Photos'},
    {'value': 'holiday',  'label': '🏖️ Holiday'},
  ];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() => isUploading = true);
    try {
      for (final file in result.files) {
        if (file.path == null) continue;
        final user  = FirebaseAuth.instance.currentUser!;
        final token = await user.getIdToken();
        final req   = http.MultipartRequest(
          'POST', Uri.parse('${ApiConfig.baseUrl}/uploads'));
        req.headers['Authorization'] = 'Bearer $token';
        req.files.add(
          await http.MultipartFile.fromPath('file', file.path!));
        final resp = await req.send();
        final body = await resp.stream.bytesToString();
        final data = jsonDecode(body);
        if (data['url'] != null) {
          setState(() => uploadedFileUrls.add(data['url']));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'),
          backgroundColor: Colors.red));
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _pickScheduleDate() async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: TPSTheme.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          )),
        child: child!),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        now.add(const Duration(hours: 1))),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: TPSTheme.primary,
            onPrimary: Colors.white,
          )),
        child: child!),
    );
    if (time == null) return;

    setState(() {
      scheduledDate = date;
      scheduledTime = time;
    });
  }

  String? get _scheduledIso {
    if (!isScheduled || scheduledDate == null || scheduledTime == null)
      return null;
    final dt = DateTime(
      scheduledDate!.year, scheduledDate!.month, scheduledDate!.day,
      scheduledTime!.hour, scheduledTime!.minute,
    );
    return dt.toIso8601String();
  }

  String get _scheduledLabel {
    if (scheduledDate == null || scheduledTime == null)
      return 'Pick date & time';
    final d = scheduledDate!;
    final t = scheduledTime!;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} at $h:$m';
  }

  Future<void> _submit() async {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')));
      return;
    }
    if (isScheduled && _scheduledIso == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick a date and time for scheduling')));
      return;
    }

    // Warn if scheduled time is in the past
    if (isScheduled && _scheduledIso != null) {
      final scheduled = DateTime.parse(_scheduledIso!);
      if (scheduled.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scheduled time must be in the future'),
            backgroundColor: Colors.red));
        return;
      }
    }

    setState(() => isPosting = true);
    try {
      await ApiService.post('/posts', {
        'title':        titleController.text.trim(),
        'content':      contentController.text.trim(),
        'category':     selectedCategory,
        'class_id':     selectedClassId,
        'file_urls':    uploadedFileUrls,
        'scheduled_at': _scheduledIso,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isScheduled
            ? '📅 Post scheduled for $_scheduledLabel'
            : '✅ Post published successfully'),
          backgroundColor: TPSTheme.primary));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create post'),
          backgroundColor: Colors.red));
    } finally {
      setState(() => isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPSTheme.background,
      appBar: AppBar(
        backgroundColor: TPSTheme.primaryDark,
        foregroundColor: Colors.white,
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: isPosting ? null : _submit,
            child: isPosting
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
              : Text(
                  isScheduled ? 'Schedule' : 'Post',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Category
            _sectionLabel('Category'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final sel = selectedCategory == cat['value'];
                return GestureDetector(
                  onTap: () =>
                    setState(() => selectedCategory = cat['value']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? TPSTheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                          ? TPSTheme.primary : TPSTheme.accentBorder)),
                    child: Text(cat['label']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: sel ? Colors.white : TPSTheme.textDark)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Target class
            _sectionLabel('Post to'),
            const SizedBox(height: 8),
            _dropdown(),

            const SizedBox(height: 20),

            // Title
            _sectionLabel('Title *'),
            const SizedBox(height: 8),
            _field(
              controller: titleController,
              hint: 'e.g. Complete pages 12–14 in maths workbook',
              maxLength: 200),

            const SizedBox(height: 16),

            // Content
            _sectionLabel('Description'),
            const SizedBox(height: 8),
            _field(
              controller: contentController,
              hint: 'Write more details here (optional)',
              maxLines: 4),

            const SizedBox(height: 20),

            // Attachments
            _sectionLabel('Attachments'),
            const SizedBox(height: 8),
            if (uploadedFileUrls.isNotEmpty)
              ...uploadedFileUrls.map((url) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: TPSTheme.accentLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TPSTheme.accentBorder)),
                child: Row(children: [
                  const Icon(Icons.attach_file,
                    size: 16, color: TPSTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      url.split('/').last,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13, color: TPSTheme.textDark))),
                  GestureDetector(
                    onTap: () => setState(
                      () => uploadedFileUrls.remove(url)),
                    child: const Icon(Icons.close,
                      size: 16, color: Colors.red)),
                ]),
              )),
            GestureDetector(
              onTap: isUploading ? null : _pickFile,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: TPSTheme.accentBorder,
                    style: BorderStyle.solid)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    isUploading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: TPSTheme.primary))
                      : const Icon(Icons.upload_file,
                          color: TPSTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isUploading
                        ? 'Uploading...'
                        : 'Attach PDF or Image',
                      style: const TextStyle(
                        fontSize: 13,
                        color: TPSTheme.primary,
                        fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── SEND OPTIONS ─────────────────────────────
            _sectionLabel('When to send'),
            const SizedBox(height: 12),

            // Option 1 — Send now
            _sendOption(
              selected: !isScheduled,
              onTap: () => setState(() => isScheduled = false),
              icon: Icons.send_rounded,
              title: 'Send right away',
              subtitle: 'Post is published immediately and\n'
                'parents are notified at once',
            ),

            const SizedBox(height: 10),

            // Option 2 — Schedule
            _sendOption(
              selected: isScheduled,
              onTap: () => setState(() => isScheduled = true),
              icon: Icons.schedule_rounded,
              title: 'Schedule for later',
              subtitle: 'Pick a date and time — the post\n'
                'will be sent automatically',
            ),

            // Date/time picker (visible only when scheduled)
            if (isScheduled) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickScheduleDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheduledDate != null
                        ? TPSTheme.primary : TPSTheme.accentBorder,
                      width: scheduledDate != null ? 2 : 1)),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: TPSTheme.accentLight,
                        borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.calendar_today,
                        color: TPSTheme.primary, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Scheduled date & time',
                            style: TextStyle(
                              fontSize: 12,
                              color: TPSTheme.textLight,
                              fontWeight: FontWeight.w500)),
                          const SizedBox(height: 3),
                          Text(_scheduledLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: scheduledDate != null
                                ? TPSTheme.textDark
                                : TPSTheme.textHint)),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_outlined,
                      color: TPSTheme.primary, size: 18),
                  ]),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isPosting ? null : _submit,
                icon: isPosting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                  : Icon(
                      isScheduled
                        ? Icons.schedule_rounded
                        : Icons.send_rounded),
                label: Text(
                  isPosting
                    ? (isScheduled ? 'Scheduling...' : 'Posting...')
                    : (isScheduled
                        ? 'Schedule Post'
                        : 'Post Now'),
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TPSTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sendOption({
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
    required String title,
    required String subtitle,
  }) =>
    GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? TPSTheme.accentLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? TPSTheme.primary : TPSTheme.accentBorder,
            width: selected ? 2 : 1)),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: selected ? TPSTheme.primary : TPSTheme.accentLight,
              borderRadius: BorderRadius.circular(11)),
            child: Icon(icon,
              color: selected ? Colors.white : TPSTheme.primary,
              size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected
                      ? TPSTheme.primary : TPSTheme.textDark)),
                const SizedBox(height: 3),
                Text(subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: TPSTheme.textLight,
                    height: 1.4)),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? TPSTheme.primary : Colors.transparent,
              border: Border.all(
                color: selected
                  ? TPSTheme.primary : TPSTheme.accentBorder,
                width: 2)),
            child: selected
              ? const Icon(Icons.check,
                  color: Colors.white, size: 12)
              : null,
          ),
        ]),
      ),
    );

  Widget _sectionLabel(String text) => Text(text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: TPSTheme.textDark));

  Widget _dropdown() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: TPSTheme.accentBorder)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        value: selectedClassId,
        style: const TextStyle(
          fontSize: 14, color: TPSTheme.textDark),
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('Entire Branch')),
          ...widget.classes.map<DropdownMenuItem<String>>((c) =>
            DropdownMenuItem(
              value: c['class_id'].toString(),
              child: Text(c['class_name']))),
        ],
        onChanged: (v) => setState(() => selectedClassId = v),
      ),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
  }) =>
    TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(
        fontSize: 14, color: TPSTheme.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: TPSTheme.textHint, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: TPSTheme.accentBorder)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: TPSTheme.accentBorder)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: TPSTheme.primary, width: 2)),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: maxLines > 1 ? 14 : 0)),
    );
}
