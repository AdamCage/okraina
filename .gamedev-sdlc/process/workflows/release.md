# release — версия и поставка

Отдельный класс. Не хвост `feature-cycle`. Стартовать только если
человек попросил ship / версию / тег / GitHub Release / store submit.

Роль: [../roles/releaser.md](../roles/releaser.md).
Платформы: [../../game/platforms.md](../../game/platforms.md).

## Шаги

1. **Подтвердить просьбу и контур.**
   Что релизим (канон, игра, пакет). Какие платформы (PC / mobile / обе).
   Какая схема версий у проекта. Если в корневом `AGENTS.md` `release`
   выключен — стоп.

2. **Проверить, что цикл закрыт.**
   На поставляемом контуре: блокеров ревью 0, `test-report.md` есть,
   открытых аналитических блокеров нет. Иначе — не релизить,
   вернуть в тот класс, который не доделан.

3. **Собрать `release.md`.**
   Шаблон [../templates/release.md](../templates/release.md):
   что вошло, совместимость, PC и mobile пути, как откатить,
   ссылка на проверки. Не копипастить процесс-принципы.

4. **Версия.**
   Правило проекта (semver / store versionCode / календарь). Нет тегов
   и нет правила — спросить. Не переписывать уже существующий тег.

5. **GitHub Release.**
   `git tag` + `gh release create` с notes из `release.md`.
   Приложить артефакты, если проект так делает и секреты позволяют.
   Force-push тега — гейт. См. [../github.md](../github.md).

6. **Платформенные пути.**
   - **PC:** Godot export presets (Windows / Linux / macOS) →
     Steam / itch / Microsoft Store / installer — только команды
     из проектного `AGENTS.md`.
   - **Mobile:** Godot Android (и iOS, если в scope) → App Store /
     Google Play tracks, certificates, listings — только команды
     проекта; гейт на public submit.
   Чеклист: [../../game/templates/RELEASE.store.md](../../game/templates/RELEASE.store.md).

7. **Проверка.**
   Тег указывает на нужный SHA. GitHub Release открывается.
   Store console показывает ожидаемый build (если ship просили).

8. **Не выкатывать молча.**
   Выкат среды / track без release notes — [deploy.md](deploy.md),
   если его тоже попросили или проект считает release = deploy
   (тогда это должно быть написано в `AGENTS.md` продукта).

9. **Issue / milestone.**
   Закрыть milestone при полном ship; иначе отметить частичный
   (например PC yes / mobile later) явно в `release.md`.

## Артефакты

Обязателен `release.md` + тег/GitHub Release, как принято в проекте.
Store listing / сертификаты — факты проекта, не канона.

## Чего не делать

- Не тащить «ещё один фикс» в релизный diff.
- Не релизить с красным отчётом «потом догоним».
- Не менять conflict rules канона в релизе.
- Не публиковать unsigned / неправильно подписанный mobile build в store.
