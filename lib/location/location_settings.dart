import 'package:flutter/material.dart';
import 'location_controller.dart';

class LocationSettingsScreen extends StatefulWidget {
  final LocationController controller;
  const LocationSettingsScreen({super.key, required this.controller});
  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  Map<String, dynamic>? settings;
  List<Map<String, dynamic>> users = [];
  String? error;
  bool saving = false;
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.controller.request('/settings');
      if (mounted) {
        setState(() {
          settings = Map<String, dynamic>.from(data['settings']);
          users = (data['users'] as List)
              .map((u) => Map<String, dynamic>.from(u))
              .toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    setState(() => saving = true);
    try {
      await widget.controller
          .request('/settings', method: 'PUT', body: settings);
      await widget.controller.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Live location settings saved.')));
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _permissions(Map<String, dynamic> user) async {
    var enabled = user['locationEnabled'] != false,
        ownHistory = user['locationHistoryEnabled'] == true,
        managerHistory = user['locationManagerHistory'] == true;
    final managers = users
        .where((u) => u['role'] == 'manager' && u['_id'] != user['_id'])
        .toList();
    String selected = managers.any((m) => m['_id'] == user['locationManager'])
        ? '${user['locationManager']}'
        : '';
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                    title: Text('${user['name']} · Privacy'),
                    content: SizedBox(
                        width: 440,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              DropdownButtonFormField<String>(
                                  initialValue: selected,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Assigned manager'),
                                  items: [
                                    const DropdownMenuItem(
                                        value: '', child: Text('Unassigned')),
                                    ...managers.map((m) => DropdownMenuItem(
                                        value: '${m['_id']}',
                                        child: Text('${m['name']}')))
                                  ],
                                  onChanged: (v) =>
                                      update(() => selected = v!)),
                              SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Allow location sharing'),
                                  value: enabled,
                                  onChanged: (v) => update(() => enabled = v)),
                              SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                      'Employee can view own history'),
                                  value: ownHistory,
                                  onChanged: (v) =>
                                      update(() => ownHistory = v)),
                              SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                      'Assigned manager can view history'),
                                  value: managerHistory,
                                  onChanged: (v) =>
                                      update(() => managerHistory = v)),
                              const Text(
                                  'Admins retain full access. Disabling sharing ends the active session. Changes apply to history access immediately.'),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Save Permissions'))
                    ])));
    if (confirmed != true) return;
    try {
      await widget.controller
          .request('/permissions/${user['_id']}', method: 'PUT', body: {
        'locationManager': selected.isEmpty ? null : selected,
        'locationEnabled': enabled,
        'locationHistoryEnabled': ownHistory,
        'locationManagerHistory': managerHistory,
      });
      await _load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Widget _number(String key, String label, int min, int max) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        initialValue: '${settings![key]}',
        decoration: InputDecoration(labelText: '$label ($min–$max)'),
        keyboardType: TextInputType.number,
        validator: (v) {
          final n = int.tryParse(v ?? '');
          return n == null || n < min || n > max
              ? 'Enter a value from $min to $max'
              : null;
        },
        onSaved: (v) => settings![key] = int.parse(v!),
      ));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Live Location Settings')),
      body: settings == null
          ? Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(error!),
                      TextButton(onPressed: _load, child: const Text('Retry'))
                    ]))
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                for (final entry in {
                  'enabled': 'Enable Live Location',
                  'managerVisibility': 'Assigned manager visibility',
                  'notifications': 'Email notifications'
                }.entries)
                  SwitchListTile(
                      title: Text(entry.value),
                      value: settings![entry.key] == true,
                      onChanged: (v) =>
                          setState(() => settings![entry.key] = v)),
                const Text('Roles allowed to share',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                    spacing: 8,
                    children: ['employee', 'manager', 'admin']
                        .map((role) => FilterChip(
                            label: Text(role),
                            selected: (settings!['allowedRoles'] as List)
                                .contains(role),
                            onSelected: (v) => setState(() {
                                  final roles = List<String>.from(
                                      settings!['allowedRoles']);
                                  v ? roles.add(role) : roles.remove(role);
                                  settings!['allowedRoles'] = roles;
                                })))
                        .toList()),
                const SizedBox(height: 16),
                _number('retentionDays', 'History retention in days', 1, 365),
                _number('maximumAccuracy',
                    'Maximum accepted GPS error in meters', 5, 1000),
                _number('updateInterval', 'Minimum update interval in seconds',
                    30, 300),
                DropdownButtonFormField<int>(
                    initialValue: (settings!['maximumDuration'] as num).toInt(),
                    decoration: const InputDecoration(
                        labelText: 'Maximum sharing duration'),
                    items: [1, 3, 8]
                        .map((h) =>
                            DropdownMenuItem(value: h, child: Text('$h Hours')))
                        .toList(),
                    onChanged: (v) => settings!['maximumDuration'] = v),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: saving ? null : _save,
                    child: Text(saving ? 'Saving…' : 'Save Settings')),
                const SizedBox(height: 24),
                const Text('Employee permissions & manager assignments',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ...users.map((u) => Card(
                    child: ListTile(
                        title: Text('${u['name']}'),
                        subtitle:
                            Text('${u['role']} · ${u['department'] ?? '—'}'),
                        trailing:
                            const Icon(Icons.admin_panel_settings_outlined),
                        onTap: () => _permissions(u)))),
              ])));
}
