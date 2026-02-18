#!/bin/bash
# ============================================================
# БЫСТРАЯ УСТАНОВКА АВТОБЭКАПА
# ============================================================

echo "🔧 Настройка автоматического бэкапа каждые 3 часа..."

# 1. Проверка скрипта
if [ ! -f "./backup.sh" ]; then
    echo "❌ Файл backup.sh не найден!"
    exit 1
fi

# 2. Права на выполнение
chmod +x backup.sh
echo "✅ Права на backup.sh установлены"

# 3. Создание директории для логов
sudo touch /var/log/helpdesk-backup.log 2>/dev/null || touch /var/log/helpdesk-backup.log
sudo chmod 666 /var/log/helpdesk-backup.log 2>/dev/null || chmod 666 /var/log/helpdesk-backup.log
echo "✅ Лог файл создан: /var/log/helpdesk-backup.log"

# 4. Получение текущего пути
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backup.sh"
echo "📁 Путь к скрипту: ${SCRIPT_PATH}"

# 5. Настройка cron
CRON_LINE="0 */3 * * * ${SCRIPT_PATH} >> /var/log/helpdesk-backup.log 2>&1"

# Проверка, не добавлено ли уже
if crontab -l 2>/dev/null | grep -q "${SCRIPT_PATH}"; then
    echo "⚠️  Cron задание уже существует!"
    echo ""
    echo "Текущие задания:"
    crontab -l | grep backup
else
    # Добавление в cron
    (crontab -l 2>/dev/null; echo "${CRON_LINE}") | crontab -
    echo "✅ Cron задание добавлено"
fi

echo ""
echo "=========================================="
echo "  НАСТРОЙКА ЗАВЕРШЕНА"
echo "=========================================="
echo ""
echo "📋 Расписание: Каждые 3 часа (00:00, 03:00, 06:00, ...)"
echo "📁 Бэкапы: $(pwd)/backups/"
echo "📄 Логи: /var/log/helpdesk-backup.log"
echo ""
echo "🧪 Тестовый запуск:"
echo "   ./backup.sh"
echo ""
echo "📊 Просмотр заданий cron:"
echo "   crontab -l"
echo ""
echo "📝 Просмотр логов:"
echo "   tail -f /var/log/helpdesk-backup.log"
echo ""

# 6. Предложение тестового запуска
read -p "Запустить тестовый бэкап сейчас? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Запуск бэкапа..."
    ./backup.sh
fi
