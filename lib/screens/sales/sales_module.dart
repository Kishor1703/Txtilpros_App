import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../location/location_screen.dart';
import '../../location/location_controller.dart';

class SalesModule extends StatefulWidget {
  final VoidCallback? onOpenService;
  const SalesModule({super.key, this.onOpenService});

  @override
  State<SalesModule> createState() => _SalesModuleState();
}

class _SalesModuleState extends State<SalesModule> {
  String section = 'overview';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final state = context.read<AppState>();
    try {
      await Future.wait([
        state.loadSalesDashboard(),
        state.loadSalesOrders(),
        if (state.canManageSales) state.loadSalesUsers(),
      ]);
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user!;

    if (!state.canAccessSalesModule) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, color: AppColors.danger, size: 40),
                const SizedBox(height: 12),
                const Text('Only Sales employees, Sales managers, and Owner can access the sales module.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                GhostButton(label: 'Logout', onPressed: () => context.read<AppState>().logout()),
              ],
            ),
          ),
        ),
      );
    }

    final canManage = state.canManageSales;
    final items = canManage
        ? const [MapEntry('Overview', 'overview'), MapEntry('All Sales Orders', 'orders'), MapEntry('Sales Team', 'employees')]
        : const [MapEntry('Overview', 'overview'), MapEntry('Add New Order', 'new'), MapEntry('My Orders', 'orders')];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: GlassCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InitialAvatar(name: (user['name'] ?? '?').toString()),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Eyebrow('Independent sales workspace'),
                            const SizedBox(height: 2),
                            Text(
                              state.isOwner ? 'Owner sales view' : (state.isSalesManager ? 'Sales manager dashboard' : 'Sales dashboard'),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                            MutedText("Signed in as ${user['name']} (${user['role']})${(user['department'] ?? '').toString().isNotEmpty ? ' | ${user['department']}' : ''}"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (state.isOwner && widget.onOpenService != null) SecondaryButton(label: 'Service Module', onPressed: widget.onOpenService),
                  GhostButton(label: 'Logout', onPressed: () => context.read<AppState>().logout()),
                ]),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionNav(items: [...items, if (state.isOwner || context.select<LocationController, bool>((l) => l.showNavigation))
                  const MapEntry('Live Location', 'location')], active: section, onSelect: (v) => setState(() => section = v)),
                const SizedBox(height: 14),
                if (loading)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                else ...[
                  if (section == 'location') const LiveLocationScreen(),
                  if (section == 'overview') ...[
                    _SalesSummary(dashboard: state.salesDashboard),
                    const SizedBox(height: 14),
                    _SalesOverviewLinks(canManage: canManage, onNav: (s) => setState(() => section = s)),
                  ],
                  if (!canManage && section == 'new') _SalesOrderForm(onSubmitted: () => setState(() => section = 'orders')),
                  if (!canManage && section == 'orders')
                    _OrdersTable(orders: state.salesOrders, title: 'My Orders', subtitle: 'Only orders created by your sales account are visible here.'),
                  if (canManage && section == 'orders')
                    _OrdersTable(orders: state.salesOrders, title: 'All Sales Orders', subtitle: 'Owner can review every sales order across the system.'),
                  if (canManage && section == 'employees') const _SalesEmployeesSection(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SalesSummary extends StatelessWidget {
  final Map<String, dynamic> dashboard;
  const _SalesSummary({required this.dashboard});
  @override
  Widget build(BuildContext context) {
    return StatGrid(children: [
      StatCard(label: 'Total Orders', value: '${dashboard['totalOrders'] ?? 0}', hint: 'Visible in your sales workspace'),
      StatCard(label: 'Pending Orders', value: '${dashboard['pendingOrders'] ?? 0}', hint: 'Current backlog'),
      StatCard(label: 'Completed Orders', value: '${dashboard['completedOrders'] ?? 0}', hint: 'Based on non-pending status'),
    ]);
  }
}

class _SalesOverviewLinks extends StatelessWidget {
  final bool canManage;
  final ValueChanged<String> onNav;
  const _SalesOverviewLinks({required this.canManage, required this.onNav});

  @override
  Widget build(BuildContext context) {
    final links = canManage
        ? [
            ('Orders', 'All Sales Orders', 'Review every order across the full sales team.', 'orders'),
            ('People', 'Sales Employees', 'Create sales users and see the current sales roster.', 'employees'),
          ]
        : [
            ('Orders', 'Add New Order', 'Create a new sales order with company ID photo upload.', 'new'),
            ('Tracking', 'My Orders', 'Review only the orders created by your sales account.', 'orders'),
          ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Module overview'),
          Text(canManage ? 'Sales operations overview' : 'Sales workspace overview', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          MutedText(canManage
              ? 'Use the separate sections below to manage sales staff and review all sales orders.'
              : 'Use the separate sections below to add new orders and review only your own sales records.'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: links
                .map((l) => SizedBox(
                      width: 260,
                      child: GlassCard(
                        onTap: () => onNav(l.$4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(l.$1),
                            Text(l.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            MutedText(l.$3),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SalesOrderForm extends StatefulWidget {
  final VoidCallback onSubmitted;
  const _SalesOrderForm({required this.onSubmitted});
  @override
  State<_SalesOrderForm> createState() => _SalesOrderFormState();
}

class _SalesOrderFormState extends State<_SalesOrderForm> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  Map<String, dynamic>? photo;
  final picker = ImagePicker();

  Future<void> _pickPhoto() async {
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 1600);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => photo = {'name': file.name, 'dataUrl': 'data:image/jpeg;base64,${base64Encode(bytes)}'});
  }

  Future<void> _submit() async {
    if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty || addressCtrl.text.isEmpty) {
      showToast(context, 'Customer name, phone, and address are required.', error: true);
      return;
    }
    try {
      await context.read<AppState>().salesOrderSubmit({
        'customer_name': nameCtrl.text,
        'phone_number': phoneCtrl.text,
        'email': emailCtrl.text,
        'address': addressCtrl.text,
        'company_id_photo': photo,
      });
      if (mounted) showToast(context, 'Sales order saved');
      widget.onSubmitted();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('New order'),
          const Text('Add sales order', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(spacing: 14, runSpacing: 14, children: [
            LabeledField(label: 'Customer name', child: TextField(controller: nameCtrl)),
            LabeledField(label: 'Phone number', child: TextField(controller: phoneCtrl, keyboardType: TextInputType.phone)),
            LabeledField(label: 'Email', child: TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress)),
          ]),
          const SizedBox(height: 12),
          LabeledField(label: 'Address', wide: true, child: TextField(controller: addressCtrl, maxLines: 3)),
          const SizedBox(height: 12),
          SecondaryButton(label: photo == null ? 'Upload company ID photo' : 'Replace company ID photo (${photo!['name']})', onPressed: _pickPhoto),
          const SizedBox(height: 16),
          PrimaryButton(label: state.salesLoading ? 'Saving order...' : 'Submit sales order', loading: state.salesLoading, expand: true, onPressed: _submit),
        ],
      ),
    );
  }
}

class _OrdersTable extends StatelessWidget {
  final List<dynamic> orders;
  final String title;
  final String subtitle;
  const _OrdersTable({required this.orders, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Sales orders'),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          MutedText(subtitle),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            const EmptyState('No sales orders found.')
          else
            ...orders.map((order) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order['customer_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                            MutedText(order['email'] ?? '-'),
                          ],
                        ),
                      ),
                      Expanded(flex: 2, child: Text(order['phone_number'] ?? '')),
                      Expanded(flex: 2, child: StatusPill(order['order_status'] ?? 'Pending', statusKey: 'pending')),
                      Expanded(flex: 2, child: Text(order['created_by']?.toString() ?? '-')),
                      Expanded(
                        flex: 2,
                        child: (order['company_id_photo'] ?? '').toString().isNotEmpty
                            ? TextButton(
                                onPressed: () async {
                                  final url = order['company_id_photo'].toString();
                                  final uri = Uri.tryParse(url);
                                  if (uri != null && await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } else if (context.mounted) {
                                    showToast(context, 'Could not open photo link', error: true);
                                  }
                                },
                                child: const Text('View photo'),
                              )
                            : const MutedText('-'),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _SalesEmployeesSection extends StatefulWidget {
  const _SalesEmployeesSection();
  @override
  State<_SalesEmployeesSection> createState() => _SalesEmployeesSectionState();
}

class _SalesEmployeesSectionState extends State<_SalesEmployeesSection> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  String role = 'employee';

  Future<void> _submit() async {
    if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
      showToast(context, 'Name, email and password are required', error: true);
      return;
    }
    try {
      await context.read<AppState>().salesEmployeeSubmit({
        'name': nameCtrl.text,
        'email': emailCtrl.text,
        'password': passwordCtrl.text,
        'role': role,
        'employeeCode': codeCtrl.text,
        'phone': phoneCtrl.text,
      });
      nameCtrl.clear();
      emailCtrl.clear();
      passwordCtrl.clear();
      codeCtrl.clear();
      phoneCtrl.clear();
      if (mounted) showToast(context, 'Sales user created');
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
              const Eyebrow('Sales access'),
              const Text('Create sales user', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const MutedText('Users created here are added to the Sales department with either Employee or Manager access.'),
              const SizedBox(height: 12),
              Wrap(spacing: 14, runSpacing: 14, children: [
                LabeledField(label: 'Name', child: TextField(controller: nameCtrl)),
                LabeledField(label: 'Email', child: TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress)),
                LabeledField(label: 'Password', child: TextField(controller: passwordCtrl, obscureText: true)),
                LabeledField(
                  label: 'Role',
                  child: DropdownButtonFormField<String>(
                    initialValue: role,
                    items: const [DropdownMenuItem(value: 'employee', child: Text('Employee')), DropdownMenuItem(value: 'manager', child: Text('Manager'))],
                    onChanged: (v) => setState(() => role = v ?? 'employee'),
                  ),
                ),
                LabeledField(label: 'Employee code', child: TextField(controller: codeCtrl)),
                LabeledField(label: 'Phone', child: TextField(controller: phoneCtrl)),
                const LabeledField(label: 'Department', child: TextField(enabled: false, decoration: InputDecoration(hintText: 'Sales'))),
              ]),
              const SizedBox(height: 14),
              PrimaryButton(label: state.salesLoading ? 'Creating user...' : 'Create sales user', loading: state.salesLoading, expand: true, onPressed: _submit),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Sales team'),
              const Text('Current sales employees', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (state.salesUsers.isEmpty)
                const EmptyState('No sales employees created yet.')
              else
                ...state.salesUsers.map((u) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)), MutedText(u['email'] ?? '')],
                            ),
                          ),
                          Expanded(child: StatusPill(u['role'] ?? '', statusKey: 'completed')),
                          Expanded(child: Text(u['employeeCode'] ?? '-')),
                          Expanded(child: StatusPill(u['active'] == true ? 'Active' : 'Disabled', statusKey: u['active'] == true ? 'completed' : 'blocked')),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }
}
