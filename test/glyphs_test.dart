import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/engine/game_engine.dart';
import 'package:idle_game/models/flux_state.dart';
import 'package:idle_game/models/game_state.dart';
import 'package:idle_game/providers/game_provider.dart';
import 'package:idle_game/ui/screens/garage_screen.dart';
import 'package:idle_game/ui/theme/garage.dart';
import 'package:idle_game/ui/widgets/boost_button.dart';

import 'support/moments.dart';
import 'support/real_fonts.dart';

/// Всё, что набрано на главном экране, есть в шрифте, которым набрано.
///
/// Знака нет в шрифте — браузер берёт его из запасного, который CanvasKit
/// скачивает из сети; без сети на его месте пустой квадрат. На глаз этого не
/// увидеть: на компьютере разработчика запасной шрифт обычно под рукой. Так
/// уже было со стрелками «→» в Rubik и «▲▼» у рынка — их пришлось рисовать
/// (TrendArrow). Кнопка ускорения — последний случай: «»×2» читалась как
/// кавычка, а знака «▶» нет ни в одном из двух шрифтов игры.
///
/// Проверка — по таблице cmap самих файлов шрифтов, а не по отрисовке.
void main() {
  late final Map<String, Set<int>> glyphs;

  setUpAll(() async {
    await loadRealFonts();
    glyphs = {
      for (final family in kFontFiles.keys) family: await fontCodePoints(family),
    };
  });

  GameState garage() {
    const engine = GameEngine();
    final t = quietMoment;
    var s = GameState.initial(
      initialGenerators: kGenerators,
      initialUpgrades: kUpgrades,
      lastUpdateTime: t,
    );
    s = s.copyWith(resources: s.resources.copyWith(money: 1e30));
    s = engine.buyGeneratorBulk(s, 'banka', 7, t);
    s = engine.buyGeneratorBulk(s, 'bidon', 2, t);
    return s.copyWith(
      resources: s.resources.copyWith(money: 840),
      flux: const FluxState(seconds: 42 * 60),
    );
  }

  /// Знаки, которых нет в шрифте, — по всем надписям под [of].
  List<String> missing(WidgetTester tester, Finder of) {
    final out = <String>[];
    void walk(InlineSpan span, String family) {
      if (span is! TextSpan) return;
      final f = span.style?.fontFamily ?? family;
      for (final r in (span.text ?? '').runes) {
        // Переводы строк и прочие управляющие шрифту не нужны.
        if (r < 0x20) continue;
        if (!glyphs[f]!.contains(r)) {
          out.add('«${String.fromCharCode(r)}» (U+${r.toRadixString(16).toUpperCase()}) '
              'в «${span.toPlainText()}», шрифт $f');
        }
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        walk(child, f);
      }
    }

    for (final e in find.descendant(of: of, matching: find.byType(RichText)).evaluate()) {
      walk((e.widget as RichText).text, GType.uiFamily);
    }
    return out;
  }

  testWidgets('на главном экране и на кнопке ускорения', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        initialStateProvider.overrideWithValue(garage()),
        timeProvider.overrideWithValue(() => quietMoment),
      ],
      child: MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: GType.uiFamily,
          useMaterial3: true,
        ),
        home: const Scaffold(body: GarageScreen()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BoostButton), findsOneWidget);
    expect(missing(tester, find.byType(GarageScreen)), isEmpty);

    // Включённая кнопка пишет другое: «СТОП» и сколько осталось.
    await tester.tap(find.byType(BoostButton));
    await tester.pump(const Duration(milliseconds: 300));
    expect(missing(tester, find.byType(BoostButton)), isEmpty);
    expect(find.descendant(of: find.byType(BoostButton), matching: find.byType(FastForwardSign)),
        findsOneWidget,
        reason: 'знак перемотки нарисован, а не набран');
  });
}
