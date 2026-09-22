import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool salesTab = false;
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    try {
      await state.login(emailCtrl.text.trim(), passwordCtrl.text);
      if (!mounted) return;
      showToast(context, 'Welcome back, ${state.user?['name'] ?? ''}');
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, error: true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFBF3), Color(0xFFE9E1D2)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -110,
                right: -90,
                child: IgnorePointer(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -130,
                left: -110,
                child: IgnorePointer(
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 520;
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 16 : 24,
                      vertical: isCompact ? 18 : 28,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - (isCompact ? 36 : 56),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: GlassCard(
                            padding: EdgeInsets.all(isCompact ? 20 : 26),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              Image.asset(
                                'assets/logo.png',
                                height: 82,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Txtilpros App',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.bg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ChoiceChip(
                                        label: const SizedBox(
                                          width: double.infinity,
                                          child: Text(
                                            'Service Login',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        selected: !salesTab,
                                        onSelected: (_) => setState(() => salesTab = false),
                                        selectedColor: AppColors.primary,
                                        backgroundColor: Colors.transparent,
                                        side: BorderSide.none,
                                        showCheckmark: false,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        labelStyle: TextStyle(
                                          color: !salesTab
                                              ? Colors.white
                                              : AppColors.ink,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: ChoiceChip(
                                        label: const SizedBox(
                                          width: double.infinity,
                                          child: Text(
                                            'Sales Login',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        selected: salesTab,
                                        onSelected: (_) => setState(() => salesTab = true),
                                        selectedColor: AppColors.primary,
                                        backgroundColor: Colors.transparent,
                                        side: BorderSide.none,
                                        showCheckmark: false,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        labelStyle: TextStyle(
                                          color: salesTab
                                              ? Colors.white
                                              : AppColors.ink,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              LabeledField(
                                label: 'Email',
                                wide: true,
                                child: TextFormField(
                                  controller: emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    hintText: salesTab
                                        ? 'sales@txtilpros.local'
                                        : 'employee@txtilpros.local',
                                  ),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Email is required'
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 12),
                              LabeledField(
                                label: 'Password',
                                wide: true,
                                child: TextFormField(
                                  controller: passwordCtrl,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter your password',
                                  ),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Password is required'
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => showToast(
                                    context,
                                    'Please contact admin to reset your password.',
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text('Forgot your password?'),
                                ),
                              ),
                              const SizedBox(height: 6),
                              PrimaryButton(
                                label: state.authLoading
                                    ? 'Signing in...'
                                    : (salesTab
                                        ? 'Login to sales dashboard'
                                        : 'Login to dashboard'),
                                loading: state.authLoading || state.pageLoading,
                                onPressed: _submit,
                                expand: true,
                              ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
