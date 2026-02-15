# МИГРАЦИЯ С BIND MOUNTS НА NAMED VOLUMES

Если у вас уже работает старая версия с `./data/`, вот как мигрировать на новую:

## ⚠️ ВАЖНО: Создайте бэкап перед миграцией!

```bash
./backup.sh  # Старый скрипт создаст бэкап bind mounts
```

## Вариант 1: Чистая установка (рекомендуется)

Если данные не критичны или есть свежий бэкап:

```bash
# 1. Остановить старую систему
docker compose down

# 2. Создать .env из текущих настроек
cp .env.example .env
# Отредактировать .env с вашими паролями

# 3. Удалить старые данные (опционально)
# rm -rf data/

# 4. Запустить новую систему
./quick-start.sh
```

## Вариант 2: Миграция данных

Если нужно сохранить текущие данные:

### Шаг 1: Остановка системы

```bash
docker compose down
```

### Шаг 2: Создание volumes и копирование данных

```bash
# Создать volumes
docker volume create glpi_files
docker volume create glpi_plugins
docker volume create glpi_config
docker volume create glpi_marketplace
docker volume create glpi_db_data
docker volume create chatwoot_storage
docker volume create chatwoot_db_data
docker volume create chatwoot_redis_data

# Скопировать данные GLPI
docker run --rm \
  -v $(pwd)/data/glpi/files:/source:ro \
  -v glpi_files:/dest \
  alpine cp -a /source/. /dest/

docker run --rm \
  -v $(pwd)/data/glpi/plugins:/source:ro \
  -v glpi_plugins:/dest \
  alpine cp -a /source/. /dest/

docker run --rm \
  -v $(pwd)/data/glpi/config:/source:ro \
  -v glpi_config:/dest \
  alpine cp -a /source/. /dest/

docker run --rm \
  -v $(pwd)/data/glpi/marketplace:/source:ro \
  -v glpi_marketplace:/dest \
  alpine cp -a /source/. /dest/

docker run --rm \
  -v $(pwd)/data/glpi/db:/source:ro \
  -v glpi_db_data:/dest \
  alpine cp -a /source/. /dest/

# Скопировать данные Chatwoot
docker run --rm \
  -v $(pwd)/data/chatwoot/storage:/source:ro \
  -v chatwoot_storage:/dest \
  alpine cp -a /source/. /dest/

docker run --rm \
  -v $(pwd)/data/chatwoot/db:/source:ro \
  -v chatwoot_db_data:/dest \
  alpine cp -a /source/. /dest/

docker run --rm \
  -v $(pwd)/data/chatwoot/redis:/source:ro \
  -v chatwoot_redis_data:/dest \
  alpine cp -a /source/. /dest/
```

### Шаг 3: Создать .env

```bash
cp .env.example .env
# Отредактировать с вашими ТЕКУЩИМИ паролями!
```

### Шаг 4: Запустить новую систему

```bash
docker compose up -d
```

### Шаг 5: Проверка

```bash
docker compose ps
docker compose logs -f

# Открыть в браузере
# https://glpi.yapomogu.com
# https://chat.yapomogu.com
```

## Вариант 3: Использование бэкапа

Если есть свежий бэкап:

```bash
# 1. Остановить старую систему
docker compose down

# 2. Создать .env
cp .env.example .env
nano .env

# 3. Запустить базы данных для создания volumes
docker compose up -d glpi_db chatwoot_db chatwoot_redis
sleep 30
docker compose down

# 4. Восстановить из бэкапа (новый скрипт)
./restore.sh backups/backup_YYYY-MM-DD_HH-MM.tar.gz

# 5. Запустить систему
docker compose up -d
```

## Откат на старую версию

Если что-то пошло не так:

```bash
# 1. Остановить новую систему
docker compose down

# 2. Вернуть старый docker-compose.yml из бэкапа
# (если вы сохранили его)

# 3. Запустить старую систему
docker compose up -d
```

## Проверка успешной миграции

```bash
# Проверить volumes
docker volume ls | grep -E "(glpi|chatwoot)"

# Проверить размеры
docker system df -v | grep -E "(glpi|chatwoot)"

# Проверить статус
./status.sh

# Проверить логи
docker compose logs --tail=50
```

## После успешной миграции

```bash
# Можно удалить старые данные (ОСТОРОЖНО!)
# rm -rf data/

# Или оставить как дополнительный бэкап на некоторое время
```

## Преимущества новой системы

✅ **Named volumes:**
- Управляются Docker
- Проще делать бэкапы
- Лучшая производительность
- Независимость от прав файловой системы

✅ **Безопасность:**
- Пароли в .env (не в Git)
- Redis с паролем
- .gitignore защищает секреты

✅ **Отказоустойчивость:**
- Health checks
- Resource limits
- Автоматические перезапуски

✅ **Готовность к расширению:**
- API интеграция
- Telegram бот
- Мониторинг
