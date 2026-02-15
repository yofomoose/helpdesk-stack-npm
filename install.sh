#!/bin/bash
# ============================================================
# УСТАНОВКА GLPI + Chatwoot | yapomogu.com
# ============================================================

set -e

echo "=========================================="
echo "  GLPI + Chatwoot - Установка"
echo "=========================================="

# 0. Проверка .env
if [ ! -f .env ]; then
    echo ""
    echo "❌ Файл .env не найден!"
    echo "Скопируйте .env.example в .env и заполните переменные."
    exit 1
fi

# 1. Создать папки
echo ""
echo "[1/4] Проверка окружения..."
mkdir -p backups

# 2. Volumes создаются автоматически
echo "[2/4] Docker volumes будут созданы автоматически..."

# 3. Запуск БД
echo "[3/4] Запуск баз данных..."
docker compose up -d glpi_db chatwoot_db chatwoot_redis

echo ""
echo "Ожидание инициализации БД (40 сек)..."
sleep 40

# 4. Миграции Chatwoot
echo "[4/4] Миграции Chatwoot..."
docker compose run --rm chatwoot bundle exec rails db:chatwoot_prepare

# 5. Запуск всех сервисов
echo ""
echo "Запуск всех сервисов..."
docker compose up -d

echo ""
echo "=========================================="
echo "  ✅ УСТАНОВКА ЗАВЕРШЕНА"
echo "=========================================="
echo ""
echo "📋 ДАННЫЕ ДЛЯ ВХОДА:"
echo ""
echo "┌─────────────────────────────────────────┐"
echo "│ GLPI (glpi.yapomogu.com)                │"
echo "├─────────────────────────────────────────┤"
echo "│ При первом входе откроется установщик   │"
echo "│ DB Server: glpi_db                      │"
echo "│ DB Name:   glpi (из .env)               │"
echo "│ DB User:   glpi (из .env)               │"
echo "│ DB Pass:   (из .env)                    │"
echo "└─────────────────────────────────────────┘"
echo ""
echo "┌─────────────────────────────────────────┐"
echo "│ Chatwoot (chat.yapomogu.com)            │"
echo "├─────────────────────────────────────────┤"
echo "│ Создайте Super Admin при первом входе   │"
echo "└─────────────────────────────────────────┘"
echo ""
echo "📌 NPM НАСТРОЙКИ:"
echo ""
echo "GLPI:"
echo "  Domain:    glpi.yapomogu.com"
echo "  Hostname:  glpi"
echo "  Port:      80"
echo ""
echo "Chatwoot:"
echo "  Domain:    chat.yapomogu.com"
echo "  Hostname:  chatwoot"
echo "  Port:      3000"
echo "  WebSocket: ✅ ВКЛЮЧИТЬ!"
echo ""
echo "⚠️  После установки GLPI выполните:"
echo "    docker exec glpi rm /var/www/html/install/install.php"
echo ""
echo "📦 Volumes (используются named volumes):"
docker volume ls | grep -E "(glpi|chatwoot)" || true
echo ""
echo "Статус:"
docker compose ps
