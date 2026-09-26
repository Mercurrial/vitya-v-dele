@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/achievements.dart';
import 'package:idle_game/ui/pixel/goal_icons.dart';
import 'package:idle_game/ui/pixel/pixel_sprite.dart';
import 'package:idle_game/ui/pixel/still_sprites.dart';
import 'package:idle_game/ui/theme/garage.dart';

/// Все значки целей в натуральную величину — 32 точки, как в сетке целей.
///
/// Значки перерисовали, потому что половина не читалась без подписи, — а
/// стерёг их до сих пор только тест на размер и палитру. Сломанный значок
/// замечали бы, лишь открыв вкладку целей. Здесь набор виден целиком и так,
/// как на экране: слева на ячейке взятой цели, справа — невзятой, где значок
/// приглушён до 0.3 и узнаваться должен по силуэту.
///
/// Ряды — те же, что в сетке целей. Текста нет, и снимок от шрифтов не
/// зависит; эталон всё равно снимает только workflow «Переснять снимки».
void main() {
  testWidgets('значки целей в натуральную величину', (tester) async {
    const cell = 44.0;
    const gap = 16.0;
    final columns = kAchievementRows.first.items.length;
    final width = 2 * columns * cell + gap;
    final height = kAchievementRows.length * cell;
    tester.view
      ..physicalSize = Size(width, height)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget panel({required bool done}) => Column(
          children: [
            for (final row in kAchievementRows)
              Row(
                children: [
                  for (final a in row.items)
                    Container(
                      width: cell,
                      height: cell,
                      alignment: Alignment.center,
                      // Цвета ячейки — как в `_AchievementCell` вкладки целей.
                      color: done ? const Color(0xFF3A2A1B) : const Color(0x33000000),
                      child: Opacity(
                        opacity: done ? 1.0 : 0.3,
                        child: PixelImage(sprite: goalIcon(a.id), size: 32, palette: kStillPalette),
                      ),
                    ),
                ],
              ),
          ],
        );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: GColors.surface1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              panel(done: true),
              const SizedBox(width: gap),
              panel(done: false),
            ],
          ),
        ),
      ),
    );

    await expectLater(find.byType(ColoredBox).first, matchesGoldenFile('goldens/goal_icons.png'));
  });
}
