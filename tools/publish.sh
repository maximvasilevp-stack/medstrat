#!/bin/zsh
# Публикует сайт с игрой в интернет с этого Mac по временной ссылке (без аккаунтов).
# Запуск:  ~/Projects/medstrat/tools/publish.sh
# Ссылка вида https://xxxx.trycloudflare.com работает, пока это окно терминала открыто.
DIR="$(cd "$(dirname "$0")/.." && pwd)/docs"
PORT=8765
LOG=/tmp/medstrat-tunnel.log
if ! command -v cloudflared >/dev/null; then
  echo "Нужна программа cloudflared: brew install cloudflared"; exit 1
fi
if ! lsof -i :$PORT >/dev/null 2>&1; then
  (cd "$DIR" && python3 -m http.server $PORT >/dev/null 2>&1 &)
  sleep 1
fi
echo "Сайт запущен локально: http://localhost:$PORT"
echo "Открываю публичную ссылку, подождите несколько секунд... (Ctrl+C — закрыть)"
cloudflared tunnel --url http://localhost:$PORT > "$LOG" 2>&1 &
TUN=$!
url=""
for i in {1..60}; do
  url=$(grep -a -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$LOG" | head -1)
  [ -n "$url" ] && break
  sleep 1
done
if [ -n "$url" ]; then
  echo ""
  echo "ПУБЛИЧНАЯ ССЫЛКА: $url"
  echo "Отправьте её другу. Ссылка живёт, пока открыто это окно."
  echo ""
else
  echo "Не удалось получить ссылку, смотрите $LOG"
fi
wait $TUN
