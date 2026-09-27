import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/ui/pixel/garage_room.dart';

void main() {
  group('Стадия помещения', () {
    test('банка и змеевик — это всё ещё гараж', () {
      expect(stageForTier(0), GarageStage.garage);
      expect(stageForTier(4), GarageStage.garage);
    });

    test('с гаражного цеха начинается цех', () {
      expect(stageForTier(5), GarageStage.shop);
      expect(stageForTier(8), GarageStage.shop);
    });

    test('с завода помещение перестаёт быть гаражом', () {
      expect(stageForTier(9), GarageStage.plant);
      expect(stageForTier(12), GarageStage.plant);
    });

    test('каждый аппарат попадает в какую-то стадию', () {
      // Если в контент добавят аппарат, а стадии забудут — тест упадёт здесь,
      // а не в виде голой кирпичной стены вокруг коллайдера.
      for (var i = 0; i < kGenerators.length; i++) {
        expect(() => stageForTier(i), returnsNormally);
      }
      expect(stageForTier(kGenerators.length - 1), GarageStage.plant,
          reason: 'последний аппарат обязан стоять на производстве');
    });

    test('у каждой стадии есть название', () {
      for (final stage in GarageStage.values) {
        expect(stageName(stage), isNotEmpty);
      }
      expect(
        GarageStage.values.map(stageName).toSet().length,
        GarageStage.values.length,
        reason: 'названия не должны повторяться',
      );
    });
  });

  group('Лампа', () {
    test('качается сильнее, когда жарко', () {
      double amplitude(double heat) {
        var peak = 0.0;
        for (var t = 0.0; t < 40; t += 0.05) {
          peak = peak > SwingingLamp.swing(t, heat).abs()
              ? peak
              : SwingingLamp.swing(t, heat).abs();
        }
        return peak;
      }

      expect(amplitude(1.0), greaterThan(amplitude(0.0)));
    });

    test('не улетает за пределы сцены даже при перегреве', () {
      for (var t = 0.0; t < 200; t += 0.1) {
        expect(SwingingLamp.swing(t, 5.0).abs(), lessThan(20),
            reason: 'жар выше единицы не должен раскачивать лампу до потолка');
      }
    });
  });

  group('Перерисовка', () {
    testWidgets('комната перерисовывается только при смене стадии',
        (tester) async {
      // Комната — самый дорогой рисунок в сцене: кирпич, пятна, обстановка.
      // Она обязана рисоваться один раз на стадию. Заведи в ней кто-нибудь
      // анимацию — перерисовка вернётся шестьдесят раз в секунду и потеряется
      // незаметно, поэтому контракт закреплён тестом.
      //
      // Проверка не по секундомеру: она отвечает на вопрос «просят ли
      // перерисовать», а не «сколько это заняло», и потому не зависит от того,
      // чем занята машина.
      CustomPainter painterOf() =>
          tester.widget<CustomPaint>(find.byType(CustomPaint).first).painter!;

      Future<void> show(GarageStage stage) => tester.pumpWidget(
            SizedBox(
              width: 200,
              height: 200,
              child: RoomBackground(stage: stage),
            ),
          );

      await show(GarageStage.garage);
      final first = painterOf();

      await show(GarageStage.garage);
      expect(painterOf().shouldRepaint(first), isFalse,
          reason: 'та же стадия — перерисовывать нечего');

      await show(GarageStage.plant);
      expect(painterOf().shouldRepaint(first), isTrue,
          reason: 'смена стадии обязана перерисовать комнату');
    });

    testWidgets('лампа не тянет за собой перерисовку комнаты', (tester) async {
      // Одного shouldRepaint мало. Лампа просит перерисовки каждый кадр, и
      // без своего слоя у комнаты вместе с лампой перерисовывался весь слой
      // сцены — комната в нём звалась шестьдесят раз в секунду, хотя
      // shouldRepaint честно отвечал «нет». Так и было, пока комнату не
      // вынесли в RepaintBoundary: 600 мкс на кадр ради неподвижной стены.
      Future<void> frame(double time) => tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  children: [
                    const Positioned.fill(child: RoomBackground(stage: GarageStage.garage)),
                    Positioned.fill(child: SwingingLamp(time: time, heat: 0.5)),
                  ],
                ),
              ),
            ),
          );

      await frame(0);
      final room = tester.renderObject<RenderRepaintBoundary>(
        find.descendant(of: find.byType(RoomBackground), matching: find.byType(RepaintBoundary)),
      );
      final withScene = room.debugSymmetricPaintCount;
      final skipped = room.debugAsymmetricPaintCount;

      for (var t = 0.1; t < 1; t += 0.1) {
        await frame(t);
      }

      // Сцена действительно перерисовывалась — иначе проверка пустая.
      expect(room.debugAsymmetricPaintCount, greaterThan(skipped),
          reason: 'лампа не просила кадров — проверять нечего');
      expect(room.debugSymmetricPaintCount, withScene,
          reason: 'комната перерисовывается вместе с лампой');
    });
  });

  group('Отрисовка', () {
    testWidgets('комната рисуется на всех стадиях и не падает на нулевом размере',
        (tester) async {
      for (final stage in GarageStage.values) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 320,
                height: 240,
                child: Stack(
                  children: [
                    Positioned.fill(child: RoomBackground(stage: stage)),
                    const Positioned.fill(
                      child: SwingingLamp(time: 3.7, heat: 0.8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }

      // Сцена успевает появиться в дереве с нулевым размером — деление на
      // высоту там обязано не родить NaN.
      await tester.pumpWidget(
        const Center(
          child: SizedBox(
            width: 0,
            height: 0,
            child: SwingingLamp(time: 1, heat: 1),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
