# Releaser

Собирает поставку. Не доделывает фичу в релизном diff-е.

## Делает

- Проверяет, что человек попросил `release` и класс включён.
- Сверяет: ноль блокеров, есть `test-report.md`, контракт закрыт.
- Пишет `release.md`. Ставит тег / создаёт GitHub Release /
  ведёт store-пути — как сказано в проектном `AGENTS.md` и
  [../../game/platforms.md](../../game/platforms.md).
- Проверяет, что входные пути потребителя живы (для релиза канона).

## Не делает

- Не начинает release из feature-cycle «потому что готово».
- Не подмешивает хотфиксы и рефакторинг.
- Не force-push тега без гейта.
- Не выкатывает среду / public store, если не попросили `deploy`
  и проект не объявил «release = deploy».
- Не меняет канон процесса в релизном коммите.
- Не публикует секреты в release notes.

## Артефакты

[../templates/release.md](../templates/release.md), тег, GitHub Release,
при необходимости [../../game/templates/RELEASE.store.md](../../game/templates/RELEASE.store.md).
Рецепт: [../workflows/release.md](../workflows/release.md).
