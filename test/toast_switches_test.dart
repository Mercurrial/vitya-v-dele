import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/core/settings.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/models/prestige_state.dart';
import 'package:idle_game/models/sort_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/providers/settings_provider.dart';
import 'package:idle_game/ui/game/heat_controller.dart';
import 'package:idle_game/ui/theme/garage.dart';
import 'package:idle_game/ui/widgets/settings_panel.dart';
import 'package:idle_game/ui/widgets/vitya_toast.dart';

import 'support/moments.dart';

/// Выключатели плашек.
///
/// Первый тестер попросил выключить «СОРТ ПОДНЯЛСЯ»: сорт и так виден на
/// шкале, а плашка закрывает гараж. Главное здесь — выключенная плашка не
/// появляется ни из одного места, где её вызывают, а выбор переживает
/// перезапуск. Умолчания — решение владельца (docs/DECISIONS.md).
void main() {
  ProviderContainer containerWith(SettingsStore store) {
    final c = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Настройки, где выключено ровно [off].
  Map<String, String> allOnBut(Set<ToastKind> off) => {
        for (final kind in ToastKind.values)
          kind.setting: off.contains(kind) ? 'off' : 'on',
      };

  group('Выбор', () {
    test('по умолчанию сорт молчит, остальное показывается', () {
      expect(
        containerWith(MemorySettingsStore()).read(toastSwitchesProvider),
        {ToastKind.goal, ToastKind.hangover, ToastKind.portal},
      );
    });

    test('переживает перезапуск — в обе стороны от умолчания', () {
      final store = MemorySettingsStore();
      final first = containerWith(store).read(toastSwitchesProvider.notifier);
      first.set(ToastKind.gradeUp, true);
      first.set(ToastKind.goal, false);

      // Второй контейнер — это и есть «игру закрыли и открыли заново».
      expect(
        containerWith(store).read(toastSwitchesProvider),
        {ToastKind.gradeUp, ToastKind.hangover, ToastKind.portal},
      );
    });

    test('мусор в настройках — как будто игрок не выбирал', () {
      final store = MemorySettingsStore({
        SettingsKeys.toastGradeUp: 'да',
        SettingsKeys.toastGoal: 'барокко',
      });
      expect(
        containerWith(store).read(toastSwitchesProvider),
        {ToastKind.goal, ToastKind.hangover, ToastKind.portal},
      );
    });

    test('у каждого вида свой ключ', () {
      final keys = ToastKind.values.map((k) => k.setting).toSet();
      expect(keys, hasLength(ToastKind.values.length),
          reason: 'два вида под одним ключом выключались бы вместе');
    });
  });

  group('Очередь', () {
    for (final kind in ToastKind.values) {
      test('выключенная «${kind.label}» не показывается', () {
        final c = containerWith(MemorySettingsStore(allOnBut({kind})));
        c.read(toastProvider.notifier).show(kind: kind, title: 'проверка');
        expect(c.read(toastProvider), isNull);
      });
    }

    test('скрытая плашка не сбивает ту, что уже на экране', () {
      final c = containerWith(MemorySettingsStore(allOnBut({ToastKind.gradeUp})));
      final queue = c.read(toastProvider.notifier);
      queue.show(kind: ToastKind.goal, title: 'цель');
      queue.show(kind: ToastKind.gradeUp, title: 'сорт');
      expect(c.read(toastProvider)?.title, 'цель');
    });

    test('включил — действует сразу, без перезапуска', () {
      final c = containerWith(MemorySettingsStore());
      final queue = c.read(toastProvider.notifier);
      queue.show(kind: ToastKind.gradeUp, title: 'сорт');
      expect(c.read(toastProvider), isNull);

      c.read(toastSwitchesProvider.notifier).set(ToastKind.gradeUp, true);
      queue.show(kind: ToastKind.gradeUp, title: 'сорт');
      expect(c.read(toastProvider)?.kind, ToastKind.gradeUp);
    });
  });

  group('Из игры', () {
    /// Гараж, где за первую секунду поднимается сорт и берутся цели, а денег
    /// хватает на коллайдер. Похмелье доступно всегда.
    GameState scene() {
      final s = newGame(content: kGenerators, upgrades: kUpgrades, now: quietMoment);
      return s.copyWith(
        resources: s.resources.copyWith(money: 1e40),
        sort: const SortState(index: 1, progress: 0.99),
        prestige: PrestigeState(totalEverEarned: PrestigeState.firstWisdomMl * 16),
      );
    }

    /// Прожить сценарий через настоящие места вызова — тик игры, покупку,
    /// похмелье — и вернуть, какие плашки игрок увидел.
    Future<Set<ToastKind>> play(
      WidgetTester tester,
      Map<String, String> settings,
    ) async {
      var now = quietMoment;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          initialStateProvider.overrideWithValue(scene()),
          timeProvider.overrideWithValue(() => now),
          settingsStoreProvider.overrideWithValue(MemorySettingsStore(settings)),
        ],
        child: const SizedBox(),
      ));
      final scope = ProviderScope.containerOf(tester.element(find.byType(SizedBox)));
      final shown = <ToastKind>{};
      scope.listen(toastProvider, (_, next) {
        if (next != null) shown.add(next.kind);
      });

      scope.read(heatStatusProvider.notifier).state = HeatStatus.inWindow;
      final game = scope.read(gameProvider.notifier); // запускает тик
      for (var i = 0; i < 5; i++) {
        now = now.add(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(scope.read(gameProvider).sort.index, greaterThan(1),
          reason: 'сорт не поднялся — плашке сорта неоткуда было взяться');

      game.buyGenerator(kPortalStillId);
      game.sleepItOff();

      // Плашка уходит сама, а дерево снимаем, чтобы тик не пережил тест.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      return shown;
    }

    testWidgets('всё выключено — ни одной плашки', (tester) async {
      final shown = await play(tester, allOnBut(ToastKind.values.toSet()));
      expect(shown, isEmpty);
    });

    for (final off in ToastKind.values) {
      testWidgets('выключена «${off.label}» — её нет, остальные на месте',
          (tester) async {
        final shown = await play(tester, allOnBut({off}));
        expect(shown, ToastKind.values.toSet().difference({off}));
      });
    }

    testWidgets('по умолчанию — всё, кроме сорта', (tester) async {
      final shown = await play(tester, {});
      expect(shown, {ToastKind.goal, ToastKind.hangover, ToastKind.portal});
    });
  });

  group('Настройки на экране', () {
    testWidgets('выключатель на каждый вид, на 320 точках ничего не вылезает',
        (tester) async {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = MemorySettingsStore();
      await tester.pumpWidget(ProviderScope(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, fontFamily: GType.uiFamily),
          home: Scaffold(body: ListView(children: const [SettingsPanel()])),
        ),
      ));

      for (final kind in ToastKind.values) {
        expect(find.text(kind.title), findsOneWidget,
            reason: 'у плашки «${kind.label}» нет выключателя');
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(ToastKind.gradeUp.title));
      await tester.pump(const Duration(milliseconds: 200));
      final scope = ProviderScope.containerOf(tester.element(find.byType(SettingsPanel)));
      expect(scope.read(toastSwitchesProvider), contains(ToastKind.gradeUp));
      expect(store.read(SettingsKeys.toastGradeUp), 'on');
    });
  });
}
