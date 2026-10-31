import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shakespeare/data/asechka_service.dart';
import 'package:shakespeare/domain/models.dart';
import 'package:shakespeare/ui/asechka_button.dart';
import 'package:shakespeare/ui/strings.dart';

const _strings = Strings(QuoteLanguage.english);

class _PublishRequest {
  _PublishRequest(this.quote);

  final Quote quote;
  final result = Completer<void>();
}

class _SignInRequest {
  _SignInRequest(this.code);

  final String code;
  final result = Completer<void>();
}

class _FakeAsechkaService extends AsechkaService {
  final publishes = <_PublishRequest>[];
  final signIns = <_SignInRequest>[];
  final posted = <String>{};

  @override
  Future<bool> isPosted(Quote quote) async => posted.contains(quote.id);

  @override
  Future<void> publish(Quote quote) async {
    final request = _PublishRequest(quote);
    publishes.add(request);
    await request.result.future;
    posted.add(quote.id);
  }

  @override
  Future<void> signIn(String code) {
    final request = _SignInRequest(code);
    signIns.add(request);
    return request.result.future;
  }
}

Quote _quote(String id) => Quote(
  id: id,
  text: 'The words of $id.',
  settings: const QuoteSettings(),
  createdAt: DateTime(2026),
);

Finder get _add => find.byKey(const Key('add-to-asechka'));
Finder get _code => find.byKey(const Key('asechka-code'));
Finder get _connect => find.byKey(const Key('asechka-connect'));

TextButton _addButton(WidgetTester tester) => tester.widget<TextButton>(_add);
TextField _codeField(WidgetTester tester) => tester.widget<TextField>(_code);

Future<ValueNotifier<Quote?>> _mount(
  WidgetTester tester,
  _FakeAsechkaService service,
  Quote quote,
) async {
  final selected = ValueNotifier<Quote?>(quote);
  addTearDown(() {
    selected.dispose();
    service.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: ValueListenableBuilder<Quote?>(
            valueListenable: selected,
            builder: (context, quote, _) => AsechkaButton(
              quote: quote,
              strings: _strings,
              service: service,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return selected;
}

Future<void> _requireSignIn(
  WidgetTester tester,
  _FakeAsechkaService service,
) async {
  await tester.tap(_add);
  await tester.pump();
  service.publishes.last.result.completeError(
    const AsechkaException('Sign in to Asechka.', needsSignIn: true),
  );
  await tester.pump();
  // The underlying publish indicator keeps ticking while the dialog is open.
  await tester.pump(const Duration(milliseconds: 350));
  expect(find.byType(AlertDialog), findsOneWidget);
  expect(_code, findsOneWidget);
}

void main() {
  testWidgets(
    'one tap publishes and duplicate taps stay disabled until added',
    (tester) async {
      final service = _FakeAsechkaService();
      final quote = _quote('first');
      await _mount(tester, service, quote);

      await tester.tap(_add);
      await tester.pump();
      expect(service.publishes, hasLength(1));
      expect(service.publishes.single.quote, same(quote));
      expect(service.signIns, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(_addButton(tester).onPressed, isNull);
      expect(find.text(_strings.t('asechkaAdded')), findsNothing);

      await tester.tap(_add);
      await tester.pump();
      expect(service.publishes, hasLength(1));
      service.publishes.single.result.complete();
      await tester.pumpAndSettle();
      expect(find.text(_strings.t('asechkaAdded')), findsOneWidget);
      expect(_addButton(tester).onPressed, isNull);
      await tester.tap(_add);
      await tester.pump();
      expect(service.publishes, hasLength(1));
    },
  );

  testWidgets(
    'sign-in clears secrets and errors and resumes only the tapped quote',
    (tester) async {
      final service = _FakeAsechkaService();
      final first = _quote('first');
      final selected = await _mount(tester, service, first);
      await _requireSignIn(tester, service);
      expect(service.signIns, isEmpty);
      expect(_codeField(tester).obscureText, isTrue);

      await tester.enterText(_code, 'incorrect private code');
      await tester.tap(_connect);
      await tester.pump();
      expect(service.signIns.single.code, 'incorrect private code');
      expect(_codeField(tester).controller!.text, isEmpty);
      service.signIns.single.result.completeError(
        const AsechkaException('Incorrect code.'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(_codeField(tester).decoration!.errorText, 'Incorrect code.');
      expect(service.publishes, hasLength(1));

      // Changing the displayed quote must not change what the login resumes.
      selected.value = _quote('second');
      await tester.pump();
      await tester.enterText(_code, 'correct private code');
      await tester.tap(_connect);
      await tester.pump();
      expect(service.signIns, hasLength(2));
      expect(service.signIns.last.code, 'correct private code');
      expect(_codeField(tester).controller!.text, isEmpty);
      expect(_codeField(tester).decoration!.errorText, isNull);
      expect(tester.widget<TextButton>(_connect).onPressed, isNull);

      service.signIns.last.result.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(AlertDialog), findsNothing);
      expect(service.publishes.map((request) => request.quote.id), [
        'first',
        'first',
      ]);
      service.publishes.last.result.complete();
      await tester.pumpAndSettle();
      expect(find.text(_strings.t('asechkaAdded')), findsNothing);
      expect(find.text(_strings.t('asechkaAdd')), findsOneWidget);
      expect(_addButton(tester).onPressed, isNotNull);
      expect(service.posted, {'first'});
    },
  );

  testWidgets(
    'cancelled sign-in never resumes publish or retains the entered code',
    (tester) async {
      final service = _FakeAsechkaService();
      await _mount(tester, service, _quote('first'));
      await _requireSignIn(tester, service);
      await tester.enterText(_code, 'abandoned private code');
      await tester.tap(_connect);
      await tester.pump();
      expect(service.signIns, hasLength(1));

      await tester.tap(find.widgetWithText(TextButton, _strings.t('cancel')));
      await tester.pumpAndSettle();
      service.signIns.single.result.complete();
      await tester.pumpAndSettle();
      expect(service.publishes, hasLength(1));
      expect(service.posted, isEmpty);
      expect(find.text(_strings.t('asechkaAdded')), findsNothing);
      expect(_addButton(tester).onPressed, isNotNull);

      await _requireSignIn(tester, service);
      expect(_codeField(tester).controller!.text, isEmpty);
      expect(_codeField(tester).decoration!.errorText, isNull);
      await tester.enterText(_code, 'unsubmitted private code');
      await tester.tap(find.widgetWithText(TextButton, _strings.t('cancel')));
      await tester.pumpAndSettle();
      expect(service.signIns, hasLength(1));
      expect(service.publishes, hasLength(2));
      expect(find.byType(AlertDialog), findsNothing);
      expect(service.posted, isEmpty);
    },
  );

  testWidgets(
    'failed publish is retryable and old completion cannot mark a new quote',
    (tester) async {
      final service = _FakeAsechkaService();
      final selected = await _mount(tester, service, _quote('first'));
      await tester.tap(_add);
      await tester.pump();
      service.publishes.single.result.completeError(
        const AsechkaException('The website is offline.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('The website is offline.'), findsOneWidget);
      expect(find.text(_strings.t('asechkaAdded')), findsNothing);
      expect(_addButton(tester).onPressed, isNotNull);
      expect(service.posted, isEmpty);
      expect(service.signIns, isEmpty);

      await tester.tap(_add);
      await tester.pump();
      expect(service.publishes, hasLength(2));
      expect(service.publishes.last.quote.id, 'first');
      selected.value = _quote('second');
      await tester.pump();
      service.publishes.last.result.complete();
      await tester.pumpAndSettle();
      expect(find.text(_strings.t('asechkaAdded')), findsNothing);
      expect(find.text(_strings.t('asechkaAdd')), findsOneWidget);
      expect(_addButton(tester).onPressed, isNotNull);

      await tester.tap(_add);
      await tester.pump();
      expect(service.publishes, hasLength(3));
      expect(service.publishes.last.quote.id, 'second');
      service.publishes.last.result.complete();
      await tester.pumpAndSettle();
      expect(find.text(_strings.t('asechkaAdded')), findsOneWidget);
      expect(_addButton(tester).onPressed, isNull);
    },
  );
}
