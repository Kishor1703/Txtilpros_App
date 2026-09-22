import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../app_state.dart';
import '../theme.dart';
import 'location_controller.dart';
import 'location_map.dart';
import 'location_history.dart';
import 'location_settings.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});
  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  late LocationController controller;
  Timer? _refresh;
  http.Client? _streamClient;
  StreamSubscription<Map<String, dynamic>>? _events;
  final _search = TextEditingController();
  List<Map<String, dynamic>> employees = [];
  String search = '',
      status = 'All',
      duration = 'All',
      manager = 'All',
      department = 'All',
      place = '';
  String? dashboardError;
  Map<String, dynamic>? selected;
  bool monitoring = true, loading = false;

  @override
  void initState() {
    super.initState();
    controller = context.read<AppState>().location;
    _load();
    _connect();
  }

  Future<void> _load() async {
    if (loading || !monitoring) return;
    loading = true;
    try {
      final data = await controller.request('/live');
      if (mounted) {
        setState(() {
          employees = (data['employees'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          dashboardError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          dashboardError = 'Connection lost. Trying to reconnect... $e';
          employees = [];
          selected = null;
        });
      }
    } finally {
      loading = false;
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _events?.cancel();
    _streamClient?.close();
    _search.dispose();
    super.dispose();
  }

  void _connect() {
    if (!mounted || !monitoring) return;
    _streamClient?.close();
    _streamClient = http.Client();
    _events = controller.events(_streamClient!).listen((data) {
      if (mounted) {
        setState(() {
          employees = (data['employees'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          dashboardError = null;
        });
      }
    }, onError: (Object e) {
      if (mounted) {
        setState(() {
          employees = [];
          selected = null;
          dashboardError = 'Connection lost. Trying to reconnect... $e';
        });
      }
      _reconnect();
    }, onDone: _reconnect, cancelOnError: true);
  }

  void _reconnect() {
    _refresh?.cancel();
    if (mounted && monitoring) {
      _refresh = Timer(const Duration(seconds: 3), _connect);
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
          context: context,
          builder: (context) =>
              AlertDialog(title: Text(title), content: Text(message), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(action == 'Stop Sharing'
                        ? 'Continue Sharing'
                        : 'Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(action))
              ])) ??
      false;

  Future<void> _start() async {
    final max = controller.settings['maximumDuration'] as num? ?? 8;
    int hours = 1;
    String companyName = '';
    final selectedHours = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => SafeArea(
                child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Share Live Location',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text(
                              'Choose how long authorized people can view your location.'),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const ValueKey('locationCompanyName'),
                            decoration: const InputDecoration(
                              labelText: 'Company name (optional)',
                              hintText: 'Enter the company you are visiting',
                              prefixIcon: Icon(Icons.business_outlined),
                            ),
                            maxLength: 120,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            onChanged: (value) => companyName = value.trim(),
                          ),
                          for (final h in [1, 3, 8].where((h) => h <= max))
                            Card(
                                child: ListTile(
                                    leading: Icon(
                                        h == 1
                                            ? Icons.timer_outlined
                                            : h == 3
                                                ? Icons.schedule
                                                : Icons.work_outline,
                                        color: AppColors.primary),
                                    title:
                                        Text('$h ${h == 1 ? 'Hour' : 'Hours'}'),
                                    subtitle: Text(
                                        'Share location for $h ${h == 1 ? 'hour' : 'hours'}'),
                                    trailing: Icon(hours == h
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off),
                                    onTap: () => update(() => hours = h))),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: () => Navigator.pop(context, hours),
                              child: const Text('Start Live Location')),
                        ])))));
    if (selectedHours == null || !mounted) return;
    if (!await _confirm(
        'Start sharing?',
        'Your live location will be shared with authorized Admins and Managers for the selected duration.',
        'Start Sharing')) {
      return;
    }
    await controller.start(selectedHours, companyName: companyName);
    await _load();
  }

  Future<void> _filters() async {
    var s = status, d = duration, m = manager, dep = department, p = place;
    final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => StatefulBuilder(builder: (context, update) {
              Widget dropdown(String label, String value,
                      Iterable<String> choices, ValueChanged<String> change) =>
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                          initialValue: value,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: label),
                          items: choices
                              .toSet()
                              .map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) => update(() => change(v!))));
              return SafeArea(
                  child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 8, 20,
                          MediaQuery.viewInsetsOf(context).bottom + 20),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Filter locations',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        dropdown(
                            'Status',
                            s,
                            ['All', 'Live', 'Offline', 'Not Sharing'],
                            (v) => s = v),
                        dropdown('Duration', d, ['All', '1', '3', '8'],
                            (v) => d = v),
                        dropdown(
                            'Manager',
                            m,
                            [
                              'All',
                              m,
                              ...employees.map((e) => '${e['managerName']}')
                            ],
                            (v) => m = v),
                        dropdown(
                            'Department',
                            dep,
                            [
                              'All',
                              dep,
                              ...employees
                                  .map((e) => '${e['department'] ?? ''}')
                            ],
                            (v) => dep = v),
                        TextFormField(
                            initialValue: p,
                            decoration: const InputDecoration(
                                labelText: 'Location / address / coordinates'),
                            onChanged: (v) => p = v),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                              child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      status = duration =
                                          manager = department = 'All';
                                      place = search = '';
                                      _search.clear();
                                    });
                                    Navigator.pop(context, false);
                                  },
                                  child: const Text('Clear Filters'))),
                          Expanded(
                              child: FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Apply Filters')))
                        ]),
                      ])));
            }));
    if (result == true && mounted) {
      setState(() {
        status = s;
        duration = d;
        manager = m;
        department = dep;
        place = p;
      });
    }
  }

  Widget _employeeCard(Map<String, dynamic> e) {
    final s = e['session'] as Map?;
    final live = locationFresh(s, controller.now);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                InitialAvatar(name: '${e['name']}'),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('${e['name']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17)))
              ]),
              const SizedBox(height: 10),
              Text('${e['employeeCode'] ?? '—'} · ${e['department'] ?? '—'}'),
              Text('Manager: ${e['managerName'] ?? 'Unassigned'}'),
              Text('Phone: ${e['phone'] ?? '—'}'),
              const SizedBox(height: 8),
              Text('● ${locationStatus(s, controller.now)}',
                  style: TextStyle(
                      color: live ? AppColors.primary : AppColors.muted,
                      fontWeight: FontWeight.bold)),
              if (s != null) ...[
                if ('${s['companyName'] ?? ''}'.isNotEmpty) Text('Company: ${s['companyName']}'),
                Text(
                    '${s['duration']} Hours · ${locationRemaining(s, controller.now)} remaining'),
                Text('Started: ${locationTime(s['startedAt'])}'),
                Text('Expires: ${locationTime(s['expiresAt'])}'),
                Text('Updated: ${locationTime(s['updatedAt'])}'),
                Text('Accuracy: ±${(s['accuracy'] as num?)?.round() ?? '—'} m'),
                Text('Location: ${locationAddress(s)}'),
                TextButton.icon(
                    onPressed: () => setState(() => selected = e),
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('View Location')),
              ],
              if (controller.permissions['canHistory'] == true)
                TextButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => LocationHistoryScreen(
                                controller: controller,
                                employeeId: '${e['_id']}'))),
                    icon: const Icon(Icons.history),
                    label: const Text('Location History')),
            ])));
  }

  Widget _personal() {
    final user = context.read<AppState>().user!;
    final s = controller.session;
    return GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        InitialAvatar(name: '${user['name']}'),
        const SizedBox(width: 12),
        Expanded(
            child: Text('${user['name']}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))
      ]),
      const SizedBox(height: 16),
      Text(
          controller.active
              ? '● LIVE · Sharing Active'
              : 'Sharing ${s?['status'] ?? 'inactive'}',
          style: const TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.bold)),
      if (controller.active) ...[
        if ('${s?['companyName'] ?? ''}'.isNotEmpty) Text('Company: ${s?['companyName']}'),
        Text(locationRemaining(s, controller.now),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        Text(
            '${s?['duration']} Hours · Started ${locationTime(s?['startedAt'])}'),
        Text('Expires ${locationTime(s?['expiresAt'])}'),
        Text('Last updated ${locationTime(s?['updatedAt'])}'),
        Text(
            'GPS accuracy: ±${(s?['accuracy'] as num?)?.round() ?? '—'} meters'),
        Text('Current location: ${locationAddress(s)}'),
        if (!controller.tracking)
          const Text(
              'GPS updates are paused on this device. Resume GPS to continue.',
              style: TextStyle(color: AppColors.accent)),
        const SizedBox(height: 12),
        if (!controller.tracking)
          FilledButton.icon(
              onPressed: controller.busy ? null : controller.resume,
              icon: const Icon(Icons.gps_fixed),
              label: const Text('Resume GPS / Allow Location')),
        OutlinedButton.icon(
            onPressed: controller.busy
                ? null
                : () async {
                    if (await _confirm(
                        'Stop sharing?',
                        'Are you sure you want to stop sharing your live location?',
                        'Stop Sharing')) {
                      await controller.stop();
                      await _load();
                    }
                  },
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop Sharing')),
      ] else ...[
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: controller.canShare && !controller.busy ? _start : null,
            icon: const Icon(Icons.share_location),
            label: const Text('Share Live Location')),
        TextButton.icon(
            onPressed: controller.canShare && !controller.busy
                ? controller.preview
                : null,
            icon: const Icon(Icons.gps_fixed),
            label: const Text('Allow Location / Preview GPS')),
        if (controller.position != null)
          Text(
              'GPS accuracy: ±${controller.position!.accuracy.round()} m · Preview stays on this device'),
        if (!controller.canShare)
          const Text(
              'Sharing is not enabled for your account. Contact your admin.'),
      ],
      const SizedBox(height: 12),
      const Text('Authorized viewers',
          style: TextStyle(fontWeight: FontWeight.bold)),
      for (final viewer in (controller.permissions['monitors'] as List? ?? []))
        Text('${viewer['name']} · ${viewer['role']}'),
      const SizedBox(height: 8),
      const Text(
          'Keep the app open while sharing. GPS may pause when your device suspends the app or browser.'),
      if (controller.busy) const LinearProgressIndicator(),
    ]));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final admin = context.read<AppState>().isOwner;
        final mine = {
          'name': context.read<AppState>().user?['name'],
          'session': controller.active
              ? controller.session
              : controller.position == null
                  ? null
                  : {
                      'latitude': controller.position!.latitude,
                      'longitude': controller.position!.longitude,
                    }
        };
        final filtered = employees.where((e) {
          final s = e['session'] as Map?;
          return '${e['name']} ${e['employeeCode']} ${e['phone']}'
                  .toLowerCase()
                  .contains(search.toLowerCase()) &&
              (status == 'All' ||
                  locationStatus(s, controller.now) == status) &&
              (duration == 'All' || '${s?['duration']}' == duration) &&
              (manager == 'All' || e['managerName'] == manager) &&
              (department == 'All' || e['department'] == department) &&
              '${locationAddress(s)} ${locationCoordinates(s)}'
                  .toLowerCase()
                  .contains(place.toLowerCase());
        }).toList();
        final live = filtered
            .where((e) => locationActive(e['session'] as Map?, controller.now))
            .toList();
        final selectedCurrent = selected == null
            ? null
            : live.where((e) => e['_id'] == selected!['_id']).firstOrNull;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                        controller.canMonitor
                            ? 'Live Location Dashboard'
                            : 'Live Location',
                        style: const TextStyle(
                            fontSize: 25, fontWeight: FontWeight.w800)),
                    Wrap(children: [
                      if (controller.permissions['canHistory'] == true)
                        IconButton(
                            tooltip: 'Location History',
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => LocationHistoryScreen(
                                        controller: controller))),
                            icon: const Icon(Icons.history)),
                      if (admin)
                        IconButton(
                            tooltip: 'Live Location Settings',
                            onPressed: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => LocationSettingsScreen(
                                          controller: controller)));
                              await controller.refresh();
                              await _load();
                            },
                            icon: const Icon(Icons.settings_outlined)),
                      IconButton(
                          tooltip: 'Refresh',
                          onPressed: () {
                            controller.refresh();
                            _load();
                          },
                          icon: const Icon(Icons.refresh)),
                    ]),
                  ]),
              if (controller.error != null || dashboardError != null)
                Card(
                    color: const Color(0xFFFFE9DE),
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(controller.error ?? dashboardError!))),
              if (controller.notice != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(controller.notice!,
                        style: const TextStyle(color: AppColors.primary))),
              const SizedBox(height: 12),
              if (controller.canMonitor) ...[
                Wrap(spacing: 10, runSpacing: 8, children: [
                  _stat('Total', employees.length),
                  _stat(
                      'Sharing',
                      employees
                          .where((e) => locationActive(
                              e['session'] as Map?, controller.now))
                          .length),
                  _stat(
                      'Not Sharing',
                      employees
                          .where((e) => !locationActive(
                              e['session'] as Map?, controller.now))
                          .length),
                  _stat(
                      'Online GPS',
                      employees
                          .where((e) => locationFresh(
                              e['session'] as Map?, controller.now))
                          .length),
                  _stat(
                      'Offline GPS',
                      employees
                          .where((e) =>
                              locationActive(
                                  e['session'] as Map?, controller.now) &&
                              !locationFresh(
                                  e['session'] as Map?, controller.now))
                          .length),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: _search,
                          decoration: const InputDecoration(
                              hintText: 'Search employee, ID or phone',
                              prefixIcon: Icon(Icons.search)),
                          onChanged: (v) => setState(() => search = v))),
                  IconButton(
                      tooltip: 'Filters',
                      onPressed: _filters,
                      icon: const Icon(Icons.filter_list))
                ]),
                const SizedBox(height: 12),
                TextButton.icon(
                    onPressed: () {
                      _refresh?.cancel();
                      _events?.cancel();
                      _streamClient?.close();
                      setState(() {
                        monitoring = !monitoring;
                        employees = [];
                        selected = null;
                      });
                      if (monitoring) {
                        _load();
                        _connect();
                      }
                    },
                    icon: Icon(monitoring ? Icons.pause : Icons.play_arrow),
                    label: Text(
                        monitoring ? 'Pause monitoring' : 'Resume monitoring')),
                if (monitoring)
                  LayoutBuilder(builder: (context, constraints) {
                    final map = LocationMap(
                        employees: live,
                        selected: selectedCurrent,
                        onSelect: (e) => setState(() => selected = e));
                    final list = Column(children: [
                      if (selectedCurrent != null)
                        _employeeCard(selectedCurrent),
                      if (filtered.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No employees match these filters.')),
                      ...filtered
                          .where((e) => e['_id'] != selectedCurrent?['_id'])
                          .map(_employeeCard)
                    ]);
                    if (constraints.maxWidth < 900) {
                      return Column(children: [map, list]);
                    }
                    return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: map),
                          const SizedBox(width: 14),
                          Expanded(
                              child: SizedBox(
                                  height: 600,
                                  child: SingleChildScrollView(child: list)))
                        ]);
                  }),
                const SizedBox(height: 16),
              ] else ...[
                LocationMap(
                    employees: controller.active || controller.position != null
                        ? [mine]
                        : []),
                const SizedBox(height: 14),
              ],
              _personal(),
            ]);
      });
  Widget _stat(String label, int count) => Chip(
      label: Text('$label  $count'),
      avatar: const Icon(Icons.people_outline, size: 18));
}
