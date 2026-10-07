import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:txtilpros_app/app_state.dart';
import 'package:txtilpros_app/screens/chat_screen.dart';

void main() {
  testWidgets(
      'loads history with session token, rejects blank composer and preserves failed draft',
      (tester) async {
    var sends = 0;
    final state = AppState()
      ..token = 'existing-session'
      ..user = {'id': 'employee'};
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: state,
          child: const MaterialApp(
              home: ChatScreen(
                  conversationId: 'conversation', title: 'Manager'))));
      await tester.pumpAndSettle();
      expect(find.text('Start the conversation.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(
          tester
              .widget<IconButton>(find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == 'Send message'))
              .onPressed,
          isNull);
      await tester.enterText(find.byType(TextField), 'Hello manager');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(sends, 1);
      expect(find.text('Hello manager'), findsOneWidget);
      expect(find.textContaining('Your draft is preserved'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              expect(
                  request.headers['Authorization'], 'Bearer existing-session');
              if (request.method == 'POST') {
                sends++;
                expect(jsonDecode(request.body)['text'], 'Hello manager');
                return http.Response('{"error":"Unavailable"}', 503);
              }
              return http.Response('{"messages":[],"hasMore":false}', 200);
            }));
    state.dispose();
  });
}
