#!/bin/bash
# ============================================================
# INIT SCRIPT - Подготовка системы (Named Volumes)
# ============================================================
# Запуск: ./init.sh
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "  HELPDESK STACK - Initialization"
echo "========================================"
echo ""

# ----------------------------------------------------------
# Проверка .env файла
# ----------------------------------------------------------
if [ ! -f "${SCRIPT_DIR}/.env" ]; then
    echo "❌ Файл .env не найден!"
    echo ""
    echo "Создайте .env файл из шаблона:"
    echo "  cp .env.example .env"
    echo "  nano .env"
    echo ""
    echo "Сгенерируйте секреты:"
    echo "  openssl rand -hex 64        # CHATWOOT_SECRET_KEY_BASE"
    echo "  openssl rand -base64 24     # Пароли"
    echo ""
    exit 1
fi

echo "✅ .env файл найден"

# ----------------------------------------------------------
# Создание директории для бэкапов
# ----------------------------------------------------------
mkdir -p "${SCRIPT_DIR}/backups"
echo "✅ Директория backups создана"

# ----------------------------------------------------------
# Проверка Docker
# ----------------------------------------------------------
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен!"
    exit 1
fi

echo "✅ Docker установлен"

# ----------------------------------------------------------
# Создание volumes (автоматически при первом запуске)
# ----------------------------------------------------------
echo ""
echo "📦 Named Volumes будут созданы автоматически при запуске:"
echo "  - glpi_files, glpi_plugins, glpi_config, glpi_marketplace"
echo "  - glpi_db_data"
echo "  - chatwoot_storage, chatwoot_db_data, chatwoot_redis_data"
echo ""

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
echo "========================================"
echo "  Следующие шаги:"
echo "========================================"
echo ""
echo "  1. Запустите базы данных:"
echo "     docker compose up -d glpi_db chatwoot_db chatwoot_redis"
echo ""
echo "  2. Подождите инициализации (30-60 сек):"
echo "     docker compose logs -f glpi_db chatwoot_db"
echo ""
echo "  3. Выполните миграции Chatwoot (первый запуск):"
echo "     docker compose run --rm chatwoot bundle exec rails db:chatwoot_prepare"
echo ""
echo "  4. Запустите все сервисы:"
echo "     docker compose up -d"
echo ""
echo "  5. Проверьте статус:"
echo "     docker compose ps"
echo "     ./status.sh"
echo ""
echo "  6. Настройте NPM proxy hosts:"
echo "     - glpi.yapomogu.com  → glpi:80"
echo "     - chat.yapomogu.com  → chatwoot:3000 (WebSocket: ON)"
echo ""
echo "  7. После установки GLPI удалите installer:"
echo "     docker exec glpi rm /var/www/html/install/install.php"
echo ""
