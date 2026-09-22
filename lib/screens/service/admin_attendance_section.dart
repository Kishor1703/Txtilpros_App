import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class AdminAttendanceSection extends StatefulWidget {
  const AdminAttendanceSection({super.key});
  @override
  State<AdminAttendanceSection> createState() => _AdminAttendanceSectionState();
}

class _AdminAttendanceSectionState extends State<AdminAttendanceSection> {
  String search = '';
  int page = 1;
  String openEmployeeId = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      await context.read<AppState>().loadAttendance();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickMonth() async {
    final state = context.read<AppState>();
    final parts = state.attendanceMonth.split('-');
    final initial = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select attendance month',
    );
    if (picked != null) {
      state.setAttendanceMonth('${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}');
      setState(() {
        page = 1;
        openEmployeeId = '';
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final attendance = state.attendance;
    final employees = (attendance['employees'] as List?) ?? [];
    final holidays = (attendance['holidays'] as List?) ?? [];
    final normalized = search.trim().toLowerCase();
    final filtered = normalized.isEmpty
        ? employees
        : employees.where((e) {
            final name = (e['name'] ?? '').toString().toLowerCase();
            final code = (e['employeeCode'] ?? '').toString().toLowerCase();
            return name.contains(normalized) || code.contains(normalized);
          }).toList();
    final pageItems = paginate(filtered, page);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionIntro(
          eyebrow: 'Attendance',
          title: attendance['monthLabel']?.toString() ?? 'Monthly attendance summary',
          description:
              'Attendance is generated automatically from submitted work reports for the selected month. Paid leave is capped at ${attendance['paidLeaveLimit'] ?? 15} days per year.',
          aside: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill('${attendance['totalDays'] ?? 0} days', statusKey: 'completed'),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _pickMonth,
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(state.attendanceMonth),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GlassCard(
          child: TextField(
            decoration: const InputDecoration(hintText: 'Search by name or employee code', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() {
              search = v;
              page = 1;
              openEmployeeId = '';
            }),
          ),
        ),
        if (holidays.isNotEmpty) ...[
          const SizedBox(height: 10),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Government holidays'),
                const SizedBox(height: 4),
                Text('${attendance['monthLabel'] ?? 'Selected month'} holiday calendar', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: holidays.map<Widget>((h) => StatusPill('${fmtDate(h['date'])} - ${h['name']}', statusKey: 'holiday')).toList(),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (filtered.isEmpty)
          EmptyState(employees.isEmpty ? 'No attendance data found for the selected month.' : 'No employees match your search.')
        else
          GlassCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                ...pageItems.map((emp) {
                  final id = (emp['id'] ?? '').toString();
                  final isOpen = openEmployeeId == id;
                  return Column(
                    children: [
                      InkWell(
                        onTap: () => setState(() => openEmployeeId = isOpen ? '' : id),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 680;
                              final employeeCode = (emp['employeeCode'] ?? emp['email'] ?? '').toString();
                              final department = (emp['department'] ?? '-').toString();

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
                                                emp['name'] ?? '',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 16),
                                              ),
                                              const SizedBox(height: 2),
                                              MutedText(employeeCode),
                                            ],
                                          ),
                                        ),
                                        Icon(isOpen ? Icons.expand_less : Icons.expand_more, color: AppColors.gray),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(department, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        StatusPill('Present ${emp['presentDays'] ?? 0}', statusKey: 'completed'),
                                        StatusPill('Leave ${emp['leaveDays'] ?? 0}', statusKey: 'leave'),
                                        StatusPill('Absent ${emp['absentDays'] ?? 0}', statusKey: 'blocked'),
                                      ],
                                    ),
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
                                        Text(emp['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                                        MutedText(employeeCode),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      department,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(child: StatusPill('Present ${emp['presentDays'] ?? 0}', statusKey: 'completed')),
                                  const SizedBox(width: 8),
                                  Flexible(child: StatusPill('Leave ${emp['leaveDays'] ?? 0}', statusKey: 'leave')),
                                  const SizedBox(width: 8),
                                  Flexible(child: StatusPill('Absent ${emp['absentDays'] ?? 0}', statusKey: 'blocked')),
                                  const SizedBox(width: 6),
                                  Icon(isOpen ? Icons.expand_less : Icons.expand_more, color: AppColors.gray),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      if (isOpen) _AttendanceDetails(employee: emp, monthLabel: attendance['monthLabel']?.toString()),
                      const Divider(height: 1),
                    ],
                  );
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Pagination(currentPage: page, totalItems: filtered.length, itemLabel: 'employees', onPageChange: (p) => setState(() => page = p)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AttendanceDetails extends StatelessWidget {
  final dynamic employee;
  final String? monthLabel;
  const _AttendanceDetails({required this.employee, this.monthLabel});

  @override
  Widget build(BuildContext context) {
    final days = (employee['attendance'] as List?) ?? [];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${employee['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
          MutedText('${monthLabel ?? 'Selected month'} attendance'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            StatusPill('Present: ${employee['presentDays'] ?? 0}', statusKey: 'completed'),
            StatusPill('Leave: ${employee['leaveDays'] ?? 0}', statusKey: 'leave'),
            StatusPill('Comp-off: ${employee['compOffDays'] ?? 0}', statusKey: 'comp-off'),
            StatusPill('Paid leave balance: ${employee['paidLeaveRemaining'] ?? employee['paidLeaveLimit'] ?? 15}', statusKey: 'pending'),
            StatusPill('Holiday: ${employee['holidayDays'] ?? 0}', statusKey: 'holiday'),
            StatusPill('Absent: ${employee['absentDays'] ?? 0}', statusKey: 'blocked'),
          ]),
          const SizedBox(height: 10),
          if (days.isEmpty)
            const MutedText('No day-level attendance to show.')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final columns = maxWidth >= 520
                    ? 4
                    : maxWidth >= 380
                        ? 3
                        : 2;
                const gap = 8.0;
                final itemWidth = (maxWidth - ((columns - 1) * gap)) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: days.map<Widget>((d) {
                    final status = (d['status'] ?? '').toString();
                    return SizedBox(
                      width: itemWidth,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.light),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d['label']?.toString() ?? '',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: statusColor(status).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: statusColor(status).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                status.replaceAll('-', ' '),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: statusColor(status),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}
