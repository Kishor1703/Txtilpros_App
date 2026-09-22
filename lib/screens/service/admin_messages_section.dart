import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:txtilpros_app/theme.dart';
import '../../app_state.dart';
import '../../widgets/common.dart';

class AdminMessagesSection extends StatefulWidget {
  const AdminMessagesSection({super.key});
  @override
  State<AdminMessagesSection> createState() => _AdminMessagesSectionState();
}

class _AdminMessagesSectionState extends State<AdminMessagesSection> {
  int page = 1;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      await context.read<AppState>().loadMessages();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _updateStatus(dynamic message, String status) async {
    try {
      await context.read<AppState>().contactStatusUpdate(message['_id'].toString(), status);
      if (mounted) showToast(context, 'Message marked $status');
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final messages = state.contacts;
    final pageItems = paginate(messages, page);
    final newCount = messages.where((m) => m['status'] == 'new').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionIntro(
          eyebrow: 'Inbox',
          title: 'Contact messages',
          description: 'Review website contact form submissions, follow up with leads, and keep message status up to date.',
          aside: StatusPill('$newCount new inquiries', statusKey: 'pending'),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (messages.isEmpty)
          const EmptyState('No contact form messages received yet.')
        else ...[
          ...pageItems.map((message) {
            final isUpdating = state.messageStatusUpdatingId == message['_id'];
            final status = (message['status'] ?? 'new').toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                              MutedText(message['email'] ?? ''),
                              MutedText(message['phone'] ?? ''),
                            ],
                          ),
                        ),
                        StatusPill(status, statusKey: status == 'replied' ? 'completed' : status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(message['subject'] ?? 'General Inquiry', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(message['message'] ?? ''),
                    const SizedBox(height: 6),
                    MutedText(fmtDateTime(message['createdAt'])),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      if (status != 'read')
                        SecondaryButton(label: 'Mark read', onPressed: isUpdating ? null : () => _updateStatus(message, 'read')),
                      if (status != 'replied')
                        PrimaryButton(label: 'Mark replied', onPressed: isUpdating ? null : () => _updateStatus(message, 'replied')),
                    ]),
                  ],
                ),
              ),
            );
          }),
          Pagination(currentPage: page, totalItems: messages.length, itemLabel: 'messages', onPageChange: (p) => setState(() => page = p)),
        ],
      ],
    );
  }
}
