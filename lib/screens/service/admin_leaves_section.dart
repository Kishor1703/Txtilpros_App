import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class AdminLeavesSection extends StatefulWidget {
  const AdminLeavesSection({super.key});
  @override
  State<AdminLeavesSection> createState() => _AdminLeavesSectionState();
}

class _AdminLeavesSectionState extends State<AdminLeavesSection> {
  String statusFilter = 'all';
  int page = 1;
  String editingLeaveId = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      await context.read<AppState>().loadLeaves();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final leaves = state.leaves;
    final filtered = statusFilter == 'all' ? leaves : leaves.where((l) => l['status'] == statusFilter).toList();
    final pageItems = paginate(filtered, page);
    final pendingCount = leaves.where((l) => l['status'] == 'pending').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionIntro(
          eyebrow: 'Leave control',
          title: 'Manage leave requests',
          description:
              'Review leave applications from employees, approve or reject them, and track the 15-day yearly paid leave balance before confirming approval.',
          aside: StatusPill('$pendingCount pending requests', statusKey: 'needs-support'),
        ),
        const SizedBox(height: 10),
        GlassCard(
          child: Row(
            children: [
              const Text('Filter status:', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: statusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All requests')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (v) => setState(() {
                  statusFilter = v ?? 'all';
                  page = 1;
                }),
              ),
              const Spacer(),
              StatusPill('${filtered.length} requests', statusKey: 'completed'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (filtered.isEmpty)
          const EmptyState('No leave requests found for this filter.')
        else ...[
          ...pageItems.map((leave) => _LeaveCard(
                leave: leave,
                isEditing: editingLeaveId == leave['_id'],
                onToggleEdit: () => setState(() => editingLeaveId = editingLeaveId == leave['_id'] ? '' : leave['_id'].toString()),
                onEditSaved: () => setState(() => editingLeaveId = ''),
              )),
          Pagination(currentPage: page, totalItems: filtered.length, itemLabel: 'leave requests', onPageChange: (p) => setState(() => page = p)),
        ],
      ],
    );
  }
}

class _LeaveCard extends StatefulWidget {
  final dynamic leave;
  final bool isEditing;
  final VoidCallback onToggleEdit;
  final VoidCallback onEditSaved;
  const _LeaveCard({required this.leave, required this.isEditing, required this.onToggleEdit, required this.onEditSaved});

  @override
  State<_LeaveCard> createState() => _LeaveCardState();
}

class _LeaveCardState extends State<_LeaveCard> {
  final commentCtrl = TextEditingController();

  String _range() {
    final from = widget.leave['fromDate'] ?? widget.leave['leaveDate'];
    final to = widget.leave['toDate'] ?? widget.leave['leaveDate'] ?? widget.leave['fromDate'];
    if (from == null) return 'Date not available';
    final s = fmtDate(from);
    final e = fmtDate(to);
    return s == e ? s : '$s - $e';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final leave = widget.leave;
    final status = (leave['status'] ?? '').toString();
    final isLoading = state.leaveActionLoadingId == leave['_id'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(leave['user']?['name'] ?? 'Unknown employee', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      MutedText('${leave['user']?['employeeCode'] ?? leave['user']?['email'] ?? '-'} | ${leave['user']?['department'] ?? 'Department not set'}'),
                    ],
                  ),
                ),
                StatusPill(status, statusKey: status),
              ],
            ),
            const SizedBox(height: 8),
            Text('Leave dates: ${_range()}'),
            Text('Applied: ${fmtDate(leave['createdAt'])}'),
            Text('Working paid days: ${leave['requestedPaidLeaveDays'] ?? 0}'),
            Text('Remaining paid leaves: ${leave['remainingPaidLeaves'] ?? leave['paidLeaveLimit'] ?? 15}'),
            const SizedBox(height: 6),
            Text('Reason: ${leave['reason'] ?? ''}'),
            const SizedBox(height: 10),
            if (status == 'pending' || status == 'approved') ...[
              if (widget.isEditing)
                _LeaveEditForm(
                  leave: leave,
                  loading: isLoading,
                  onCancel: widget.onToggleEdit,
                  onSave: (values) async {
                    final ok = await state.leaveEdit(leave['_id'].toString(), values);
                    if (ok) {
                      widget.onEditSaved();
                      if (mounted) showToast(context, 'Leave request updated');
                    } else if (mounted) {
                      showToast(context, 'Could not update leave request', error: true);
                    }
                  },
                )
              else ...[
                Wrap(spacing: 8, children: [
                  GhostButton(label: 'Edit leave', onPressed: isLoading ? null : widget.onToggleEdit),
                ]),
                if (status == 'pending') ...[
                  const SizedBox(height: 8),
                  TextField(controller: commentCtrl, maxLines: 2, decoration: const InputDecoration(hintText: 'Optional admin note')),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    PrimaryButton(
                      label: isLoading ? 'Saving...' : 'Approve',
                      loading: isLoading,
                      onPressed: () async {
                        await state.leaveDecision(leave['_id'].toString(), 'approved', commentCtrl.text);
                        if (mounted) showToast(context, 'Leave request approved');
                      },
                    ),
                    SecondaryButton(
                      label: isLoading ? 'Saving...' : 'Reject',
                      onPressed: () async {
                        await state.leaveDecision(leave['_id'].toString(), 'rejected', commentCtrl.text);
                        if (mounted) showToast(context, 'Leave request rejected');
                      },
                    ),
                  ]),
                ],
              ],
            ] else ...[
              MutedText('Reviewed by ${leave['reviewedBy']?['name'] ?? 'Admin'} on ${leave['reviewedAt'] != null ? fmtDate(leave['reviewedAt']) : 'N/A'}'),
              if (status == 'approved') Text('Paid leave counted: ${leave['paidLeaveDays'] ?? 0} of ${leave['paidLeaveLimit'] ?? 15}'),
              if (status == 'approved') Text('Remaining paid leaves: ${leave['remainingPaidLeaves'] ?? 0}'),
              if ((leave['adminComment'] ?? '').toString().isNotEmpty) Text('Admin note: ${leave['adminComment']}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaveEditForm extends StatefulWidget {
  final dynamic leave;
  final bool loading;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSave;
  const _LeaveEditForm({required this.leave, required this.loading, required this.onCancel, required this.onSave});

  @override
  State<_LeaveEditForm> createState() => _LeaveEditFormState();
}

class _LeaveEditFormState extends State<_LeaveEditForm> {
  late TextEditingController fromCtrl;
  late TextEditingController toCtrl;
  late TextEditingController reasonCtrl;
  late TextEditingController paidDaysCtrl;
  late TextEditingController adminCommentCtrl;

  String _toInput(dynamic v) {
    if (v == null) return '';
    try {
      final d = DateTime.parse(v.toString());
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    final leave = widget.leave;
    fromCtrl = TextEditingController(text: _toInput(leave['fromDate'] ?? leave['leaveDate']));
    toCtrl = TextEditingController(text: _toInput(leave['toDate'] ?? leave['leaveDate'] ?? leave['fromDate']));
    reasonCtrl = TextEditingController(text: leave['reason']?.toString() ?? '');
    paidDaysCtrl = TextEditingController(text: (leave['paidLeaveDays'] ?? leave['requestedPaidLeaveDays'] ?? 0).toString());
    adminCommentCtrl = TextEditingController(text: leave['adminComment']?.toString() ?? '');
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) {
      ctrl.text = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            LabeledField(label: 'From date', child: TextField(controller: fromCtrl, readOnly: true, onTap: () => _pickDate(fromCtrl))),
            LabeledField(label: 'To date', child: TextField(controller: toCtrl, readOnly: true, onTap: () => _pickDate(toCtrl))),
            LabeledField(label: 'Paid leave days charged', child: TextField(controller: paidDaysCtrl, keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 10),
          LabeledField(label: 'Reason', wide: true, child: TextField(controller: reasonCtrl, maxLines: 2)),
          const SizedBox(height: 10),
          LabeledField(label: 'Admin note', wide: true, child: TextField(controller: adminCommentCtrl, maxLines: 2)),
          const SizedBox(height: 6),
          const MutedText(
              "Set paid leave days to 0 for an unpaid leave. The employee's remaining balance is recalculated from the 15-day annual allocation."),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            PrimaryButton(
              label: widget.loading ? 'Saving...' : 'Save changes',
              loading: widget.loading,
              onPressed: () => widget.onSave({
                'fromDate': fromCtrl.text,
                'toDate': toCtrl.text,
                'reason': reasonCtrl.text,
                'paidLeaveDays': num.tryParse(paidDaysCtrl.text) ?? 0,
                'adminComment': adminCommentCtrl.text,
              }),
            ),
            GhostButton(label: 'Cancel', onPressed: widget.onCancel),
          ]),
        ],
      ),
    );
  }
}
