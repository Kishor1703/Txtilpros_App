import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

String locationCoordinates(Map? session) => session?['latitude'] is num &&
        session?['longitude'] is num
    ? '${(session!['latitude'] as num).toStringAsFixed(5)}, ${(session['longitude'] as num).toStringAsFixed(5)}'
    : 'No location shared';
String locationAddress(Map? session) => '${session?['address'] ?? ''}'.isEmpty
    ? locationCoordinates(session)
    : '${session!['address']}';
String locationTime(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '—';
  return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String locationRemaining(Map? session, DateTime now) {
  final seconds = (DateTime.tryParse('${session?['expiresAt']}')
              ?.difference(now)
              .inSeconds ??
          0)
      .clamp(0, 28800);
  return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m ${seconds % 60}s';
}

bool locationActive(Map? session, DateTime now) =>
    session?['status'] == 'active' &&
    (DateTime.tryParse('${session?['expiresAt']}')?.isAfter(now) ?? false);
bool locationFresh(Map? session, DateTime now) =>
    locationActive(session, now) &&
    now
            .difference(
                DateTime.tryParse('${session?['updatedAt']}') ?? DateTime(2000))
            .inSeconds <=
        ((session?['updateInterval'] as num? ?? 30) * 2 + 30).clamp(150, 630);
String locationStatus(Map? session, DateTime now) =>
    locationActive(session, now)
        ? (locationFresh(session, now) ? 'Live' : 'Offline')
        : 'Not Sharing';

class LocationMap extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final ValueChanged<Map<String, dynamic>>? onSelect;
  final Map<String, dynamic>? selected;
  final List<LatLng> trail;
  const LocationMap(
      {super.key,
      required this.employees,
      this.onSelect,
      this.selected,
      this.trail = const []});
  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  final _controller = MapController();
  bool _ready = false;
  List<Map<String, dynamic>> get _points => widget.employees
      .where((e) => (e['session'] as Map?)?['latitude'] is num)
      .toList();
  LatLng _point(Map e) => LatLng((e['session']['latitude'] as num).toDouble(),
      (e['session']['longitude'] as num).toDouble());
  void _fit() {
    if (!_ready || _points.isEmpty) return;
    if (_points.length == 1) {
      _controller.move(_point(_points.first), 15);
      return;
    }
    _controller.fitCamera(CameraFit.coordinates(
        coordinates: _points.map(_point).toList(),
        padding: const EdgeInsets.all(60),
        maxZoom: 16));
  }

  @override
  void didUpdateWidget(covariant LocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready &&
        widget.selected != null &&
        widget.selected?['_id'] != oldWidget.selected?['_id'] &&
        widget.selected!['session'] != null) {
      _controller.move(_point(widget.selected!), 16);
    } else if (oldWidget.employees.isEmpty && _points.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
            height: 450,
            child: Stack(children: [
              FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: _points.isEmpty
                        ? const LatLng(11.0168, 76.9558)
                        : _point(_points.first),
                    initialZoom: _points.isEmpty ? 5 : 14,
                    onMapReady: () {
                      _ready = true;
                      _fit();
                    },
                  ),
                  children: [
                    TileLayer(
                        urlTemplate: const String.fromEnvironment(
                            'MAP_TILE_URL',
                            defaultValue:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                        userAgentPackageName: 'in.txtilpros.app'),
                    if (widget.trail.isNotEmpty)
                      PolylineLayer(polylines: [
                        Polyline(
                            points: widget.trail,
                            color: AppColors.primary,
                            strokeWidth: 4)
                      ]),
                    MarkerClusterLayerWidget(
                        options: MarkerClusterLayerOptions(
                      maxClusterRadius: 45,
                      size: const Size(44, 44),
                      markers: _points
                          .map((e) => Marker(
                              point: _point(e),
                              width: 115,
                              height: 72,
                              child: Semantics(
                                  label: 'View ${e['name']} location',
                                  button: true,
                                  child: InkWell(
                                      onTap: () => widget.onSelect?.call(e),
                                      child: Column(children: [
                                        CircleAvatar(
                                            backgroundColor: locationFresh(
                                                    e['session'] as Map?,
                                                    DateTime.now())
                                                ? AppColors.primary
                                                : AppColors.muted,
                                            foregroundColor: Colors.white,
                                            child: Text('${e['name'] ?? '?'}'
                                                .substring(0, 1)
                                                .toUpperCase())),
                                        Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 2),
                                            color: Colors.white,
                                            child: Text(
                                                '${locationFresh(e['session'] as Map?, DateTime.now()) ? '●' : '○'} ${e['name']}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.ink))),
                                      ])))))
                          .toList(),
                      builder: (context, markers) => CircleAvatar(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          child: Text('${markers.length}')),
                    )),
                    RichAttributionWidget(attributions: [
                      TextSourceAttribution('OpenStreetMap contributors',
                          onTap: () => launchUrl(Uri.parse(
                              'https://www.openstreetmap.org/copyright')))
                    ]),
                  ]),
              Positioned(
                  top: 12,
                  right: 12,
                  child: Column(children: [
                    FloatingActionButton.small(
                        heroTag: null,
                        tooltip: 'Fit shared locations',
                        onPressed: _fit,
                        child: const Icon(Icons.center_focus_strong)),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                        heroTag: null,
                        tooltip: 'Zoom in',
                        onPressed: () => _controller.move(
                            _controller.camera.center,
                            (_controller.camera.zoom + 1).clamp(2, 19)),
                        child: const Icon(Icons.add)),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                        heroTag: null,
                        tooltip: 'Zoom out',
                        onPressed: () => _controller.move(
                            _controller.camera.center,
                            (_controller.camera.zoom - 1).clamp(2, 19)),
                        child: const Icon(Icons.remove)),
                  ])),
              if (_points.isEmpty)
                const Positioned(
                    left: 12,
                    top: 12,
                    child: Card(
                        child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No active locations to display')))),
            ])),
      );
}
