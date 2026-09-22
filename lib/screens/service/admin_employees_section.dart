import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:txtilpros_app/theme.dart';
import '../../app_state.dart';
import '../../widgets/common.dart';

class AdminEmployeesSection extends StatefulWidget {
  const AdminEmployeesSection({super.key});
  @override
  State<AdminEmployeesSection> createState() => _AdminEmployeesSectionState();
}

class _AdminEmployeesSectionState extends State<AdminEmployeesSection> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  String role = 'employee';
  String department = 'Service';
  int page = 1;
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      await context.read<AppState>().loadEmployees();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _submit() async {
    if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
      showToast(context, 'Name, email and password are required', error: true);
      return;
    }
    setState(() => saving = true);
    try {
      await context.read<AppState>().userSubmit({
        'name': nameCtrl.text,
        'email': emailCtrl.text,
        'password': passwordCtrl.text,
        'role': role,
        'employeeCode': codeCtrl.text,
        'phone': phoneCtrl.text,
        'department': department,
      });
      nameCtrl.clear();
      emailCtrl.clear();
      passwordCtrl.clear();
      codeCtrl.clear();
      phoneCtrl.clear();
      if (mounted) showToast(context, 'User created');
      await _load();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _toggle(dynamic user) async {
    try {
      await context.read<AppState>().userToggle(user);
      if (mounted) showToast(context, "User ${user['active'] == true ? 'disabled' : 'enabled'}");
      await _load();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final users = state.users;
    final pageItems = paginate(users, page);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionIntro(
          eyebrow: 'Access control',
          title: 'Manage employees',
          description: 'Create employee or manager accounts, then enable or disable access without leaving the dashboard.',
          aside: StatusPill('${users.length} team members', statusKey: 'completed'),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('New account'),
              const SizedBox(height: 4),
              const Text('Create employee profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(spacing: 14, runSpacing: 14, children: [
                LabeledField(label: 'Name', child: TextField(controller: nameCtrl)),
                LabeledField(label: 'Email', child: TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress)),
                LabeledField(label: 'Password', child: TextField(controller: passwordCtrl, obscureText: true)),
                LabeledField(
                  label: 'Role',
                  child: DropdownButtonFormField<String>(
                    initialValue: role,
                    items: const [
                      DropdownMenuItem(value: 'employee', child: Text('Employee')),
                      DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    ],
                    onChanged: (v) => setState(() => role = v ?? 'employee'),
                  ),
                ),
                LabeledField(label: 'Employee code', child: TextField(controller: codeCtrl)),
                LabeledField(label: 'Phone', child: TextField(controller: phoneCtrl)),
                LabeledField(
                  label: 'Department',
                  child: DropdownButtonFormField<String>(
                    initialValue: department,
                    items: const [
                      DropdownMenuItem(value: 'Service', child: Text('Service')),
                      DropdownMenuItem(value: 'Sales', child: Text('Sales')),
                    ],
                    onChanged: (v) => setState(() => department = v ?? 'Service'),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              PrimaryButton(label: saving ? 'Saving user...' : 'Create user', loading: saving, onPressed: _submit, expand: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Team roster'),
              const SizedBox(height: 4),
              const Text('Employee directory', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (loading)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (users.isEmpty)
                const EmptyState('No employees created yet.')
              else ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 700;
                    return Column(
                      children: pageItems
                          .map((user) => compact
                              ? _EmployeeCard(user: user, onToggle: () => _toggle(user))
                              : _EmployeeRow(user: user, onToggle: () => _toggle(user)))
                          .toList(),
                    );
                  },
                ),
                Pagination(currentPage: page, totalItems: users.length, itemLabel: 'employees', onPageChange: (p) => setState(() => page = p)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  final dynamic user;
  final VoidCallback onToggle;

  const _EmployeeRow({required this.user, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final active = user['active'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _EmployeeIdentity(user: user),
          ),
          Expanded(child: StatusPill(user['role'] ?? '', statusKey: 'completed')),
          Expanded(flex: 2, child: Text(user['department'] ?? '-')),
          Expanded(child: Text(user['employeeCode'] ?? '-')),
          Expanded(child: StatusPill(active ? 'Active' : 'Disabled', statusKey: active ? 'completed' : 'blocked')),
          TextButton(onPressed: onToggle, child: Text(active ? 'Disable' : 'Enable')),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final dynamic user;
  final VoidCallback onToggle;

  const _EmployeeCard({required this.user, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final active = user['active'] == true;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EmployeeIdentity(user: user),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(user['role'] ?? '-', statusKey: 'completed'),
              StatusPill(active ? 'Active' : 'Disabled', statusKey: active ? 'completed' : 'blocked'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _EmployeeDetail(label: 'Department', value: user['department'] ?? '-')),
              const SizedBox(width: 16),
              Expanded(child: _EmployeeDetail(label: 'Employee code', value: user['employeeCode'] ?? '-')),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onToggle, child: Text(active ? 'Disable' : 'Enable')),
          ),
        ],
      ),
    );
  }
}

class _EmployeeIdentity extends StatelessWidget {
  final dynamic user;

  const _EmployeeIdentity({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(user['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        MutedText(user['email'] ?? ''),
      ],
    );
  }
}

class _EmployeeDetail extends StatelessWidget {
  final String label;
  final String value;

  const _EmployeeDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.gray, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
