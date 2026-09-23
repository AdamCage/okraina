# spec.md — vertical_slice

Источник истины поведения первого playable slice «Окраина».
Мир: [`docs/world/`](../../../docs/world/). Issue: https://github.com/AdamCage/okraina/issues/2

## Цель

Игрок на Windows запускает игру и проходит короткий цикл:
**квартира → подъезд гигахруща → top-down забег с боем → смерть или выход → возврат в квартиру**,
с намёком на «комнату за кухней». Placeholder-арт допустим.

## Граница

### Входит

- Godot 4.7 + GDScript проект в `game/`
- Сцены: Main → ApartmentHub → Entrance → RunFloor → Result
- Движение WASD/стрелки, атака ближняя (ЛКМ / Space), шаг в сторону (Shift) — см. [`../combat_feel/spec.md`](../combat_feel/spec.md)
- В начале этажа выбор одной находки из трёх — см. [`../run_builds/spec.md`](../run_builds/spec.md)
- 1 тип врага, спавн на этаже, HP игрока, смерть → restart hub
- Выход с этажа (дверь «на улицу/другой район») → успех → hub
- UI: HP, краткий статус этажа, объявление ЖЭКа (тон мира)
- Крючок: на кухне появляется/мигает контур двери («комната за кухней») после первого возврата

### Не входит

- Полноценный лут/билды/метапрокачка
- Имиджборда как UI-система
- Поезд-hub (SLICE-B3)
- AUTHOR TRUTH / разгадка тайны
- Android/iOS export, store, IAP
- Процедурная генерация всего гигахруща (один этаж-арена)

## Поведение

1. Старт: сцена квартиры. Можно выйти в подъезд (зона/кнопка).
2. Подъезд: короткий коридор → «войти на этаж» → RunFloor.
3. RunFloor: top-down; враги идут к игроку; игрок бьёт; HP≤0 → Result(death) → ApartmentHub.
4. На этаже есть зона EXIT; войти → Result(extract) → ApartmentHub; при первом extract включается крючок двери за кухней.
5. Дверь за кухней в slice: осмотр → текст («За кухней раньше не было двери.» / намёк на форум); без полноценного квеста 2002.
6. Тон UI: ЖЭК-канцелярит, не «BOSS FIGHT!!!».

## User paths

| Путь | Актор | Успех | Ошибка |
|---|---|---|---|
| VS1 Launch | Игрок | Окно Godot, видна квартира | Краш / пустой экран |
| VS2 Enter run | Игрок | Из квартиры → подъезд → этаж с врагами | Застревание без перехода |
| VS3 Combat | Игрок | Убить ≥1 врага атакой | Нельзя бить / враг бессмертен |
| VS4 Death | Игрок | HP=0 → текст смерти → квартира | Softlock |
| VS5 Extract | Игрок | EXIT → успех → квартира; дверь-крючок активна | Нет выхода / нет крючка |
| VS6 Hook | Игрок | Осмотр двери → lore-текст без спойлера AUTHOR | Спойлер «это симуляция» |

## Платформы

- PC: Windows — must
- Mobile: later
- Расхождения: нет в slice

## Дизайн-пакет

- [`DESIGN.md`](DESIGN.md)
- [`assumptions.md`](assumptions.md)
- Lore SoT: `docs/world/LORE.md` (не дублировать)

## Допущения

[`assumptions.md`](assumptions.md) — в т.ч. SLICE-* для B1–B3.

## GitHub

- Issue: https://github.com/AdamCage/okraina/issues/2
- Increment: https://github.com/AdamCage/okraina/issues/3

## Delta — increment multi-floor (Issue #3)

### Меняется

- Забег из **≥3 различных этажей** (layout / exit / враги / цвет)
- Переход этаж→этаж через жёлтую зону; extract только с последнего
- После death/extract — выбор **находки (boon)** на *следующую* попытку: урон / HP / скорость
- Hub: ЖЭК-лента и блок `/pod/` отражают последний забег; kitchen-door после extract
- Headless: boot, floors, kill, death, extract, meta, boon

### Не меняется

- AUTHOR TRUTH UNSET; B1–B3 не закрываем
- Нет Android/поезда/полного лут-Diablo
- Тон ЖЭКа / запрет спойлера тайны
