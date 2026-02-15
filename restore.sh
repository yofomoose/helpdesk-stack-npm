#!/bin/bash
# ============================================================
# RESTORE SCRIPT | GLPI + Chatwoot | yapomogu.com (Named Volumes)
# ============================================================
# Запуск: ./restore.sh backup_2024-01-15_03-00.tar.gz
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/backups"

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
# ПРОВЕРКА АРГУМЕНТОВ
# ============================================================

BACKUP_FILE="${1:-}"

if [ -z "${BACKUP_FILE}" ]; then
    echo ""
    echo "Использование: $0 <backup_file.tar.gz>"
    echo ""
    echo "Доступные бэкапы:"
    ls -lht "${BACKUP_DIR}"/backup_*.tar.gz 2>/dev/null | head -10 || echo "  Бэкапы не найдены"
    echo ""
    exit 1
fi

if [ ! -f "${BACKUP_FILE}" ]; then
    if [ -f "${BACKUP_DIR}/${BACKUP_FILE}" ]; then
        BACKUP_FILE="${BACKUP_DIR}/${BACKUP_FILE}"
    else
        error "Файл не найден: ${BACKUP_FILE}"
    fi
fi

# ============================================================
# ПОДТВЕРЖДЕНИЕ
# ============================================================

echo ""
warn "ВНИМАНИЕ! Это действие ПЕРЕЗАПИШЕТ текущие данные:"
echo ""
echo "  - База данных GLPI"
echo "  - Volumes GLPI"
echo "  - База данных Chatwoot"
echo "  - Volumes Chatwoot"
echo ""
echo "Бэкап: ${BACKUP_FILE}"
echo ""
read -p "Продолжить? (yes/no): " CONFIRM

if [ "${CONFIRM}" != "yes" ]; then
    log "Отменено"
    exit 0
fi

# ============================================================
# РАСПАКОВКА
# ============================================================

log "=========================================="
log "  RESTORE STARTED"
log "=========================================="

TEMP_DIR=$(mktemp -d)
log "Распаковка архива..."
tar -xzf "${BACKUP_FILE}" -C "${TEMP_DIR}"

RESTORE_DIR=$(find "${TEMP_DIR}" -mindepth 1 -maxdepth 1 -type d | head -1)
if [ -z "${RESTORE_DIR}" ]; then
    rm -rf "${TEMP_DIR}"
    error "Некорректная структура архива!"
fi

# ============================================================
# ОСТАНОВКА СЕРВИСОВ
# ============================================================

log "Остановка сервисов..."
cd "${SCRIPT_DIR}"
docker compose stop glpi chatwoot chatwoot_sidekiq 2>/dev/null || true

# ============================================================
# RESTORE GLPI DATABASE
# ============================================================

if [ -f "${RESTORE_DIR}/glpi_database.sql" ]; then
    log "GLPI: Восстановление базы данных..."

    docker exec v2_glpi_db mysql -u root -p"${GLPI_DB_ROOT_PASSWORD}" -e "
        DROP DATABASE IF EXISTS ${GLPI_DB_NAME};
        CREATE DATABASE ${GLPI_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        GRANT ALL PRIVILEGES ON ${GLPI_DB_NAME}.* TO '${GLPI_DB_USER}'@'%';
        FLUSH PRIVILEGES;
    "

    docker exec -i v2_glpi_db mysql \
        -u"${GLPI_DB_USER}" \
        -p"${GLPI_DB_PASSWORD}" \
        "${GLPI_DB_NAME}" < "${RESTORE_DIR}/glpi_database.sql"

    log "   OK: База GLPI восстановлена"
else
    warn "   glpi_database.sql не найден, пропуск..."
fi

# ============================================================
# RESTORE GLPI VOLUMES
# ============================================================

restore_volume() {
    local backup_file=$1
    local volume_name=$2
    
    if [ -f "${RESTORE_DIR}/${backup_file}" ]; then
        log "Восстановление ${volume_name}..."
        docker run --rm \
            -v "${volume_name}:/data" \
            -v "${RESTORE_DIR}:/backup:ro" \
            alpine sh -c "rm -rf /data/* && tar xzf /backup/${backup_file} -C /data"
        log "   OK: ${volume_name} восстановлен"
    else
        warn "   ${backup_file} не найден, пропуск..."
    fi
}

log "GLPI: Восстановление volumes..."
restore_volume "glpi_files.tar.gz" "v2_glpi_files"
restore_volume "glpi_config.tar.gz" "v2_glpi_config"
restore_volume "glpi_plugins.tar.gz" "v2_glpi_plugins"
restore_volume "glpi_marketplace.tar.gz" "v2_glpi_marketplace"

# ============================================================
# RESTORE CHATWOOT DATABASE
# ============================================================

if [ -f "${RESTORE_DIR}/chatwoot_database.sql" ]; then
    log "Chatwoot: Восстановление базы данных..."

    docker exec v2_chatwoot_db psql -U "${CHATWOOT_DB_USER}" -d postgres -c "
        SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${CHATWOOT_DB_NAME}';
    " 2>/dev/null || true

    docker exec v2_chatwoot_db psql -U "${CHATWOOT_DB_USER}" -d postgres -c "
        DROP DATABASE IF EXISTS ${CHATWOOT_DB_NAME};
    " 2>/dev/null || true

    docker exec v2_chatwoot_db psql -U "${CHATWOOT_DB_USER}" -d postgres -c "
        CREATE DATABASE ${CHATWOOT_DB_NAME};
    "

    docker exec -i v2_chatwoot_db psql \
        -U "${CHATWOOT_DB_USER}" \
        -d "${CHATWOOT_DB_NAME}" < "${RESTORE_DIR}/chatwoot_database.sql"

    log "   OK: База Chatwoot восстановлена"
else
    warn "   chatwoot_database.sql не найден, пропуск..."
fi

# ============================================================
# RESTORE CHATWOOT VOLUMES
# ============================================================

log "Chatwoot: Восстановление storage..."
restore_volume "chatwoot_storage.tar.gz" "v2_chatwoot_storage"

# ============================================================
# ОЧИСТКА И ЗАПУСК
# ============================================================

log "Очистка временных файлов..."
rm -rf "${TEMP_DIR}"

log "Запуск сервисов..."
docker compose up -d
sleep 5

# ============================================================
# ИТОГ
# ============================================================

echo ""
log "=========================================="
log "  RESTORE COMPLETED"
log "=========================================="
echo ""
docker compose ps
echo ""
echo "Проверьте:"
echo "  - https://glpi2.yapomogu.com"
echo "  - https://chat2.yapomogu.com"
echo ""
