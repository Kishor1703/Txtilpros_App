import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../app_state.dart';

String chatTime(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null ? '' : DateFormat('MMM d, HH:mm').format(date.toLocal());
}

/// Poll only the visible foreground route. Transport can later be replaced.
class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String title;
  const ChatScreen({super.key, this.conversationId, this.title = 'Chat'});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final composer = TextEditingController();
  Timer? timer;
  List<dynamic> rows = [];
  bool loading = true, busy = false, sending = false, hasMore = false;
  bool foreground = true;
  String? error;
  bool get thread => widget.conversationId != null;
  String get path => '/chat/conversations/${widget.conversationId}';

  Future<Map<String, dynamic>> request(String path,
      {String method = 'GET', Map<String, dynamic>? body}) {
    return ApiService.request(path,
        method: method,
        body: body,
        token: context.read<AppState>().token,
        timeout: const Duration(seconds: 20));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (foreground && (ModalRoute.of(context)?.isCurrent ?? false)) refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground && (ModalRoute.of(context)?.isCurrent ?? false)) refresh();
  }

  Future<void> refresh({bool older = false}) async {
    if (busy || !mounted) return;
    busy = true;
    try {
      final suffix =
          older && rows.isNotEmpty ? '?before=${rows.last['_id']}' : '';
      final data = await request(
          thread ? '$path/messages$suffix' : '/chat/conversations');
      if (!mounted) return;
      final incoming = (data[thread ? 'messages' : 'conversations'] as List);
      setState(() {
        if (thread && !older) {
          // A long pause can exceed one page: reset rather than leave a hidden gap.
          if (incoming.length == 50 &&
              rows.isNotEmpty &&
              !incoming.any((r) => rows.any((old) => old['_id'] == r['_id']))) {
            rows = [];
          }
          // Keep already loaded older pages, while merging refreshed recent messages.
          final merged = {
            for (final r in rows) r['_id']: r,
            for (final r in incoming) r['_id']: r
          };
          rows = merged.values.toList()
            ..sort(
                (a, b) => (b['_id'] as String).compareTo(a['_id'] as String));
        } else {
          rows = older ? [...rows, ...incoming] : incoming;
        }
        if (older || loading || rows.length <= 50) {
          hasMore = data['hasMore'] == true;
        }
        loading = false;
        error = null;
      });
      if (thread &&
          !older &&
          incoming.isNotEmpty &&
          foreground &&
          (ModalRoute.of(context)?.isCurrent ?? false)) {
        await request('$path/seen',
            method: 'POST', body: {'messageId': incoming.first['_id']});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
          if (e is ApiException && [401, 403, 404].contains(e.statusCode)) {
            rows = [];
          }
        });
      }
    } finally {
      busy = false;
    }
  }

  Future<void> startChat() async {
    try {
      final data = await request('/chat/contacts');
      if (!mounted) return;
      final contacts = data['contacts'] as List;
      final recipient = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) =>
            SimpleDialog(title: const Text('New conversation'), children: [
          if (contacts.isEmpty)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No contacts available.')),
          for (final contact in contacts)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, Map<String, dynamic>.from(contact)),
              child: Text('${contact['name']} (${contact['role']})'),
            ),
        ]),
      );
      if (recipient == null || !mounted) return;
      final result = await request('/chat/conversations',
          method: 'POST', body: {'recipientId': recipient['id']});
      if (!mounted) return;
      await openThread(result['conversation']);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> openThread(dynamic conversation) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
              conversationId: conversation['id'],
              title: conversation['contact']['name'],
            )));
    if (mounted) refresh();
  }

  Future<void> send() async {
    final text = composer.text.trim();
    if (sending || text.isEmpty || composer.text.length > 4000) return;
    setState(() => sending = true);
    try {
      final data =
          await request('$path/messages', method: 'POST', body: {'text': text});
      if (!mounted) return;
      composer.clear();
      setState(() {
        rows = [
          data['message'],
          ...rows.where((r) => r['_id'] != data['message']['_id'])
        ];
        error = null;
      });
      await refresh();
    } catch (e) {
      if (mounted) setState(() => error = '$e Your draft is preserved.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AppState>().user?['id'];
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(
            tooltip: 'Refresh',
            onPressed: () => refresh(),
            icon: const Icon(Icons.refresh)),
        if (!thread)
          IconButton(
              tooltip: 'New conversation',
              onPressed: startChat,
              icon: const Icon(Icons.add_comment_outlined)),
      ]),
      body: SafeArea(
          child: Column(children: [
        if (error != null)
          MaterialBanner(content: Text(error!), actions: [
            TextButton(onPressed: () => refresh(), child: const Text('Retry')),
          ]),
        Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                    ? Center(
                        child: Text(thread
                            ? 'Start the conversation.'
                            : 'No conversations yet. Tap + to start one.'))
                    : ListView.builder(
                        reverse: thread,
                        padding: const EdgeInsets.all(12),
                        itemCount: rows.length + (thread && hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == rows.length) {
                            return TextButton(
                                onPressed: () => refresh(older: true),
                                child: const Text('Load older messages'));
                          }
                          final row = rows[index];
                          if (!thread) {
                            return ListTile(
                              leading: const Icon(Icons.chat_bubble_outline),
                              title: Text(row['contact']['name']),
                              subtitle: Text(
                                  row['lastMessage']?['text'] ??
                                      'No messages yet',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                        chatTime(
                                            row['lastMessage']?['createdAt']),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall),
                                    if ((row['unread'] as num) > 0)
                                      Text('${row['unread']} unread',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              fontWeight: FontWeight.bold)),
                                  ]),
                              onTap: () => openThread(row),
                            );
                          }
                          final mine = row['sender'] == userId;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 560),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: mine
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectableText(row['text']),
                                    const SizedBox(height: 4),
                                    Text(chatTime(row['createdAt']),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall),
                                  ]),
                            ),
                          );
                        },
                      )),
        if (thread)
          Padding(
              padding: const EdgeInsets.all(12),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: TextField(
                  controller: composer,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText: 'Message', border: OutlineInputBorder()),
                )),
                IconButton(
                    tooltip: 'Send message',
                    onPressed: sending ||
                            composer.text.trim().isEmpty ||
                            composer.text.length > 4000
                        ? null
                        : send,
                    icon: sending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send)),
              ])),
      ])),
    );
  }
}
