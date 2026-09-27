import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_game/content/balance.dart';
import 'package:idle_game/content/game_content.dart';
import 'package:idle_game/core/game_serializer.dart';
import 'package:idle_game/core/save.dart';
import 'package:idle_game/core/save_code.dart';

import 'support/economy_fingerprint.dart';
import 'support/save_facts.dart';

/// Договор с уже выпущенной версией.
///
/// Всё остальное тестирование отвечает на вопрос «работает ли то, что я
/// написал сегодня». Этот файл отвечает на другой: **не сломал ли я то, что
/// уже стоит у людей на телефонах**. Это разные вопросы, и второй важнее:
/// ошибку в новой фиче игрок переживёт, потерю гаража — нет.
///
/// ## Эталонный сейв
///
/// В `test/fixtures/` лежит настоящий сейв, записанный выпущенной версией.
/// Каждая следующая версия обязана его открыть и не потерять факты. Файл
/// НЕ ПРАВИТСЯ — это снимок прошлого, а не тестовые данные. Если он перестал
/// читаться, чинить надо код, а не файл.
///
/// Каждый выпуск кладёт рядом свой эталон: так накапливается история
/// форматов, и каждая новая версия проверяется против всех прошлых.
///
/// ## До выпуска
///
/// Эталоны тестовых сборок (1.0.0 и 1.1.0 для своих) удалены при чистом
/// старте (docs/DECISIONS.md): их сейвы выпуск не читает. Пока папка пуста,
/// игроков нет — договариваться не с кем. Версии баланса и сейва стоят на
/// единице, журнал не пишется, отпечаток чисел не сверяется: экономику ещё
/// перестраивают, и объяснять правку некому.
///
/// Первый эталон снимает выпуск 1.0.0 (`tools/make_fixture.dart`), и с ним
/// всё строгое включается само — без чьей-то памяти и без правки этого
/// файла, кроме отпечатка, который выпуск записывает вместе с эталоном.
void main() {
  const ser = GameSerializer();
  const codec = SaveCodec();
  final now = DateTime.utc(2026, 12, 1);

  final dir = Directory('test/fixtures');
  final saves = dir.existsSync()
      ? dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))
      : <File>[];

  final released = saves.isNotEmpty;

  group('До выпуска версии не поднимаются', () {
    // Пока эталона нет, подъём версии — не забота об игроке, а шум: у
    // выпуска появился бы журнал из записей, которые никто не застал, и
    // миграции из форматов, которых ни у кого нет.
    test('версия баланса — 1, в журнале одна запись', () {
      expect(kBalanceVersion, 1,
          reason: 'эталона в test/fixtures нет — игроков нет, версию '
              'баланса до выпуска не поднимают');
      expect([for (final r in kBalanceLog) r.version], [1],
          reason: 'до выпуска журнал не пишется: объяснять правку некому');
    });

    test('версия сейва — 1', () {
      expect(kSaveVersion, 1,
          reason: 'эталона в test/fixtures нет — формат до выпуска правится '
              'на месте, без версий и миграций');
    });
  }, skip: released ? 'выпуск состоялся: действуют правила ниже' : false);

  // Факты эталона, которые загрузка вправе поменять, — путь и почему; путь
  // покрывает и всё, что под ним. Служебные ключи (version, balanceVersion,
  // lastSeen) не факты и в сверку не входят вовсе — см. kServiceKeys.
  //
  // Сейчас здесь пусто: загрузка ничего не пересчитывает, только читает.
  // Сюда попадает осознанная правка после выпуска — id, убранный из игры,
  // ключ, переименованный миграцией, — с тем, чем это возмещено игроку или
  // куда переехало значение. Не способ заглушить упавшую сверку: пропавший
  // факт — это то, что игрок потерял.
  const mayChange = <String, String>{};

  group('Сейвы выпущенных версий открываются', () {
    for (final file in saves) {
      final name = file.uri.pathSegments.last;

      test('$name читается текущей версией', () {
        final result = codec.decode(file.readAsStringSync());

        expect(result.wasCorrupt, isFalse,
            reason: 'сейв версии $name перестал читаться — это потерянный '
                'гараж у каждого, кто на ней играл');
        expect(result.data, isNotNull);

        final state = ser.fromJson(
          result.data!,
          content: kGenerators,
          upgrades: kUpgrades,
          now: now,
        );

        // Факты обязаны пережить обновление — все, а не выборочно: сверка
        // двух ключей из двадцати пропустила бы потерю потока, статистики
        // или портала. Сверяется с файлом, а не с тем, что вернула миграция:
        // факт, потерянный миграцией, игрок теряет точно так же. Оценки
        // (доход, мудрость) могут измениться — на то они и оценки, в сейве
        // их нет.
        final original =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final lost = lostFacts(
          original,
          ser.toJson(state, lastSeenMillis: now.millisecondsSinceEpoch),
          allowed: mayChange,
        );
        expect(lost, isEmpty,
            reason: 'сейв версии $name открылся, но потерял факты — у каждого, '
                'кто на ней играл, пропадёт то же самое');

        // И главное: состояние живое, а не просто разобранное.
        expect(() => state.mlPerSecond, returnsNormally);
        expect(state.mlPerSecond, greaterThanOrEqualTo(0));
      });

      test('$name переживает круг через код переноса', () {
        // Игрок мог сохранить прогресс кодом на старой версии и вставить его
        // уже на новой.
        final code = encodeSaveCode(file.readAsStringSync());
        final back = decodeSaveCode(code);

        expect(back.isOk, isTrue, reason: back.message);
        expect(codec.decode(back.save).wasCorrupt, isFalse);
      });
    }
  });

  group('Забыть поднять версию баланса нельзя', () {
    // Отпечаток — все числа экономики, от которых зависят доход, цены и
    // скорость прогресса, а не только поля Balance.
    //
    // Нужен потому, что забыть поднять kBalanceVersion очень легко: правишь
    // одно число, тесты зелёные, а игрок при обновлении не получает ни
    // объяснения, ни компенсации — просто замечает, что доход поехал.
    // Отпечаток превращает эту забывчивость в упавший тест. Первый отпечаток
    // собирался из одних полей Balance и промолчал бы о правке цены сорта,
    // гостя или серии жара.
    //
    // Что в отпечатке, а что сознательно нет, — test/support/
    // economy_fingerprint.dart. Что каждое число в него действительно
    // попадает и что новое не забыто, проверяет economy_fingerprint_test —
    // всегда, а не только после выпуска.
    //
    // До выпуска сверка пропускается: экономику ещё перестраивают. Выпуск,
    // снимая первый эталон, записывает сюда действующий отпечаток — тест
    // сам его напечатает, упав на первом прогоне с эталоном.
    test('числа экономики совпадают с записанным отпечатком', skip: released
        ? false
        : 'до выпуска: эталона в test/fixtures нет, числа ещё правят', () {
      // Записан выпуском 1.0.0 вместе с эталоном save_1.0.0.json.
      const expected = r'''
Balance.costGrowth = 1.15
Balance.firstWisdomMl = 1.597e16
Balance.firstWisdomBonus = 1
Balance.bonusPerWisdom = 0.5
Balance.basePricePerMl = 0.1
Balance.baseTankMl = 2000
Balance.baseBufferSeconds = 60
Balance.maxBufferSeconds = 1800
Balance.milestones = 10, 25, 50, 100, 150, 200, 250, 300, 400, 500
Balance.firstGeneratorCost = 15
Balance.tierCostRatio = 40
Balance.firstGeneratorOutput = 1
Balance.tierOutputRatio = 6
Balance.tierUpgradeCosts = 30, 1000, 100000
Balance.tierUpgradeMultiplier = 2
Balance.globalUpgradeCost = 500
Balance.globalUpgradeMultiplier = 2
Balance.qualityUpgradeCost = 50000
Balance.qualityUpgradeMultiplier = 1.3
Balance.fluxMinutesPerHour = 10
Balance.fluxMaxMinutesPerHour = 60
Balance.fluxBankHours = 1
Balance.fluxMaxBankHours = 24
Balance.fluxRateCostBase = 45
Balance.fluxRateCostStep = 20
Balance.fluxBankCostBase = 30
Balance.fluxBankCostStep = 15
Balance.fluxMaxSpeed = 10
Balance.colliderCostFactor = 2000
Balance.wisdomMilestones[0] = world=garage wisdom=1 KeepUpgrades target=heatControl
Balance.wisdomMilestones[1] = world=garage wisdom=2 StillBoost generatorId=banka factor=2
Balance.wisdomMilestones[2] = world=garage wisdom=3 RunStart money=10000
Balance.wisdomMilestones[3] = world=garage wisdom=5 StillBoost generatorId=bidon factor=2
Balance.wisdomMilestones[4] = world=garage wisdom=7 KeepUpgrades target=tankCapacity
Balance.wisdomMilestones[5] = world=garage wisdom=9 StillBoost generatorId=flyaga factor=2
Balance.wisdomMilestones[6] = world=garage wisdom=10 AllBoost factor=1.3
Balance.wisdomMilestones[7] = world=garage wisdom=11 SortSpeed factor=1.5
Balance.wisdomMilestones[8] = world=garage wisdom=13 StillBoost generatorId=dedov factor=2
Balance.wisdomMilestones[9] = world=garage wisdom=15 GuestPay factor=1.5
Balance.wisdomMilestones[10] = world=garage wisdom=16 AllBoost factor=1.3
Balance.wisdomMilestones[11] = world=garage wisdom=17 RunStart money=1e8
Balance.wisdomMilestones[12] = world=garage wisdom=20 AllBoost factor=2
Balance.wisdomMilestones[13] = world=garage wisdom=22 AllBoost factor=2
Balance.wisdomMilestones[14] = world=garage wisdom=23 RunStart money=1e12
Balance.wisdomMilestones[15] = world=garage wisdom=24 AllBoost factor=2
Balance.wisdomMilestones[16] = world=garage wisdom=26 AllBoost factor=2
Balance.wisdomMilestones[17] = world=garage wisdom=27 GuestPay factor=2
Balance.wisdomMilestones[18] = world=garage wisdom=28 AllBoost factor=2
Balance.wisdomMilestones[19] = world=garage wisdom=30 AllBoost factor=2
Balance.wisdomMilestones[20] = world=garage wisdom=31 SortSpeed factor=2
Balance.wisdomMilestones[21] = world=garage wisdom=32 AllBoost factor=2
Balance.wisdomMilestones[22] = world=garage wisdom=34 AllBoost factor=2
Balance.wisdomMilestones[23] = world=garage wisdom=36 AllBoost factor=2
Balance.wisdomMilestones[24] = world=garage wisdom=38 AllBoost factor=2
Balance.wisdomMilestones[25] = world=garage wisdom=40 AllBoost factor=2
Balance.wisdomMilestones[26] = world=garage wisdom=42 AllBoost factor=2
Balance.wisdomMilestones[27] = world=garage wisdom=44 AllBoost factor=2
Balance.wisdomMilestones[28] = world=garage wisdom=46 AllBoost factor=2
Balance.wisdomMilestones[29] = world=garage wisdom=48 AllBoost factor=2
Balance.wisdomMilestones[30] = world=garage wisdom=50 AllBoost factor=2
kGenerators.banka = baseCost=15 baseProduction=1
kGenerators.bidon = baseCost=600 baseProduction=6
kGenerators.flyaga = baseCost=24000 baseProduction=36
kGenerators.dedov = baseCost=960000 baseProduction=216
kGenerators.zmeevik = baseCost=3.84e7 baseProduction=1296
kGenerators.tseh = baseCost=1.536e9 baseProduction=7776
kGenerators.podval = baseCost=6.144e10 baseProduction=46656
kGenerators.tsisterna = baseCost=2.4576e12 baseProduction=279936
kGenerators.druzhba = baseCost=9.8304e13 baseProduction=1679616
kGenerators.zavod = baseCost=3.93216e15 baseProduction=1.0077696e7
kGenerators.tanker = baseCost=1.572864e17 baseProduction=6.0466176e7
kGenerators.orbita = baseCost=6.291456e18 baseProduction=3.62797056e8
kGenerators.collider = baseCost=5.0331648e23 baseProduction=2.176782336e9
kUpgrades.heat_1 = cost=40 target=heatControl targetGeneratorId=null multiplier=1.25
kUpgrades.heat_2 = cost=1200 target=heatControl targetGeneratorId=null multiplier=1.25
kUpgrades.heat_3 = cost=30000 target=heatControl targetGeneratorId=null multiplier=1.3
kUpgrades.tank_1 = cost=200 target=tankCapacity targetGeneratorId=null multiplier=2
kUpgrades.tank_2 = cost=9000 target=tankCapacity targetGeneratorId=null multiplier=3
kUpgrades.tank_3 = cost=900000 target=tankCapacity targetGeneratorId=null multiplier=4
kUpgrades.tank_4 = cost=6e7 target=tankCapacity targetGeneratorId=null multiplier=5
kUpgrades.gen_banka_1 = cost=450 target=generatorOutput targetGeneratorId=banka multiplier=2
kUpgrades.gen_banka_2 = cost=15000 target=generatorOutput targetGeneratorId=banka multiplier=2
kUpgrades.gen_banka_3 = cost=1500000 target=generatorOutput targetGeneratorId=banka multiplier=2
kUpgrades.all_banka = cost=7500 target=allGenerators targetGeneratorId=null multiplier=2
kUpgrades.price_banka = cost=750000 target=quality targetGeneratorId=null multiplier=1.3
kUpgrades.gen_bidon_1 = cost=18000 target=generatorOutput targetGeneratorId=bidon multiplier=2
kUpgrades.gen_bidon_2 = cost=600000 target=generatorOutput targetGeneratorId=bidon multiplier=2
kUpgrades.gen_bidon_3 = cost=6e7 target=generatorOutput targetGeneratorId=bidon multiplier=2
kUpgrades.all_bidon = cost=300000 target=allGenerators targetGeneratorId=null multiplier=2
kUpgrades.price_bidon = cost=3e7 target=quality targetGeneratorId=null multiplier=1.3
kUpgrades.gen_flyaga_1 = cost=720000 target=generatorOutput targetGeneratorId=flyaga multiplier=2
kUpgrades.gen_flyaga_2 = cost=2.4e7 target=generatorOutput targetGeneratorId=flyaga multiplier=2
kUpgrades.gen_flyaga_3 = cost=2.4e9 target=generatorOutput targetGeneratorId=flyaga multiplier=2
kUpgrades.all_flyaga = cost=1.2e7 target=allGenerators targetGeneratorId=null multiplier=2
kUpgrades.price_flyaga = cost=1.2e9 target=quality targetGeneratorId=null multiplier=1.3
kUpgrades.gen_dedov_1 = cost=2.88e7 target=generatorOutput targetGeneratorId=dedov multiplier=2
kUpgrades.gen_dedov_2 = cost=9.6e8 target=generatorOutput targetGeneratorId=dedov multiplier=2
kUpgrades.gen_dedov_3 = cost=9.6e10 target=generatorOutput targetGeneratorId=dedov multiplier=2
kUpgrades.all_dedov = cost=4.8e8 target=allGenerators targetGeneratorId=null multiplier=2
kUpgrades.price_dedov = cost=4.8e10 target=quality targetGeneratorId=null multiplier=1.3
kUpgrades.gen_zmeevik_1 = cost=1.152e9 target=generatorOutput targetGeneratorId=zmeevik multiplier=2
kUpgrades.gen_zmeevik_2 = cost=3.84e10 target=generatorOutput targetGeneratorId=zmeevik multiplier=2
kUpgrades.gen_zmeevik_3 = cost=3.84e12 target=generatorOutput targetGeneratorId=zmeevik multiplier=2
kUpgrades.all_zmeevik = cost=1.92e10 target=allGenerators targetGeneratorId=null multiplier=2
kUpgrades.price_zmeevik = cost=1.92e12 target=quality targetGeneratorId=null multiplier=1.3
kUpgrades.gen_tseh_1 = cost=4.608e10 target=generatorOutput targetGeneratorId=tseh multiplier=2
kUpgrades.gen_tseh_2 = cost=1.536e12 target=generatorOutput targetGeneratorId=tseh multiplier=2
kUpgrades.gen_tseh_3 = cost=1.536e14 target=generatorOutput targetGeneratorId=tseh multiplier=2
kUpgrades.all_tseh = cost=7.68e11 target=allGenerators targetGeneratorId=null multiplier=2
kUpgrades.price_tseh = cost=7.68e13 target=quality targetGeneratorId=null multiplier=1.3
kUpgrades.gen_podval_1 = cost=1.8432e12 target=generatorOutput targetGeneratorId=podval multiplier=2
kUpgrades.gen_podval_2 = cost=6.144e13 target=generatorOutput targetGeneratorId=podval multiplier=2
kUpgrades.gen_podval_3 = cost=6.144e15 target=generatorOutput targetGeneratorId=podval multiplier=2
kUpgrades.all_podval = cost=3.072e13 target=allGenerators targetGeneratorId=null multiplier=2
kUpgrades.price_podval = cost=3.072e15 target=quality targetGeneratorId=null multiplier=1.3
kUpgrades.gen_tsisterna_1 = cost=7.3728e13 target=generatorOutput targetGeneratorId=tsisterna multiplier=2
kUpgrades.gen_tsisterna_2 = cost=2.4576e15 target=generatorOutput targetGeneratorId=tsisterna multiplier=2
kUpgrades.gen_tsisterna_3 = cost=2.4576e17 target=generatorOutput targetGeneratorId=tsisterna multiplier=2
kUpgrades.all_tsisterna = cost=1.2288e15 target=allGenerators targetGeneratorId=null multiplier=2
kUpgrades.price_tsisterna = cost=1.2288e17 target=quality targetGeneratorId=null multiplier=1.3
kUpgrades.gen_druzhba_1 = cost=2.94912e15 target=generatorOutput targetGeneratorId=druzhba multiplier=2
kUpgrades.gen_druzhba_2 = cost=9.8304e16 target=generatorOutput targetGeneratorId=druzhba multiplier=2
kUpgrades.gen_druzhba_3 = cost=9.8304e18 target=generatorOutput targetGeneratorId=druzhba multiplier=2
kUpgrades.all_druzhba = cost=4.9152e16 target=allGenerators targetGeneratorId=null multiplier=2
kUpgrades.price_druzhba = cost=4.9152e18 target=quality targetGeneratorId=null multiplier=1.3
kUpgrades.gen_zavod_1 = cost=1.179648e17 target=generatorOutput targetGeneratorId=zavod multiplier=2
kUpgrades.gen_zavod_2 = cost=3.93216e18 target=generatorOutput targetGeneratorId=zavod multiplier=2
kUpgrades.gen_zavod_3 = cost=3.93216e20 target=generatorOutput targetGeneratorId=zavod multiplier=2
kUpgrades.all_zavod = cost=1.96608e18 target=allGenerators targetGeneratorId=null multiplier=2
kUpgrades.price_zavod = cost=1.96608e20 target=quality targetGeneratorId=null multiplier=1.3
kUpgrades.gen_tanker_1 = cost=4.718592e18 target=generatorOutput targetGeneratorId=tanker multiplier=2
kUpgrades.gen_tanker_2 = cost=1.572864e20 target=generatorOutput targetGeneratorId=tanker multiplier=2
kUpgrades.gen_tanker_3 = cost=1.572864e22 target=generatorOutput targetGeneratorId=tanker multiplier=2
kUpgrades.all_tanker = cost=7.86432e19 target=allGenerators targetGeneratorId=null multiplier=2
kUpgrades.price_tanker = cost=7.86432e21 target=quality targetGeneratorId=null multiplier=1.3
kUpgrades.gen_orbita_1 = cost=1.8874368e20 target=generatorOutput targetGeneratorId=orbita multiplier=2
kUpgrades.gen_orbita_2 = cost=6.291456e21 target=generatorOutput targetGeneratorId=orbita multiplier=2
kUpgrades.gen_orbita_3 = cost=6.291456e23 target=generatorOutput targetGeneratorId=orbita multiplier=2
kUpgrades.all_orbita = cost=3.145728e21 target=allGenerators targetGeneratorId=null multiplier=2
kUpgrades.price_orbita = cost=3.145728e23 target=quality targetGeneratorId=null multiplier=1.3
kUpgrades.gen_collider_1 = cost=1.50994944e25 target=generatorOutput targetGeneratorId=collider multiplier=2
kUpgrades.gen_collider_2 = cost=5.0331648e26 target=generatorOutput targetGeneratorId=collider multiplier=2
kUpgrades.gen_collider_3 = cost=5.0331648e28 target=generatorOutput targetGeneratorId=collider multiplier=2
kUpgrades.all_collider = cost=2.5165824e26 target=allGenerators targetGeneratorId=null multiplier=2
kUpgrades.price_collider = cost=2.5165824e28 target=quality targetGeneratorId=null multiplier=1.3
kUpgrades.syn_1 = cost=70000 target=synergyCoupling targetGeneratorId=null multiplier=1
kUpgrades.syn_2 = cost=300000 target=synergyResonance targetGeneratorId=null multiplier=1
kSorts[0] = multiplier=1
kSorts[1] = multiplier=1.25
kSorts[2] = multiplier=1.6
kSorts[3] = multiplier=2.1
kSorts[4] = multiplier=2.8
kBuyers.petrovich = multiplier=1 minSortIndex=0 minMl=0 maxMl=null consumesSort=false
kGarageEvents.shabashka = multiplier=1.7 minSortIndex=1 minMl=0 maxMl=null consumesSort=true
kGarageEvents.pominki = multiplier=2.3 minSortIndex=2 minMl=0 maxMl=null consumesSort=true
kGarageEvents.svadba = multiplier=3 minSortIndex=3 minMl=0 maxMl=null consumesSort=true
kGarageEvents.nachalnik = multiplier=3.6 minSortIndex=4 minMl=0 maxMl=null consumesSort=true
kAchievementRows[0] = a_first_tap a_first_still a_first_sale a_litre:bulkBuy
kAchievementRows[1] = a_ten a_assortment a_full_tank a_thousand:autoSell
kAchievementRows[2] = a_quality a_tank_up a_hands a_dedov
kAchievementRows[3] = a_hundred a_million a_brigade a_synergy
kAchievementRows[4] = a_first_hangover a_wise a_again a_legacy
kSortGainPerSecond = 0.17
kSortBurnPerSecond = 0.42
kSortDecayPerSecond = 0.06
kEventPeriod, с = 600
kEventWindow, с = 300
kAchievementMultiplier = 1.05
kRowMultiplier = 1.35
Market.swing = 0.35
HeatController.risePerSecond = 0.28
HeatController.decayPerSecond = 0.2
HeatController.seriesGraceSeconds = 3
HeatController.seriesFadeSeconds = 14
HeatController.seriesFillSeconds = 45
HeatController.maxSeriesMultiplier = 3
HeatController.purchaseStoke = 0.18
HeatController.baseWindowSize = 0.24
HeatController.maxWindowSize = 0.5
HeatController.windowSpeed = 0.022
HeatController.windowMin = 0.1
HeatController.overheatAt = 0.93
GameNotifier.afkGap, с = 120
Market.wave(t=0 с) = 1.097183151
Market.wave(t=50 с) = 1.027702884
Market.wave(t=150 с) = 1.162360022
Market.wave(t=300 с) = 1.093470465
Market.wave(t=450 с) = 0.697015849
Market.wave(t=600 с) = 0.9882044079
Market.wave(t=1000 с) = 0.773548471
Market.wave(t=3000 с) = 0.9181490961
PrestigeState.wisdomFor(0.5·firstWisdomMl) = 0
PrestigeState.wisdomFor(1.5·firstWisdomMl) = 1
PrestigeState.wisdomFor(2.5·firstWisdomMl) = 1
PrestigeState.wisdomFor(5·firstWisdomMl) = 2
PrestigeState.wisdomFor(10·firstWisdomMl) = 3
PrestigeState.wisdomFor(100·firstWisdomMl) = 6
PrestigeState.wisdomFor(10000·firstWisdomMl) = 13
PrestigeState(всего 5·firstWisdomMl).nextWisdomAtMl / firstWisdomMl = 7
PrestigeState.multiplierFor(0) = 1
PrestigeState.multiplierFor(1) = 2
PrestigeState.multiplierFor(2) = 2.5
PrestigeState.multiplierFor(5) = 4
Production.milestoneMultiplier(9) = 1
Production.milestoneMultiplier(10) = 2
Production.milestoneMultiplier(30) = 4
Production.milestoneMultiplier(100) = 16
Production.milestoneMultiplier(500) = 1024
Production.mlPerSecond(пробный гараж) = 21888
Production.mlPerSecond(пробный гараж, связки) = 28131.84
Production.mlPerSecond(пробный гараж, всё куплено, мудрость 2, все цели) = 5.511759746e10
Production.tankCapacity(1 мл/с) = 2000
Production.tankCapacity(1000 мл/с) = 60000
Production.tankCapacity(1000 мл/с, весь бак) = 1800000
AchievementsState(первый ряд).multiplier = 1.640933438
AchievementsState(все цели).multiplier = 11.89747563
GameEngine.generatorCost(banka, 10 шт.) = 60.68336604
GameEngine.bulkCost(bidon, +10 к 5 шт.) = 24502.81777
GameEngine.saleValueFor(petrovich, литр лучшего сорта, всё качество, t=0) = 9304.66499
GameEngine.saleValueFor(event:shabashka, литр лучшего сорта, всё качество, t=0) = 15817.93048
GameEngine.saleValueFor(event:pominki, литр лучшего сорта, всё качество, t=0) = 21400.72948
GameEngine.saleValueFor(event:svadba, литр лучшего сорта, всё качество, t=0) = 27913.99497
GameEngine.saleValueFor(event:nachalnik, литр лучшего сорта, всё качество, t=0) = 33496.79397
GameEngine.processTick(10 с, жар ×2, ускорение ×3): налито, мл = 60
GameEngine.processTick(10 с, жар ×2, ускорение ×3): потока ушло, с = 20
GameEngine.creditAfk(3 ч, копилка пуста).gained, с = 1800
GameEngine.creditAfk(30 ч, копилка пуста).gained, с = 3600
FluxState(rateLevel 3, bankLevel 2).minutesPerHour = 13
FluxState(rateLevel 3, bankLevel 2).bankSeconds = 10800
FluxState(rateLevel 3, bankLevel 2).rateCostSeconds = 6300
FluxState(rateLevel 3, bankLevel 2).bankCostSeconds = 3600
SortState(3, 0.5).dropOneStep(): ступень + прогресс = 2
SortState().advance(2.5): ступень + прогресс = 2.5
startingGenerators: banka = 1
eventAt за неделю: shabashka = 241
eventAt за неделю: pominki = 250
eventAt за неделю: svadba = 261
eventAt за неделю: nachalnik = 256
''';

      final actual = economyFingerprint(currentEconomy());
      final changes = fingerprintChanges(expected, actual);
      if (changes.isEmpty) return;

      final block = "const expected = r'''\n$actual\n''';";
      fail(expected.trim().isEmpty
          ? 'отпечаток чисел экономики не записан. Выпуск записывает его '
              'вместе с первым эталоном — вот действующий, целиком:\n\n$block'
          : 'числа экономики изменились:\n${changes.join('\n')}\n\n'
              'Это нормально — но тогда:\n'
              '  1) подними kBalanceVersion;\n'
              '  2) добавь запись в kBalanceLog: что изменилось и почему;\n'
              '  3) если игроку стало хуже — isNerf: true и компенсация;\n'
              '  4) обнови отпечаток здесь:\n\n$block\n\n'
              'Пункт 3 — единственная причина, по которой всё это существует.');
    });

    test('версия баланса объявлена в журнале', () {
      final versions = {for (final r in kBalanceLog) r.version};
      expect(versions, contains(kBalanceVersion),
          reason: 'текущая версия баланса не описана в kBalanceLog: игрок '
              'увидит изменения, но не получит объяснения');
    });
  });

  group('Версия приложения', () {
    test('в pubspec стоит версия с номером сборки', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);

      expect(match, isNotNull);
      final version = match!.group(1)!;
      expect(version, contains('+'),
          reason: 'без +N Android не отличит новую сборку от старой и не даст '
              'поставить обновление поверх');
    });

    test('номер сборки не меньше розданного', () {
      // Имя версии при чистом старте ушло с 1.1.0 назад на 1.0.0, а номер
      // сборки — нет: у друзей стоит APK 1.1.0+2, и Android не поставит
      // поверх сборку с меньшим номером. Удалить игру ради обновления —
      // потерять гараж.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final build = RegExp(r'^version:\s*\S+\+(\d+)', multiLine: true)
          .firstMatch(pubspec)
          ?.group(1);
      expect(int.tryParse(build ?? ''), greaterThan(2),
          reason: 'розданная сборка — 1.1.0+2; следующая обязана быть больше');
    });
  });
}
