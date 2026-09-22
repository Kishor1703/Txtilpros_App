import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:txtilpros_app/theme.dart';
import '../../app_state.dart';
import '../../widgets/common.dart';

class AdminReportDetailsSection extends StatefulWidget {
  final String reportId;
  final VoidCallback onBack;
  const AdminReportDetailsSection({super.key, required this.reportId, required this.onBack});

  @override
  State<AdminReportDetailsSection> createState() => _AdminReportDetailsSectionState();
}

class _AdminReportDetailsSectionState extends State<AdminReportDetailsSection> {
  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadReportDetails(widget.reportId).catchError((e) {
      if (mounted) showToast(context, e.toString(), error: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final report = state.selectedReport;
    final loading = state.selectedReportLoading;

    if (loading && report == null) {
      return const GlassCard(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));
    }

    if (report == null) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Report details'),
            const SizedBox(height: 6),
            const Text('Report not found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const MutedText('Try selecting a different week or go back to the reports list.'),
            const SizedBox(height: 12),
            SecondaryButton(label: 'Back to reports', onPressed: widget.onBack),
          ],
        ),
      );
    }

    final status = (report['status'] ?? '').toString();
    final photos = (report['photos'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionIntro(
          eyebrow: 'Report details',
          title: report['siteName'] ?? '',
          description: 'Review the employee, work summary, and photo evidence linked to this submission.',
          aside: StatusPill(status.replaceAll('-', ' '), statusKey: status),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: MutedText('${fmtDate(report['workDate'])} | ${report['shift']} | ${report['hoursWorked']} hrs')),
                  SecondaryButton(label: 'Back to reports', onPressed: widget.onBack),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 14, runSpacing: 14, children: [
                SizedBox(
                  width: 320,
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('Employee'),
                        const SizedBox(height: 4),
                        Text(report['user']?['name'] ?? 'Unknown employee', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Email: ${report['user']?['email'] ?? '-'}'),
                        Text('Employee code: ${report['user']?['employeeCode'] ?? '-'}'),
                        Text('Department: ${report['user']?['department'] ?? '-'}'),
                        const SizedBox(height: 6),
                        StatusPill(status.replaceAll('-', ' '), statusKey: status),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('Work summary'),
                        const SizedBox(height: 4),
                        const Text('Field update', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 8),
                        if ((report['machineName'] ?? '').toString().isNotEmpty) Text('Machine: ${report['machineName']}'),
                        if ((report['clientName'] ?? '').toString().isNotEmpty) Text('Client: ${report['clientName']}'),
                        Text('Work: ${report['workSummary'] ?? ''}'),
                        if ((report['problemsObserved'] ?? '').toString().isNotEmpty) Text('Problems: ${report['problemsObserved']}'),
                        if ((report['materialsUsed'] ?? '').toString().isNotEmpty) Text('Materials: ${report['materialsUsed']}'),
                        Text('Sheets sync: ${report['sheetsSync']?['status'] ?? 'pending'}'),
                      ],
                    ),
                  ),
                ),
              ]),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Eyebrow('Attachments'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: photos.map<Widget>((photo) {
                    final kind = (photo['kind'] ?? '').toString().toLowerCase();
                    final label = kind == 'before' ? 'Before work' : 'After work';
                    final src = photo['dataUrl'] ?? photo['url'];
                    return SizedBox(
                      width: 160,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: src != null
                                ? Image.network(src, height: 120, width: 160, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(height: 120, color: Colors.black12, child: const Icon(Icons.broken_image)))
                                : Container(height: 120, color: Colors.black12),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
