import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/core/bootstrap.dart';
import 'package:idle_game/core/game_clock.dart';
import 'package:idle_game/core/home_screen.dart';
import 'package:idle_game/core/settings.dart';
import 'package:idle_game/main.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/providers/ios_launch_provider.dart';
import 'package:idle_game/ui/screens/in_app_browser_hint.dart';
import 'package:idle_game/ui/widgets/panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/moments.dart';
import 'support/real_fonts.dart';

/// Встроенный браузер мессенджера: «открой игру в Safari».
///
/// Ссылку из Telegram или ВКонтакте открывают внутри приложения. Там нет
/// «На экран Домой», буфер обмена урезан, а хранилище своё: сыгранное там в
/// Safari само не переедет. Игрок об этом не знает и решает, что игра
/// сломана. Плашка говорит, как уйти в настоящий браузер, — во встроенном и
/// только в нём.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Настоящие шрифты: «влезает ли в 320×640» зависит от ширины букв.
  setUpAll(loadRealFonts);

  group('Кто встроенный', () {
    const iphoneSafari = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac '
        'OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 '
        'Mobile/15E148 Safari/604.1';
    const iphoneChrome = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac '
        'OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) '
        'CriOS/138.0.7204.119 Mobile/15E148 Safari/604.1';
    const iphoneFirefox = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac '
        'OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/141.0 '
        'Mobile/15E148 Safari/605.1.15';
    // WKWebView внутри приложения — без «Safari/». Так же выглядит и
    // иконка с экрана «Домой»; её отличает standalone.
    const iphoneWebView = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac '
        'OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';
    const iphoneFacebook = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac '
        'OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 '
        '[FBAN/FBIOS;FBAV/520.0.0.38.101;FBBV/750000000;FBDV/iPhone16,2]';
    // Притворяется Safari целиком, но подписывается.
    const iphoneTelegram = '$iphoneSafari Telegram 11.14';
    const macSafari = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 '
        'Safari/605.1.15';
    const androidChrome = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Mobile '
        'Safari/537.36';
    const androidWebView = 'Mozilla/5.0 (Linux; Android 14; Pixel 8; wv) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
        'Chrome/138.0.0.0 Mobile Safari/537.36';
    const androidInstagram = '$androidChrome Instagram 390.0.0.43.81 Android';
    const windowsChrome = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 '
        'Safari/537.36';

    InAppBrowser of(
      String ua, {
      int touches = 5,
      bool standalone = false,
      bool bridge = false,
    }) =>
        inAppBrowserOf(
          userAgent: ua,
          maxTouchPoints: touches,
          standalone: standalone,
          messengerBridge: bridge,
        );

    test('настоящие браузеры — не встроенные', () {
      for (final ua in [iphoneSafari, iphoneChrome, iphoneFirefox, androidChrome]) {
        expect(of(ua), InAppBrowser.none, reason: ua);
      }
      expect(of(macSafari, touches: 5), InAppBrowser.none,
          reason: 'iPad, который выдаёт себя за Мак, в Safari');
    });

    test('встроенные на iPhone — уходить в Safari', () {
      expect(of(iphoneWebView), InAppBrowser.ios);
      expect(of(iphoneFacebook), InAppBrowser.ios);
      expect(of(iphoneTelegram), InAppBrowser.ios);
      expect(of(iphoneSafari, bridge: true), InAppBrowser.ios,
          reason: 'Telegram, неотличимый от Safari, узнаётся по мосту');
    });

    test('встроенные на Android — уходить в Chrome', () {
      expect(of(androidWebView), InAppBrowser.android);
      expect(of(androidInstagram), InAppBrowser.android);
      expect(of(androidChrome, bridge: true), InAppBrowser.android);
    });

    test('с экрана «Домой» и установленное — не встроенные', () {
      expect(of(iphoneWebView, standalone: true), InAppBrowser.none,
          reason: 'иконка на iPhone тоже без «Safari/»');
      expect(of(androidChrome, standalone: true), InAppBrowser.none);
    });

    test('компьютер — никогда, даже со словом приложения', () {
      expect(of(windowsChrome, touches: 10), InAppBrowser.none);
      expect(of('$windowsChrome Telegram'), InAppBrowser.none);
      expect(of(macSafari, touches: 0, bridge: true), InAppBrowser.none);
    });

    test('во встроенном — не «на экран Домой»: её там нет', () {
      final settings = MemorySettingsStore();
      expect(shouldSuggestHomeScreen(IosLaunch.browserTab, settings), isTrue);
      expect(
        shouldSuggestHomeScreen(IosLaunch.browserTab, settings,
            inApp: InAppBrowser.ios),
        isFalse,
      );
    });
  });

  group('При запуске', () {
    final clock = GameClock(now: () => quietMoment);

    Future<void> start(
      WidgetTester tester, {
      required InAppBrowser inApp,
      IosLaunch launch = IosLaunch.other,
      Size size = const Size(390, 844),
    }) async {
      final boot = await bootstrapGame(clock: clock);
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...bootOverrides(boot),
          timeProvider.overrideWithValue(() => quietMoment),
          clockProvider.overrideWithValue(clock),
          iosLaunchProvider.overrideWithValue(launch),
          inAppBrowserProvider.overrideWithValue(inApp),
        ],
        child: VityaApp(boot: boot),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> stay(WidgetTester tester) async {
      await tester.tap(find.text('Играть здесь'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> quit(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }

    testWidgets('в мессенджере на iPhone — на каждом запуске, вместо «Домой»',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      for (var run = 0; run < 2; run++) {
        await start(tester,
            inApp: InAppBrowser.ios, launch: IosLaunch.browserTab);
        expect(find.byType(InAppBrowserHint), findsOneWidget,
            reason: 'запуск ${run + 1}: здесь игре не место каждый раз');
        expect(find.textContaining('Safari'), findsWidgets);
        await stay(tester);
        expect(find.byType(AlertDialog), findsNothing,
            reason: '«на экран Домой» во встроенном браузере не поставить');
        await quit(tester);
      }

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('vitya_setting_${SettingsKeys.homeScreenHint}'),
          isNull,
          reason: 'в Safari подсказка «на экран Домой» ещё понадобится');
    });

    testWidgets('в мессенджере на Android — зовёт в Chrome', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await start(tester, inApp: InAppBrowser.android);
      expect(find.byType(InAppBrowserHint), findsOneWidget);
      expect(find.textContaining('Chrome'), findsWidgets);
      expect(find.textContaining('Safari'), findsNothing);
    });

    testWidgets('в обычном браузере — никогда', (tester) async {
      for (final launch in IosLaunch.values) {
        SharedPreferences.setMockInitialValues({});
        await start(tester, inApp: InAppBrowser.none, launch: launch);
        expect(find.byType(InAppBrowserHint), findsNothing, reason: '$launch');
        await quit(tester);
      }
    });

    testWidgets('влезает в 320×640: обе кнопки на виду', (tester) async {
      const narrow = Size(320, 640);
      SharedPreferences.setMockInitialValues({});
      await start(tester, inApp: InAppBrowser.ios, size: narrow);

      expect(tester.takeException(), isNull);
      final screen = Offset.zero & narrow;
      for (final button in [
        find.descendant(
          of: find.byType(InAppBrowserHint),
          matching: find.byType(WideButton),
        ),
        find.text('Играть здесь'),
      ]) {
        final rect = tester.getRect(button);
        expect(screen.intersect(rect), rect, reason: '$rect за краем 320×640');
      }
    });
  });

  group('Ссылка', () {
    Future<void> show(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showInAppBrowserHint(
                  context,
                  where: InAppBrowser.ios,
                  link: Uri.parse('https://mercurrial.github.io/vitya-v-dele/'),
                ),
                child: const Text('открыть'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
    }

    test('без меток мессенджера и якоря', () {
      expect(
        gameLink(Uri.parse(
            'https://mercurrial.github.io/vitya-v-dele/?fbclid=abc&utm_source=tg#x')),
        Uri.parse('https://mercurrial.github.io/vitya-v-dele/'),
      );
      expect(
        gameLink(Uri.parse('http://192.168.1.5:8770/?t=1790280000000')),
        Uri.parse('http://192.168.1.5:8770/'),
        reason: 'проверка с телефона по Wi-Fi — порт на месте',
      );
    });

    testWidgets('копируется; не дали буфер — адрес на экране', (tester) async {
      final written = <String>[];
      var deny = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method != 'Clipboard.setData') return null;
          if (deny) throw PlatformException(code: 'NotAllowedError');
          written.add((call.arguments as Map)['text'] as String);
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await show(tester);
      expect(find.text('mercurrial.github.io/vitya-v-dele'), findsOneWidget,
          reason: 'адрес должно быть можно набрать руками');

      await tester.tap(find.text('СКОПИРОВАТЬ ССЫЛКУ'));
      await tester.pump();
      expect(written, ['https://mercurrial.github.io/vitya-v-dele/']);
      expect(find.textContaining('скопирована'), findsOneWidget);

      deny = true;
      await tester.tap(find.text('СКОПИРОВАТЬ ССЫЛКУ'));
      await tester.pump();
      expect(find.textContaining('скопирована'), findsNothing);
      expect(find.textContaining('не дал'), findsOneWidget,
          reason: 'отказ буфера прошёл молча');
    });
  });
}
