# ROADMAP.md — индекс этапов

Исполняемый контракт: [`docs/program/spec.md`](../program/spec.md).
Допущения: [`docs/program/assumptions.md`](../program/assumptions.md).

Прежняя цепочка R1 (сборки) → A1 здесь больше не живёт.
Маппинг старых id — в spec, раздел «Соответствие прежнему ROADMAP».

## Сейчас

Greybox на `main`: квартира → три этажа → melee → смерть или выход →
один boon → строка ЖЭКа и `/pod/` → осмотр двери.
Lore bible v0.1: `docs/world/`. Дискового save нет.

## Следующий шаг

**E1 — бой, который читается.** Класс `feature-cycle`.
Артефакты: `game/docs/combat_feel/`.

Не начинать E2 и не включать класс `release`.

## Порядок

```text
E1 → E2 → E3 → E4 → E5 → E6 → E7 → E8 → E9 → E10 → E11
```

| ID | Класс | Суть |
|---|---|---|
| E1 | `feature-cycle` | Телеграф, одно защитное действие, видимый удар; форма ввода записана для touch |
| E2 | `feature-cycle` | Выбор из 3 офферов внутри забега |
| E3 | `increment` | ≥6 пресетов; сравниваются id пресетов, не сам seed |
| E4 | `feature-cycle` | Один слот `user://` |
| E5 | `feature-cycle` | `/pod/` и заготовка `/hr/`: лид сверется с итогом забега, не с тайной мира |
| E6 | `increment` | Объявление ЖЭКа действует на следующий забег |
| E7 | `feature-cycle` | Дверь → копия квартиры ~2003 и ПК 2002; до кода человек снимает B1 |
| E8 | `feature-cycle` | Пороги Восприятия |
| E9 | `feature-cycle` | Своя картинка и звук вместо greybox |
| E10 | `feature-cycle` | Пауза и три забега на Windows держат планку |
| E11 | `feature-cycle` | Android: палец на эмуляторе или устройстве, resume, preset без секретов |

По событию, не вместо этапа: `hotfix`, `review-only`, `admin`.
`deploy`, `incident`, `release` в план не входят.
