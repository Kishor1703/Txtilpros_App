import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../widgets/common.dart';
import '../../location/location_screen.dart';
import '../../location/location_controller.dart';
import 'admin_overview_section.dart';
import 'admin_attendance_section.dart';
import 'admin_leaves_section.dart';
import 'admin_salaries_section.dart';
import 'admin_reports_section.dart';
import 'admin_report_details_section.dart';
import 'admin_employees_section.dart';
import 'admin_messages_section.dart';

class AdminShell extends StatefulWidget {
  final String weekStart;
  const AdminShell({super.key, required this.weekStart});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  String section = 'overview';
  String? openReportId;

  void _openReport(String id) => setState(() {
        openReportId = id;
        section = 'reports';
      });

  void _backToReports() => setState(() => openReportId = null);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final canViewSalaries = state.isOwner;
    final canViewMessages = state.isOwner;

    final items = <MapEntry<String, String>>[
      const MapEntry('Overview', 'overview'),
      if (state.isOwner || context.select<LocationController, bool>((l) => l.showNavigation))
        const MapEntry('Live Location', 'location'),
      const MapEntry('Attendance', 'attendance'),
      const MapEntry('Leaves', 'leaves'),
      if (canViewSalaries) const MapEntry('Salaries', 'salaries'),
      const MapEntry('Reports', 'reports'),
      const MapEntry('Employees', 'employees'),
      if (canViewMessages) const MapEntry('Messages', 'messages'),
    ];

    Widget body;
    if (openReportId != null) {
      body = AdminReportDetailsSection(reportId: openReportId!, onBack: _backToReports);
    } else {
      switch (section) {
        case 'location':
          body = const LiveLocationScreen();
          break;
        case 'attendance':
          body = const AdminAttendanceSection();
          break;
        case 'leaves':
          body = const AdminLeavesSection();
          break;
        case 'salaries':
          body = canViewSalaries ? const AdminSalariesSection() : AdminOverviewSection(weekStart: widget.weekStart, onOpenReport: _openReport);
          break;
        case 'reports':
          body = AdminReportsSection(weekStart: widget.weekStart, onOpenReport: _openReport);
          break;
        case 'employees':
          body = const AdminEmployeesSection();
          break;
        case 'messages':
          body = canViewMessages ? const AdminMessagesSection() : AdminOverviewSection(weekStart: widget.weekStart, onOpenReport: _openReport);
          break;
        case 'overview':
        default:
          body = AdminOverviewSection(weekStart: widget.weekStart, onOpenReport: _openReport);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionNav(
            items: items,
            active: openReportId != null ? 'reports' : section,
            onSelect: (key) => setState(() {
              section = key;
              openReportId = null;
            }),
          ),
          const SizedBox(height: 14),
          body,
        ],
      ),
    );
  }
}
