#!/bin/bash
# ============================================================
# BACKUP SCRIPT | GLPI + Chatwoot | yapomogu.com (Named Volumes)
# ============================================================
# Запуск:  ./backup.sh
# Cron:    0 3 * * * /opt/helpdesk/backup.sh >> /var/log/helpdesk-backup.log 2>&1
# ============================================================

set -e

# Настройки
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/backups"
DATE=$(date +%Y-%m-%d_%H-%M)
RETENTION_DAYS=14

# Загрузка переменных из .env
if [ -f "${SCRIPT_DIR}/.env" ]; then
    export $(grep -v '^#' "${SCRIPT_DIR}/.env" | xargs)
fi

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')]${NC} $1"; exit 1; }

# ============================================================
# ПРОВЕРКИ
# ============================================================

if ! docker ps | grep -q v2_glpi_db; then
    error "Контейнер v2_glpi_db не запущен!"
fi

if ! docker ps | grep -q v2_chatwoot_db; then
    error "Контейнер v2_chatwoot_db не запущен!"
fi

mkdir -p "${BACKUP_DIR}/${DATE}"
CURRENT_BACKUP="${BACKUP_DIR}/${DATE}"

log "=========================================="
log "  BACKUP STARTED: ${DATE}"
log "=========================================="

# ============================================================
# GLPI DATABASE
# ============================================================

log "GLPI: Создание дампа базы данных..."
docker exec v2_glpi_db mysqldump \
    -u"${GLPI_DB_USER}" \
    -p"${GLPI_DB_PASSWORD}" \
    --single-transaction \
    --quick \
    --lock-tables=false \
    "${GLPI_DB_NAME}" > "${CURRENT_BACKUP}/glpi_database.sql"

if [ -s "${CURRENT_BACKUP}/glpi_database.sql" ]; then
    log "   OK: glpi_database.sql ($(du -h "${CURRENT_BACKUP}/glpi_database.sql" | cut -f1))"
else
    error "   FAIL: Ошибка дампа GLPI!"
fi

# ============================================================
# GLPI VOLUMES
# ============================================================

log "GLPI: Бэкап volumes..."

# Функция для бэкапа volume
backup_volume() {
    local volume_name=$1
    local backup_file=$2
    
    docker run --rm \
        -v "${volume_name}:/data:ro" \
        -v "${CURRENT_BACKUP}:/backup" \
        alpine tar czf "/backup/${backup_file}" -C /data .
}

backup_volume "v2_glpi_files" "glpi_files.tar.gz"
backup_volume "v2_glpi_config" "glpi_config.tar.gz"
backup_volume "v2_glpi_plugins" "glpi_plugins.tar.gz"
backup_volume "v2_glpi_marketplace" "glpi_marketplace.tar.gz"

log "   OK: GLPI volumes backed up"

# ============================================================
# CHATWOOT DATABASE
# ============================================================

log "Chatwoot: Создание дампа базы данных..."
docker exec v2_chatwoot_db pg_dump \
    -U "${CHATWOOT_DB_USER}" \
    -d "${CHATWOOT_DB_NAME}" \
    --no-owner \
    --no-acl \
    > "${CURRENT_BACKUP}/chatwoot_database.sql"

if [ -s "${CURRENT_BACKUP}/chatwoot_database.sql" ]; then
    log "   OK: chatwoot_database.sql ($(du -h "${CURRENT_BACKUP}/chatwoot_database.sql" | cut -f1))"
else
    error "   FAIL: Ошибка дампа Chatwoot!"
fi

# ============================================================
# CHATWOOT VOLUMES
# ============================================================

log "Chatwoot: Бэкап storage..."
backup_volume "v2_chatwoot_storage" "chatwoot_storage.tar.gz"
    -C "${DATA_DIR}/chatwoot" \
    storage 2>/dev/null || true
log "   OK: chatwoot_storage.tar.gz ($(du -h "${CURRENT_BACKUP}/chatwoot_storage.tar.gz" | cut -f1))"

# ============================================================
# CONFIG
# ============================================================

log "Копирование конфигурации..."
cp "${SCRIPT_DIR}/docker-compose.yml" "${CURRENT_BACKUP}/" 2>/dev/null || true
cp "${SCRIPT_DIR}/.env" "${CURRENT_BACKUP}/" 2>/dev/null || true

# ============================================================
# ФИНАЛЬНЫЙ АРХИВ
# ============================================================

log "Создание финального архива..."
cd "${BACKUP_DIR}"
tar -czf "backup_${DATE}.tar.gz" "${DATE}/"
rm -rf "${DATE}/"

FINAL_SIZE=$(du -h "${BACKUP_DIR}/backup_${DATE}.tar.gz" | cut -f1)

# ============================================================
# ОЧИСТКА СТАРЫХ
# ============================================================

log "Удаление бэкапов старше ${RETENTION_DAYS} дней..."
find "${BACKUP_DIR}" -name "backup_*.tar.gz" -mtime +${RETENTION_DAYS} -delete

# ============================================================
# ИТОГ
# ============================================================

TOTAL_BACKUPS=$(ls -1 "${BACKUP_DIR}"/backup_*.tar.gz 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sh "${BACKUP_DIR}" 2>/dev/null | cut -f1)

echo ""
log "=========================================="
log "  BACKUP COMPLETED"
log "=========================================="
echo ""
echo "  Файл:     backup_${DATE}.tar.gz"
echo "  Размер:   ${FINAL_SIZE}"
echo "  Путь:     ${BACKUP_DIR}/backup_${DATE}.tar.gz"
echo ""
echo "  Всего бэкапов: ${TOTAL_BACKUPS}"
echo "  Общий размер:  ${TOTAL_SIZE}"
echo ""
