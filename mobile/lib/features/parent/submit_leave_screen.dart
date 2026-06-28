import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/services/api_service.dart';

class SubmitLeaveScreen extends StatefulWidget {
  final List<dynamic> children;
  const SubmitLeaveScreen({super.key, required this.children});
  @override
  State<SubmitLeaveScreen> createState() => _SubmitLeaveScreenState();
}

class _SubmitLeaveScreenState extends State<SubmitLeaveScreen> {
  String? selectedStudentId;
  DateTime fromDate = DateTime.now().add(const Duration(days: 1));
  DateTime toDate   = DateTime.now().add(const Duration(days: 2));
  String selectedReason = '🤒 Illness';
  final detailController = TextEditingController();
  bool isSubmitting = false;
  bool submitted = false;

  final reasons = ['🤒 Illness','👨‍👩‍👧 Family Event','✈️ Travel','🏥 Medical','📝 Other'];

  @override
  void initState() {
    super.initState();
    if (widget.children.isNotEmpty) {
      selectedStudentId = widget.children[0]['student_id'].toString();
    }
  }

  int get duration =>
      toDate.difference(fromDate).inDays + 1;

  Future<void> _pick(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: TPSTheme.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) { fromDate = picked; if (toDate.isBefore(fromDate)) toDate = fromDate; }
        else toDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a child'), backgroundColor: TPSTheme.error));
      return;
    }
    if (toDate.isBefore(fromDate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('End date cannot be before start date'), backgroundColor: TPSTheme.error));
      return;
    }
    setState(() => isSubmitting = true);
    try {
      await ApiService.post('/leaves', {
        'student_id': selectedStudentId,
        'from_date': fromDate.toIso8601String().split('T')[0],
        'to_date':   toDate.toIso8601String().split('T')[0],
        'reason': '$selectedReason — ${detailController.text.trim()}',
      });
      setState(() { submitted = true; isSubmitting = false; });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to submit'), backgroundColor: TPSTheme.error));
      }
      setState(() => isSubmitting = false);
    }
  }

  @override
  void dispose() {
    detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPSTheme.background,
      appBar: AppBar(title: const Text('Apply for Leave')),
      body: submitted ? _successView() : _formView(),
      bottomNavigationBar: submitted ? null : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: isSubmitting ? null : _submit,
            child: isSubmitting
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit Leave Request'),
          ),
        ),
      ),
    );
  }

  Widget _formView() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      // Child selector
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Student'),
        if (widget.children.length == 1)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TPSTheme.accentLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TPSTheme.accentBorder),
            ),
            child: Row(children: [
              CircleAvatar(radius: 19, backgroundColor: TPSTheme.primary,
                  child: Text(widget.children[0]['name'][0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.children[0]['name'],
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: TPSTheme.textDark)),
                Text(widget.children[0]['class_name'] ?? 'No Class',
                    style: const TextStyle(fontSize: 11, color: TPSTheme.textLight)),
              ]),
            ]),
          )
        else
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Select Child *'),
            value: selectedStudentId,
            items: widget.children
                .map<DropdownMenuItem<String>>((c) => DropdownMenuItem(
                      value: c['student_id'].toString(),
                      child: Text(c['name']),
                    ))
                .toList(),
            onChanged: (v) => setState(() => selectedStudentId = v),
          ),
      ])),
      const SizedBox(height: 12),

      // Dates
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Leave Dates'),
        Row(children: [
          Expanded(child: _dateField('From', fromDate, () => _pick(true))),
          const SizedBox(width: 10),
          Expanded(child: _dateField('To', toDate, () => _pick(false))),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: TPSTheme.accentLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TPSTheme.accentBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('📅'),
            const SizedBox(width: 6),
            Text('$duration ${duration == 1 ? "day" : "days"} leave',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: TPSTheme.primary)),
          ]),
        ),
      ])),
      const SizedBox(height: 12),

      // Reason
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Reason'),
        Wrap(spacing: 7, runSpacing: 7,
          children: reasons.map((r) {
            final active = selectedReason == r;
            return GestureDetector(
              onTap: () => setState(() => selectedReason = r),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? TPSTheme.primary : TPSTheme.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active ? TPSTheme.primary : TPSTheme.accentBorder),
                ),
                child: Text(r, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: active ? Colors.white : TPSTheme.primary)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: detailController,
          maxLines: 3,
          style: const TextStyle(color: TPSTheme.textDark),
          decoration: const InputDecoration(
              hintText: 'Add more details (optional)…'),
        ),
      ])),
    ],
  );

  Widget _successView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(
              color: TPSTheme.accentLight, shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_outline,
              color: TPSTheme.primary, size: 36),
        ),
        const SizedBox(height: 16),
        const Text('Leave Request Submitted!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                color: TPSTheme.textDark)),
        const SizedBox(height: 8),
        const Text('The school will review and notify you shortly.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: TPSTheme.textLight)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(minimumSize: const Size(180, 46)),
          child: const Text('Back to Home'),
        ),
      ]),
    ),
  );

  Widget _dateField(String label, DateTime date, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: TPSTheme.textLight, letterSpacing: 0.5)),
          const SizedBox(height: 5),
          Container(
            height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: TPSTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: TPSTheme.accentBorder),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              Text('${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(
                      fontSize: 14, color: TPSTheme.textDark)),
              const Icon(Icons.calendar_today_outlined,
                  size: 16, color: TPSTheme.textLight),
            ]),
          ),
        ]),
      );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: TPSTheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: TPSTheme.accentBorder),
    ),
    child: child,
  );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600,
        color: TPSTheme.textLight, letterSpacing: 0.6)),
  );
}
