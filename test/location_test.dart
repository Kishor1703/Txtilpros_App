import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:txtilpros_app/app_state.dart';
import 'package:txtilpros_app/location/location_controller.dart';
import 'package:txtilpros_app/location/location_map.dart';
import 'package:txtilpros_app/location/location_screen.dart';

class FakeLocation extends LocationController {
  int? startedHours;
  String? startedCompany;
  FakeLocation() {
    permissions = {
      'canShare': true,
      'canMonitor': true,
      'settings': {'maximumDuration': 8},
      'monitors': [
        {'name': 'Manager', 'role': 'manager'}
      ]
    };
  }
  @override
  Future<Map<String, dynamic>> request(String path,
          {String method = 'GET', Map<String, dynamic>? body}) async =>
      {'employees': []};
  @override
  Future<void> start(int hours, {String companyName = ''}) async {
    startedHours = hours;
    startedCompany = companyName;
  }

  @override
  Stream<Map<String, dynamic>> events(dynamic client) => const Stream.empty();
}

class FakeAppState extends AppState {
  final fake = FakeLocation();
  @override
  LocationController get location => fake;
  FakeAppState() {
    user = {'id': 'employee', 'name': 'Test Employee', 'role': 'employee'};
  }
}

void main() {
  test('location entry remains visible before permissions load but sharing stays blocked', () {
    final controller = LocationController();
    expect(controller.showNavigation, isTrue);
    expect(controller.canShare, isFalse);
    expect(controller.canMonitor, isFalse);
    controller.permissions = {'canShare': false, 'canMonitor': false, 'canHistory': false};
    expect(controller.showNavigation, isFalse);
    controller.dispose();
  });
  test('expired sessions disappear exactly at their deadline', () {
    final now = DateTime.utc(2026, 9, 7, 12);
    final session = {
      'status': 'active',
      'expiresAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String()
    };
    expect(locationActive(session, now), false);
    expect(locationStatus(session, now), 'Not Sharing');
    expect(locationRemaining(session, now), '0h 0m 0s');
  });
  test('stale GPS never reports a live employee', () {
    final now = DateTime.utc(2026, 9, 7, 12);
    final session = {
      'status': 'active',
      'expiresAt': now.add(const Duration(hours: 1)).toIso8601String(),
      'updatedAt': now.subtract(const Duration(minutes: 3)).toIso8601String()
    };
    expect(locationStatus(session, now), 'Offline');
    session['updatedAt'] = now.toIso8601String();
    expect(locationStatus(session, now), 'Live');
  });
  for (final hours in [1, 3, 8]) {
    testWidgets('duration $hours requires explicit confirmation',
        (tester) async {
      tester.view.physicalSize = hours == 1 ? const Size(390, 844) : hours == 3 ? const Size(820, 1180) : const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = FakeAppState();
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: app,
          child: const MaterialApp(
              home: Scaffold(
                  body: SingleChildScrollView(child: LiveLocationScreen())))));
      await tester.pump();
      await tester.tap(find.text('Pause monitoring'));
      await tester.pump();
      await tester.ensureVisible(find.text('Share Live Location'));
      await tester.tap(find.text('Share Live Location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$hours ${hours == 1 ? 'Hour' : 'Hours'}'));
      await tester.enterText(find.byKey(const ValueKey('locationCompanyName')), '  Acme Textiles  ');
      await tester.ensureVisible(find.text('Start Live Location'));
      await tester.tap(find.text('Start Live Location'));
      await tester.pumpAndSettle();
      expect(app.fake.startedHours, isNull);
      expect(
          find.text(
              'Your live location will be shared with authorized Admins and Managers for the selected duration.'),
          findsOneWidget);
      await tester.tap(find.text('Start Sharing'));
      await tester.pumpAndSettle();
      expect(app.fake.startedHours, hours);
      expect(app.fake.startedCompany, 'Acme Textiles');
      await tester.pumpWidget(const SizedBox());
      app.fake.dispose();
    });
  }
}
