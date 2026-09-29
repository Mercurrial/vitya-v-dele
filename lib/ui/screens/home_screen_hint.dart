/// «Поставь на экран Домой» — подсказка на iPhone во вкладке браузера.
///
/// Кому и почему — в `core/home_screen.dart`. Здесь только слова: как
/// поставить, зачем и почему сейчас. Их мало, потому что экран один раз и до
/// игры, и влезть он обязан в 320×640. Во встроенном браузере мессенджера
/// вместо неё — `in_app_browser_hint.dart`.
library;

import 'package:flutter/material.dart';

import '../theme/garage.dart';
import '../widgets/panel.dart';

Future<void> showHomeScreenHint(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xCC0B0806),
    builder: (context) => const HomeScreenHint(),
  );
}

class HomeScreenHint extends StatelessWidget {
  const HomeScreenHint({super.key});

  @override
  Widget build(BuildContext context) {
    final strong = GType.body().copyWith(
      color: GColors.textHi,
      fontWeight: FontWeight.w600,
    );
    return AlertDialog(
      backgroundColor: GColors.surface1,
      // Крупный шрифт в настройках телефона не должен уносить кнопку за
      // край экрана.
      scrollable: true,
      title: Text('Поставь игру на экран «Домой»',
          style: GType.ui(size: 17, weight: FontWeight.w600)),
      // Ширина — как у колонки игры, см. test_save_notice.dart.
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Text.rich(
          TextSpan(
            style: GType.body(),
            children: [
              // Словами, а не стрелками: в Rubik нет «→», и в браузере
              // вместо неё рисовался пустой квадрат. И не «⋯»: его в Rubik
              // тоже нет.
              //
              // «Поделиться» — с тем, где её искать: на iOS 26 её убрали из
              // нижней панели в меню за тремя точками, и тестер на iPhone не
              // нашёл, с чего начать. «На экран Домой» — внизу списка.
              TextSpan(
                text: 'В Safari: «Поделиться» — внизу экрана или в меню за '
                    'тремя точками у адреса. Пролистай вниз до «На экран '
                    'Домой».',
                style: strong,
              ),
              const TextSpan(
                text: '\n\nВо вкладке Safari iPhone стирает прогресс, если '
                    // Неразрывный пробел: одинокая «С» висела в конце
                    // строки на 320 точках.
                    'неделю не заходить в игру. С иконки — нет.'
                    '\n\nСтавь сейчас: у иконки своё хранилище, и прогресс '
                    'из Safari туда сам не переедет. Уже играл здесь — '
                    'перенеси его кодом: вкладка «Витя», ',
              ),
              TextSpan(text: 'ПЕРЕНОС ПРОГРЕССА', style: strong),
              // Встроенный браузер мессенджера узнаётся не всякий
              // (home_screen.dart), и тогда показывается эта подсказка.
              const TextSpan(
                text: '.\n\nТакого пункта нет — игра открыта внутри '
                    'мессенджера. Открой её в Safari: в меню этого окна '
                    '«Открыть в Safari».',
              ),
            ],
          ),
        ),
      ),
      // Янтарная кнопка во всю ширину, как у других действий игры. Была
      // серой надписью TextButton — на тёмном окне её принимали за подпись и
      // искали, чем окно закрыть.
      actions: [
        SizedBox(
          width: double.infinity,
          child: WideButton(
            label: 'ПОНЯТНО',
            enabled: true,
            onTap: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }
}
