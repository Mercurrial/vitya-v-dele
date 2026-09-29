import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/vitya_quotes.dart';
import '../../core/settings.dart';
import '../../providers/settings_provider.dart';
import '../pixel/goal_icons.dart';
import '../pixel/pixel_sprite.dart';
import '../pixel/still_sprites.dart';
import '../theme/garage.dart';

/// Вид плашки, и у каждого — свой выключатель в настройках.
///
/// Вид был строкой, пока плашку нельзя было выключить. Первый тестер попросил
/// убрать «СОРТ ПОДНЯЛСЯ», и строка стала перечислением: ключ настройки и
/// умолчание — обязательные поля, а настройки перебирают [values]. Плашку,
/// добавленную через месяц, без выключателя просто не собрать.
enum ToastKind {
  // Сорт и так виден на шкале, а плашка закрывает гараж: по умолчанию
  // выключена (docs/DECISIONS.md, 29.09.2026).
  gradeUp('СОРТ ПОДНЯЛСЯ', SettingsKeys.toastGradeUp,
      note: 'новый сорт и его цена', onByDefault: false),
  goal('ЦЕЛЬ ВЗЯТА', SettingsKeys.toastGoal, note: 'цель и что она открыла'),
  hangover('ПОХМЕЛЬЕ', SettingsKeys.toastHangover, note: 'мудрость и новые вехи'),
  portal('ПОРТАЛ ОТКРЫТ', SettingsKeys.toastPortal, note: 'один раз за игру');

  /// Мелкая строка-ярлык на самой плашке.
  final String label;

  /// Ключ выключателя в [SettingsStore].
  final String setting;

  /// Подпись к выключателю в настройках.
  final String note;

  /// Показывать ли плашку, пока игрок не выбрал сам.
  final bool onByDefault;

  const ToastKind(
    this.label,
    this.setting, {
    required this.note,
    this.onByDefault = true,
  });

  /// Название выключателя — ярлык плашки строчными. Выводится из ярлыка, а
  /// не пишется второй раз: в настройках игрок должен узнать ровно то, что
  /// видел на экране.
  String get title => label[0] + label.substring(1).toLowerCase();
}

/// Какие плашки показывать. Читается из настроек один раз при создании,
/// как звук и вибрация.
class ToastSwitches extends Notifier<Set<ToastKind>> {
  @override
  Set<ToastKind> build() {
    final store = ref.read(settingsStoreProvider);
    return {
      for (final kind in ToastKind.values)
        if (settingOn(store.read(kind.setting), byDefault: kind.onByDefault))
          kind,
    };
  }

  void set(ToastKind kind, bool on) {
    state = on ? {...state, kind} : state.difference({kind});
    ref.read(settingsStoreProvider).write(kind.setting, settingValue(on));
  }
}

final toastSwitchesProvider =
    NotifierProvider<ToastSwitches, Set<ToastKind>>(ToastSwitches.new);

/// Что показать во всплывающей плашке.
class ToastMessage {
  final ToastKind kind;

  /// Крупная строка: название сорта, имя покупателя.
  final String title;

  /// Сухая подпись с числами.
  final String note;

  /// Реплика Вити — здесь шутка уместна, потому что видят её редко.
  final String voice;

  /// Цель, значок которой показать вместо галочки. `null` — галочка.
  final String? goalId;

  const ToastMessage({
    required this.kind,
    required this.title,
    this.note = '',
    this.voice = '',
    this.goalId,
  });
}

/// Очередь плашек. Живёт в провайдере, чтобы её мог наполнять кто угодно —
/// движок через провайдер игры, интерфейс напрямую.
class ToastQueue extends Notifier<ToastMessage?> {
  Timer? _timer;
  final VityaVoice _voice = VityaVoice();

  @override
  ToastMessage? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  /// Показать плашку с репликой Вити под событие — если игрок её не выключил.
  void show({
    required ToastKind kind,
    required String title,
    String note = '',
    VityaEvent? event,
    String? goalId,
  }) {
    // Выключатель смотрится здесь, а не там, где плашку вызывают, — по той
    // же причине, что звук смотрит только Feedback: мест вызова четыре, и
    // пятое, дописанное через месяц, про настройку не вспомнит. Выходим до
    // реплики и таймера: скрытая плашка не должна съесть шутку Вити и
    // оборвать ту, что уже на экране.
    if (!ref.read(toastSwitchesProvider).contains(kind)) return;
    state = ToastMessage(
      kind: kind,
      title: title,
      note: note,
      voice: event == null ? '' : _voice.line(event),
      goalId: goalId,
    );
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2800), () => state = null);
  }
}

final toastProvider = NotifierProvider<ToastQueue, ToastMessage?>(ToastQueue.new);

/// Сама плашка. Появляется сверху, уезжает сама.
class VityaToast extends ConsumerWidget {
  const VityaToast({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(toastProvider);
    final reduced = MediaQuery.of(context).disableAnimations;

    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduced ? 0 : 220),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.3), end: Offset.zero)
              .animate(animation),
          child: child,
        ),
      ),
      child: message == null
          ? const SizedBox.shrink()
          : _Card(key: ValueKey(message), message: message),
    );
  }
}

class _Card extends StatelessWidget {
  final ToastMessage message;
  const _Card({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: GS.s3),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          color: GColors.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GColors.amber),
          boxShadow: const [
            BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 12)),
            BoxShadow(color: GColors.amberGlow, blurRadius: 22),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [GColors.copperDim, Color(0xFF5E3820)],
                ),
                border: Border.all(color: GColors.amber.withOpacity(0.6)),
              ),
              child: message.goalId != null
                  ? PixelImage(
                      sprite: goalIcon(message.goalId!),
                      size: 32,
                      palette: kStillPalette,
                    )
                  : Text(
                      '✓',
                      style: GType.num(
                        size: 15,
                        weight: FontWeight.w700,
                        color: GColors.lamp,
                      ),
                    ),
            ),
            const SizedBox(width: GS.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.kind.label,
                    style: GType.label().copyWith(color: GColors.amber, fontSize: 9),
                  ),
                  Text(
                    message.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.ui(size: 14, weight: FontWeight.w600),
                  ),
                  if (message.note.isNotEmpty)
                    Text(
                      message.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GType.num(size: 11, color: GColors.textMid),
                    ),
                  if (message.voice.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      message.voice,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GType.quote().copyWith(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
