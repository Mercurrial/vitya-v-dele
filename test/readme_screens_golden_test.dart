@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/game/vitya_portrait.dart';
import 'package:idle_game/ui/pixel/pixel_portrait.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';
import 'package:idle_game/ui/theme/garage.dart';

import '../tools/demo_saves.dart' show demoStages;
import 'support/moments.dart';
import 'support/real_fonts.dart';

/// Скриншоты README — снимками экрана, а не руками в браузере.
///
/// Первые сняли в браузере 25.09, и через день они устарели: на них осталась
/// гладкая лампа, которую к выпуску перерисовали, и владелец принял старую
/// картинку за поломку. Теперь README показывает эти снимки, а переснимает
/// их тот же workflow, что и остальные (goldens.yml): что в игре, то и в
/// README.
///
/// Стадии — из tools/demo_saves.dart, те же, по которым игру смотрят глазами.
///
/// Портрет прогревается заранее. Фото декодируется асинхронно, тестовый кадр
/// его не ждёт, и в остальных снимках экрана на месте Вити ровная заливка —
/// для проверки вёрстки это неважно, а для витрины README важнее всего.
void main() {
  setUpAll(loadRealFonts);

  Future<void> open(WidgetTester tester, GameState state, DateTime now) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Кэш портрета статический: картинка, собранная здесь по-настоящему
    // асинхронно, достанется виджету готовой.
    await tester.runAsync(() => PixelPortraitCache.get(
          vityaEraFor(state.prestige.totalEverEarned).asset,
          PixelPortraitStyle.pixel,
        ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialStateProvider.overrideWithValue(state),
          timeProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: GColors.bg,
            fontFamily: GType.uiFamily,
            useMaterial3: true,
          ),
          home: const Scaffold(
            backgroundColor: GColors.bg,
            body: GarageScreen(),
          ),
        ),
      ),
    );
    // Первый кадр забирает готовый портрет из кэша (он приходит микрозадачей),
    // второй его рисует.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // Середина — с гостем: на витрине видно, что в гараж приходят.
  for (final (stage, now) in [
    ('early', quietMoment),
    ('mid', eventMoment),
    ('final', quietMoment),
  ]) {
    testWidgets('скриншот README: $stage', (tester) async {
      await open(tester, demoStages(now)[stage]!, now);

      await expectLater(
        find.byType(GarageScreen),
        matchesGoldenFile('goldens/readme_$stage.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
