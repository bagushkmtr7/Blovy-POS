#!/data/data/com.termux/files/usr/bin/bash
set -e

TARGET="${1:-all}"
cd ~/kasir_pos

build_pos() {
  echo "[BLOVY POS] Building web (/pos/)..."
  flutter build web --release -t lib/main_pos.dart --base-href /pos/
  rm -rf ~/blovy_server/web_pos
  cp -r build/web ~/blovy_server/web_pos
}

build_sis() {
  echo "[BLOVY SIS] Building web (/sis/)..."
  flutter build web --release -t lib/main_sis.dart --base-href /sis/
  rm -rf ~/blovy_server/web_sis
  cp -r build/web ~/blovy_server/web_sis
}

case "$TARGET" in
  pos)
    build_pos
    ;;
  sis)
    build_sis
    ;;
  all)
    build_pos
    build_sis
    ;;
  *)
    echo "Pakai: ./hot-web.sh [pos|sis|all]"
    exit 1
    ;;
esac

echo "[SERVER] Hot restarting blovy_db on port 8085..."
termux-wake-lock
tmux kill-session -t blovy_db 2>/dev/null || true
tmux new-session -d -s blovy_db "cd ~/blovy_server && python server.py"
sleep 1
curl -s http://127.0.0.1:8085/api/health && echo ""
echo "[DONE] Web app ($TARGET) sudah ter-restart di http://localhost:8085/"
