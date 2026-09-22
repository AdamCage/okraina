# test-report.md — `<контур или прогон>`

Класс задачи: `<feature-cycle | increment | hotfix | …>`.
Раннер E2E / playtest — факт проекта, не канона.

## Что гоняли

| Слой | Команда / устройство | Результат |
|---|---|---|
| unit / integration | | pass / fail / skipped |
| E2E (user paths) | | pass / fail / skipped / нет раннера |
| playtest (ручной / device) | | pass / fail / skipped |

## User paths

| Путь из спеки | Платформа | Прогон | Заметка |
|---|---|---|---|
| | PC / mobile / both | | |

## Repro (hotfix / incident)

- Шаги / тест / устройство / build id:
- До: красное / краш
- После: зелёное / не воспроизвели

## Намеренно не гоняли

- (что и почему; для hotfix — полный playtest-пакет фичи нормально снять)

## Красное

Чинить. Не переносить сюда как known без accept человека.
