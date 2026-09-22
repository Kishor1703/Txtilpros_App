import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'location/location_controller.dart';

String _todayIso() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String _monthIso() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
}

String _weekStartIso() {
  final now = DateTime.now();
  final day = now.weekday; // Mon=1..Sun=7
  final diff = day - 1;
  final monday = now.subtract(Duration(days: diff));
  return '${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> createEmptyReportForm() => {
      'workDate': _todayIso(),
      'siteName': '',
      'clientName': '',
      'machineName': '',
      'shift': 'General',
      'hoursWorked': '8',
      'workSummary': '',
      'problemsObserved': '',
      'materialsUsed': '',
      'status': 'completed',
      'photos': <String, dynamic>{'before': <Map<String, dynamic>>[], 'after': null},
    };

Map<String, dynamic> createReportFormFromReport(Map<String, dynamic> report) {
  final photos = (report['photos'] as List?) ?? [];
  return {
    'workDate': (report['workDate']?.toString() ?? _todayIso()).substring(0, 10),
    'siteName': report['siteName'] ?? '',
    'clientName': report['clientName'] ?? '',
    'machineName': report['machineName'] ?? '',
    'shift': report['shift'] ?? 'General',
    'hoursWorked': (report['hoursWorked'] ?? '8').toString(),
    'workSummary': report['workSummary'] ?? '',
    'problemsObserved': report['problemsObserved'] ?? '',
    'materialsUsed': report['materialsUsed'] ?? '',
    'status': report['status'] ?? 'completed',
    'photos': {
      'before': photos.where((p) => (p['kind'] ?? '').toString().toLowerCase() == 'before').toList(),
      'after': photos.firstWhere((p) => (p['kind'] ?? '').toString().toLowerCase() == 'after', orElse: () => null),
    },
  };
}

Map<String, dynamic> createEmptyLeaveForm() => {
      'fromDate': _todayIso(),
      'toDate': _todayIso(),
      'reason': '',
    };

Map<String, dynamic> emptyUserForm() => {
      'name': '',
      'email': '',
      'password': '',
      'role': 'employee',
      'employeeCode': '',
      'department': 'Service',
      'phone': '',
    };

Map<String, dynamic> emptySalesOrderForm() => {
      'customer_name': '',
      'phone_number': '',
      'email': '',
      'address': '',
      'company_id_photo': null,
    };

Map<String, dynamic> emptySalesEmployeeForm() => {
      'name': '',
      'email': '',
      'password': '',
      'role': 'employee',
      'employeeCode': '',
      'phone': '',
    };

class AppState extends ChangeNotifier {
  final location = LocationController();
  @override
  void dispose() { location.dispose(); super.dispose(); }
  String? token;
  Map<String, dynamic>? user;

  bool authLoading = false;
  bool pageLoading = true;

  // --- Reporting (service) state ---
  String weekStart = _weekStartIso();
  String attendanceMonth = _monthIso();
  String salaryMonth = _monthIso();
  String salaryStatus = '';

  List<dynamic> reports = [];
  List<dynamic> leaves = [];
  List<dynamic> salaries = [];
  Map<String, List<dynamic>> auditLogsBySalary = {};
  Map<String, dynamic> summary = {};
  Map<String, dynamic> dashboard = {};
  Map<String, dynamic> attendance = {'daily': [], 'employees': []};
  List<dynamic> users = [];
  List<dynamic> contacts = [];
  Map<String, dynamic>? selectedReport;
  bool selectedReportLoading = false;

  bool submitting = false;
  bool leaveSubmitting = false;
  String leaveActionLoadingId = '';
  bool userSaving = false;
  String salarySavingId = '';
  String salaryHistoryLoadingId = '';
  String messageStatusUpdatingId = '';

  // --- Sales state ---
  Map<String, dynamic> salesDashboard = {};
  List<dynamic> salesOrders = [];
  List<dynamic> salesUsers = [];
  bool salesLoading = false;

  bool get isAuthenticated => token != null && token!.isNotEmpty && user != null;

  bool get isOwner => user?['role'] == 'admin';

  bool get isSalesDepartment => (user?['department']?.toString().toLowerCase() ?? '').contains('sales');

  bool get isServiceManager => user?['role'] == 'manager' && !isSalesDepartment;

  bool get canAccessServiceManagement => isOwner || isServiceManager;

  bool get isSalesUser => user?['role'] == 'employee' && isSalesDepartment;

  bool get isSalesManager => user?['role'] == 'manager' && isSalesDepartment;

  bool get canAccessSalesModule => isOwner || isSalesUser || isSalesManager;

  bool get canManageSales => isOwner || isSalesManager;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(kTokenKey);
    if (token == null || token!.isEmpty) {
      pageLoading = false;
      notifyListeners();
      return;
    }
    try {
      final data = await ApiService.request('/auth/me', token: token);
      user = data['user'] as Map<String, dynamic>?;
      if (user != null && token != null) location.attach(token!);
    } catch (_) {
      await prefs.remove(kTokenKey);
      token = null;
      user = null;
    } finally {
      pageLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    authLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.request('/auth/login', method: 'POST', body: {'email': email, 'password': password});
      token = data['token'] as String?;
      user = data['user'] as Map<String, dynamic>?;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kTokenKey, token ?? '');
      if (user != null && token != null) location.attach(token!);
    } finally {
      authLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await location.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTokenKey);
    token = null;
    user = null;
    reports = [];
    leaves = [];
    salaries = [];
    contacts = [];
    auditLogsBySalary = {};
    users = [];
    summary = {};
    dashboard = {};
    attendance = {'daily': [], 'employees': []};
    selectedReport = null;
    salesDashboard = {};
    salesOrders = [];
    salesUsers = [];
    notifyListeners();
  }

  // ---------------- Admin / manager (service) loaders ----------------

  Future<void> loadOverview() async {
    final results = await Future.wait([
      ApiService.request('/admin/dashboard?weekStart=$weekStart', token: token),
      ApiService.request('/admin/reports?weekStart=$weekStart', token: token),
    ]);
    dashboard = (results[0]['dashboard'] as Map<String, dynamic>?) ?? {};
    reports = (results[1]['reports'] as List?) ?? [];
    notifyListeners();
  }

  Future<void> loadAttendance() async {
    final data = await ApiService.request('/admin/attendance?month=$attendanceMonth', token: token);
    attendance = (data['attendance'] as Map<String, dynamic>?) ?? {'daily': [], 'employees': []};
    notifyListeners();
  }

  Future<void> loadLeaves() async {
    final data = await ApiService.request('/admin/leaves', token: token);
    leaves = (data['leaves'] as List?) ?? [];
    notifyListeners();
  }

  Future<void> loadSalaries() async {
    final query = {'month': salaryMonth, if (salaryStatus.isNotEmpty) 'status': salaryStatus};
    final qs = Uri(queryParameters: query).query;
    final data = await ApiService.request('/salaries?$qs', token: token);
    salaries = (data['salaries'] as List?) ?? [];
    notifyListeners();
  }

  Future<void> loadReports() async {
    final data = await ApiService.request('/admin/reports?weekStart=$weekStart', token: token);
    reports = (data['reports'] as List?) ?? [];
    notifyListeners();
  }

  Future<void> loadEmployees() async {
    final data = await ApiService.request('/admin/users', token: token);
    users = (data['users'] as List?) ?? [];
    notifyListeners();
  }

  Future<void> loadMessages() async {
    final data = await ApiService.request('/contact', token: token);
    contacts = (data['contacts'] as List?) ?? [];
    notifyListeners();
  }

  Future<void> loadReportDetails(String reportId) async {
    selectedReportLoading = true;
    final cached = reports.firstWhere((r) => r['_id']?.toString() == reportId, orElse: () => null);
    if (cached != null) selectedReport = cached as Map<String, dynamic>?;
    notifyListeners();
    try {
      final data = await ApiService.request('/admin/reports/$reportId', token: token, timeout: const Duration(seconds: 15));
      selectedReport = data['report'] as Map<String, dynamic>?;
    } catch (_) {
      if (cached == null) selectedReport = null;
      rethrow;
    } finally {
      selectedReportLoading = false;
      notifyListeners();
    }
  }

  // ---------------- Employee (self) loaders ----------------

  Future<void> loadEmployeeWorkspace() async {
    final results = await Future.wait([
      ApiService.request('/reports/weekly-summary?weekStart=$weekStart', token: token),
      ApiService.request('/reports/mine?weekStart=$weekStart', token: token),
      ApiService.request('/leaves/mine', token: token),
      ApiService.request('/salaries/mine', token: token),
    ]);
    summary = (results[0]['summary'] as Map<String, dynamic>?) ?? {};
    reports = (results[1]['reports'] as List?) ?? [];
    leaves = (results[2]['leaves'] as List?) ?? [];
    salaries = (results[3]['salaries'] as List?) ?? [];
    notifyListeners();
  }

  // ---------------- Mutations (service) ----------------

  Future<void> submitReport(Map<String, dynamic> form, {String? editingReportId}) async {
    submitting = true;
    notifyListeners();
    try {
      final before = List<Map<String, dynamic>>.from(form['photos']['before'] ?? []);
      final after = form['photos']['after'] as Map<String, dynamic>?;
      if (before.isEmpty || after == null) {
        throw ApiException('Please upload at least one before-work photo and one after-work photo.');
      }
      final photos = [...before, after];
      final Map<String, dynamic> payload = {...form, 'hoursWorked': num.tryParse(form['hoursWorked'].toString()) ?? 0};
      payload['photos'] = photos;
      if (editingReportId != null && editingReportId.isNotEmpty) {
        await ApiService.request('/reports/$editingReportId', method: 'PATCH', body: payload, token: token);
      } else {
        await ApiService.request('/reports', method: 'POST', body: payload, token: token);
      }
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<void> submitLeave(Map<String, dynamic> form) async {
    leaveSubmitting = true;
    notifyListeners();
    try {
      await ApiService.request('/leaves', method: 'POST', body: form, token: token);
    } finally {
      leaveSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> leaveDecision(String leaveId, String status, String comment) async {
    leaveActionLoadingId = leaveId;
    notifyListeners();
    try {
      await ApiService.request('/admin/leaves/$leaveId', method: 'PATCH', body: {'status': status, 'adminComment': comment}, token: token);
    } finally {
      leaveActionLoadingId = '';
      notifyListeners();
    }
  }

  Future<bool> leaveEdit(String leaveId, Map<String, dynamic> updates) async {
    leaveActionLoadingId = leaveId;
    notifyListeners();
    try {
      await ApiService.request('/admin/leaves/$leaveId', method: 'PATCH', body: updates, token: token);
      return true;
    } catch (_) {
      return false;
    } finally {
      leaveActionLoadingId = '';
      notifyListeners();
    }
  }

  Future<void> contactStatusUpdate(String contactId, String status) async {
    messageStatusUpdatingId = contactId;
    notifyListeners();
    try {
      final updated = await ApiService.request('/contact/$contactId/status', method: 'PATCH', body: {'status': status}, token: token);
      contacts = contacts.map((c) => c['_id'] == contactId ? updated : c).toList();
    } finally {
      messageStatusUpdatingId = '';
      notifyListeners();
    }
  }

  Future<void> userSubmit(Map<String, dynamic> form) async {
    userSaving = true;
    notifyListeners();
    try {
      await ApiService.request('/admin/users', method: 'POST', body: form, token: token);
    } finally {
      userSaving = false;
      notifyListeners();
    }
  }

  Future<void> userToggle(Map<String, dynamic> targetUser) async {
    final id = targetUser['id'] ?? targetUser['_id'];
    await ApiService.request('/admin/users/$id', method: 'PATCH', body: {'active': !(targetUser['active'] == true)}, token: token);
  }

  Future<void> salarySave(String salaryId, Map<String, dynamic> editForm) async {
    salarySavingId = salaryId;
    notifyListeners();
    try {
      final data = await ApiService.request('/salaries/$salaryId', method: 'PATCH', body: editForm, token: token);
      salaries = salaries.map((s) => s['_id'] == salaryId ? data['salary'] : s).toList();
    } finally {
      salarySavingId = '';
      notifyListeners();
    }
  }

  Future<void> salaryApprove(String salaryId) async {
    salarySavingId = salaryId;
    notifyListeners();
    try {
      final data = await ApiService.request('/salaries/$salaryId/approve', method: 'POST', token: token);
      salaries = salaries.map((s) => s['_id'] == salaryId ? data['salary'] : s).toList();
    } finally {
      salarySavingId = '';
      notifyListeners();
    }
  }

  Future<void> salaryGeneratePayslip(String salaryId) async {
    salarySavingId = salaryId;
    notifyListeners();
    try {
      final data = await ApiService.request('/salaries/$salaryId/generate-payslip', method: 'POST', token: token);
      salaries = salaries.map((s) => s['_id'] == salaryId ? data['salary'] : s).toList();
    } finally {
      salarySavingId = '';
      notifyListeners();
    }
  }

  Future<String> salaryResendEmail(String salaryId) async {
    salarySavingId = salaryId;
    notifyListeners();
    try {
      final data = await ApiService.request('/salaries/$salaryId/resend-email', method: 'POST', token: token);
      salaries = salaries.map((s) => s['_id'] == salaryId ? data['salary'] : s).toList();
      return (data['salary']?['emailDeliveryStatus'] ?? 'pending').toString();
    } finally {
      salarySavingId = '';
      notifyListeners();
    }
  }

  Future<void> salaryHistoryLoad(String salaryId) async {
    salaryHistoryLoadingId = salaryId;
    notifyListeners();
    try {
      final data = await ApiService.request('/salaries/$salaryId/audit-logs', token: token);
      auditLogsBySalary = {...auditLogsBySalary, salaryId: (data['logs'] as List?) ?? []};
    } finally {
      salaryHistoryLoadingId = '';
      notifyListeners();
    }
  }

  Future<String> salaryDownload(Map<String, dynamic> salary) async {
    final label = monthLabelFor(salary);
    return ApiService.download('/salaries/${salary['_id']}/payslip', 'SalarySlip_${label}_${salary['year']}.pdf', token);
  }

  Future<String> employeePayslipDownload(Map<String, dynamic> salary) async {
    final label = monthLabelFor(salary);
    return ApiService.download('/salaries/mine/${salary['_id']}/payslip', 'SalarySlip_${label}_${salary['year']}.pdf', token);
  }

  String monthLabelFor(Map<String, dynamic> salary) {
    const names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final m = int.tryParse(salary['month']?.toString() ?? '1') ?? 1;
    return names[(m - 1).clamp(0, 11)];
  }

  // ---------------- Sales ----------------

  Future<void> loadSalesDashboard() async {
    final data = await ApiService.request('/sales/dashboard', token: token);
    salesDashboard = (data['dashboard'] as Map<String, dynamic>?) ?? {};
    notifyListeners();
  }

  Future<void> loadSalesOrders() async {
    final data = canManageSales
        ? await ApiService.request('/sales/orders/all', token: token)
        : await ApiService.request('/sales/orders/mine', token: token);
    salesOrders = (data['orders'] as List?) ?? [];
    notifyListeners();
  }

  Future<void> loadSalesUsers() async {
    if (!canManageSales) return;
    final data = await ApiService.request('/admin/users', token: token);
    final all = (data['users'] as List?) ?? [];
    salesUsers = all.where((u) => (u['department']?.toString().toLowerCase() ?? '') == 'sales').toList();
    notifyListeners();
  }

  Future<void> salesOrderSubmit(Map<String, dynamic> form) async {
    salesLoading = true;
    notifyListeners();
    try {
      if (form['company_id_photo'] == null) {
        throw ApiException('Please upload a company ID photo.');
      }
      await ApiService.request('/sales/orders', method: 'POST', body: form, token: token);
      await loadSalesDashboard();
      await loadSalesOrders();
    } finally {
      salesLoading = false;
      notifyListeners();
    }
  }

  Future<void> salesEmployeeSubmit(Map<String, dynamic> form) async {
    salesLoading = true;
    notifyListeners();
    try {
      await ApiService.request('/admin/users', method: 'POST', body: {...form, 'department': 'Sales'}, token: token);
      await loadSalesUsers();
    } finally {
      salesLoading = false;
      notifyListeners();
    }
  }

  void setWeekStart(String value) {
    weekStart = value;
    notifyListeners();
  }

  void setAttendanceMonth(String value) {
    attendanceMonth = value;
    notifyListeners();
  }

  void setSalaryMonth(String value) {
    salaryMonth = value;
    notifyListeners();
  }

  void setSalaryStatus(String value) {
    salaryStatus = value;
    notifyListeners();
  }
}
