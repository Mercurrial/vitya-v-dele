import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/core/save.dart';
import 'package:idle_game/core/save_code.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/theme/garage.dart';
import 'package:idle_game/ui/widgets/transfer_progress.dart';

/// Перенос прогресса в любом браузере — и там, где буфер обмена не дают.
///
/// Так бывает во встроенных браузерах мессенджеров, во вкладке без фокуса,
/// при запрете в настройках, на странице не по https, а Firefox не даёт
/// читать буфер вовсе. В 1.0.0 отказ в чтении и не код в буфере вели в
/// тупик: тестер на iPhone так и не перенёс гараж. Проверяется, что код
/// уносится и приносится при любом ответе браузера, а гараж меняется только
/// после «Заменить».
void main() {
  late ProviderContainer game;

  // Контейнером владеет дерево виджетов, а не тест: у игры тикает таймер, и
  // закрыться он обязан вместе с экраном, а не после проверки таймеров.
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveServiceProvider
              .overrideWithValue(SaveService(storage: MemorySaveStorage())),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, fontFamily: GType.uiFamily),
          home: const Scaffold(
            body: SingleChildScrollView(child: TransferProgress()),
          ),
        ),
      ),
    );
    game = ProviderScope.containerOf(tester.element(find.byType(TransferProgress)));
  }

  double money() => game.read(gameProvider).resources.money;

  void setMoney(double value) {
    final notifier = game.read(gameProvider.notifier);
    notifier.state = notifier.state.copyWith(
      resources: notifier.state.resources.copyWith(money: value),
    );
  }

  /// Код «с другого устройства»: там в кассе 777.
  String codeFromElsewhere() {
    final other = ProviderContainer(
      overrides: [
        saveServiceProvider
            .overrideWithValue(SaveService(storage: MemorySaveStorage())),
      ],
    );
    final notifier = other.read(gameProvider.notifier);
    notifier.state = notifier.state.copyWith(
      resources: notifier.state.resources.copyWith(money: 777),
    );
    final code = notifier.exportCode();
    other.dispose();
    return code;
  }

  /// Браузер с буфером обмена: [clip] — что в нём лежит; `null` — браузер
  /// отказывает и в записи, и в чтении. Что записали — в [written].
  List<String> clipboard(WidgetTester tester, {String? clip, bool deny = false}) {
    final written = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            if (deny) throw PlatformException(code: 'NotAllowedError');
            written.add((call.arguments as Map)['text'] as String);
            return null;
          case 'Clipboard.getData':
            if (deny) throw PlatformException(code: 'NotAllowedError');
            return clip == null ? null : <String, Object>{'text': clip};
          // Поля ввода сами спрашивают, есть ли что вставить, — это не отказ.
          case 'Clipboard.hasStrings':
            return <String, Object>{'value': false};
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    return written;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  group('Скопировать', () {
    testWidgets('буфер дали — код в нём и принимается обратно', (tester) async {
      await open(tester);
      final written = clipboard(tester);

      await tap(tester, 'СКОПИРОВАТЬ');

      expect(written, hasLength(1));
      expect(decodeSaveCode(written.single).isOk, isTrue);
      expect(find.byType(AlertDialog), findsNothing,
          reason: 'буфер сработал — окно не нужно');
    });

    testWidgets('не дали — код в поле целиком, копировать руками',
        (tester) async {
      await open(tester);
      clipboard(tester, deny: true);

      await tap(tester, 'СКОПИРОВАТЬ');

      // Поле, а не SelectableText: у того копирование шло бы через тот же
      // буфер, который браузер только что не дал.
      final field = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      expect(field, findsOneWidget, reason: 'отказ буфера снова прошёл молча');
      final shown = tester.widget<TextField>(field);
      expect(shown.readOnly, isTrue, reason: 'код в окне можно испортить');
      expect(decodeSaveCode(shown.controller!.text).isOk, isTrue,
          reason: 'показанный код не принимается обратно');
    });
  });

  group('Вставить', () {
    testWidgets('код в буфере — одно «Заменить», без поля', (tester) async {
      await open(tester);
      clipboard(tester, clip: codeFromElsewhere());

      await tap(tester, 'ВСТАВИТЬ');
      expect(find.byType(TextField), findsNothing);
      expect(money(), isNot(closeTo(777, 1e-6)),
          reason: 'гараж сменился без вопроса');

      await tap(tester, 'Заменить');
      expect(money(), closeTo(777, 1e-6));
    });

    // Каждый отказ ведёт в поле — и с объяснением, что случилось.
    for (final (what, clip, deny) in [
      ('браузер не дал буфер', null, true),
      ('буфер пуст', '', false),
      ('в буфере не код', 'https://mercurrial.github.io/vitya-v-dele/', false),
      ('в буфере обрезанный код', 'VITYA2.eyJ2ZXJzaW9uIjox', false),
    ]) {
      testWidgets('$what — код принимается из поля', (tester) async {
        final code = codeFromElsewhere();
        await open(tester);
        clipboard(tester, clip: clip, deny: deny);

        await tap(tester, 'ВСТАВИТЬ');
        final field = find.byType(TextField);
        expect(field, findsOneWidget, reason: 'некуда вставить код руками');

        await tester.enterText(field, code);
        await tap(tester, 'Принять');
        expect(money(), isNot(closeTo(777, 1e-6)),
            reason: 'гараж сменился без вопроса');
        await tap(tester, 'Заменить');

        expect(money(), closeTo(777, 1e-6));
      });
    }

    testWidgets('не тот код в поле — окно не закрывается и объясняет',
        (tester) async {
      // Код тестовой сборки (до 1.0.0): версия кода 1, сейв v5 внутри.
      final testCode = encodeSaveCode('{"version": 5, "money": 5e6}')
          .replaceFirst('$kSaveCodePrefix$kSaveCodeVersion', '${kSaveCodePrefix}1');

      await open(tester);
      clipboard(tester, deny: true);
      setMoney(555);

      await tap(tester, 'ВСТАВИТЬ');
      await tester.enterText(find.byType(TextField), testCode);
      await tap(tester, 'Принять');

      expect(money(), 555);
      expect(
        find.text(
            const SaveCodeResult.failed(SaveCodeError.fromTestVersion).message),
        findsOneWidget,
        reason: 'игрок обязан узнать, почему код не принят',
      );
      expect(find.byType(TextField), findsOneWidget,
          reason: 'поле закрылось на ошибке — вставлять заново с нуля');

      // Исправил — принимается из того же окна.
      await tester.enterText(find.byType(TextField), codeFromElsewhere());
      await tap(tester, 'Принять');
      await tap(tester, 'Заменить');
      expect(money(), closeTo(777, 1e-6));
    });

    testWidgets('передумал в поле — гараж не тронут', (tester) async {
      await open(tester);
      clipboard(tester, deny: true);
      setMoney(555);

      await tap(tester, 'ВСТАВИТЬ');
      await tap(tester, 'Отмена');

      expect(money(), 555);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('передумал заменять — гараж не тронут', (tester) async {
      await open(tester);
      clipboard(tester, clip: codeFromElsewhere());
      setMoney(555);

      await tap(tester, 'ВСТАВИТЬ');
      await tap(tester, 'Отмена');

      expect(money(), 555);
    });
  });
}
