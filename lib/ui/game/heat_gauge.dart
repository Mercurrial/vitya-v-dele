import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/sorts.dart';
import '../../core/formatters.dart';
import '../../providers/game_provider.dart';
import '../theme/content_colors.dart';
import '../theme/garage.dart';
import '../widgets/fill_bar.dart';
import '../widgets/trend_arrow.dart';
import '../widgets/tutorial_hint.dart';
import 'heat_controller.dart';

/// Пульт под гаражом: ЖАР, СЕРИЯ и СОРТ в одной карточке.
///
/// Три вещи, которые игрок делает пальцем, собраны в одно место, потому что
/// это одна механика: держишь жар в окне — растёт серия (она множит доход)
/// и растёт сорт (он поднимает цену). Раньше сорт жил наверху, у бака, а
/// серия — отдельной полоской над шкалой, и связь между ними приходилось
/// угадывать.
class HeatPanel extends StatelessWidget {
  final HeatController controller;

  const HeatPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Поля и зазоры тоньше прежних: пульт стоит между сценой и
      // магазином, и каждая его точка отнята у одного из них. На 320×640
      // сцене не хватало как раз этих точек: банка на полу выходила в
      // двадцать точек ростом.
      padding: const EdgeInsets.fromLTRB(GS.s3, 4, GS.s3, 5),
      decoration: BoxDecoration(
        color: GColors.surface1,
        borderRadius: BorderRadius.circular(GR.button),
        border: Border.all(color: GColors.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Заголовок — одна строка. Пока идёт обучение, в ней подсказка:
          // первые шаги про жар, и смотрят в этот момент именно сюда.
          SizedBox(
            height: 16,
            child: TutorialHint(
              heat: controller,
              fallback: _HeatHeader(controller: controller),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 18,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => CustomPaint(
                painter: _GaugePainter(
                  heat: controller.heat,
                  windowStart: controller.windowStart,
                  windowEnd: controller.windowEnd,
                  series: controller.series,
                  status: controller.status,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 3),
          _SortRow(controller: controller),
        ],
      ),
    );
  }
}

/// Как подробно подписать жар: чем уже пульт, тем короче.
enum _HeaderForm {
  /// «ЖАР  СЛАБО — зажми гараж».
  full,

  /// «СЛАБО — зажми гараж»: подпись шкалы уступает место первой.
  noLabel,

  /// «Зажми гараж» цветом состояния: остаётся только действие.
  hintOnly,
}

/// «ЖАР · В САМЫЙ РАЗ — так и держи          СЕРИЯ ×1.6»
///
/// Подсказка — главная подсказка управления, и обрезать её нельзя. Раньше
/// она обрывалась многоточием: на 320 точках с кнопкой ускорения рядом от
/// неё оставалось «СЛАБО — за…», на 390 в середине игры — «В САМЫЙ РАЗ —
/// так и …». Второй строкой её не спасти: пульт вырос бы на 14 точек, а их
/// на 320×640 отнимать не у кого — сцена и так едва вмещает банку.
///
/// Поэтому на узком пульте строка становится короче: сперва уходит подпись
/// «ЖАР» (шкалу и так видно), потом слово состояния — остаётся действие,
/// окрашенное в цвет состояния, как и шкала. Вид выбирается по самой длинной
/// подсказке, а не по текущей: иначе строка меняла бы вид на каждом переходе
/// жара.
class _HeatHeader extends StatelessWidget {
  final HeatController controller;
  const _HeatHeader({required this.controller});

  static TextStyle _stateStyle(Color color) =>
      GType.ui(size: 11, weight: FontWeight.w700, color: color, letterSpacing: 0.6);
  static TextStyle get _hintStyle => GType.ui(size: 11, color: GColors.textMid);
  static TextStyle _actionStyle(Color color) =>
      GType.ui(size: 11, weight: FontWeight.w600, color: color);

  static String _action(HeatCue cue) =>
      cue.hint[0].toUpperCase() + cue.hint.substring(1);

  /// Самый подробный вид, в котором любая подсказка влезает в [room].
  static _HeaderForm formFor(double room, TextScaler scaler) {
    double widthOf(List<(String, TextStyle)> parts) {
      final painter = TextPainter(
        text: TextSpan(children: [
          for (final (text, style) in parts) TextSpan(text: text, style: style),
        ]),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    double widest(List<(String, TextStyle)> Function(HeatCue) parts) =>
        HeatCue.values.map((c) => widthOf(parts(c))).reduce(math.max);

    final phrase = widest((c) => [
          (c.label, _stateStyle(GColors.textHi)),
          (' — ${c.hint}', _hintStyle),
        ]);
    if (widthOf([('ЖАР', GType.label())]) + GS.s2 + phrase <= room) {
      return _HeaderForm.full;
    }
    if (phrase <= room) return _HeaderForm.noLabel;
    return _HeaderForm.hintOnly;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        // Серию меряем по самой широкой: цифры у моноширинного шрифта одной
        // ширины, но «×3.0» против «×1» сдвигало бы выбор на ходу.
        final series = (TextPainter(
          text: TextSpan(children: [
            TextSpan(text: 'СЕРИЯ ', style: GType.label()),
            TextSpan(text: '×3.0', style: _seriesStyle(GColors.textLo)),
          ]),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout());
        final seriesW = series.width;
        series.dispose();
        final form = formFor(c.maxWidth - seriesW - GS.s2, scaler);

        return Row(
          children: [
            if (form == _HeaderForm.full) ...[
              Text('ЖАР', style: GType.label()),
              const SizedBox(width: GS.s2),
            ],
            Expanded(
              // Подписи меняются раз в несколько секунд — подписываемся на
              // статус, а не на каждый кадр контроллера.
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  controller.statusNotifier,
                  controller.stokingNotifier,
                ]),
                builder: (context, _) {
                  final cue = controller.cue;
                  final accent = heatAccent(controller.status);
                  return Text.rich(
                    form == _HeaderForm.hintOnly
                        ? TextSpan(text: _action(cue), style: _actionStyle(accent))
                        : TextSpan(children: [
                            TextSpan(text: cue.label, style: _stateStyle(accent)),
                            TextSpan(text: ' — ${cue.hint}', style: _hintStyle),
                          ]),
                    maxLines: 1,
                    // Не должно случиться: вид выбран так, чтобы влезало. Но
                    // при крупном шрифте в настройках телефона не влезет и
                    // самое короткое — тогда многоточие лучше переполнения.
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
            const SizedBox(width: GS.s2),
            // СЕРИЯ — то, ради чего вообще держат палец. Её обязано быть видно
            // рядом со шкалой: без неё зажим выглядит бессмысленным.
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                // Набранная серия, а не действующий множитель: на паузе она
                // не множит, но и не пропадает — это и надо видеть.
                final mult = controller.seriesMultiplier;
                final live = mult > 1.05;
                // Перегрев обнуляет серию — красным, чтобы это читалось без
                // слов: подсказка «отпусти, серия сгорает» стала короче.
                final color = controller.status == HeatStatus.overheated
                    ? GColors.hot
                    : (live ? GColors.amber : GColors.textLo);
                return Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'СЕРИЯ ', style: GType.label().copyWith(color: color)),
                    TextSpan(
                      text: Fmt.mult(double.parse(mult.toStringAsFixed(1))),
                      style: _seriesStyle(color),
                    ),
                  ]),
                );
              },
            ),
          ],
        );
      },
    );
  }

  static TextStyle _seriesStyle(Color color) =>
      GType.num(size: 13, weight: FontWeight.w700, color: color);
}

/// Цвет состояния жара — один на шкалу, подписи и огонь в сцене.
Color heatAccent(HeatStatus status) => switch (status) {
      HeatStatus.overheated => GColors.hot,
      HeatStatus.inWindow => GColors.green,
      HeatStatus.off => GColors.textHi,
      HeatStatus.paused => GColors.textLo,
    };

/// Сорт: что сейчас в баке и что с ним делает жар.
class _SortRow extends ConsumerWidget {
  final HeatController controller;
  const _SortRow({required this.controller});

  /// Меньше этого полоске со стрелкой не отдаём: иначе от неё остаётся точка.
  static const double _minTail = 28;

  static const String _topNote = 'лучше не бывает';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(gameProvider.select((s) => s.sort));
    final index = sort.index;
    final color = sort.current.toColor;
    // Высота строки — своя, а не от темы: тема даёт 1.43 кегля, и строка
    // сорта выходила на три точки выше своих букв.
    final nameStyle = GType.ui(size: 13, weight: FontWeight.w700, color: color, height: 1.2);
    final multStyle = GType.num(size: 10, color: GColors.textMid).copyWith(height: 1.2);
    final noteStyle = GType.ui(size: 10, color: GColors.textLo, height: 1.2);
    final mult = Fmt.mult(sort.multiplier);

    final scaler = MediaQuery.textScalerOf(context);
    double widthOf(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    return LayoutBuilder(
      builder: (context, outer) {
        // Подпись «СОРТ» и лесенка уступают место названию. Рядом с пультом
        // встаёт кнопка ускорения, и на 320 точках без этого «Двойной
        // перегон» резался до «Двой…», а лесенка — только повтор того же
        // сорта цветом.
        final lead = widthOf('СОРТ', GType.label()) + GS.s2 + kSorts.length * 6 + GS.s2;
        final need = widthOf(sort.name, nameStyle) + 6 + widthOf(mult, multStyle) + GS.s2 + _minTail;
        final showLead = outer.maxWidth - lead >= need;
        return Row(
          children: [
            if (showLead) ...[
              Text('СОРТ', style: GType.label()),
              const SizedBox(width: GS.s2),
              // Пипки пройденных ступеней: лесенка вверх, как уровень сигнала.
              for (var i = 0; i < kSorts.length; i++)
                Container(
                  width: 4,
                  height: 5.0 + i * 2.5,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: i <= index ? kSorts[i].toColor : const Color(0x21FFFFFF),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              const SizedBox(width: GS.s2),
            ],
            // Название сорта важнее полоски, полоска важнее слов «к цене».
            //
            // Раньше название и полоска делили остаток строки поровну, и
            // «Двойной перегон» выходил «Двойной п…» даже на 390 точках — а это
            // уже не сорт, а загадка. «Лучше не бывает» на 320 точках ломалось
            // в две строки и раздувало весь пульт.
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final nameW = widthOf(sort.name, nameStyle);
                  final full = '$mult к цене';
                  final label =
                      nameW + 6 + widthOf(full, multStyle) + GS.s2 + _minTail <= c.maxWidth
                          ? full
                          : mult;
                  final labelW = widthOf(label, multStyle);
                  final nameMax = math.max(0.0, c.maxWidth - 6 - labelW - GS.s2 - _minTail);
                  final tailW = c.maxWidth - math.min(nameW, nameMax) - 6 - labelW - GS.s2;

                  return Row(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: nameMax),
                        child: Text(
                          sort.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: nameStyle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(label, maxLines: 1, style: multStyle),
                      const SizedBox(width: GS.s2),
                      Expanded(
                        child: sort.isTop
                            // Не влезает целиком — не пишем вовсе: пипки и так
                            // все горят, а обрывок фразы хуже её отсутствия.
                            ? (tailW >= widthOf(_topNote, noteStyle)
                                ? Text(
                                    _topNote,
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    style: noteStyle,
                                  )
                                : const SizedBox.shrink())
                            : ValueListenableBuilder<HeatStatus>(
                                valueListenable: controller.statusNotifier,
                                builder: (context, status, _) => Row(
                                  children: [
                                    Expanded(
                                      child: FillBar(
                                        value: sort.progress,
                                        height: 4,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Куда сорт движется прямо сейчас — стрелкой,
                                    // а не словами: читается боковым зрением,
                                    // пока держишь жар.
                                    TrendArrow(
                                      up: status == HeatStatus.inWindow,
                                      count: status == HeatStatus.overheated ? 2 : 1,
                                      size: 8,
                                      color: switch (status) {
                                        HeatStatus.inWindow => GColors.green,
                                        HeatStatus.overheated => GColors.hot,
                                        HeatStatus.off || HeatStatus.paused => GColors.textLo,
                                      },
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double heat;
  final double windowStart;
  final double windowEnd;
  final double series;
  final HeatStatus status;

  _GaugePainter({
    required this.heat,
    required this.windowStart,
    required this.windowEnd,
    required this.series,
    required this.status,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const trackHeight = 10.0;
    final top = (size.height - trackHeight) / 2 - 2;
    const radius = Radius.circular(trackHeight / 2);
    final track = Rect.fromLTWH(0, top, size.width, trackHeight);

    // Жёлоб.
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, radius),
      Paint()..color = const Color(0x4D000000),
    );

    // Зона перегрева — видно заранее, куда нельзя.
    final hotX = HeatController.overheatAt * size.width;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(track, radius));
    canvas.drawRect(
      Rect.fromLTRB(hotX, top, size.width, top + trackHeight),
      Paint()..color = GColors.hot.withOpacity(0.35),
    );

    // Окно — подложка под заливкой.
    final ws = windowStart.clamp(0.0, 1.0) * size.width;
    final we = windowEnd.clamp(0.0, 1.0) * size.width;
    canvas.drawRect(
      Rect.fromLTRB(ws, top, we, top + trackHeight),
      Paint()..color = GColors.green.withOpacity(0.28),
    );

    // Заливка жара.
    final fill = heat.clamp(0.0, 1.0) * size.width;
    if (fill > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, top, fill, trackHeight),
        Paint()
          ..shader = LinearGradient(
            colors: [
              const Color(0xFF7A4A2A),
              switch (status) {
                HeatStatus.overheated => GColors.hot,
                HeatStatus.inWindow => GColors.green,
                HeatStatus.off || HeatStatus.paused => GColors.copper,
              },
            ],
          ).createShader(Rect.fromLTWH(0, top, fill.clamp(1.0, size.width), trackHeight)),
      );
    }
    canvas.restore();

    // Рамка окна ПОВЕРХ заливки — она обязана оставаться видимой всегда,
    // иначе после перегрева не видно, куда возвращаться.
    final edge = Paint()
      ..color = GColors.green
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(ws, top - 3), Offset(ws, top + trackHeight + 3), edge);
    canvas.drawLine(Offset(we, top - 3), Offset(we, top + trackHeight + 3), edge);

    // Стрелка текущего жара.
    final x = fill.clamp(2.0, size.width - 2.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 2, top - 4, 4, trackHeight + 8),
        const Radius.circular(2),
      ),
      Paint()..color = GColors.lamp,
    );

    // Серия — тонкой янтарной нитью под шкалой: сколько набрано.
    final sy = top + trackHeight + 5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, sy, size.width, 2), const Radius.circular(1)),
      Paint()..color = const Color(0x14FFFFFF),
    );
    if (series > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, sy, size.width * series.clamp(0.0, 1.0), 2),
          const Radius.circular(1),
        ),
        Paint()..color = GColors.amber,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.heat != heat ||
      old.windowStart != windowStart ||
      old.windowEnd != windowEnd ||
      old.series != series ||
      old.status != status;
}
