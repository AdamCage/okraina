---
name: sdlc-evolve
description: >-
  Change this agentic SDLC canon: process/, evolve/, domain canons,
  root README/AGENTS, templates, .github/, or this repo's editor
  skills/rules. Not for product game code in another repository. Use
  when adding a domain, changing the router or conflict rules,
  tightening checklists, or lifting a pattern from a consumer project.
---

# Эволюция канона — skill

Сначала [AGENTS.md](AGENTS.md) и корневой [../AGENTS.md](../AGENTS.md).
Дальше одна строка:

| Задача | Читать |
|---|---|
| Новый предметный домен | `feature-cycle` + [workflows.md](workflows.md) (`new-domain`), [../process/new-domain.md](../process/new-domain.md), [templates/domain/](templates/domain/) |
| Новый подход SDLC (класс / роль / гейт / артефакт / конфликт / GitHub SoR) | `feature-cycle` + [workflows.md](workflows.md) (`new-approach`) |
| Формулировка, чеклист, дыра в существующем тексте | `increment` + [workflows.md](workflows.md) (`improve-existing`) |
| Поднять паттерн из продукта | `spec-only`, затем `increment` или `feature-cycle` + `lift-from-project` |
| Ревью PR канона | `review-only` + [review.md](review.md) |
| Проверить, что потребительский bootstrap жив | `review-only` + [../process/workflows/bootstrap-project.md](../process/workflows/bootstrap-project.md) |
| Ломающее переименование входа | `feature-cycle` + `breaking-entry-change`, гейт человека |
| Правка только `game/` без процесса | router + [../game/SKILL.md](../game/SKILL.md); этот файл — если меняется стык |

Не читать все файлы process «на всякий случай».
Не открывать продуктовые репозитории как источник имён для канона.
