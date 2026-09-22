import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../widgets/common.dart';
import 'admin_reports_section.dart';

class AdminOverviewSection extends StatefulWidget {
  final String weekStart;
  final ValueChanged<String> onOpenReport;
  const AdminOverviewSection({super.key, required this.weekStart, required this.onOpenReport});
  @override
  State<AdminOverviewSection> createState() => _AdminOverviewSectionState();
}

class _AdminOverviewSectionState extends State<AdminOverviewSection> {
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminOverviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekStart != widget.weekStart) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      await context.read<AppState>().loadOverview();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final d = state.dashboard;
    final recent = state.reports.length > 6 ? state.reports.sublist(0, 6) : state.reports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionIntro(
          eyebrow: 'Overview',
          title: 'Operations snapshot',
          description: 'Monitor weekly reporting activity, logged hours, and operational issues from one admin workspace.',
          aside: StatusPill('${d['activeEmployees'] ?? 0} active now', statusKey: 'completed'),
        ),
        const SizedBox(height: 14),
        if (loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else ...[
          StatGrid(children: [
            StatCard(label: 'Employees', value: '${d['totalEmployees'] ?? 0}', hint: '${d['activeEmployees'] ?? 0} active this week'),
            StatCard(label: 'Reports submitted', value: '${d['totalReports'] ?? 0}', hint: '${d['todaySubmissions'] ?? 0} added today'),
            StatCard(label: 'Hours reported', value: '${d['totalHours'] ?? 0}', hint: '${d['photoCount'] ?? 0} photo uploads'),
            StatCard(label: 'Needs action', value: '${d['attentionNeeded'] ?? 0}', hint: '${d['syncFailures'] ?? 0} Sheets sync failures'),
            StatCard(label: 'Pending leaves', value: '${d['pendingLeaves'] ?? 0}', hint: '${d['approvedLeaves'] ?? 0} approved overall'),
            StatCard(label: 'Rejected leaves', value: '${d['rejectedLeaves'] ?? 0}', hint: 'Closed without approval'),
          ]),
          const SizedBox(height: 14),
          AdminReportsSection(
            weekStart: widget.weekStart,
            reports: recent,
            title: 'Latest company reports',
            subtitle: 'Recent employee submissions shown in the same format as the reports section.',
            onOpenReport: widget.onOpenReport,
          ),
        ],
      ],
    );
  }
}
