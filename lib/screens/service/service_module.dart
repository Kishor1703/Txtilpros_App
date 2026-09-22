import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'admin_shell.dart';
import 'employee_shell.dart';

class ServiceModule extends StatelessWidget {
  final VoidCallback? onOpenSales;
  const ServiceModule({super.key, this.onOpenSales});

  Future<void> _pickWeek(BuildContext context, AppState state) async {
    final parts = state.weekStart.split('-');
    final initial = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) {
      state.setWeekStart('${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user!;
    final isManagementUser = user['role'] == 'admin' || user['role'] == 'manager';

    if (state.isSalesDepartment) {
      return const _AccessDenied(message: 'Sales users cannot access the service module.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: GlassCard(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final title = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InitialAvatar(name: (user['name'] ?? '?').toString()),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Eyebrow('Secure reporting workspace'),
                          const SizedBox(height: 2),
                          Text(
                            isManagementUser ? 'Management dashboard' : 'Employee dashboard',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                          MutedText(
                            "Signed in as ${user['name']} (${user['role']})${(user['department'] ?? '').toString().isNotEmpty ? ' | ${user['department']}' : ''}",
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final actions = Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: compact ? WrapAlignment.start : WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickWeek(context, state),
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: Text(state.weekStart),
                    ),
                    if (state.isOwner && onOpenSales != null) SecondaryButton(label: 'Sales Module', onPressed: onOpenSales),
                    GhostButton(label: 'Logout', onPressed: () => context.read<AppState>().logout()),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 18),
                      actions,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    Flexible(child: actions),
                  ],
                );
              },
            ),
          ),
        ),
        Expanded(
          child: state.canAccessServiceManagement
              ? AdminShell(weekStart: state.weekStart)
              : EmployeeShell(weekStart: state.weekStart),
        ),
      ],
    );
  }
}

class _AccessDenied extends StatelessWidget {
  final String message;
  const _AccessDenied({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, color: AppColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              GhostButton(label: 'Logout', onPressed: () => context.read<AppState>().logout()),
            ],
          ),
        ),
      ),
    );
  }
}
