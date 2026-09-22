# RELEASE.store.md — `<версия>`

Чеклист store-поставки. Заполнять фактами проекта. Секреты не писать.

## Общее

- GitHub Release / tag:
- `release.md`:
- Платформы в этом ship:

## PC

- [ ] Godot export preset(ы) PC прошли (Windows / Linux / macOS по контракту)
- [ ] Smoke: boot + critical path на экспорте (не только editor)
- [ ] Depot / upload команда проекта выполнена
- [ ] Branch / visibility (default / beta) как просили
- [ ] Rollback path известен

Канал: Steam / itch / MS Store / other: `<…>`
Export preset:
Build id:

## Mobile — iOS

- [ ] Signing / profile из Secrets, не из git (путь Godot iOS export)
- [ ] Version / build number согласованы
- [ ] Internal (TestFlight) smoke на устройстве
- [ ] Privacy / permissions тексты актуальны
- [ ] Listing / screenshots обновлены если нужно
- [ ] Public submit — только с гейтом человека

Export preset:
Build number:
Track:

## Mobile — Android

- [ ] Keystore только в Secrets (не в `export_presets.cfg`)
- [ ] versionName / versionCode согласованы
- [ ] Godot Android export + internal / closed track smoke
- [ ] Data safety / permissions актуальны
- [ ] Listing / screenshots обновлены если нужно
- [ ] Production submit — только с гейтом человека

Export preset:
Build number:
Track:

## IAP / экономика (если затронуто)

- [ ] Product ids совпадают с контрактом
- [ ] Нет wipe / миграции без записи в `release.md`
- [ ] Гейт человека пройден

## Запрещено

- Публиковать unsigned / чужим сертификатом
- Печатать пароли keystore в логах Actions
- Смешивать новый gameplay без закрытого review cycle
