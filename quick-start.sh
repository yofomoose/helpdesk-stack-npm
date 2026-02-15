#!/bin/bash
# ============================================================
# БЫСТРЫЙ СТАРТ - Первое развертывание системы
# ============================================================

set -e

echo ""
echo "=========================================="
echo "  GLPI + Chatwoot - Быстрый старт"
echo "=========================================="
echo ""

# 1. Проверка .env
if [ -f .env ]; then
    echo "✅ Файл .env найден"
else
    echo "📝 Создание .env из шаблона..."
    cp .env.example .env
    echo ""
    echo "⚠️  ВАЖНО: Отредактируйте .env файл!"
    echo ""
    echo "Сгенерируйте секреты:"
    echo "  openssl rand -hex 64        # CHATWOOT_SECRET_KEY_BASE"
    echo "  openssl rand -base64 24     # Пароли"
    echo ""
    echo "Затем запустите: ./quick-start.sh"
    exit 0
fi

# 2. Проверка Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен!"
    exit 1
fi

echo "✅ Docker установлен"

# 3. Создание директорий
mkdir -p backups
echo "✅ Директории созданы"

# 4. Запуск баз данных
echo ""
echo "🚀 Запуск баз данных..."
docker compose up -d glpi_db chatwoot_db chatwoot_redis

# 5. Ожидание инициализации
echo ""
echo "⏳ Ожидание инициализации баз данных (60 сек)..."
for i in {60..1}; do
    echo -ne "\r   Осталось: $i сек   "
    sleep 1
done
echo ""

# 6. Проверка health
echo ""
echo "🔍 Проверка здоровья БД..."
for i in {1..10}; do
    if docker ps | grep -q "healthy.*glpi_db" && \
       docker ps | grep -q "healthy.*chatwoot_db" && \
       docker ps | grep -q "healthy.*chatwoot_redis"; then
        echo "✅ Все базы данных готовы"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "⚠️  Базы данных еще инициализируются, продолжаем..."
    fi
    sleep 5
done

# 7. Миграции Chatwoot
echo ""
echo "🔄 Выполнение миграций Chatwoot..."
docker compose run --rm chatwoot bundle exec rails db:chatwoot_prepare

# 8. Запуск всех сервисов
echo ""
echo "🚀 Запуск всех сервисов..."
docker compose up -d

# 9. Финишная проверка
echo ""
echo "⏳ Ожидание запуска сервисов (30 сек)..."
sleep 30

echo ""
echo "=========================================="
echo "  ✅ УСТАНОВКА ЗАВЕРШЕНА!"
echo "=========================================="
echo ""
echo "📊 Статус сервисов:"
docker compose ps
echo ""
echo "🌐 Настройте NPM (Nginx Proxy Manager):"
echo ""
echo "  GLPI:"
echo "    Domain:    glpi.yapomogu.com"
echo "    Forward:   glpi:80"
echo "    WebSocket: OFF"
echo ""
echo "  Chatwoot:"
echo "    Domain:    chat.yapomogu.com"
echo "    Forward:   chatwoot:3000"
echo "    WebSocket: ON ✅ (обязательно!)"
echo ""
echo "🔐 Первый вход:"
echo ""
echo "  GLPI:     https://glpi.yapomogu.com"
echo "            → Следуйте мастеру установки"
echo "            → После установки выполните:"
echo "              docker exec glpi rm /var/www/html/install/install.php"
echo ""
echo "  Chatwoot: https://chat.yapomogu.com"
echo "            → Создайте Super Admin аккаунт"
echo ""
echo "📖 Подробная документация: cat README.md"
echo ""
echo "🔧 Полезные команды:"
echo "  ./status.sh              # Проверить статус"
echo "  ./backup.sh              # Создать бэкап"
echo "  docker compose logs -f   # Смотреть логи"
echo ""
