import 'package:flutter/material.dart';
import '../theme.dart';

const int kPageSize = 10;

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  const StatCard({super.key, required this.label, required this.value, required this.hint});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gray, letterSpacing: 0.2),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1)),
          const SizedBox(height: 8),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          MutedText(hint),
        ],
      ),
    );
  }
}

class StatGrid extends StatelessWidget {
  final List<Widget> children;
  const StatGrid({super.key, required this.children});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth >= 980
            ? 3
            : maxWidth >= 620
                ? 2
                : 1;
        const gap = 14.0;
        final itemWidth = columns == 1
            ? maxWidth
            : (maxWidth - ((columns - 1) * gap)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

Color statusColor(String status) {
  final s = status.toLowerCase().replaceAll(' ', '-');
  switch (s) {
    case 'completed':
    case 'approved':
    case 'active':
    case 'paid':
      return AppColors.statusCompleted;
    case 'pending':
    case 'unpaid':
      return AppColors.statusPending;
    case 'leave':
      return AppColors.statusLeave;
    case 'holiday':
      return AppColors.statusHoliday;
    case 'comp-off':
      return AppColors.statusCompOff;
    case 'blocked':
    case 'rejected':
    case 'disabled':
    case 'failed':
      return AppColors.statusBlocked;
    case 'needs-support':
      return AppColors.statusNeedsSupport;
    case 'new':
    case 'read':
      return AppColors.accent;
    default:
      return AppColors.gray;
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final String? statusKey;
  const StatusPill(this.label, {super.key, this.statusKey});
  @override
  Widget build(BuildContext context) {
    final color = statusColor(statusKey ?? label);
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12, height: 1.15),
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false, this.expand = false});
  @override
  Widget build(BuildContext context) {
    final child = ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
            )
          : Text(label),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const SecondaryButton({super.key, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const GhostButton({super.key, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: AppColors.gray, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      child: Text(label),
    );
  }
}

class SectionIntro extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final Widget? aside;
  const SectionIntro({super.key, required this.eyebrow, required this.title, required this.description, this.aside});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(eyebrow),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 6),
              MutedText(description),
            ],
          );

          if (aside == null) return content;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 12),
                aside!,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              const SizedBox(width: 12),
              Flexible(child: aside!),
            ],
          );
        },
      ),
    );
  }
}

/// Horizontally scrollable section navigation, ports AdminNavigation / SalesNavigation.
/// Redesigned as a clean segmented tab bar so the active section reads at a
/// glance, while keeping the exact same constructor as before.
class SectionNav extends StatelessWidget {
  final List<MapEntry<String, String>> items; // label -> key
  final String active;
  final ValueChanged<String> onSelect;
  const SectionNav({super.key, required this.items, required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.shadow.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.map((item) {
            final isActive = item.value == active;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: isActive
                      ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 3))]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    onTap: () => onSelect(item.value),
                    hoverColor: isActive ? Colors.transparent : AppColors.primary.withValues(alpha: 0.06),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      child: Text(
                        item.key,
                        style: TextStyle(
                          color: isActive ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  const EmptyState(this.message, {super.key});
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, color: AppColors.gray.withValues(alpha: 0.6), size: 28),
            const SizedBox(height: 10),
            MutedText(message, align: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Ports AdminPagination.jsx
class Pagination extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final String itemLabel;
  final ValueChanged<int> onPageChange;
  const Pagination({
    super.key,
    required this.currentPage,
    required this.totalItems,
    required this.onPageChange,
    this.pageSize = kPageSize,
    this.itemLabel = 'items',
  });

  @override
  Widget build(BuildContext context) {
    if (totalItems <= pageSize) return const SizedBox.shrink();
    final totalPages = (totalItems / pageSize).ceil().clamp(1, 1 << 30);
    final startItem = totalItems == 0 ? 0 : (currentPage - 1) * pageSize + 1;
    final endItem = (currentPage * pageSize).clamp(0, totalItems);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: MutedText('Showing $startItem-$endItem of $totalItems $itemLabel')),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PageArrow(
                icon: Icons.chevron_left,
                enabled: currentPage > 1,
                onTap: () => onPageChange(currentPage - 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink),
                ),
              ),
              _PageArrow(
                icon: Icons.chevron_right,
                enabled: currentPage < totalPages,
                onTap: () => onPageChange(currentPage + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageArrow({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 20, color: enabled ? AppColors.ink : AppColors.light),
        splashRadius: 20,
      ),
    );
  }
}

int clampPage(int page, int totalItems, {int pageSize = kPageSize}) {
  final totalPages = (totalItems / pageSize).ceil().clamp(1, 1 << 30);
  return page.clamp(1, totalPages);
}

List<T> paginate<T>(List<T> items, int page, {int pageSize = kPageSize}) {
  final safePage = clampPage(page, items.length, pageSize: pageSize);
  final start = (safePage - 1) * pageSize;
  if (start >= items.length) return [];
  return items.sublist(start, (start + pageSize).clamp(0, items.length));
}

/// Standard labeled text field, ports the repeated `.field` label/input pattern.
class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool wide;
  const LabeledField({super.key, required this.label, required this.child, this.wide = false});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide ? double.infinity : 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

void showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: error ? AppColors.danger : AppColors.primaryDark,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

String fmtDate(dynamic value) {
  if (value == null) return '-';
  try {
    final d = DateTime.parse(value.toString()).toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  } catch (_) {
    return value.toString();
  }
}

String fmtDateTime(dynamic value) {
  if (value == null) return '-';
  try {
    final d = DateTime.parse(value.toString()).toLocal();
    return '${fmtDate(value)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return value.toString();
  }
}

String fmtMoney(dynamic value) {
  final n = num.tryParse(value?.toString() ?? '0') ?? 0;
  final s = n.toStringAsFixed(n % 1 == 0 ? 0 : 2);
  final parts = s.split('.');
  final digits = parts[0].replaceAll('-', '');
  final buf = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final posFromRight = digits.length - i;
    buf.write(digits[i]);
    if (posFromRight > 1 && (posFromRight - 1) % 3 == 0 && posFromRight > 3) buf.write(',');
  }
  final sign = n < 0 ? '-' : '';
  return '$sign$buf${parts.length > 1 ? '.${parts[1]}' : ''}';
}

String monthLabel(int month, int year) {
  const names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final idx = (month - 1).clamp(0, 11);
  return '${names[idx]} $year';
}
