import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'location_controller.dart';
import 'location_map.dart';

class LocationHistoryScreen extends StatefulWidget {
  final LocationController controller;
  final String? employeeId;
  const LocationHistoryScreen(
      {super.key, required this.controller, this.employeeId});
  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  List<Map<String, dynamic>> sessions = [];
  String? error;
  int page = 0;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.controller.request(
          '/history?page=$page${widget.employeeId == null ? '' : '&employeeId=${Uri.encodeQueryComponent(widget.employeeId!)}'}');
      if (mounted) {
        setState(() => sessions = (data['sessions'] as List)
            .map((s) => Map<String, dynamic>.from(s))
            .toList());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          sessions = [];
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _trail(Map<String, dynamic> session) async {
    try {
      final data =
          await widget.controller.request('/history/${session['_id']}');
      if (!mounted) return;
      final points = (data['points'] as List)
          .map((p) => LatLng((p['latitude'] as num).toDouble(),
              (p['longitude'] as num).toDouble()))
          .toList();
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${session['employeeName']} · Movement history',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    LocationMap(employees: [
                      {
                        'name': session['employeeName'],
                        'session': data['session']
                      }
                    ], trail: points),
                    Text(
                        '${points.length} recorded updates · ${session['status']}'),
                  ]))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Location History')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (error != null) ...[
                Text(error!),
                TextButton(onPressed: _load, child: const Text('Retry'))
              ],
              if (error == null && sessions.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'No history is available for your permissions and this page.')),
              ...sessions.map((s) => Card(
                  child: ListTile(
                      isThreeLine: true,
                      leading: const Icon(Icons.history),
                      title: Text('${s['employeeName']} · ${s['status']}'),
                      // Older sessions may not have a company name.
                      subtitle: Text(
                          '${'${s['companyName'] ?? ''}'.isEmpty ? '' : 'Company: ${s['companyName']}\n'}Started ${locationTime(s['startedAt'])}\nEnds ${locationTime(s['stoppedAt'] ?? s['expiresAt'])} · ${s['duration']} Hours\nLast location: ${locationCoordinates(s)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _trail(s)))),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(
                    onPressed: page == 0
                        ? null
                        : () {
                            page--;
                            _load();
                          },
                    child: const Text('Previous')),
                Text('Page ${page + 1}'),
                TextButton(
                    onPressed: sessions.length < 50
                        ? null
                        : () {
                            page++;
                            _load();
                          },
                    child: const Text('Next')),
              ]),
            ]));
}
