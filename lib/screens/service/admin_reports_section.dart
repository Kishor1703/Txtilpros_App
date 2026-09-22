import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class AdminReportsSection extends StatefulWidget {
  final String weekStart;
  final List<dynamic>? reports; // if null, loads full reports list itself
  final String title;
  final String subtitle;
  final ValueChanged<String> onOpenReport;

  const AdminReportsSection({
    super.key,
    required this.weekStart,
    this.reports,
    this.title = 'All employee submissions',
    this.subtitle = 'Review weekly work reports and open any report for full details.',
    required this.onOpenReport,
  });

  @override
  State<AdminReportsSection> createState() => _AdminReportsSectionState();
}

class _AdminReportsSectionState extends State<AdminReportsSection> {
  String search = '';
  int page = 1;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.reports == null) _load();
  }

  @override
  void didUpdateWidget(covariant AdminReportsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekStart != widget.weekStart) {
      setState(() => page = 1);
      if (widget.reports == null) {
        _load();
      }
    }
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      await context.read<AppState>().loadReports();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allReports = widget.reports ?? state.reports;
    final normalized = search.trim().toLowerCase();
    final filtered = normalized.isEmpty
        ? allReports
        : allReports.where((r) {
            final name = (r['user']?['name'] ?? '').toString().toLowerCase();
            final code = (r['user']?['employeeCode'] ?? '').toString().toLowerCase();
            return name.contains(normalized) || code.contains(normalized);
          }).toList();
    final pageItems = paginate(filtered, page);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final intro = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Reports'),
                  const SizedBox(height: 4),
                  Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  MutedText(widget.subtitle),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    intro,
                    const SizedBox(height: 12),
                    StatusPill('${filtered.length} entries', statusKey: 'completed'),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: intro),
                  const SizedBox(width: 12),
                  StatusPill('${filtered.length} entries', statusKey: 'completed'),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        GlassCard(
          child: TextField(
            decoration: const InputDecoration(hintText: 'Search by employee name or code', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() {
              search = v;
              page = 1;
            }),
          ),
        ),
        const SizedBox(height: 10),
        if (loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (filtered.isEmpty)
          EmptyState(allReports.isEmpty ? 'No reports found for the selected week.' : 'No reports match your search.')
        else
          GlassCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                ...pageItems.map((report) => _ReportRow(report: report, onOpen: () => widget.onOpenReport(report['_id'].toString()))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Pagination(currentPage: page, totalItems: filtered.length, itemLabel: 'reports', onPageChange: (p) => setState(() => page = p)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  final dynamic report;
  final VoidCallback onOpen;
  const _ReportRow({required this.report, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final status = (report['status'] ?? '').toString();
    final employeeName = (report['user']?['name'] ?? 'Unknown').toString();
    final employeeMeta = (report['user']?['employeeCode'] ?? report['user']?['email'] ?? '-').toString();
    final siteName = (report['siteName'] ?? 'Site not added').toString();
    final machineName = (report['machineName'] ?? 'Machine not added').toString();
    final shift = (report['shift'] ?? '').toString();

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;
            final statusChip = StatusPill(status.replaceAll('-', ' '), statusKey: status);

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
                              employeeName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            MutedText(employeeMeta),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.chevron_right, color: AppColors.gray),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusPill(fmtDate(report['workDate']), statusKey: 'read'),
                      if (shift.isNotEmpty) StatusPill(shift, statusKey: 'pending'),
                      statusChip,
                      StatusPill('${report['hoursWorked'] ?? 0} hrs', statusKey: 'completed'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    siteName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  MutedText(machineName),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fmtDate(report['workDate']), style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (shift.isNotEmpty) MutedText(shift),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employeeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      MutedText(employeeMeta),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(siteName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      MutedText(machineName),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(child: statusChip),
                const SizedBox(width: 10),
                SizedBox(
                  width: 64,
                  child: Text(
                    '${report['hoursWorked'] ?? 0} hrs',
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: AppColors.gray),
              ],
            );
          },
        ),
      ),
    );
  }
}
