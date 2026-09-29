/// Как открыта игра на iOS — в дереве провайдеров.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/home_screen.dart';
import '../core/ios_launch.dart';

/// Браузер спрашивается один раз. В тестах подменяется: так проверяется,
/// что подсказка «на экран Домой» показывается во вкладке на iPhone и
/// только там, — без браузера. Вне веба ответ всегда [IosLaunch.other].
final iosLaunchProvider = Provider<IosLaunch>((ref) => detectIosLaunch());

/// Встроенный ли это браузер мессенджера — так же, один раз. Вне веба —
/// всегда [InAppBrowser.none].
final inAppBrowserProvider =
    Provider<InAppBrowser>((ref) => detectInAppBrowser());
