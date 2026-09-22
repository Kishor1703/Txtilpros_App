import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../location/location_screen.dart';
import '../../location/location_controller.dart';

class EmployeeShell extends StatefulWidget {
  final String weekStart;
  const EmployeeShell({super.key, required this.weekStart});
  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  String section = 'reports';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EmployeeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekStart != widget.weekStart) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      await context.read<AppState>().loadEmployeeWorkspace();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final summary = state.summary;
    final attendance = (summary['attendance'] as Map?) ?? {};
    final pending = state.leaves.where((l) => l['status'] == 'pending').length;
    final approved = state.leaves.where((l) => l['status'] == 'approved').length;
    final rejected = state.leaves.where((l) => l['status'] == 'rejected').length;
    final todayStatus = attendance['todayStatus'];
    final todayLabel = todayStatus == 'holiday'
        ? 'Holiday today'
        : todayStatus == 'comp-off'
            ? 'Comp-off today'
            : todayStatus == 'present'
                ? 'Present today'
                : 'Awaiting report today';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionIntro(
            eyebrow: 'Workspace',
            title: 'Your reporting dashboard',
            description: 'Submit field activity, apply for leave, and track both your work updates and admin decisions in one place.',
            aside: StatusPill(todayLabel, statusKey: 'completed'),
          ),
          const SizedBox(height: 14),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else ...[
            StatGrid(children: [
              StatCard(label: 'Reports this week', value: '${summary['totalReports'] ?? 0}', hint: 'Daily submissions captured'),
              StatCard(label: 'Hours logged', value: '${summary['totalHours'] ?? 0}', hint: 'Total service effort recorded'),
              StatCard(label: 'Present days', value: '${attendance['presentDays'] ?? 0}', hint: todayLabel),
              StatCard(label: 'Absent days', value: '${attendance['absentDays'] ?? 0}', hint: '${summary['attentionNeeded'] ?? 0} blocked or support-needed jobs'),
              StatCard(label: 'Pending leaves', value: '$pending', hint: '$approved approved requests'),
              StatCard(label: 'Rejected leaves', value: '$rejected', hint: 'Requests not approved yet'),
            ]),
            const SizedBox(height: 14),
            SectionNav(
              items: [const MapEntry('Reports', 'reports'), const MapEntry('Leave', 'leave'), const MapEntry('Payslips', 'payslips'),
                if (context.select<LocationController, bool>((l) => l.showNavigation)) const MapEntry('Live Location', 'location')],
              active: section,
              onSelect: (v) => setState(() => section = v),
            ),
            const SizedBox(height: 14),
            if (section == 'reports') const _EmployeeReportsSection(),
            if (section == 'leave') const _EmployeeLeaveSection(),
            if (section == 'payslips') const _EmployeePayslipsSection(),
            if (section == 'location') const LiveLocationScreen(),
          ],
        ],
      ),
    );
  }
}

// -------------------- Reports --------------------

class _EmployeeReportsSection extends StatefulWidget {
  const _EmployeeReportsSection();
  @override
  State<_EmployeeReportsSection> createState() => _EmployeeReportsSectionState();
}

class _EmployeeReportsSectionState extends State<_EmployeeReportsSection> {
  Map<String, dynamic> form = createEmptyReportForm();
  String editingReportId = '';
  final siteCtrl = TextEditingController();
  final clientCtrl = TextEditingController();
  final machineCtrl = TextEditingController();
  final hoursCtrl = TextEditingController(text: '8');
  final summaryCtrl = TextEditingController();
  final problemsCtrl = TextEditingController();
  final materialsCtrl = TextEditingController();
  String shift = 'General';
  String status = 'completed';
  String workDate = '';
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    workDate = form['workDate'];
  }

  void _resetForm({Map<String, dynamic>? seed}) {
    form = seed ?? createEmptyReportForm();
    siteCtrl.text = form['siteName'] ?? '';
    clientCtrl.text = form['clientName'] ?? '';
    machineCtrl.text = form['machineName'] ?? '';
    hoursCtrl.text = (form['hoursWorked'] ?? '8').toString();
    summaryCtrl.text = form['workSummary'] ?? '';
    problemsCtrl.text = form['problemsObserved'] ?? '';
    materialsCtrl.text = form['materialsUsed'] ?? '';
    shift = form['shift'] ?? 'General';
    status = form['status'] ?? 'completed';
    workDate = form['workDate'];
    setState(() {});
  }

  Future<Map<String, dynamic>?> _pickPhoto() async {
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1600);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    return {'name': file.name, 'size': bytes.length, 'type': 'image/jpeg', 'dataUrl': dataUrl};
  }

  Future<void> _addBeforePhoto() async {
    final photo = await _pickPhoto();
    if (photo == null) return;
    final before = List<Map<String, dynamic>>.from(form['photos']['before'] ?? []);
    if (before.length >= 4) {
      showToast(context, 'You can select up to 4 before-work photos.', error: true);
      return;
    }
    before.add({...photo, 'kind': 'before'});
    setState(() => form['photos']['before'] = before);
  }

  Future<void> _setAfterPhoto() async {
    final photo = await _pickPhoto();
    if (photo == null) return;
    setState(() => form['photos']['after'] = {...photo, 'kind': 'after'});
  }

  Future<void> _submit() async {
    form['siteName'] = siteCtrl.text;
    form['clientName'] = clientCtrl.text;
    form['machineName'] = machineCtrl.text;
    form['hoursWorked'] = hoursCtrl.text;
    form['workSummary'] = summaryCtrl.text;
    form['problemsObserved'] = problemsCtrl.text;
    form['materialsUsed'] = materialsCtrl.text;
    form['shift'] = shift;
    form['status'] = status;
    form['workDate'] = workDate;

    if (siteCtrl.text.isEmpty || summaryCtrl.text.isEmpty) {
      showToast(context, 'Site name and work summary are required.', error: true);
      return;
    }

    try {
      await context.read<AppState>().submitReport(form, editingReportId: editingReportId.isEmpty ? null : editingReportId);
      if (mounted) showToast(context, editingReportId.isEmpty ? 'Work report saved' : 'Work report updated');
      _resetForm();
      editingReportId = '';
      await context.read<AppState>().loadEmployeeWorkspace();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) {
      setState(() => workDate = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final before = List<Map<String, dynamic>>.from(form['photos']['before'] ?? []);
    final after = form['photos']['after'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('Daily update'),
                        Text(editingReportId.isEmpty ? 'Submit work report' : 'Edit work report', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        MutedText(editingReportId.isEmpty
                            ? 'Capture work done, machine status, materials used, and before-after photo proof from the field.'
                            : 'Update your submitted report. Edits are allowed only within 1 hour of submission.'),
                      ],
                    ),
                  ),
                  if (editingReportId.isNotEmpty)
                    GhostButton(
                        label: 'Cancel edit',
                        onPressed: () {
                          editingReportId = '';
                          _resetForm();
                        }),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 14, runSpacing: 14, children: [
                LabeledField(label: 'Work date', child: TextField(readOnly: true, onTap: _pickDate, controller: TextEditingController(text: workDate))),
                LabeledField(label: 'Site name', child: TextField(controller: siteCtrl, decoration: const InputDecoration(hintText: 'Mill or branch'))),
                LabeledField(label: 'Client name', child: TextField(controller: clientCtrl)),
                LabeledField(label: 'Machine name', child: TextField(controller: machineCtrl, decoration: const InputDecoration(hintText: 'Air Jet Loom / model'))),
                LabeledField(
                  label: 'Shift',
                  child: DropdownButtonFormField<String>(
                    initialValue: shift,
                    items: const ['General', 'Morning', 'Afternoon', 'Night'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => shift = v ?? 'General'),
                  ),
                ),
                LabeledField(label: 'Hours worked', child: TextField(controller: hoursCtrl, keyboardType: TextInputType.number)),
                LabeledField(
                  label: 'Status',
                  child: DropdownButtonFormField<String>(
                    initialValue: status,
                    items: const [
                      DropdownMenuItem(value: 'completed', child: Text('Completed')),
                      DropdownMenuItem(value: 'needs-support', child: Text('Needs support')),
                      DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                    ],
                    onChanged: (v) => setState(() => status = v ?? 'completed'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              LabeledField(label: 'Work summary', wide: true, child: TextField(controller: summaryCtrl, maxLines: 3)),
              const SizedBox(height: 12),
              LabeledField(label: 'Problems observed', wide: true, child: TextField(controller: problemsCtrl, maxLines: 3)),
              const SizedBox(height: 12),
              LabeledField(label: 'Materials used', wide: true, child: TextField(controller: materialsCtrl, maxLines: 3)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: SecondaryButton(label: 'Add before-work photo (${before.length}/4)', onPressed: _addBeforePhoto)),
                  const SizedBox(width: 10),
                  Expanded(child: SecondaryButton(label: after == null ? 'Add after-work photo' : 'Replace after-work photo', onPressed: _setAfterPhoto)),
                ],
              ),
              const SizedBox(height: 10),
              if (before.isEmpty && after == null)
                const EmptyState('Before and after photo previews will appear here.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...before.asMap().entries.map((e) => _PhotoChip(
                          label: 'Before work ${e.key + 1}',
                          dataUrl: e.value['dataUrl'],
                          onRemove: () => setState(() {
                            before.removeAt(e.key);
                            form['photos']['before'] = before;
                          }),
                        )),
                    if (after != null)
                      _PhotoChip(label: 'After work', dataUrl: after['dataUrl'], onRemove: () => setState(() => form['photos']['after'] = null)),
                  ],
                ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: state.submitting ? (editingReportId.isEmpty ? 'Submitting report...' : 'Updating report...') : (editingReportId.isEmpty ? 'Save work report' : 'Update work report'),
                loading: state.submitting,
                expand: true,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Eyebrow('Report stream'),
                        Text('Your weekly reports', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  StatusPill('${state.reports.length} reports', statusKey: 'completed'),
                ],
              ),
              const SizedBox(height: 10),
              if (state.reports.isEmpty)
                const EmptyState('No reports found for the selected week.')
              else
                ...state.reports.map((report) {
                  final createdAt = DateTime.tryParse(report['createdAt']?.toString() ?? '');
                  final elapsed = createdAt != null ? DateTime.now().difference(createdAt) : const Duration(hours: 999);
                  final canEdit = elapsed.inMilliseconds <= 60 * 60 * 1000;
                  final remainingMin = canEdit ? (60 - elapsed.inMinutes).clamp(0, 60) : 0;
                  final st = (report['status'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(report['siteName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                                    MutedText('${fmtDate(report['workDate'])} | ${report['shift']} | ${report['hoursWorked']} hrs'),
                                  ],
                                ),
                              ),
                              StatusPill(st.replaceAll('-', ' '), statusKey: st),
                            ],
                          ),
                          if (canEdit) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Edit available for $remainingMin more min', style: const TextStyle(fontSize: 12, color: AppColors.gray)),
                                GhostButton(
                                  label: 'Edit report',
                                  onPressed: () {
                                    editingReportId = report['_id'].toString();
                                    _resetForm(seed: createReportFormFromReport(Map<String, dynamic>.from(report)));
                                  },
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          if ((report['machineName'] ?? '').toString().isNotEmpty) Text('Machine: ${report['machineName']}'),
                          if ((report['clientName'] ?? '').toString().isNotEmpty) Text('Client: ${report['clientName']}'),
                          Text('Work: ${report['workSummary'] ?? ''}'),
                          if ((report['problemsObserved'] ?? '').toString().isNotEmpty) Text('Problems: ${report['problemsObserved']}'),
                          if ((report['materialsUsed'] ?? '').toString().isNotEmpty) Text('Materials: ${report['materialsUsed']}'),
                          const SizedBox(height: 6),
                          MutedText('Sheets sync: ${report['sheetsSync']?['status'] ?? 'pending'} · ${(report['photos'] as List?)?.length ?? 0} photos'),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoChip extends StatelessWidget {
  final String label;
  final String? dataUrl;
  final VoidCallback onRemove;
  const _PhotoChip({required this.label, required this.dataUrl, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    if (dataUrl != null && dataUrl!.contains(',')) {
      try {
        bytes = base64Decode(dataUrl!.split(',').last);
      } catch (_) {}
    }
    return Container(
      width: 130,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.light)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: bytes != null
                ? Image.memory(bytes, height: 90, width: 118, fit: BoxFit.cover)
                : Container(height: 90, width: 118, color: Colors.black12),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(padding: EdgeInsets.zero, iconSize: 18, onPressed: onRemove, icon: const Icon(Icons.close)),
          ),
        ],
      ),
    );
  }
}

// -------------------- Leave --------------------

class _EmployeeLeaveSection extends StatefulWidget {
  const _EmployeeLeaveSection();
  @override
  State<_EmployeeLeaveSection> createState() => _EmployeeLeaveSectionState();
}

class _EmployeeLeaveSectionState extends State<_EmployeeLeaveSection> {
  Map<String, dynamic> form = createEmptyLeaveForm();
  final reasonCtrl = TextEditingController();

  Future<void> _pickDate(String field) async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) {
      setState(() => form[field] = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _submit() async {
    if (reasonCtrl.text.isEmpty) {
      showToast(context, 'Please explain the reason for leave.', error: true);
      return;
    }
    try {
      await context.read<AppState>().submitLeave({...form, 'reason': reasonCtrl.text});
      if (mounted) showToast(context, 'Leave request submitted');
      setState(() {
        form = createEmptyLeaveForm();
        reasonCtrl.clear();
      });
      await context.read<AppState>().loadEmployeeWorkspace();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Leave request'),
              const Text('Apply for leave', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const MutedText('Choose your leave dates in advance. Approved working-day leave is counted against the 15 paid leave days available each year.'),
              const SizedBox(height: 12),
              Wrap(spacing: 14, runSpacing: 14, children: [
                LabeledField(label: 'From date', child: TextField(readOnly: true, controller: TextEditingController(text: form['fromDate']), onTap: () => _pickDate('fromDate'))),
                LabeledField(label: 'To date', child: TextField(readOnly: true, controller: TextEditingController(text: form['toDate']), onTap: () => _pickDate('toDate'))),
              ]),
              const SizedBox(height: 12),
              LabeledField(label: 'Reason', wide: true, child: TextField(controller: reasonCtrl, maxLines: 4, decoration: const InputDecoration(hintText: 'Explain why you need leave'))),
              const SizedBox(height: 14),
              PrimaryButton(label: state.leaveSubmitting ? 'Submitting leave...' : 'Submit leave request', loading: state.leaveSubmitting, expand: true, onPressed: _submit),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow('Leave tracker'),
                        Text('Your leave requests', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  StatusPill('${state.leaves.length} requests', statusKey: 'completed'),
                ],
              ),
              const SizedBox(height: 10),
              if (state.leaves.isEmpty)
                const EmptyState('No leave requests submitted yet.')
              else
                ...state.leaves.map((leave) {
                  final st = (leave['status'] ?? '').toString();
                  final from = leave['fromDate'] ?? leave['leaveDate'];
                  final to = leave['toDate'] ?? leave['leaveDate'] ?? leave['fromDate'];
                  final range = from == null ? 'Date not available' : (fmtDate(from) == fmtDate(to) ? fmtDate(from) : '${fmtDate(from)} - ${fmtDate(to)}');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(range, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    MutedText('Applied on ${fmtDate(leave['createdAt'])}'),
                                  ],
                                ),
                              ),
                              StatusPill(st, statusKey: st),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Reason: ${leave['reason'] ?? ''}'),
                          if (st == 'approved') Text('Paid leave counted: ${leave['paidLeaveDays'] ?? 0} day(s)'),
                          if (st == 'approved') Text('Remaining paid leaves: ${leave['remainingPaidLeaves'] ?? 0}'),
                          if ((leave['adminComment'] ?? '').toString().isNotEmpty) Text('Admin note: ${leave['adminComment']}'),
                          const SizedBox(height: 4),
                          MutedText(leave['reviewedAt'] != null ? 'Reviewed by ${leave['reviewedBy']?['name'] ?? 'Admin'}' : 'Waiting for admin decision'),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

// -------------------- Payslips --------------------

class _EmployeePayslipsSection extends StatelessWidget {
  const _EmployeePayslipsSection();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('Payslips'),
                    Text('Your approved payslips', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              StatusPill('${state.salaries.length} payslips', statusKey: 'completed'),
            ],
          ),
          const SizedBox(height: 10),
          if (state.salaries.isEmpty)
            const EmptyState('No approved payslips available yet.')
          else
            ...state.salaries.map((salary) {
              final month = monthLabel(int.tryParse(salary['month']?.toString() ?? '1') ?? 1, int.tryParse(salary['year']?.toString() ?? '0') ?? 0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(month, style: const TextStyle(fontWeight: FontWeight.w800)),
                                MutedText('Generated ${salary['generatedDate'] != null ? fmtDate(salary['generatedDate']) : '-'}'),
                              ],
                            ),
                          ),
                          StatusPill(salary['paymentStatus'] ?? 'pending', statusKey: salary['paymentStatus']),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Present Days: ${salary['presentDays'] ?? 0}'),
                      Text('Absent Days: ${salary['absentDays'] ?? 0}'),
                      Text('Net Salary: ₹${fmtMoney(salary['netSalary'])}'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          MutedText('Email: ${salary['emailDeliveryStatus'] ?? 'pending'}'),
                          SecondaryButton(
                            label: 'Download PDF',
                            onPressed: () async {
                              try {
                                final path = await state.employeePayslipDownload(Map<String, dynamic>.from(salary));
                                showToast(context, 'Saved payslip to $path');
                              } catch (e) {
                                showToast(context, e.toString(), error: true);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
