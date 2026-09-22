# test-report.md — vertical_slice (+ increment Issue #3)

Дата: 2026-09-22
Godot: `tools/godot/Godot_v4.7.2-stable_win64_console.exe` (4.7.2)

## Increment прогоны

| Прогон | Результат |
|---|---|
| `full_smoke.gd` | `FULL_SMOKE_OK` EXIT 0 — boot, F1/F2/F3 distinct, combat kill, extract+meta, boon, death+meta |
| `loop_smoke.gd` | `LOOP_SMOKE_OK` EXIT 0 |
| `--quit-after 3` | EXIT 0 |

### Exact lines (full_smoke)

```
FULL: boot ok
FULL: floor1 F1:e4:ex1120,120:bg0.17
FULL: floor2 F2:e6:ex1000,620:bg0.14
FULL: floor3 F3:e7:ex140,360:bg0.22
FULL: combat kill ok
FULL: extract+meta ok
FULL: boon next-attempt ok
FULL: death ok
FULL: death meta ok
FULL_SMOKE_OK
```

## User paths

| Path | Статус |
|---|---|
| VS1 Launch | OK |
| VS2 multi-floor | OK (3 fingerprints) |
| VS3 Combat kill | OK headless |
| VS4 Death | OK headless |
| VS5 Extract | OK |
| VS6 Hook + board/ЖЭК meta | OK |
| INC boon next run | OK |

## Намеренно нет

Android, audio, full campaign, AUTHOR resolve, train hub.
