import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/flux_state.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/game/heat_controller.dart';
import 'package:idle_game/ui/game/heat_gauge.dart';
import 'package:idle_game/ui/pixel/garage_scene.dart';
import 'package:idle_game/ui/pixel/pixel_sprite.dart';
import 'package:idle_game/ui/pixel/still_sprites.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';
import 'package:idle_game/ui/theme/garage.dart';
import 'package:idle_game/ui/widgets/boost_button.dart';
import 'package:idle_game/ui/widgets/edge_fade.dart';
import 'package:idle_game/ui/widgets/shop.dart';

import 'support/moments.dart';
import 'support/real_fonts.dart';
import 'support/shelf_tabs.dart';

/// Главный экран на самом маленьком телефоне — 320×640 — и с кнопкой
/// ускорения, которая отнимает у пульта ширину.
///
/// Всё здесь найдено досмотром снимков перед выпуском, и всё — про то, что
/// на узком экране что-то тихо резалось или ужималось: подсказка жара
/// многоточием, банка в сцене до двадцати точек, вкладки за краем без
/// намёка, название аппарата мельче соседних. По отдельности каждый блок
/// «помещался», поэтому проверяется то, что видит игрок.
///
/// Шрифты настоящие: вопрос «влезает ли» Ahem решает неверно.
void main() {
  setUpAll(loadRealFonts);

  const small = Size(320, 640);

  /// Гараж, в котором обучение уже пройдено (аппаратов двух видов), с
  /// потоком — тогда рядом с пультом стоит кнопка ускорения.
  GameState garage({
    Map<String, int> stills = const {'banka': 7, 'bidon': 2},
    double flux = 42 * 60,
    bool bulk = false,
  }) {
    const engine = GameEngine();
    final t = quietMoment;
    var s = GameState.initial(
      initialGenerators: kGenerators,
      initialUpgrades: kUpgrades,
      lastUpdateTime: t,
    );
    s = s.copyWith(resources: s.resources.copyWith(money: 1e30));
    stills.forEach((id, n) => s = engine.buyGeneratorBulk(s, id, n, t));
    return s.copyWith(
      resources: s.resources.copyWith(money: 500),
      flux: FluxState(seconds: flux),
      // «Целый литр» открывает кнопку количества справа от вкладок.
      achievements: bulk ? s.achievements.withUnlocked(['a_litre']) : s.achievements,
    );
  }

  Future<ProviderContainer> openOn(WidgetTester tester, GameState state,
      {Size size = small}) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        initialStateProvider.overrideWithValue(state),
        timeProvider.overrideWithValue(() => quietMoment),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: GColors.bg,
          fontFamily: GType.uiFamily,
          useMaterial3: true,
        ),
        home: const Scaffold(body: GarageScreen()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    return ProviderScope.containerOf(tester.element(find.byType(GarageScreen)));
  }

  Rect rectOf(WidgetTester tester, Finder finder) {
    final box = tester.renderObject<RenderBox>(finder);
    return box.localToGlobal(Offset.zero) & box.size;
  }

  group('Подсказка жара', () {
    // Главная подсказка управления. На 320 точках рядом с кнопкой ускорения
    // от неё оставалось «СЛАБО — за…», на 390 — «В САМЫЙ РАЗ — так и …».
    //
    // Жар гоняется по-настоящему, зажимом: от «зажми гараж» через окно и
    // перегрев обратно, а потом пауза. Каждая подсказка должна за это время
    // показаться целиком.
    for (final size in const [small, Size(390, 844)]) {
      testWidgets(
          'на ${size.width.toInt()}×${size.height.toInt()} рядом с кнопкой '
          'ускорения читается целиком в любом состоянии', (tester) async {
        final game = await openOn(tester, garage(), size: size);
        expect(find.byType(BoostButton), findsOneWidget);

        final panel = find.byType(HeatPanel);
        final seen = <HeatCue>{};
        void look() {
          for (final cue in HeatCue.values) {
            // Без первой буквы: на узком пульте подсказка идёт с заглавной.
            final text = find.descendant(
              of: panel,
              matching: find.textContaining(cue.hint.substring(1), findRichText: true),
            );
            if (text.evaluate().isEmpty) continue;
            final paragraph = tester.renderObject<RenderParagraph>(text.first);
            expect(paragraph.didExceedMaxLines, isFalse,
                reason: '«${cue.hint}» обрезана на ${size.width.toInt()} точках');
            seen.add(cue);
          }
        }

        look();
        final hold = await tester.startGesture(tester.getCenter(find.byType(GarageScene)));
        for (var i = 0; i < 400 && !seen.contains(HeatCue.overheated); i++) {
          await tester.pump(const Duration(milliseconds: 50));
          look();
        }
        await hold.up();
        for (var i = 0; i < 100; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          look();
        }
        game.read(shelfPositionProvider.notifier).state = ShelfPosition.shop;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        look();

        expect(seen, HeatCue.values.toSet(),
            reason: 'не дождались подсказок: ${HeatCue.values.toSet().difference(seen)}');
      });
    }
  });

  group('Аппарат в сцене', () {
    // Банка на полу выходила в пиксель на клетку — двадцать две точки
    // ростом, с бейджем «×7» вплотную: портрет с табличкой забирали сотню
    // точек из полутора сотен сцены. 33 точки — это полтора пикселя на
    // клетку, следующий шаг масштаба после одного: при нём у банки видны
    // стекло и уровень.
    for (final flux in [0.0, 42 * 60.0]) {
      for (final stills in const [
        {'banka': 7},
        {'banka': 7, 'bidon': 2},
      ]) {
        testWidgets(
            '${stills.keys.join(' и ')} на 320×640 '
            '${flux > 0 ? 'с кнопкой ускорения' : 'без неё'} — '
            'не мельче полутора пикселей', (tester) async {
          await openOn(tester, garage(stills: stills, flux: flux));
          expect(find.byType(BoostButton), flux > 0 ? findsOneWidget : findsNothing);

          for (final id in stills.keys) {
            final sprite = stillSpriteFor(id);
            final still = find.descendant(
              of: find.byType(GarageScene),
              matching: find.byWidgetPredicate((w) => w is PixelImage && w.sprite == sprite),
            );
            expect(still, findsOneWidget, reason: '«$id» нет в сцене');
            final rect = rectOf(tester, still);
            expect(rect.width / sprite.width, greaterThanOrEqualTo(1.5),
                reason: '«$id» нарисован в ${rect.width / sprite.width} пикселя на клетку');
            if (id == 'banka') expect(rect.height, greaterThanOrEqualTo(33));

            // Бейдж количества — под аппаратом, а не поверх него.
            final tag = find.descendant(
              of: find.byType(GarageScene),
              matching: find.text('×${stills[id]}'),
            );
            expect(rectOf(tester, tag).top, greaterThanOrEqualTo(rect.bottom),
                reason: 'бейдж «×${stills[id]}» налез на аппарат');
          }
        });
      }
    }
  });

  group('Строка вкладок', () {
    // На 320 точках вкладки уезжали за край без намёка: «ЦЕЛЕЙ» и «ВИТИ» не
    // было видно вовсе, а метка у «ПОТОКА» резалась краем экрана.
    testWidgets('видно, что дальше есть вкладки, и метки не режутся',
        (tester) async {
      // Полная копилка — метка у «ПОТОКА», кнопка количества — справа.
      await openOn(tester, garage(flux: 3600, bulk: true));
      final strip = rectOf(tester, shelfTabs);
      final fade = find.descendant(of: shelfTabs, matching: find.byType(EdgeFade));
      final scroll = find.descendant(of: shelfTabs, matching: find.byType(Scrollable));
      expect(scroll, findsOneWidget, reason: 'на 320 точках вкладки не влезают — строка листается');

      void dotsInside(String when) {
        for (final tab in ['stills', 'flux']) {
          final dot = find.byKey(ValueKey('shelf-dot-$tab'));
          expect(dot, findsOneWidget, reason: 'нет метки у «$tab» $when');
          final r = rectOf(tester, dot);
          expect(r.left, greaterThanOrEqualTo(strip.left - 0.5),
              reason: 'метка «$tab» за левым краем строки $when: $r');
          expect(r.right, lessThanOrEqualTo(strip.right + 0.5),
              reason: 'метка «$tab» за правым краем строки $when: $r');
        }
      }

      var edge = tester.widget<EdgeFade>(fade);
      expect(edge.end, isTrue, reason: 'правый край не затухает, хотя вкладки есть дальше');
      expect(edge.start, isFalse);
      dotsInside('в начале');

      final position = tester.state<ScrollableState>(scroll).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      edge = tester.widget<EdgeFade>(fade);
      expect(edge.start, isTrue, reason: 'левый край не затухает, хотя вкладки есть слева');
      expect(edge.end, isFalse);
      dotsInside('в конце');
      expect(await shelfTab(tester, 'ВИТЯ'), findsOneWidget);
    });
  });

  group('Названия аппаратов', () {
    // На 320 точках «Бидон эмалированный» ужимался мельче «Трёхлитровой
    // банки»: каждое название сидело в своём FittedBox. Теперь кегль один на
    // весь список, длинное название переносится по словам — и не рвётся
    // посреди слова: «Бидон эмалиро / ванный» хуже, чем мелко. Строка от
    // переноса в две строки не растёт — иначе на 320×640 в магазин не
    // влезали бы две строки.
    //
    // Цена — самая широкая, какая бывает: девять знаков, «1.23квд ₽». Рядом с
    // ней названию остаётся меньше всего места.
    //
    // 296 — строка на экране 320 точек, 366 — на 390: там кегль полный.
    for (final (width, full) in const [(296.0, false), (366.0, true)]) {
      testWidgets('одного размера и по словам в строке шириной ${width.toInt()}',
          (tester) async {
        double? size;
        double? base;
        for (final g in kGeneratorNames) {
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(brightness: Brightness.dark, fontFamily: GType.uiFamily, useMaterial3: true),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: StillRow(
                    id: g.id,
                    name: g.name,
                    owned: 3,
                    output: 7,
                    cost: 1.23e15,
                    affordable: true,
                    locked: false,
                    onBuy: () {},
                  ),
                ),
              ),
            ),
          ));
          expect(tester.takeException(), isNull);

          final name = tester.renderObject<RenderParagraph>(find.text(g.name));
          final style = name.text.style!;
          expect(name.didExceedMaxLines, isFalse, reason: '«${g.name}» обрезано');
          expect(name.getTransformTo(null).getMaxScaleOnAxis(), closeTo(1, 1e-9),
              reason: '«${g.name}» ужато');
          size ??= style.fontSize;
          expect(style.fontSize, size, reason: '«${g.name}» другого кегля, чем соседи');
          if (full) expect(style.fontSize, 14, reason: 'на обычном телефоне кегль ужат');
          expect(style.fontSize, greaterThanOrEqualTo(12), reason: 'названия мельче 12 не читаются');

          // Перенос — только между словами или после дефиса: там, где у
          // соседних знаков разные строки, левый обязан быть пробелом или
          // дефисом.
          final text = g.name;
          double top(int i) => name
              .getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1))
              .first
              .top;
          for (var i = 0; i + 1 < text.length; i++) {
            if (text[i + 1] == ' ' || text[i] == ' ') continue;
            if (top(i) != top(i + 1)) {
              expect(text[i], '-',
                  reason: '«$text» разорвано посреди слова: «${text.substring(0, i + 1)}» / '
                      '«${text.substring(i + 1)}»');
            }
          }

          // Строк — по высоте абзаца: высота строки задана в стиле.
          final lines = (name.size.height / (style.fontSize! * style.height!)).round();
          final height = tester.getSize(find.byType(StillRow)).height;
          // Первые две ступени — те, что на 320×640 обязаны стоять в
          // магазине целиком, — всегда не больше чем в две строки.
          if (g.id == 'banka' || g.id == 'bidon') {
            expect(lines, lessThanOrEqualTo(2), reason: '«${g.name}» в $lines строки');
          }
          if (lines <= 2) {
            base ??= height;
            expect(height, base, reason: 'строка с «${g.name}» в $lines строки выше других');
          }
        }
      });
    }
  });
}
