import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';
import 'service/service_module.dart';
import 'sales/sales_module.dart';

/// Ports the top-level routing behaviour split across ReportingPortalPage.jsx
/// and SalesPortalPage.jsx: a Sales-only user only ever sees the Sales
/// module, a Service-only user only ever sees the Service module, and the
/// Owner (admin) can freely switch between both — mirroring the
/// "Sales Module" / "Service Module" links in each page's header.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late String module;
  bool initialized = false;

  void _initModule(AppState state) {
    if (initialized) return;
    initialized = true;
    if (state.isSalesUser || state.isSalesManager) {
      module = 'sales';
    } else {
      module = 'service';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _initModule(state);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: module == 'sales'
            ? SalesModule(onOpenService: state.isOwner ? () => setState(() => module = 'service') : null)
            : ServiceModule(onOpenSales: state.isOwner ? () => setState(() => module = 'sales') : null),
      ),
    );
  }
}
