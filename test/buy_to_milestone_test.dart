import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/formatters.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/engine/production.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/generator.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';
import 'package:idle_game/ui/screens/shelf.dart';
import 'package:idle_game/ui/widgets/shop.dart';

import 'support/moments.dart';

/// Режим покупки «ДО ВЕХИ»: ровно столько штук, чтобы множитель аппарата
/// удвоился, — или ничего (docs/DECISIONS.md, «Интерфейс»).
///
/// Рубежи в тестах не выписаны числами, а берутся из баланса: проверяется,
/// что режим ведёт туда же, куда множитель, какими бы рубежи ни стали.
void main() {
  final marks = Production.milestones;
  const engine = GameEngine();
  final t = quietMoment;

  group('Сколько до вехи', () {
    test('с нуля — до первой вехи', () {
      expect(Production.toNextMilestone(0), marks.first);
    });

    test('ведёт ровно до ближайшего удвоения, не дальше и не ближе', () {
      for (var owned = 0; owned < marks.last; owned++) {
        final n = Production.toNextMilestone(owned);
        expect(n, isNotNull, reason: 'с $owned штук вехи ещё есть');
        expect(n, greaterThan(0), reason: 'с $owned штук');
        final now = Production.milestoneMultiplier(owned);
        expect(Production.milestoneMultiplier(owned + n!), now * 2,
            reason: 'с $owned штук +$n не дошли до удвоения');
        expect(Production.milestoneMultiplier(owned + n - 1), now,
            reason: 'с $owned штук веха ближе, чем +$n');
      }
    });

    test('ровно на вехе — до следующей, а не ноль', () {
      for (var i = 0; i < marks.length - 1; i++) {
        expect(Production.toNextMilestone(marks[i]), marks[i + 1] - marks[i],
            reason: 'на вехе ${marks[i]}');
      }
    });

    test('за штуку до вехи — одна штука', () {
      for (final m in marks) {
        expect(Production.toNextMilestone(m - 1), 1, reason: 'перед вехой $m');
      }
    });

    test('на последней вехе и после неё вести некуда', () {
      for (final owned in [marks.last, marks.last + 1, marks.last * 3]) {
        expect(Production.toNextMilestone(owned), isNull, reason: 'при $owned штук');
      }
    });
  });

  GameState withStill(String id, int owned, {double money = 0}) {
    final s = GameState.initial(
      initialGenerators: kGenerators,
      initialUpgrades: kUpgrades,
      lastUpdateTime: t,
    );
    return s.copyWith(
      generators: s.generators.copyWith(items: [
        for (final g in s.generators.items) g.id == id ? g.copyWith(ownedCount: owned) : g,
      ]),
      resources: s.resources.copyWith(money: money),
    );
  }

  Generator still(GameState s, String id) => s.generators.items.firstWhere((g) => g.id == id);

  /// Цена пачки до вехи — та, что на кнопке.
  double packCost(GameState s, String id) {
    final g = still(s, id);
    return engine.bulkCost(g, Production.toNextMilestone(g.ownedCount)!, t);
  }

  GameState withMoney(GameState s, double money) =>
      s.copyWith(resources: s.resources.copyWith(money: money));

  group('Покупка до вехи', () {
    test('берёт ровно до вехи и списывает цену пачки', () {
      final s = withStill('bidon', 7);
      final n = Production.toNextMilestone(7)!;
      final cost = packCost(s, 'bidon');
      final rich = withMoney(s, cost * 3);

      final after = engine.buyToMilestone(rich, 'bidon', t);

      expect(still(after, 'bidon').ownedCount, 7 + n);
      expect(Production.milestoneMultiplier(7 + n), Production.milestoneMultiplier(7) * 2);
      expect(after.resources.money, closeTo(cost * 2, cost * 1e-9));
      expect(after.stats.stillsBought, rich.stats.stillsBought + n);
    });

    test('денег ровно на пачку — покупает', () {
      // Логарифм в «сколько влезет» на ровной сумме недобирает штуку — при
      // замере в трети случаев. Через него горящая кнопка ничего бы не
      // купила. Поэтому — все количества подряд, а не одно удачное.
      for (var owned = 0; owned < marks.last; owned++) {
        final s = withStill('bidon', owned);
        final exact = withMoney(s, packCost(s, 'bidon'));
        final after = engine.buyToMilestone(exact, 'bidon', t);
        expect(still(after, 'bidon').ownedCount, owned + Production.toNextMilestone(owned)!,
            reason: 'при $owned штук');
      }
    });

    test('денег на пачку не хватает — не берёт ни штуки', () {
      final s = withStill('bidon', 3);
      final poor = withMoney(s, packCost(s, 'bidon') * 0.99);
      // Иначе проверка пустая: пачкой здесь взялось бы несколько штук.
      expect(engine.affordableCount(poor, still(poor, 'bidon'), t), greaterThan(1));

      expect(engine.buyToMilestone(poor, 'bidon', t), same(poor));
    });

    test('ровно на вехе — берёт до следующей', () {
      final s = withStill('banka', marks.first);
      final after = engine.buyToMilestone(withMoney(s, packCost(s, 'banka')), 'banka', t);
      expect(still(after, 'banka').ownedCount, marks[1]);
    });

    test('после последней вехи не покупает ничего', () {
      for (final owned in [marks.last, marks.last + 7]) {
        final s = withStill('banka', owned, money: double.maxFinite);
        expect(engine.buyToMilestone(s, 'banka', t), same(s), reason: 'при $owned штук');
      }
    });

    test('незнакомый аппарат — ничего', () {
      final s = withStill('banka', 3, money: 1e12);
      expect(engine.buyToMilestone(s, 'нет-такого', t), same(s));
    });
  });

  group('Кнопка в режиме «ДО ВЕХИ»', () {
    /// Полка с открытой покупкой пачками и уже выбранным режимом.
    Future<ProviderContainer> open(WidgetTester tester, GameState state) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          initialStateProvider.overrideWithValue(state.copyWith(
            // «Целый литр» открывает покупку пачками.
            achievements: state.achievements.withUnlocked(['a_litre']),
          )),
          timeProvider.overrideWithValue(() => t),
          buyAmountProvider.overrideWith((ref) => kBuyToMilestone),
        ],
        child: const MaterialApp(home: Scaffold(body: GarageScreen())),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      return ProviderScope.containerOf(tester.element(find.byType(Shelf)));
    }

    Finder buttonOf(String id) => find.descendant(
          of: find.byWidgetPredicate((w) => w is StillRow && w.id == id),
          matching: find.byType(BuyButton),
        );

    testWidgets('показывает, сколько штук и какой будет множитель, и берёт их', (tester) async {
      final scope = await open(tester, withStill('banka', 3, money: 1e12));
      final n = Production.toNextMilestone(3)!;
      final button = tester.widget<BuyButton>(buttonOf('banka'));
      expect(button.caption, '+$n → ×${Production.milestoneMultiplier(3 + n).toInt()}');
      expect(button.affordable, isTrue);

      await tester.tap(buttonOf('banka'));
      await tester.pump();

      expect(still(scope.read(gameProvider), 'banka').ownedCount, 3 + n);
    });

    testWidgets('без денег на пачку — серая, с ценой всей пачки, и не берёт меньше', (tester) async {
      final s = withStill('banka', 3);
      final g = still(s, 'banka');
      // На одну штуку хватает: ×1 бы купил.
      final scope = await open(tester, withMoney(s, engine.generatorCost(g, t) * 1.5));
      final money = scope.read(gameProvider).resources.money;
      expect(money, greaterThanOrEqualTo(engine.generatorCost(g, t)));
      expect(money, lessThan(packCost(s, 'banka')));

      final button = tester.widget<BuyButton>(buttonOf('banka'));
      expect(button.affordable, isFalse);
      expect(button.label, Fmt.money(packCost(s, 'banka')));

      await tester.tap(buttonOf('banka'));
      await tester.pump();
      expect(still(scope.read(gameProvider), 'banka').ownedCount, 3);
    });

    testWidgets('вехи пройдены — серая, вместо цены «вехи все», не покупает', (tester) async {
      final scope = await open(tester, withStill('banka', marks.last, money: 1e300));
      final button = tester.widget<BuyButton>(buttonOf('banka'));
      expect(button.affordable, isFalse);
      expect(button.label, isNot(contains('₽')));
      expect(button.caption, '×${Production.milestoneMultiplier(marks.last).toInt()}');

      final bought = scope.read(gameProvider).stats.stillsBought;
      await tester.tap(buttonOf('banka'));
      await tester.pump();
      expect(still(scope.read(gameProvider), 'banka').ownedCount, marks.last);
      expect(scope.read(gameProvider).stats.stillsBought, bought);
    });
  });
}
