@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/engine/production.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';
import 'package:idle_game/ui/screens/shelf.dart';
import 'package:idle_game/ui/theme/garage.dart';

import 'support/moments.dart';

/// Развёрнутый магазин в режиме «ДО ВЕХИ» — все три вида кнопки разом:
/// пачка по карману, пачка не по карману (серая, с ценой всей пачки) и
/// «вехи все» у аппарата, прошедшего последнюю веху.
///
/// Шрифты настоящие: подпись «+2 → ×4» над ценой и «ДО ВЕХИ» в две строки
/// на кнопке количества проверяются только глазами.
///
/// Запуск:
///   flutter test --tags golden --run-skipped --update-goldens
void main() {
  setUpAll(() async {
    const fonts = {
      GType.uiFamily: ['Rubik-Variable.ttf'],
      GType.numFamily: [
        'IBMPlexMono-Regular.ttf',
        'IBMPlexMono-Medium.ttf',
        'IBMPlexMono-SemiBold.ttf',
        'IBMPlexMono-Bold.ttf',
      ],
    };
    for (final MapEntry(key: family, value: files) in fonts.entries) {
      final loader = FontLoader(family);
      for (final file in files) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
  });

  testWidgets('магазин в режиме «ДО ВЕХИ»', (tester) async {
    final now = quietMoment;
    const engine = GameEngine();
    final last = Production.milestones.last;
    // Банки прошли все вехи; бидону до вехи две штуки, и на них хватает;
    // фляге — семь, и на них не хватает, хоть на одну и хватило бы.
    const owned = {'bidon': 23, 'flyaga': 3};

    var state = newGame(content: kGenerators, upgrades: kUpgrades, now: now);
    state = state.copyWith(
      generators: state.generators.copyWith(items: [
        for (final g in state.generators.items)
          g.copyWith(ownedCount: g.id == 'banka' ? last : owned[g.id] ?? 0),
      ]),
    );
    double pack(String id) {
      final g = state.generators.items.firstWhere((g) => g.id == id);
      return engine.bulkCost(g, Production.toNextMilestone(g.ownedCount)!, now);
    }

    final money = pack('bidon') * 1.05;
    expect(money, lessThan(pack('flyaga')), reason: 'фляга должна быть не по карману');

    state = state.copyWith(
      resources: state.resources.copyWith(money: money),
      // «Целый литр» открывает покупку пачками.
      achievements: state.achievements.withUnlocked(['a_litre']),
    );
    // Цели, до которых такой гараж дорос, — заранее: иначе первый тик
    // открыл бы их, и на снимок попала бы плашка «цель взята».
    final GameState ready = engine.checkAchievements(state).state;

    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        initialStateProvider.overrideWithValue(ready),
        timeProvider.overrideWithValue(() => now),
        buyAmountProvider.overrideWith((ref) => kBuyToMilestone),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: GColors.bg,
          fontFamily: GType.uiFamily,
          useMaterial3: true,
        ),
        home: const Scaffold(backgroundColor: GColors.bg, body: GarageScreen()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('shelf-grabber')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(Shelf),
      matchesGoldenFile('goldens/shop_to_milestone.png'),
    );
    expect(tester.takeException(), isNull);
  });
}
