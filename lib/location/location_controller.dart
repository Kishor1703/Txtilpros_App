import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../api_service.dart';

class LocationController extends ChangeNotifier {
  String? _token;
  Timer? _timer;
  StreamSubscription<Position>? _gps;
  Position? position;
  Map<String, dynamic> permissions = {};
  Map<String, dynamic>? session;
  String? error;
  String? notice;
  bool busy = false, _syncing = false, _sending = false;
  bool _locating = false;
  DateTime? _sentAt;
  Position? _sentPosition;
  Duration _clockOffset = Duration.zero;
  int _generation = 0;
  Map<String, dynamic> get settings =>
      Map<String, dynamic>.from(permissions['settings'] ?? {});
  DateTime get now => DateTime.now().add(_clockOffset);
  bool get active =>
      session?['status'] == 'active' && remaining > Duration.zero;
  bool get tracking => _gps != null;
  Duration get remaining =>
      DateTime.tryParse('${session?['expiresAt']}')?.difference(now) ??
      Duration.zero;
  bool get canShare => permissions['canShare'] == true;
  bool get canMonitor => permissions['canMonitor'] == true;
  // Keep the entry discoverable while permissions load or the API is unavailable.
  // Sharing and monitoring still require explicit backend authorization.
  bool get showNavigation => permissions.isEmpty || canShare || canMonitor || active || permissions['canHistory'] == true;

  Future<Map<String, dynamic>> request(String path,
          {String method = 'GET', Map<String, dynamic>? body}) =>
      ApiService.request('/location$path',
          token: _token,
          method: method,
          body: body,
          timeout: const Duration(seconds: 20));

  void attach(String token) {
    if (_token == token) return;
    _token = token;
    _generation++;
    refresh();
    var ticks = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (session?['status'] == 'active' && !active) {
        session = {...session!, 'status': 'expired'};
        _cancelGps();
        notice = 'Your live location sharing session has expired.';
        refresh();
      }
      if (++ticks % 30 == 0) refresh();
      if (ticks % 60 == 0 && active && tracking) _freshFix();
      if (active && position != null && tracking) _send(position!);
      notifyListeners();
    });
  }

  Stream<Map<String, dynamic>> events(http.Client client) async* {
    final request =
        http.Request('GET', Uri.parse('$kApiBaseUrl/location/events'));
    request.headers['Authorization'] = 'Bearer $_token';
    final response =
        await client.send(request).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw ApiException(
          'Live connection unavailable (${response.statusCode}).');
    }
    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(const Duration(seconds: 35))) {
      if (line.startsWith('data: ')) {
        final data = Map<String, dynamic>.from(jsonDecode(line.substring(6)));
        if (!data.containsKey('employees')) {
          throw ApiException('Live connection ended. Reconnecting…');
        }
        yield data;
      }
    }
  }

  Future<void> _freshFix() async {
    if (_locating) return;
    _locating = true;
    final generation = _generation;
    try {
      final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 20)));
      if (generation == _generation && active && tracking) {
        position = p;
        await _send(p);
      }
    } catch (e) {
      if (generation == _generation) error = 'GPS unavailable. $e';
    } finally {
      _locating = false;
    }
  }

  Future<void> refresh() async {
    if (_token == null || _syncing) return;
    final generation = _generation;
    _syncing = true;
    try {
      final results =
          await Future.wait([request('/permissions'), request('/self')]);
      if (generation != _generation) return;
      permissions = results[0];
      _setSession(results[1]);
      if (!active || !canShare) _cancelGps();
      if (error?.startsWith('Connection lost') == true) {
        error = null;
        notice = 'Live location reconnected.';
      }
    } catch (e) {
      if (generation == _generation) {
        if (e is ApiException && e.statusCode == 401) {
          _cancelGps();
          permissions = {};
          error =
              'Your login session has expired. Sign in again to resume location sharing.';
        } else if (e is ApiException && e.statusCode == 404) {
          error = 'Live Location is not available on the connected backend yet. Restart the updated backend and point the app to it, or deploy the new backend routes.';
        } else {
          error = 'Connection lost. Trying to reconnect... $e';
        }
      }
    } finally {
      _syncing = false;
      if (generation == _generation) notifyListeners();
    }
  }

  void _setSession(Map<String, dynamic> data) {
    final serverTime = DateTime.tryParse('${data['serverTime']}');
    if (serverTime != null) {
      _clockOffset = serverTime.difference(DateTime.now());
    }
    session = data['session'] == null
        ? null
        : Map<String, dynamic>.from(data['session']);
  }

  Future<Position> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw ApiException(
          'GPS is unavailable. Enable device location services.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw ApiException(
          'Location permission is required to share your live location. Allow location in your device or browser settings.');
    }
    return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
  }

  Map<String, dynamic> _coordinates(Position p) => {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'accuracy': p.accuracy
      };
  Future<void> preview() async {
    if (busy || !canShare) return;
    final generation = _generation;
    busy = true;
    notifyListeners();
    try {
      final p = await locate();
      if (generation == _generation) {
        position = p;
        error = null;
      }
    } catch (e) {
      if (generation == _generation) error = e.toString();
    } finally {
      busy = false;
      if (generation == _generation) notifyListeners();
    }
  }

  Future<void> start(int hours, {String companyName = ''}) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    final generation = _generation;
    final startingToken = _token;
    try {
      final p = await locate();
      if (generation != _generation) return;
      final data = await request('/start',
          method: 'POST', body: {..._coordinates(p), 'duration': hours, 'companyName': companyName.trim()});
      if (generation != _generation) {
        // A logout can finish while the start request is in flight.
        await ApiService.request('/location/stop',
            token: startingToken,
            method: 'POST',
            body: {'sessionId': data['session']['_id']},
            timeout: const Duration(seconds: 20));
        return;
      }
      position = p;
      _sentPosition = p;
      _sentAt = DateTime.now();
      _setSession(data);
      _watch();
      notice = 'Live location sharing started.';
    } catch (e) {
      if (generation == _generation) error = e.toString();
    } finally {
      busy = false;
      if (generation == _generation) notifyListeners();
    }
  }

  Future<void> resume() async {
    if (busy || !active) return;
    busy = true;
    notifyListeners();
    final generation = _generation;
    try {
      final p = await locate();
      if (generation != _generation || !active) return;
      position = p;
      error = null;
      _watch();
      await _send(p);
    } catch (e) {
      if (generation == _generation) error = e.toString();
    } finally {
      busy = false;
      if (generation == _generation) notifyListeners();
    }
  }

  void _watch() {
    _cancelGps();
    _gps = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high, distanceFilter: 15))
        .listen((p) {
      position = p;
      _send(p);
    }, onError: (Object e) {
      error = 'GPS unavailable: $e';
      _cancelGps();
      notifyListeners();
    });
  }

  Future<void> _send(Position p) async {
    if (_sending || !active || !canShare || _token == null) return;
    final interval = (settings['updateInterval'] as num? ?? 30).toInt();
    final stationary = _sentPosition != null &&
        Geolocator.distanceBetween(p.latitude, p.longitude,
                _sentPosition!.latitude, _sentPosition!.longitude) <
            15;
    final age = DateTime.now().difference(p.timestamp).inSeconds;
    if (age > 120) {
      return; // Never present an old fix as a fresh GPS measurement.
    }
    if (_sentAt != null &&
        DateTime.now().difference(_sentAt!).inSeconds <
            (stationary ? interval * 2 : interval)) {
      return;
    }
    if (p.accuracy > (settings['maximumAccuracy'] as num? ?? 100)) {
      error =
          'Poor GPS accuracy (±${p.accuracy.round()} m). Move outdoors for a better signal.';
      return;
    }
    _sending = true;
    final generation = _generation;
    _sentAt = DateTime.now();
    try {
      final data = await request('/update',
          method: 'POST',
          body: {..._coordinates(p), 'sessionId': session!['_id']});
      if (generation != _generation) return;
      _setSession(data);
      _sentPosition = p;
      if (error != null) notice = 'Live location reconnected.';
      error = null;
    } catch (e) {
      if (generation == _generation) {
        error = 'Connection lost. Trying to reconnect... $e';
        await refresh();
      }
    } finally {
      _sending = false;
      if (generation == _generation) notifyListeners();
    }
  }

  Future<void> stop() async {
    final generation = ++_generation;
    _cancelGps();
    if (session == null) return;
    busy = true;
    notifyListeners();
    try {
      final data = await request('/stop',
          method: 'POST', body: {'sessionId': session!['_id']});
      if (generation != _generation) return;
      if (data['session'] != null) {
        _setSession(data);
      } else {
        session = {...session!, 'status': 'stopped'};
      }
      error = null;
      notice = 'Location Sharing Stopped';
    } catch (e) {
      if (generation == _generation) {
        error =
            'GPS updates stopped on this device. Server stop is unconfirmed; retry when connected. $e';
      }
    } finally {
      busy = false;
      if (generation == _generation) notifyListeners();
    }
  }

  Future<void> logout() async {
    final token = _token;
    _generation++;
    _cancelGps();
    _timer?.cancel();
    _token = null;
    session = null;
    permissions = {};
    position = null;
    _sentAt = null;
    _sentPosition = null;
    error = null;
    notice = null;
    notifyListeners();
    if (token != null) {
      try {
        await ApiService.request('/location/stop',
            token: token,
            method: 'POST',
            body: {},
            timeout: const Duration(seconds: 10));
      } catch (_) {
        // Local GPS is already stopped. Remote session becomes stale and expires
        // if logout happens without connectivity; no location is queued offline.
      }
    }
  }

  void _cancelGps() {
    _gps?.cancel();
    _gps = null;
  }

  @override
  void dispose() {
    _generation++;
    _cancelGps();
    _timer?.cancel();
    super.dispose();
  }
}
