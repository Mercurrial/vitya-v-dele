/// Подсказка «поставь на экран Домой» — кому и когда её показывать.
///
/// iPhone получает игру веб-версией (docs/DECISIONS.md, «Платформа и
/// раздача»), а у iOS две особенности, о которых игрок узнаёт, когда уже
/// поздно:
///
/// * у иконки на экране «Домой» своё хранилище, отдельное от Safari. Кто
///   начал во вкладке, а потом поставил иконку, откроет пустой гараж. WebKit
///   делает так намеренно: webkit.org/tracking-prevention, баг 181849 на
///   bugs.webkit.org закрывать не собираются;
/// * во вкладке Safari всё, что сайт записал скриптом, — сейв лежит именно
///   там — стирается после 7 дней пользования Safari без захода на сайт
///   (ITP). Иконку на экране «Домой» это не касается.
///
/// Поэтому сказать надо до того, как игрок вложился в гараж во вкладке, и
/// один раз: уведомлений в игре минимум.
///
/// Во встроенном браузере мессенджера ставить некуда — там игрок каждый
/// запуск видит, как уйти в Safari или Chrome ([InAppBrowser]).
///
/// Правило — здесь, в чистом Dart, а браузер только отвечает на вопросы
/// (`ios_launch.dart`). Так оно проверяется тестом на строках user agent,
/// без браузера.
library;

import 'settings.dart';

/// Как открыта игра.
enum IosLaunch {
  /// Не iOS или не веб. Хранилище не делится, подсказка не нужна.
  other,

  /// Вкладка браузера на iPhone или iPad — Safari или встроенный браузер
  /// мессенджера. Хранилище у обоих не то, что у иконки. Встроенный
  /// отличает [inAppBrowserOf], и то не всякий.
  browserTab,

  /// Приложение с экрана «Домой».
  homeScreen,
}

/// Как открыта игра — по тому, что браузер говорит о себе.
///
/// iPad с iPadOS 13 по умолчанию представляется Маком. Отличает его только
/// сенсорный экран: у Маков его нет, и [maxTouchPoints] там 0.
/// [standalone] — открыто ли как приложение (`navigator.standalone`).
IosLaunch iosLaunchOf({
  required String userAgent,
  required int maxTouchPoints,
  required bool standalone,
}) {
  if (!_isIos(userAgent, maxTouchPoints)) return IosLaunch.other;
  return standalone ? IosLaunch.homeScreen : IosLaunch.browserTab;
}

bool _isIos(String userAgent, int maxTouchPoints) =>
    _iosDevice.hasMatch(userAgent) ||
    (userAgent.contains('Macintosh') && maxTouchPoints > 1);

final _iosDevice = RegExp('iPhone|iPad|iPod');

/// Игра открыта во встроенном браузере приложения — мессенджера, соцсети, —
/// и куда из него уходить.
///
/// Ссылку, присланную в Telegram или ВКонтакте, открывают тут же, внутри
/// приложения. Там нет «На экран Домой», буфер обмена урезан, а хранилище
/// своё — отдельно от Safari и Chrome: сыгранное здесь в браузер само не
/// переедет. Игрок этого не знает и винит игру.
enum InAppBrowser {
  /// Обычный браузер, приложение с экрана «Домой» или не телефон.
  none,

  /// Внутри приложения на iPhone или iPad — уходить в Safari.
  ios,

  /// Внутри приложения на Android — уходить в Chrome.
  android,
}

/// Встроенный ли браузер — по тому, что он говорит о себе.
///
/// Узнаётся не всякий. Настоящие браузеры на iOS — Safari, Chrome, Firefox —
/// все пишут в user agent «Safari/», а встроенный на WKWebView обычно нет. На
/// Android встроенный помечен «; wv)». Кто притворяется Safari целиком —
/// Telegram на iOS так делал, — ловится по своему слову или по мосту, который
/// Telegram кладёт в страницу ([messengerBridge]). Кого не узнали, тот видит
/// обычную подсказку «на экран Домой», и в ней сказано, что делать, если
/// пункта нет.
InAppBrowser inAppBrowserOf({
  required String userAgent,
  required int maxTouchPoints,
  required bool standalone,
  bool messengerBridge = false,
}) {
  // С экрана «Домой» уже поставили — уходить некуда.
  if (standalone) return InAppBrowser.none;
  final ios = _isIos(userAgent, maxTouchPoints);
  final android = !ios && userAgent.contains('Android');
  if (!ios && !android) return InAppBrowser.none;
  final inApp = messengerBridge ||
      _inAppToken.hasMatch(userAgent) ||
      (ios ? !userAgent.contains('Safari/') : userAgent.contains('; wv)'));
  if (!inApp) return InAppBrowser.none;
  return ios ? InAppBrowser.ios : InAppBrowser.android;
}

/// Слова, которыми встроенные браузеры приложений подписывают user agent.
final _inAppToken = RegExp(
  r'Telegram|WhatsApp|FBAN|FBAV|FB_IAB|Instagram|\bLine/|MicroMessenger|'
  r'KAKAOTALK|Snapchat|musical_ly|BytedanceWebview',
);

/// Метка закрытой подсказки. Другая метка — подсказка покажется снова.
///
/// Первая, «seen», — от 1.0.0: там путь был «Поделиться», затем «На экран
/// Домой». На iOS 26 «Поделиться» спрятали в меню за тремя точками, и тестер
/// на iPhone не смог поставить игру по этому пути. Кто закрыл ту подсказку,
/// увидит исправленную ещё раз.
const _hintSeen = 'seen-2';

/// Показать ли подсказку на этом запуске.
///
/// Во встроенном браузере — никогда: «На экран Домой» там нет, и вместо неё
/// показывается «открой в Safari» ([InAppBrowser]).
bool shouldSuggestHomeScreen(
  IosLaunch launch,
  SettingsStore settings, {
  InAppBrowser inApp = InAppBrowser.none,
}) =>
    launch == IosLaunch.browserTab &&
    inApp == InAppBrowser.none &&
    settings.read(SettingsKeys.homeScreenHint) != _hintSeen;

/// Подсказку закрыли — больше не показывать.
Future<void> markHomeScreenHintSeen(SettingsStore settings) =>
    settings.write(SettingsKeys.homeScreenHint, _hintSeen);
