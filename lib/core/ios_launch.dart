/// Как открыта игра — спросить браузер: вкладка ли на iOS и не встроенный
/// ли браузер мессенджера.
///
/// Условный импорт, как у `page_reload.dart`: вне веба браузера нет, и ответ
/// всегда [IosLaunch.other] и [InAppBrowser.none]. Сами правила — в
/// `home_screen.dart`, отдельно от браузера, чтобы их проверял тест.
library;

export 'ios_launch_stub.dart'
    if (dart.library.js_interop) 'ios_launch_web.dart';
