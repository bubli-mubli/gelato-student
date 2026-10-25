#!/usr/bin/env bash
# Собирает агента для OpenCode (V2 и V1) и режим для Claude Code из одного текста agents/core.md.
# Запуск после правки agents/core.md: ./scripts/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SKILLS=(gelato-hints gelato-review gelato-debug gelato-explain gelato-teach-back gelato-practice gelato-progress)
# Команды запуска кода и тестов — без подтверждения (последнее совпавшее правило побеждает)
RUN=("git status*" "git diff*" "git log*" "npm test*" "npm run test*" "npm start*" "pnpm test*" "yarn test*" "bun test*"
  "npx vitest*" "npx jest*" "node *" "python *" "python3 *" "pytest*" "go run *" "go test*" "cargo run*" "cargo test*"
  "dotnet run*" "dotnet test*" "mvn test*" "./mvnw test*" "gradle test*" "./gradlew test*" "php *" "ruby *")
DESC="Учебный режим Gelato Student — подсказывает по ступеням, проверяет и объясняет, а код пишешь ты."

mkdir -p agents/opencode agents/opencode-v1 claude

{
  echo "---"
  echo "description: $DESC"
  echo "mode: primary"
  echo 'color: "#FED453"'
  echo "permissions:"
  for a in read glob grep list; do printf '  - action: %s\n    resource: "*"\n    effect: allow\n' "$a"; done
  echo "  # правки — только с подтверждения ученика, кроме дневника учёбы"
  printf '  - action: edit\n    resource: "*"\n    effect: ask\n'
  printf '  - action: edit\n    resource: ".gelato/*"\n    effect: allow\n'
  printf '  - action: shell\n    resource: "*"\n    effect: ask\n'
  for c in "${RUN[@]}"; do printf '  - action: shell\n    resource: "%s"\n    effect: allow\n' "$c"; done
  printf '  - action: skill\n    resource: "*"\n    effect: ask\n'
  for s in "${SKILLS[@]}"; do printf '  - action: skill\n    resource: "%s"\n    effect: allow\n' "$s"; done
  echo "---"
  echo
  cat agents/core.md
} >agents/opencode/gelato-student.md

{
  echo "---"
  echo "description: $DESC"
  echo "mode: primary"
  echo 'color: "#FED453"'
  echo "permission:"
  echo "  read: allow"
  echo "  glob: allow"
  echo "  grep: allow"
  echo "  list: allow"
  echo "  edit: ask"
  echo "  bash:"
  echo '    "*": ask'
  for c in "${RUN[@]}"; do printf '    "%s": allow\n' "$c"; done
  echo "  skill:"
  echo '    "*": ask'
  for s in "${SKILLS[@]}"; do printf '    "%s": allow\n' "$s"; done
  echo "---"
  echo
  cat agents/core.md
} >agents/opencode-v1/gelato-student.md

{
  echo "---"
  echo "name: Gelato Student"
  echo "description: $DESC"
  echo "keep-coding-instructions: true"
  echo "---"
  echo
  cat agents/core.md
  echo
  echo "## Claude Code"
  echo
  echo "- Скиллы набора лежат в ~/.claude/skills (gelato-*): загружай нужный по таблице выше."
  echo "- Правки файлов ученика — только по его прямой просьбе, даже если инструмент правки разрешён без подтверждения."
} >claude/gelato-student.md

echo "✓ agents/opencode/gelato-student.md, agents/opencode-v1/gelato-student.md, claude/gelato-student.md"
