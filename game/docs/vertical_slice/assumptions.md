# assumptions.md — vertical_slice

| ID | Допущение | Статус | Кто снял |
|---|---|---|---|
| S1 | Placeholder-арт (ColorRect / простые Shape) ок для acceptance. | accepted | slice |
| S2 | Один этаж-арена ≈ 24×18 тайлов логики; 4–8 врагов. | accepted | slice |
| S3 | Одна атака melee hitbox; без оружия/лута в slice. | accepted | slice |
| S4 | Нет save между сессиями в slice (состояние только runtime). | accepted | slice |
| S5 | Русский UI-текст. | accepted | product |
| **SLICE-B1** | AUTHOR TRUTH остаётся **UNSET**. Для slice: улики не выбирают «правильную» теорию; крючок двери — только странность быта. **Не** locked AUTHOR MODEL. | accepted (working for slice) | user override continue |
| **SLICE-B2** | Город без канонического топонима; в UI — «Город» / «ЭЖК №17». | accepted (working for slice) | user override continue |
| **SLICE-B3** | Hub slice = **квартира**. Поезд не в slice (не metaphysics, не hub). | accepted (working for slice) | user override continue |
| S6 | Critic human-gate обойдён по явному «не останавливайся» пользователя; замечания фиксируем в review, блокеры slice снимаем working assumptions. | accepted | user override |
| INC1 | Три этажа: «обычные» / «смещение» / «техзона» — hand-authored layouts, не один клон. | accepted | increment |
| INC2 | Meta-boon выбирается на result screen и применяется в следующем `go_run`. | accepted | increment |
| INC3 | Imageboard в hub — текстовый блок `/pod/`, не полноценный клиент борды. | accepted | increment |

B1–B3 в `docs/world/` **не закрыты** человеком; STATUS AUTHOR TRUTH не меняем на LOCKED.
