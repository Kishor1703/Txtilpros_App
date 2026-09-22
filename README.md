# TXTILPROS — Flutter Reporting & Sales Portal

This is a Flutter port of the React web app's **Reporting Portal** (Admin +
Manager + Employee) and **Sales Portal**, talking to the **same backend
API** your React app already uses. Public marketing pages were intentionally
left out per your request — only the two portals were ported.

## 1. Set up the project

This sandbox doesn't have the Flutter SDK installed, so the project couldn't
be compiled/tested here. On your own machine with Flutter installed:

```bash
# from inside this folder
flutter create . --platforms=android,ios,web   # generates android/ios/web scaffolding
flutter pub get
```

`flutter create .` will not overwrite the `lib/`, `pubspec.yaml`, or
`analysis_options.yaml` files already here — it only fills in the missing
`android/`, `ios/`, `web/` platform folders.

## 2. Point it at your backend

The API base URL mirrors `VITE_API_URL` from the React app's `.env`. Set it
at build/run time (no code edit needed):

```bash
flutter run --dart-define=API_URL=http://localhost:5000/api
# or, for the deployed backend:
flutter run --dart-define=API_URL=https://txtilpros-backend.vercel.app/api
```

If you don't pass `--dart-define`, it defaults to
`https://txtilpros-backend.vercel.app/api` (see `lib/api_service.dart`).

For a permanent default, just edit `kApiBaseUrl`'s `defaultValue` in
`lib/api_service.dart`.

## 3. What was ported (feature parity with the React app)

**Auth** — `/auth/login`, `/auth/me`, same JWT bearer token, stored under the
same `employee-reporting-token` key (via `shared_preferences` instead of
`localStorage`). Login screen has the same Service/Sales tab switch.

**Reporting portal**
- Admin/Manager (`role: admin` or `role: manager` outside Sales dept):
  Overview, Attendance, Leaves, Salaries (admin only), Reports (+ report
  detail drill-down), Employees, Messages (admin only) — same section list
  and same field-level data as `AdminDashboard.jsx` and its section
  components.
- Employee: report submission (with before/after photo capture, compressed
  and base64-encoded like the web app's `readFiles`), leave requests,
  payslip downloads — same as `EmployeeDashboard.jsx`.
- Sales-department users are shown the same "access denied" panel when they
  try to open the service module.

**Sales portal** — Overview stats, Add New Order (with company ID photo
upload), My Orders / All Sales Orders, Sales Team management (owner/sales
manager) — same as `SalesPortalPage.jsx`. Owners can jump between the
Service and Sales modules exactly like the "Sales Module"/"Service Module"
links in the React header.

## 4. Notable implementation differences (Flutter vs. web)

- **Data loading** — the React hook (`useReportingPortal`) re-fetches based
  on the current route (`location.pathname`). Flutter has no URL router by
  default here, so each section screen (e.g. `AdminAttendanceSection`)
  fetches its own data in `initState`, which is the idiomatic Flutter
  equivalent and preserves the same end result.
- **Photo uploads** — `image_picker` replaces the `<input type="file">` +
  `browser-image-compression` combo. Images are read, downsized via
  `imageQuality`/`maxWidth`, and base64-encoded into the same
  `{name, size, type, dataUrl}` shape the backend already expects, so no
  backend changes are required.
- **PDF payslip downloads** — `apiDownload()` is ported as
  `ApiService.download()`; files save to the app's documents directory
  (via `path_provider`) and the saved path is shown in a snackbar.
- **Toasts** — `react-hot-toast` → `ScaffoldMessenger` snackbars
  (`showToast()` helper in `lib/widgets/common.dart`).

## 5. Project structure

```
lib/
  main.dart                     # Provider + login/home routing
  app_state.dart                # Central state (auth + all API calls)
  api_service.dart              # http wrapper (mirrors api.js)
  theme.dart                    # Colors/typography ported from global.css
  screens/
    login_screen.dart           # Service/Sales login tabs
    home_shell.dart             # Picks Service vs Sales module by role
    service/
      service_module.dart       # Header + Admin/Employee shell switch
      admin_shell.dart          # Section nav (Overview/Attendance/.../Messages)
      admin_overview_section.dart
      admin_attendance_section.dart
      admin_leaves_section.dart
      admin_salaries_section.dart
      admin_reports_section.dart
      admin_report_details_section.dart
      admin_employees_section.dart
      admin_messages_section.dart
      employee_shell.dart       # Report form/list, leave form/list, payslips
    sales/
      sales_module.dart         # Header, nav, overview, order form, orders, team
  widgets/
    common.dart                 # StatCard, StatusPill, buttons, pagination, etc.
```

## 6. Still to wire up if you need it later

- Real push notifications / background sync are not implemented (the React
  app doesn't have them either).
- The "public marketing site" (Home/Contact/Navbar/Footer) was intentionally
  left out per your instruction to focus on the portals — say the word if
  you'd like that ported too.
