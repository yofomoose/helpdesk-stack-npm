# Настройка автоматического бэкапа GLPI + Chatwoot

## 🔧 Установка

### 1. Подготовка скрипта

```bash
cd /opt/helpdesk
chmod +x backup.sh

# Проверка работы вручную
./backup.sh
```

### 2. Настройка cron (каждые 3 часа)

```bash
# Открыть crontab
crontab -e

# Добавить строку (бэкап каждые 3 часа)
0 */3 * * * /opt/helpdesk/backup.sh >> /var/log/helpdesk-backup.log 2>&1
```

**Расписание cron:**
- `0 */3 * * *` - каждые 3 часа (00:00, 03:00, 06:00, 09:00, 12:00, 15:00, 18:00, 21:00)
- `0 3 * * *` - раз в день в 03:00
- `0 */6 * * *` - каждые 6 часов
- `*/30 * * * *` - каждые 30 минут

### 3. Создание директории для логов

```bash
sudo touch /var/log/helpdesk-backup.log
sudo chmod 666 /var/log/helpdesk-backup.log
```

### 4. Проверка cron задания

```bash
# Список всех cron заданий
crontab -l

# Просмотр логов
tail -f /var/log/helpdesk-backup.log

# Проверка последних бэкапов
ls -lh /opt/helpdesk/backups/
```

## 📦 Что сохраняется

### GLPI
- ✅ База данных MySQL (`glpi_database.sql`)
- ✅ Файлы (`v2_glpi_files` volume)
- ✅ Конфигурация (`v2_glpi_config` volume)
- ✅ Плагины (`v2_glpi_plugins` volume)
- ✅ Marketplace (`v2_glpi_marketplace` volume)

### Chatwoot
- ✅ База данных PostgreSQL (`chatwoot_database.sql`)
- ✅ Storage файлы (`v2_chatwoot_storage` volume)

### Конфигурация
- ✅ docker-compose.yml
- ✅ .env

## 📊 Параметры

**Период хранения:** 14 дней  
**Расписание:** Каждые 3 часа  
**Путь к бэкапам:** `/opt/helpdesk/backups/`  
**Формат:** `backup_YYYY-MM-DD_HH-MM.tar.gz`

## 🔄 Ручной запуск

```bash
cd /opt/helpdesk
./backup.sh
```

## 📋 Просмотр статуса

```bash
# Последние бэкапы
ls -lht /opt/helpdesk/backups/ | head -10

# Размер директории бэкапов
du -sh /opt/helpdesk/backups/

# Количество бэкапов
ls -1 /opt/helpdesk/backups/*.tar.gz | wc -l

# Логи последнего бэкапа
tail -50 /var/log/helpdesk-backup.log
```

## ⚠️ Важно

1. **Место на диске**: Следите за свободным местом
   ```bash
   df -h /opt/helpdesk/backups/
   ```

2. **Тестирование**: Периодически проверяйте восстановление из бэкапа

3. **Удаленное хранение**: Рекомендуется копировать бэкапы на другой сервер
   ```bash
   # Пример синхронизации на удаленный сервер
   rsync -avz /opt/helpdesk/backups/ user@backup-server:/backups/helpdesk/
   ```

## 🔧 Troubleshooting

### Ошибка: контейнер не запущен
```bash
docker ps | grep v2_glpi_db
docker ps | grep v2_chatwoot_db
docker compose up -d
```

### Ошибка: нет прав на запись
```bash
chmod +x /opt/helpdesk/backup.sh
mkdir -p /opt/helpdesk/backups
chmod 755 /opt/helpdesk/backups
```

### Проверка cron запуска
```bash
# Смотрим системный лог cron
sudo tail -f /var/log/syslog | grep CRON

# Или
sudo tail -f /var/log/cron
```

### Тестовый запуск cron команды вручную
```bash
/opt/helpdesk/backup.sh >> /var/log/helpdesk-backup.log 2>&1
cat /var/log/helpdesk-backup.log
```
