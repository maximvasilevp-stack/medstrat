#!/bin/zsh
# Пересобирает веб-версию и отправляет её на GitHub Pages (https://maximvasilevp-stack.github.io/medstrat/).
set -e
cd "$(dirname "$0")/.."
echo "Собираю веб-версию..."
godot --headless --path . --export-release Web docs/play.html > /tmp/medstrat-export.log 2>&1
echo "Прогоняю тесты..."
perl -e 'alarm 600; exec @ARGV' -- godot --headless --path . -s tests/run_tests.gd 2>&1 | grep -E "^tests:|^FAIL" || true
git add -A
if git diff --cached --quiet; then
  echo "Изменений нет, отправлять нечего."
else
  git commit -q -m "web build $(date '+%Y-%m-%d %H:%M')"
fi
git push origin main
echo "Готово: через минуту обновится https://maximvasilevp-stack.github.io/medstrat/"
