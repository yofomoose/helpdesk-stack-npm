#!/bin/bash
# ============================================================
# STATUS CHECK | GLPI + Chatwoot | yapomogu.com (Named Volumes)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "=========================================="
echo "  СТАТУС СЕРВИСОВ"
echo "=========================================="
echo ""

docker compose ps

echo ""
echo "=========================================="
echo "  DOCKER VOLUMES"
echo "=========================================="
echo ""

echo "GLPI:"
docker volume ls | grep glpi | sed 's/^/  /'

echo ""
echo "Chatwoot:"
docker volume ls | grep chatwoot | sed 's/^/  /'

echo ""
echo "Размеры volumes:"
docker system df -v | grep -E "(glpi|chatwoot)" | sed 's/^/  /'

echo ""
echo "=========================================="
echo "  БЭКАПЫ"
echo "=========================================="
echo ""

BACKUP_COUNT=$(ls -1 "${SCRIPT_DIR}/backups/"backup_*.tar.gz 2>/dev/null | wc -l)
BACKUP_SIZE=$(du -sh "${SCRIPT_DIR}/backups" 2>/dev/null | cut -f1)

echo "Количество: ${BACKUP_COUNT}"
echo "Общий размер: ${BACKUP_SIZE}"
echo ""
echo "Последние 5:"
ls -lht "${SCRIPT_DIR}/backups/"backup_*.tar.gz 2>/dev/null | head -5 | sed 's/^/  /'

echo ""
echo "=========================================="
echo "  HEALTH STATUS"
echo "=========================================="
echo ""

docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(glpi|chatwoot)" || echo "Контейнеры не запущены"

echo ""
echo "=========================================="
echo "  ЛОГИ (последние ошибки)"
echo "=========================================="
echo ""

echo "GLPI:"
docker logs glpi 2>&1 | grep -i error | tail -3 | sed 's/^/  /' || echo "  Ошибок нет"

echo ""
echo "Chatwoot:"
docker logs chatwoot 2>&1 | grep -i error | tail -3 | sed 's/^/  /' || echo "  Ошибок нет"

echo ""
