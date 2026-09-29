/// Настройки интерфейса.
///
/// Живут ОТДЕЛЬНО от сейва, и это осознанно. Сейв версионирован и обвешан
/// миграциями, потому что в нём прогресс: потерять его нельзя. Звук,
/// вибрация и плашки — не прогресс. Сунуть его в тот же JSON значило бы поднимать версию формата
/// и писать миграцию ради галочки в настройках.
///
/// Хранилище спрятано за [SettingsStore] по той же причине, что и сейв:
/// игровой код не должен знать про плагины.
library;

/// Куда физически кладём настройки.
abstract class SettingsStore {
  String? read(String key);
  Future<void> write(String key, String value);
}

/// Настройки в памяти — для тестов и для платформ без плагинов.
class MemorySettingsStore implements SettingsStore {
  final Map<String, String> _values;

  MemorySettingsStore([Map<String, String>? initial])
      : _values = {...?initial};

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

/// Разбор значения выключателя. Отсутствующая настройка означает «включено»:
/// игрок, который ничего не трогал, должен получить игру целиком.
///
/// Исключения решает владелец, и тогда умолчание — [byDefault]: плашка
/// «СОРТ ПОДНЯЛСЯ» стоит выключенной, пока игрок не включит её сам
/// (docs/DECISIONS.md). Мусор в хранилище читается как отсутствие настройки:
/// то, что не разобрали, игрок не выбирал.
bool settingOn(String? raw, {bool byDefault = true}) => switch (raw) {
      'on' => true,
      'off' => false,
      _ => byDefault,
    };

/// Как записать выключатель обратно.
String settingValue(bool on) => on ? 'on' : 'off';

/// Ключи настроек. Строки собраны здесь, чтобы опечатка в одном месте не
/// приводила к молча потерянной настройке.
abstract final class SettingsKeys {
  /// Докуда дошло обучение. В настройках, а не в сейве: это не прогресс
  /// гаража, и поднимать ради него версию формата сохранения незачем.
  ///
  /// До выпуска 1.0.0 ключ был `tutorial_step`. Выпуск начинает гараж
  /// заново, и новый гараж без подсказок выглядел бы странно, поэтому ключ
  /// сменили вместе с ключом сейва: старый прогресс обучения не читается,
  /// а звук и вибрация лежат под прежними ключами и переживают выпуск.
  static const tutorial = 'tutorial';

  /// Звук и вибрация. Хранятся строками 'on'/'off' — формат хранилища
  /// строковый, а заводить сериализацию булева ради двух галочек незачем.
  static const sound = 'sound';
  static const haptics = 'haptics';

  /// Выключатели плашек, по одному на вид (`ToastKind` в `vitya_toast.dart`).
  /// Хранят только выбор игрока: не выбирал — действует умолчание вида, и
  /// сменить его можно будет, не переписывая ничьих настроек.
  static const toastGradeUp = 'toast_grade_up';
  static const toastGoal = 'toast_goal';
  static const toastHangover = 'toast_hangover';
  static const toastPortal = 'toast_portal';

  /// Подсказку «поставь на экран Домой» закрыли (`home_screen.dart`). Не
  /// прогресс, а «это уже говорили». Лежит в хранилище вкладки Safari —
  /// сотрёт его iPhone через неделю без игры, сотрёт и прогресс, и тогда
  /// подсказка покажется снова по делу.
  static const homeScreenHint = 'home_screen_hint';
}
