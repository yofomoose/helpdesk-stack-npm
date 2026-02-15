# ⚡ БЫСТРАЯ ШПАРГАЛКА ДЛЯ СЕРВЕРА

## 🚀 Быстрый запуск (всё в одну команду)

```bash
cd /path/to/helpdesk-stack-npm && \
chmod +x *.sh && \
docker compose up -d glpi_db chatwoot_db chatwoot_redis && \
sleep 60 && \
docker compose run --rm chatwoot bundle exec rails db:chatwoot_prepare && \
docker compose up -d && \
docker compose ps
```

## 📋 Пошагово

```bash
# 1. Бэкап старой системы (ВАЖНО!)
cd /path/to/old-version && ./backup.sh

# 2. Загрузите файлы на сервер (scp, git pull, etc.)

# 3. Запуск БД
cd /path/to/helpdesk-stack-npm
chmod +x *.sh
docker compose up -d glpi_db chatwoot_db chatwoot_redis
sleep 60

# 4. Инициализация Chatwoot
docker compose run --rm chatwoot bundle exec rails db:chatwoot_prepare

# 5. Запуск всех сервисов
docker compose up -d

# 6. Проверка
docker compose ps
docker compose logs -f
```

## 🌐 NPM настройки

### GLPI2
- Domain: `glpi2.yapomogu.com`
- Forward: `v2_glpi:80`
- SSL: ✅ Let's Encrypt
- WebSocket: ❌ OFF

### Chat2
- Domain: `chat2.yapomogu.com`
- Forward: `v2_chatwoot:3000`
- SSL: ✅ Let's Encrypt
- WebSocket: ✅ ON ← ОБЯЗАТЕЛЬНО!

## 🔧 Полезные команды

```bash
# Статус
docker compose ps
./status.sh

# Логи
docker compose logs -f
docker logs v2_chatwoot --tail 100

# Рестарт
docker compose restart v2_chatwoot
docker compose restart v2_glpi

# Остановка/Запуск
docker compose stop
docker compose start

# Бэкап
./backup.sh

# Удалить GLPI installer после установки
docker exec v2_glpi rm /var/www/html/install/install.php
```

## ✅ После первого запуска

1. **GLPI** (https://glpi2.yapomogu.com):
   - Следуйте мастеру установки
   - DB Server: `glpi_db`
   - Удалите installer: `docker exec v2_glpi rm /var/www/html/install/install.php`

2. **Chatwoot** (https://chat2.yapomogu.com):
   - Создайте Super Admin аккаунт
   - Настройте первый Inbox

## 🆘 Если что-то не работает

```bash
# Проверьте логи на ошибки
docker compose logs | grep -i error

# Перезапустите проблемный контейнер
docker compose restart v2_chatwoot

# Полный рестарт
docker compose down && docker compose up -d

# Проверьте ресурсы
docker stats
df -h
```

## 📞 Имена контейнеров (новые)

- `v2_glpi` → https://glpi2.yapomogu.com
- `v2_glpi_db` → MariaDB для GLPI
- `v2_chatwoot` → https://chat2.yapomogu.com
- `v2_chatwoot_sidekiq` → Фоновые задачи Chatwoot
- `v2_chatwoot_db` → PostgreSQL для Chatwoot
- `v2_chatwoot_redis` → Redis для Chatwoot

## 🔄 Миграция данных со старой версии

```bash
# Создать бэкап старой версии
cd /path/to/old-version
./backup.sh

# Восстановить в новую
cd /path/to/new-version
./restore.sh /path/to/old-version/backups/backup_YYYY-MM-DD_HH-MM.tar.gz
```

Подробная инструкция: **DEPLOY.md**
