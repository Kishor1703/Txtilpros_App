import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';
import 'location/location_controller.dart';

void main() {
  runApp(const TxtilprosApp());
}

class TxtilprosApp extends StatelessWidget {
  const TxtilprosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..init()),
        ListenableProxyProvider<AppState, LocationController>(update: (_, state, previous) => state.location),
      ],
      child: MaterialApp(
        title: 'TXTILPROS',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.pageLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!state.isAuthenticated) {
      return const LoginScreen();
    }
    return const HomeShell();
  }
}
