import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/models/leave_model.dart';
import '../../core/utils/time_utils.dart';
import '../../config/theme.dart';

class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({super.key});
  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<LeaveModel> pending  = [];
  List<LeaveModel> reviewed = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final all = await ApiService.get('/leaves');
      final leaves = (all as List).map((l) => LeaveModel.fromJson(l)).toList();
      setState(() {
        pending  = leaves.where((l) => l.status == 'pending').toList();
        reviewed = leaves.where((l) => l.status != 'pending').toList();
        isLoading = false;
      });
    } catch (_) { setState(() => isLoading = false); }
  }

  Future<void> _review(String leaveId, String status) async {
    try {
      await ApiService.put('/leaves/$leaveId', {'status': status});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Leave ${status == 'approved' ? 'approved ✅' : 'rejected ❌'}'),
          backgroundColor: status == 'approved'
              ? TPSTheme.primary : TPSTheme.error,
        ));
      }
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to update leave'),
            backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TPSTheme.background,
    appBar: AppBar(
      backgroundColor: TPSTheme.primaryDark,
      foregroundColor: Colors.white,
      title: const Text('Leave Requests'),
      bottom: TabBar(
        controller: _tabs,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: TPSTheme.accent,
        tabs: [
          Tab(text: 'Pending (${pending.length})'),
          Tab(text: 'Reviewed (${reviewed.length})'),
        ],
      ),
    ),
    body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            pending.isEmpty
                ? _emptyState('No pending leave requests')
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                      children: pending
                          .map((l) => _LeaveCard(
                                leave: l,
                                showActions: true,
                                onReview: _review,
                              ))
                          .toList(),
                    ),
                  ),
            reviewed.isEmpty
                ? _emptyState('No reviewed requests yet')
                : ListView(
                    padding: const EdgeInsets.all(14),
                    children: reviewed
                        .map((l) => _LeaveCard(leave: l))
                        .toList(),
                  ),
          ]),
  );

  Widget _emptyState(String msg) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('📋', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text(msg, style: const TextStyle(
          fontSize: 15, color: TPSTheme.textLight)),
    ]),
  );
}

// ── Expandable Leave Card ──────────────────────────────────────
class _LeaveCard extends StatefulWidget {
  final LeaveModel leave;
  final bool showActions;
  final Future<void> Function(String, String)? onReview;

  const _LeaveCard({
    required this.leave,
    this.showActions = false,
    this.onReview,
  });

  @override
  State<_LeaveCard> createState() => _LeaveCardState();
}

class _LeaveCardState extends State<_LeaveCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.leave;
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: TPSTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded ? l.statusColor : TPSTheme.accentBorder,
            width: _expanded ? 1.5 : 1,
          ),
        ),
        child: Column(children: [
          // Status strip top
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: l.statusColor,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: TPSTheme.accentLight,
                    child: Text(
                      l.studentName[0].toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: TPSTheme.primary,
                          fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.studentName,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: TPSTheme.textDark)),
                        if (l.parentName != null)
                          Text('Parent: ${l.parentName}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: TPSTheme.textLight)),
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: l.statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(l.statusLabel,
                        style: TextStyle(
                            color: l.statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),

                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.keyboard_arrow_down,
                        size: 18, color: TPSTheme.textHint),
                  ),
                ]),

                const SizedBox(height: 10),

                // Date range pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: TPSTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: TPSTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${l.from.day}/${l.from.month}/${l.from.year}'
                      '  →  ${l.to.day}/${l.to.month}/${l.to.year}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: TPSTheme.textDark),
                    ),
                    const Spacer(),
                    Text(
                      '${l.durationDays}d',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: TPSTheme.primary),
                    ),
                  ]),
                ),

                // Expandable section
                SizeTransition(
                  sizeFactor: _anim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),

                      // Reason
                      if (l.reason.isNotEmpty)
                        _detailRow(Icons.notes_outlined, 'Reason', l.reason),

                      // Submitted time
                      _detailRow(Icons.access_time_outlined, 'Submitted',
                          TimeUtils.formatFull(l.createdAt)),

                      // Reviewer info
                      if (l.reviewerName != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: l.statusBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: l.statusColor.withOpacity(0.3)),
                          ),
                          child: Row(children: [
                            Icon(
                              l.status == 'approved'
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined,
                              size: 16,
                              color: l.statusColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${l.status == 'approved' ? 'Approved' : 'Rejected'} by ${l.reviewerName}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: l.statusColor),
                                  ),
                                  if (l.reviewedAt != null)
                                    Text(
                                      TimeUtils.formatFull(l.reviewedAt),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: TPSTheme.textLight),
                                    ),
                                ],
                              ),
                            ),
                          ]),
                        ),
                      ],

                      // Action buttons
                      if (widget.showActions) ...[
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  widget.onReview?.call(
                                      l.leaveId, 'rejected'),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: TPSTheme.error,
                                side: BorderSide(
                                    color: TPSTheme.error),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  widget.onReview?.call(
                                      l.leaveId, 'approved'),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TPSTheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Icon(icon, size: 13, color: TPSTheme.textLight),
          const SizedBox(width: 6),
          SizedBox(width: 72,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: TPSTheme.textLight))),
          Expanded(child: Text(value,
              style: const TextStyle(
                  fontSize: 12, color: TPSTheme.textDark))),
        ]),
      );
}
