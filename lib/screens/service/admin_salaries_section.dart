import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class AdminSalariesSection extends StatefulWidget {
  const AdminSalariesSection({super.key});

  @override
  State<AdminSalariesSection> createState() => _AdminSalariesSectionState();
}

class _AdminSalariesSectionState extends State<AdminSalariesSection> {
  String search = '';
  int page = 1;
  String openId = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      await context.read<AppState>().loadSalaries();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickMonth() async {
    final state = context.read<AppState>();
    final parts = state.salaryMonth.split('-');
    final initial = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      state.setSalaryMonth(
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}',
      );
      setState(() => page = 1);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final normalized = search.trim().toLowerCase();
    final filtered = state.salaries.where((record) {
      if (normalized.isEmpty) return true;
      final employee = record['employee'] ?? {};
      final haystack = [
        employee['name'],
        employee['employeeCode'],
        employee['department'],
        monthLabel(
          int.tryParse(record['month']?.toString() ?? '1') ?? 1,
          int.tryParse(record['year']?.toString() ?? '0') ?? 0,
        ),
      ].join(' ').toLowerCase();
      return haystack.contains(normalized);
    }).toList();
    final pageItems = paginate(filtered, page);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionIntro(
          eyebrow: 'Salary Review',
          title: 'Admin Salary Dashboard',
          description:
              'Attendance data flows into auto salary calculation, then admin review, edits, approval, payslip generation, email delivery, and salary history.',
          aside: OutlinedButton.icon(
            onPressed: _pickMonth,
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text(state.salaryMonth),
          ),
        ),
        const SizedBox(height: 10),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Name, employee ID, department, month, year',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() {
                  search = v;
                  page = 1;
                }),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Status:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  DropdownButton<String>(
                    value: state.salaryStatus.isEmpty ? '' : state.salaryStatus,
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All')),
                      DropdownMenuItem(value: 'paid', child: Text('Paid')),
                      DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    ],
                    onChanged: (v) {
                      state.setSalaryStatus(v ?? '');
                      setState(() => page = 1);
                      _load();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (filtered.isEmpty)
          const EmptyState('No salary records match the selected filters.')
        else ...[
          ...pageItems.map(
            (record) => _SalaryRow(
              record: record,
              isOpen: openId == record['_id'],
              onToggle: () => setState(
                () => openId =
                    openId == record['_id'] ? '' : record['_id'].toString(),
              ),
            ),
          ),
          Pagination(
            currentPage: page,
            totalItems: filtered.length,
            itemLabel: 'salary records',
            onPageChange: (p) => setState(() => page = p),
          ),
        ],
      ],
    );
  }
}

const _moneyFields = [
  ['basicSalary', 'Basic Salary'],
  ['incentives', 'Incentives'],
  ['overtimeAmount', 'Overtime Amount'],
  ['leaveDeduction', 'Leave Deduction'],
  ['otherDeductions', 'Other Deductions'],
];

class _SalaryRow extends StatefulWidget {
  final dynamic record;
  final bool isOpen;
  final VoidCallback onToggle;

  const _SalaryRow({
    required this.record,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  State<_SalaryRow> createState() => _SalaryRowState();
}

class _SalaryRowState extends State<_SalaryRow> {
  bool editing = false;
  bool historyOpen = false;
  Map<String, dynamic> editForm = {};
  final remarksCtrl = TextEditingController();
  final Map<String, TextEditingController> moneyCtrls = {};
  String paymentStatus = 'pending';

  void _startEdit() {
    final record = widget.record;
    editForm = {
      'basicSalary': record['basicSalary'] ?? 0,
      'incentives': record['incentives'] ?? 0,
      'overtimeAmount': record['overtimeAmount'] ?? 0,
      'leaveDeduction': record['leaveDeduction'] ?? 0,
      'otherDeductions': record['otherDeductions'] ?? 0,
      'paymentStatus': record['paymentStatus'] ?? 'pending',
      'remarks': record['remarks'] ?? '',
    };
    paymentStatus = editForm['paymentStatus'];
    remarksCtrl.text = editForm['remarks'].toString();
    for (final f in _moneyFields) {
      moneyCtrls[f[0]] = TextEditingController(
        text: editForm[f[0]].toString(),
      );
    }
    setState(() => editing = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final record = widget.record;
    final employee = record['employee'] ?? {};
    final approved = record['approvalStatus'] == 'approved';
    final saving = state.salarySavingId == record['_id'];
    final month = monthLabel(
      int.tryParse(record['month']?.toString() ?? '1') ?? 1,
      int.tryParse(record['year']?.toString() ?? '0') ?? 0,
    );
    final employeeMeta =
        '${employee['employeeCode'] ?? employee['email'] ?? '-'} | ${employee['department'] ?? '-'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: widget.onToggle,
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 680;
                  final paymentChip = StatusPill(
                    record['paymentStatus'] ?? 'pending',
                    statusKey: record['paymentStatus'],
                  );
                  final expandIcon = Icon(
                    widget.isOpen ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.gray,
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    employee['name'] ?? '-',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  MutedText(employeeMeta),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            expandIcon,
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          month,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Rs ${fmtMoney(record['netSalary'])}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        paymentChip,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employee['name'] ?? '-',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            MutedText(employeeMeta),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          month,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Rs ${fmtMoney(record['netSalary'])}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Flexible(child: paymentChip),
                      const SizedBox(width: 6),
                      expandIcon,
                    ],
                  );
                },
              ),
            ),
            if (widget.isOpen) ...[
              const Divider(height: 20),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _detailPanel('Employee Details', [
                    employee['name'] ?? '-',
                    employee['employeeCode'] ?? employee['email'] ?? '-',
                    employee['department'] ?? '-',
                  ]),
                  _detailPanel('Attendance Summary', [
                    'Present Days: ${record['presentDays'] ?? 0}',
                    'Absent Days: ${record['absentDays'] ?? 0}',
                    'Leave Details: ${record['leaveDays'] ?? 0} day(s)',
                    'Overtime Hours: ${record['overtimeHours'] ?? 0}',
                  ]),
                  _detailPanel('Salary Breakdown', [
                    'Basic Salary: Rs ${fmtMoney(record['basicSalary'])}',
                    'Allowances: Rs ${fmtMoney(record['allowances'])}',
                    'Incentives: Rs ${fmtMoney(record['incentives'])}',
                    'Net Salary: Rs ${fmtMoney(record['netSalary'])}',
                  ]),
                  _detailPanel('Delivery', [
                    'Generated: ${record['generatedDate'] != null ? fmtDateTime(record['generatedDate']) : '-'}',
                    'Email status: ${record['emailDeliveryStatus'] ?? 'pending'}',
                    'Approval: ${approved ? 'Approved' : 'Admin Review'}',
                    'Remarks: ${record['remarks'] ?? '-'}',
                  ]),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SecondaryButton(
                    label: 'Edit Salary',
                    onPressed: approved ? null : _startEdit,
                  ),
                  PrimaryButton(
                    label: 'Approve Salary',
                    loading: saving,
                    onPressed: approved
                        ? null
                        : () async {
                            await state.salaryApprove(record['_id'].toString());
                            if (mounted) showToast(context, 'Salary approved');
                          },
                  ),
                  SecondaryButton(
                    label: 'Generate Payslip',
                    onPressed: () async {
                      await state.salaryGeneratePayslip(
                        record['_id'].toString(),
                      );
                      if (mounted) showToast(context, 'Payslip generated');
                    },
                  ),
                  GhostButton(
                    label: 'Resend Email',
                    onPressed: () async {
                      final status = await state.salaryResendEmail(
                        record['_id'].toString(),
                      );
                      if (mounted) {
                        showToast(
                          context,
                          status == 'sent'
                              ? 'Payslip email sent'
                              : 'Email $status',
                        );
                      }
                    },
                  ),
                  SecondaryButton(
                    label: 'Download PDF',
                    onPressed: () async {
                      try {
                        final path = await state.salaryDownload(
                          Map<String, dynamic>.from(record),
                        );
                        if (mounted) {
                          showToast(context, 'Saved payslip to $path');
                        }
                      } catch (e) {
                        if (mounted) {
                          showToast(context, e.toString(), error: true);
                        }
                      }
                    },
                  ),
                  GhostButton(
                    label: 'View Edit History',
                    onPressed: () {
                      final nextOpen = !historyOpen;
                      setState(() => historyOpen = nextOpen);
                      if (nextOpen) {
                        state.salaryHistoryLoad(record['_id'].toString());
                      }
                    },
                  ),
                ],
              ),
              if (editing) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final f in _moneyFields)
                      LabeledField(
                        label: f[1],
                        child: TextField(
                          controller: moneyCtrls[f[0]],
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    LabeledField(
                      label: 'Payment Status',
                      child: DropdownButtonFormField<String>(
                        initialValue: paymentStatus,
                        items: const [
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'paid',
                            child: Text('Paid'),
                          ),
                          DropdownMenuItem(
                            value: 'unpaid',
                            child: Text('Unpaid'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => paymentStatus = v ?? 'pending'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LabeledField(
                  label: 'Remarks',
                  wide: true,
                  child: TextField(controller: remarksCtrl, maxLines: 3),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: saving ? 'Saving...' : 'Save Changes',
                  loading: saving,
                  expand: true,
                  onPressed: () async {
                    final body = {
                      for (final f in _moneyFields)
                        f[0]: num.tryParse(moneyCtrls[f[0]]!.text) ?? 0,
                      'paymentStatus': paymentStatus,
                      'remarks': remarksCtrl.text,
                    };
                    await state.salarySave(record['_id'].toString(), body);
                    setState(() => editing = false);
                    if (mounted) {
                      showToast(
                        context,
                        'Salary updated and net salary recalculated',
                      );
                    }
                  },
                ),
              ],
              if (historyOpen) ...[
                const SizedBox(height: 12),
                const Eyebrow('Audit Log'),
                const SizedBox(height: 8),
                if (state.salaryHistoryLoadingId == record['_id'])
                  const Center(child: CircularProgressIndicator())
                else if ((state.auditLogsBySalary[record['_id'].toString()] ??
                        [])
                    .isEmpty)
                  const MutedText('No edits recorded for this salary.')
                else
                  ...List<Widget>.from(
                    (state.auditLogsBySalary[record['_id'].toString()] ?? [])
                        .map(
                      (log) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${log['edited_by']?['name'] ?? '-'} changed ${log['field_name']}: ${log['old_value'] ?? '-'} -> ${log['new_value'] ?? '-'} (${fmtDateTime(log['edited_at'])})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailPanel(String title, List<String> lines) {
    return SizedBox(
      width: 280,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(title),
            const SizedBox(height: 6),
            ...lines.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
