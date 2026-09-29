/// Веб: спросить браузер, где он. См. `ios_launch.dart`.
///
/// Через `dart:js_interop` по той же причине, что и `page_reload_web.dart`.
library;

import 'dart:js_interop';

import 'home_screen.dart';

IosLaunch detectIosLaunch() => iosLaunchOf(
      userAgent: _navigator.userAgent,
      maxTouchPoints: _navigator.maxTouchPoints ?? 0,
      standalone: _standalone(),
    );

InAppBrowser detectInAppBrowser() => inAppBrowserOf(
      userAgent: _navigator.userAgent,
      maxTouchPoints: _navigator.maxTouchPoints ?? 0,
      standalone: _standalone(),
      // Мост к приложению Telegram кладёт в свои окна: на iOS —
      // TelegramWebviewProxy, на Android — TelegramWebview. Он есть, даже
      // когда user agent слово в слово как у Safari.
      messengerBridge: _telegramProxy != null || _telegramWebview != null,
    );

/// `navigator.standalone` — только у iOS, и только он там надёжен: так
/// WebKit сам отвечает «открыто с экрана Домой». Медиазапрос — стандартный
/// способ на случай, если старое свойство когда-нибудь уберут, и он же
/// отвечает за установленное приложение на Android.
bool _standalone() =>
    _navigator.standalone == true ||
    _matchMedia('(display-mode: standalone)').matches;

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  external String get userAgent;
  external int? get maxTouchPoints;
  external bool? get standalone;
}

@JS('matchMedia')
external _MediaQueryList _matchMedia(String query);

extension type _MediaQueryList._(JSObject _) implements JSObject {
  external bool get matches;
}

@JS('TelegramWebviewProxy')
external JSAny? get _telegramProxy;

@JS('TelegramWebview')
external JSAny? get _telegramWebview;
