import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/services/api_service.dart';

class SubmitLeaveScreen extends StatefulWidget {
  final List<dynamic> children;
  final VoidCallback? onHome;
  const SubmitLeaveScreen({super.key, required this.children, this.onHome});
  @override
  State<SubmitLeaveScreen> createState() => _SubmitLeaveScreenState();
}

class _SubmitLeaveScreenState extends State<SubmitLeaveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Apply form state ──
  String? selectedStudentId;
  DateTime fromDate = DateTime.now().add(const Duration(days: 1));
  DateTime toDate   = DateTime.now().add(const Duration(days: 2));
  String selectedReason = '🤒 Illness';
  final detailController = TextEditingController();
  bool isSubmitting = false;

  // ── History state ──
  List<dynamic> leaveHistory = [];
  bool isLoadingHistory = true;

  final reasons = [
    '🤒 Illness',
    '👨‍👩‍👧 Family Event',
    '✈️ Travel',
    '🏥 Medical',
    '📝 Other',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.children.isNotEmpty) {
      selectedStudentId = widget.children[0]['student_id'].toString();
    }
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    detailController.dispose();
    super.dispose();
  }

  int get duration => toDate.difference(fromDate).inDays + 1;

  // ── Load leave history ──
  Future<void> _loadHistory() async {
    setState(() => isLoadingHistory = true);
    try {
      final data = await ApiService.get('/leaves');
      if (mounted) {
        setState(() {
          leaveHistory = data as List<dynamic>;
          isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingHistory = false);
    }
  }

  Future<void> _pick(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: TPSTheme.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
          if (toDate.isBefore(fromDate)) toDate = fromDate;
        } else {
          toDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a child'),
          backgroundColor: TPSTheme.error));
      return;
    }
    if (toDate.isBefore(fromDate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('End date cannot be before start date'),
          backgroundColor: TPSTheme.error));
      return;
    }
    setState(() => isSubmitting = true);
    try {
      await ApiService.post('/leaves', {
        'student_id': selectedStudentId,
        'from_date': fromDate.toIso8601String().split('T')[0],
        'to_date': toDate.toIso8601String().split('T')[0],
        'reason': '$selectedReason — ${detailController.text.trim()}',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Leave request submitted!'),
            backgroundColor: TPSTheme.primary));
        detailController.clear();
        // Switch to history tab and reload
        _tabController.animateTo(1);
        _loadHistory();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to submit'),
            backgroundColor: TPSTheme.error));
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TPSTheme.background,
      appBar: AppBar(
        backgroundColor: TPSTheme.primaryDark,
        foregroundColor: Colors.white,
        title: const Text('Leave Management'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Apply Leave'),
            Tab(text: 'Leave History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _applyTab(),
          _historyTab(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  APPLY TAB
  // ═══════════════════════════════════════════
  Widget _applyTab() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Child selector
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('STUDENT'),
                    if (widget.children.length == 1)
                      _studentChip(widget.children[0])
                    else
                      DropdownButtonFormField<String>(
                        decoration:
                            const InputDecoration(labelText: 'Select Child *'),
                        value: selectedStudentId,
                        items: widget.children
                            .map<DropdownMenuItem<String>>((c) =>
                                DropdownMenuItem(
                                  value: c['student_id'].toString(),
                                  child: Text(c['name']),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => selectedStudentId = v),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Dates
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('LEAVE DATES'),
                    Row(children: [
                      Expanded(
                          child:
                              _dateField('From', fromDate, () => _pick(true))),
                      const SizedBox(width: 10),
                      Expanded(
                          child:
                              _dateField('To', toDate, () => _pick(false))),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: TPSTheme.accentLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: TPSTheme.accentBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('📅'),
                          const SizedBox(width: 6),
                          Text(
                            '$duration ${duration == 1 ? "day" : "days"} leave',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: TPSTheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Reason
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('REASON'),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: reasons.map((r) {
                        final active = selectedReason == r;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => selectedReason = r),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 6),
                            decoration: BoxDecoration(
                              color: active
                                  ? TPSTheme.primary
                                  : TPSTheme.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: active
                                      ? TPSTheme.primary
                                      : TPSTheme.accentBorder),
                            ),
                            child: Text(r,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: active
                                        ? Colors.white
                                        : TPSTheme.primary)),
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
                  ],
                ),
              ),
            ],
          ),
        ),

        // Submit button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : _submit,
                icon: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  isSubmitting ? 'Submitting...' : 'Submit Leave Request',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TPSTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  HISTORY TAB
  // ═══════════════════════════════════════════
  Widget _historyTab() {
    if (isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (leaveHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                  color: TPSTheme.accentLight, shape: BoxShape.circle),
              child: const Icon(Icons.inbox_rounded,
                  color: TPSTheme.primary, size: 32),
            ),
            const SizedBox(height: 14),
            const Text('No leave requests yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: TPSTheme.textDark)),
            const SizedBox(height: 4),
            const Text('Your submitted leaves will appear here',
                style: TextStyle(fontSize: 13, color: TPSTheme.textLight)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: leaveHistory.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _leaveCard(leaveHistory[i]),
      ),
    );
  }

  Widget _leaveCard(dynamic leave) {
    final status = (leave['status'] ?? 'pending').toString();
    final studentName = leave['student_name'] ?? 'Student';
    final reason = leave['reason'] ?? '';
    final fromStr = _fmtDate(leave['from_date']);
    final toStr = _fmtDate(leave['to_date']);
    final reviewerName = leave['reviewer_name'];
    final reviewedAt = leave['reviewed_at'];

    // Calculate days
    int days = 1;
    try {
      final f = DateTime.parse(leave['from_date']);
      final t = DateTime.parse(leave['to_date']);
      days = t.difference(f).inDays + 1;
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: TPSTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'approved'
              ? const Color(0xFFB7E4A8)
              : status == 'rejected'
                  ? const Color(0xFFF09595)
                  : TPSTheme.accentBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: status == 'approved'
                  ? const Color(0xFFF0FAF0)
                  : status == 'rejected'
                      ? const Color(0xFFFCF0F0)
                      : const Color(0xFFFFF9EC),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_statusIcon(status),
                      color: _statusColor(status), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: TPSTheme.textDark)),
                      const SizedBox(height: 2),
                      Text(
                        '$days ${days == 1 ? "day" : "days"} • $fromStr → $toStr',
                        style: const TextStyle(
                            fontSize: 11, color: TPSTheme.textLight),
                      ),
                    ],
                  ),
                ),
                _statusBadge(status),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reason.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes_rounded,
                          size: 14, color: TPSTheme.textHint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(reason,
                            style: const TextStyle(
                                fontSize: 12.5, color: TPSTheme.textMid)),
                      ),
                    ],
                  ),
                ],
                if (reviewerName != null && reviewedAt != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        status == 'approved'
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        size: 13,
                        color: _statusColor(status),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${status == 'approved' ? 'Approved' : 'Rejected'} by $reviewerName • ${_fmtDate(reviewedAt)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: _statusColor(status),
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(status).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor(status).withOpacity(0.3)),
      ),
      child: Text(
        status == 'approved'
            ? 'Approved'
            : status == 'rejected'
                ? 'Rejected'
                : 'Pending',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _statusColor(status)),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF2E7D32);
      case 'rejected':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFFE68A00);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  Widget _studentChip(dynamic child) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TPSTheme.accentLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TPSTheme.accentBorder),
        ),
        child: Row(children: [
          CircleAvatar(
              radius: 19,
              backgroundColor: TPSTheme.primary,
              child: Text(child['name'][0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700))),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(child['name'],
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TPSTheme.textDark)),
            Text(child['class_name'] ?? 'No Class',
                style:
                    const TextStyle(fontSize: 11, color: TPSTheme.textLight)),
          ]),
        ]),
      );

  Widget _dateField(String label, DateTime date, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: TPSTheme.textLight,
                  letterSpacing: 0.5)),
          const SizedBox(height: 5),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: TPSTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: TPSTheme.accentBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(
                        fontSize: 14, color: TPSTheme.textDark)),
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: TPSTheme.textLight),
              ],
            ),
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
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: TPSTheme.textLight,
                letterSpacing: 0.6)),
      );

  String _fmtDate(dynamic dateVal) {
    if (dateVal == null) return '';
    try {
      final dt = DateTime.parse(dateVal.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return dateVal.toString().split('T')[0];
    }
  }
}
