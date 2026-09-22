# Ревью изменений Godot game

Агент сверяет diff с этим списком после
`<sdlc-root>/process/review.md`. Сначала блокеры, потом стиль.

## Блокеры

- [ ] Реализация не шире спеки / must-scope.
- [ ] User paths из спеки покрыты тестами или playtest-записью
      (для класса, который их требует).
- [ ] Платформы из контракта учтены; нет скрытого «mobile later»
      при label/спеке `both`.
- [ ] Performance budget целевого profile не пробит (или есть accept).
- [ ] Save / economy миграции описаны, если менялся формат.
- [ ] Секреты, keystore, provisioning, tokens не в diff;
      пароли не в `export_presets.cfg`.
- [ ] Краш/assert из repro закрыт (hotfix) или не введён заново.
- [ ] Изменился граф сцен/нод/сигналов/autoload — обновлён
      `ARCHITECTURE.md`.
- [ ] Изменилось обещание механики/UX — обновлён дизайн-срез.
- [ ] Не нарушен проектный `<game-root>/AGENTS.md` (версия Godot,
      язык GDScript/C#, пути).
- [ ] Export reproducibility: нужные presets/feature tags/плагины
      учтены, если трогали shipping path.

## Дизайн / UX / playtest

- [ ] Дизайн-критика закрыта или accepted в assumptions.
- [ ] UX-поток не блокирует игрока softlock-ом на must-path.
- [ ] Accessibility/input: заявленные устройства работают на must-path
      (InputMap, touch vs mouse).
- [ ] Playtest-замечания с фактами (шаги, build id / editor), не чистый вкус.
- [ ] Сломанные ссылки на сцены/ресурсы/uid не оставлены «починим потом».

## Платформы

- [ ] Mobile lifecycle (resume/background) учтён, если трогали session.
- [ ] Safe area / orientation — если трогали UI mobile.
- [ ] PC focus/alt-tab — если трогали pause/menu.
- [ ] Store/IAP ids не хардкодят секреты; контракт согласован.
- [ ] Android / iOS signing path не сломан правкой export, если в scope.

## Стиль

- [ ] Имена стабильны, как в [style.md](style.md) (сцены, ноды, `.gd`).
- [ ] Нет narrating-комментариев и emoji.
- [ ] Нет «god node», смешивающего store hooks и правила механики
      без нужды (см. [layout.md](layout.md)).
- [ ] Сигналы используются осознанно; нет скрытых глобальных мутаций
      вместо контракта без причины.

## Проектный слой

- [ ] Не задет чужой канон (live-ops сервис, отдельный античит) —
      для них свои `AGENTS.md`.

Формат замечаний: сначала что сломается у игрока или на device,
потом расхождение с каноном, потом вкус. Не предлагать смену движка
без запроса.
