# Gelato Student

Учебный режим для ИИшек-помощников по коду — **OpenCode** и **Claude Code**. Наставник не пишет код за тебя: подсказывает по ступеням, проверяет, разбирает ошибки и объясняет. Код пишешь ты.

## Установка

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/bubli-mubli/gelato-student/main/install.sh | bash
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/bubli-mubli/gelato-student/main/install.ps1 | iex
```

Флаги: `--default` — включить режим по умолчанию, `--only opencode|claude`, `--uninstall`.

- **OpenCode** — Shift+Tab (в старых версиях Tab) → `gelato-student`.
- **Claude Code** — `/config` → Output style → **Gelato Student**.

## Что внутри

| Скилл | Когда | Что делает |
|---|---|---|
| `gelato-hints` | «застрял», «с чего начать» | Подсказки по 4 ступеням: направление → план → фрагмент → решение (только по просьбе) |
| `gelato-debug` | ошибка, «падает» | Учит читать ошибку самому: воспроизвести → место → гипотеза → проверка |
| `gelato-review` | «проверь» | Учебное ревью: не чинит, а спрашивает |
| `gelato-explain` | «объясни код» | По блокам или построчно, простым языком |
| `gelato-teach-back` | после решения | Ты объясняешь сам — наставник ищет пробелы |
| `gelato-practice` | «дай похожую» | Задача на закрепление с тестами |
| `gelato-progress` | «мой прогресс» | Дневник `.gelato/journal.md`: что умеешь, где проседаешь, что пора отдавать ИИшке |

Задачу, которую решал много раз, отдай ИИшке. Новую — пиши сам.

Примеры задач — в `examples/`. Агент собирается из `agents/core.md` командой `./scripts/build.sh`.

Лицензия MIT.
