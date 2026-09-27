import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../providers/game_provider.dart';
import '../theme/garage.dart';

/// Ширина кнопки ускорения рядом с пультом жара.
const double kBoostButtonWidth = 64;

/// Кнопка ускорения потоком — на главном экране, справа от пульта жара.
///
/// Встаёт сбоку от пульта, а не отдельным рядом: высоту на главном экране
/// делят шапка, сцена и магазин (docs/DECISIONS.md, «Главный экран»), и ряд
/// под кнопку отнял бы у магазина вторую строку на 320×640. Сбоку пульт
/// теряет немного ширины, а по высоте кнопка равна ему.
///
/// Показывается, только пока есть поток или идёт ускорение: новичку, у
/// которого потока ещё не было, кнопка, которая ничего не делает, не нужна.
/// Скорость выбирается на вкладке «ПОТОК»; здесь — включить и выключить.
class BoostButton extends ConsumerWidget {
  const BoostButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flux = ref.watch(gameProvider.select((s) => s.flux.seconds));
    final speed = ref.watch(fluxSpeedProvider);
    final choice = ref.watch(fluxChoiceProvider);
    final on = speed > 1;
    final shown = on ? speed : choice;

    // Включено — сколько настоящего времени осталось; выключено — сколько
    // потока в копилке. Первое отвечает на «надолго ли», второе — на «есть
    // ли что тратить».
    final note = on
        ? Fmt.clock(Duration(seconds: (flux / (speed - 1)).ceil()))
        : Fmt.duration(Duration(seconds: flux.floor()));

    return Semantics(
      button: true,
      toggled: on,
      label: on ? 'Выключить ускорение' : 'Ускорить потоком',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(gameProvider.notifier).toggleBoost(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: gEase,
          width: kBoostButtonWidth,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            gradient: on
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [GColors.amber, GColors.amberDim],
                  )
                : null,
            color: on ? null : GColors.surface1,
            borderRadius: BorderRadius.circular(GR.button),
            border: Border.all(color: on ? GColors.amber : GColors.copper),
            boxShadow: on
                ? const [BoxShadow(color: GColors.amberGlow, blurRadius: 12)]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  on ? 'СТОП' : 'УСКОРИТЬ',
                  style: GType.ui(
                    size: 9,
                    weight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: on ? GColors.onAmber : GColors.textMid,
                  ),
                ),
                // «▶▶ ×2»: знак перемотки нарисован, а не набран. Была «»» —
                // рядом с «×2» она читалась как закрывающая кавычка. Своего
                // знака «вперёд» нет ни в Rubik, ни в IBM Plex Mono (есть
                // только «→», а это «куда», а не «быстрее»), и браузер
                // подставил бы его из шрифта, скачанного из сети, — без сети
                // был бы пустой квадрат.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FastForwardSign(color: on ? GColors.onAmber : GColors.amber),
                    const SizedBox(width: 3),
                    Text(
                      '×${shown.round()}',
                      style: GType.num(
                        size: 18,
                        weight: FontWeight.w700,
                        color: on ? GColors.onAmber : GColors.amber,
                      ),
                    ),
                  ],
                ),
                Text(
                  note,
                  style: GType.num(
                    size: 10,
                    color: on ? GColors.onAmber : GColors.textMid,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Знак перемотки ▶▶ — два треугольника вправо, как на пульте видеомагнитофона.
class FastForwardSign extends StatelessWidget {
  final Color color;

  /// Высота знака: под цифры кегля 18.
  final double height;

  const FastForwardSign({super.key, required this.color, this.height = 11});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(height * 1.4, height),
      painter: _FastForwardPainter(color),
    );
  }
}

class _FastForwardPainter extends CustomPainter {
  final Color color;
  _FastForwardPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Треугольники вплотную: второй начинается там, где кончился первый.
    final w = size.width / 2;
    final path = Path();
    for (final x in [0.0, w]) {
      path
        ..moveTo(x, 0)
        ..lineTo(x + w, size.height / 2)
        ..lineTo(x, size.height)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FastForwardPainter old) => old.color != color;
}
