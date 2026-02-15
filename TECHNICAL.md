# 🤖 ТЕХНИЧЕСКАЯ ДОКУМЕНТАЦИЯ ДЛЯ ИИ-АССИСТЕНТОВ

> **Версия:** 2.0.1  
> **Дата:** 2026-02-15  
> **Цель:** Быстрый onboarding ИИ для продолжения разработки

---

## 📐 АРХИТЕКТУРА СИСТЕМЫ

### Компоненты
```
┌─────────────────────────────────────────────────────────┐
│                    Nginx Proxy Manager                   │
│                   (npm_default network)                  │
└─────────────┬───────────────────────┬───────────────────┘
              │                       │
    ┌─────────▼─────────┐   ┌────────▼──────────┐
    │   GLPI System     │   │  Chatwoot System  │
    │  glpi2.yapomogu   │   │  chat2.yapomogu   │
    └─────────┬─────────┘   └────────┬──────────┘
              │                      │
    ┌─────────▼─────────┐   ┌────────▼──────────┐
    │  v2_glpi:80       │   │ v2_chatwoot:3000  │
    │  v2_glpi_db       │   │ v2_chatwoot_db    │
    │  (MariaDB 10.11)  │   │ (PostgreSQL 15)   │
    └───────────────────┘   │ v2_chatwoot_redis │
                            │ v2_chatwoot_sidekiq│
                            └────────────────────┘

Volumes (named, managed by Docker):
  GLPI:     v2_glpi_files, v2_glpi_plugins, v2_glpi_config, 
            v2_glpi_marketplace, v2_glpi_db_data
  Chatwoot: v2_chatwoot_storage, v2_chatwoot_db_data, 
            v2_chatwoot_redis_data
```

### Паттерн развертывания: Параллельные версии
- **Префикс v2_** для всех ресурсов (контейнеры, volumes)
- **Домены *2.yapomogu.com** для разделения систем
- **Shared network** npm_default для NPM доступа
- **Internal network** backend для межконтейнерной связи

---

## 📂 СТРУКТУРА ПРОЕКТА

```
helpdesk-stack-npm/
├── docker-compose.yml      # Главная конфигурация (278 строк)
├── .env                    # Секреты (НЕ в Git)
├── .env.example            # Шаблон секретов (В Git)
├── .gitignore              # Git исключения
│
├── Deployment Scripts:
│   ├── init.sh             # Проверка окружения
│   ├── install.sh          # Первая установка
│   ├── quick-start.sh      # Быстрый запуск
│   ├── backup.sh           # Бэкап volumes через Docker
│   ├── restore.sh          # Восстановление volumes
│   └── status.sh           # Статус системы
│
└── Documentation:
    ├── README.md           # Общая документация
    ├── DEPLOY.md           # Инструкция развертывания (297 строк)
    ├── CHEATSHEET.md       # Быстрая справка (132 строки)
    ├── MIGRATION.md        # Миграция bind mounts → volumes
    ├── CHANGELOG.md        # История изменений (v2.0 → v2.0.1)
    └── TECHNICAL.md        # ← Этот файл (для ИИ)
```

---

## 🔧 КРИТИЧЕСКИЕ ТЕХНИЧЕСКИЕ РЕШЕНИЯ

### 1. Named Volumes vs Bind Mounts
**Решение:** Named volumes (Docker-managed)  
**Причина:**
- Кроссплатформенность (Windows/Linux)
- Производительность на Windows
- Независимость от прав FS хоста
- Простота бэкапа через Docker

**Пути в контейнерах:**
```yaml
# GLPI (diouxx/glpi)
/var/www/html/glpi/files       → v2_glpi_files
/var/www/html/glpi/plugins     → v2_glpi_plugins
/var/www/html/glpi/config      → v2_glpi_config
/var/www/html/glpi/marketplace → v2_glpi_marketplace ⚠️ НЕ /var/www/html/marketplace
/var/lib/mysql                 → v2_glpi_db_data

# Chatwoot (chatwoot/chatwoot)
/app/storage                   → v2_chatwoot_storage
/var/lib/postgresql/data       → v2_chatwoot_db_data
/data                          → v2_chatwoot_redis_data
```

### 2. Redis URL Interpolation
**Решение:** Формирование в docker-compose.yml  
**Анти-паттерн:** `REDIS_URL=${REDIS_URL}` в .env с `${REDIS_PASSWORD}`  
**Правильно:**
```yaml
# docker-compose.yml
environment:
  - REDIS_URL=redis://:${REDIS_PASSWORD}@chatwoot_redis:6379
# .env (только пароль)
REDIS_PASSWORD=secret
```
**Причина:** Вложенная интерполяция не работает в env_file

### 3. Health Checks
**Реализация:**
```yaml
# GLPI
test: ["CMD-SHELL", "curl -f http://localhost/ || exit 1"]
# Не используем /status.php - может отсутствовать

# Chatwoot
test: ["CMD-SHELL", "wget -q --spider http://localhost:3000/api || exit 1"]
# Не /health - требует авторизации

# MariaDB
test: ["CMD", "/usr/local/bin/healthcheck.sh", "--connect", "--innodb_initialized"]

# PostgreSQL
test: ["CMD-SHELL", "pg_isready -U ${CHATWOOT_DB_USER} -d ${CHATWOOT_DB_NAME}"]

# Redis
test: ["CMD-SHELL", "redis-cli -a $$REDIS_PASSWORD ping | grep PONG"]
# Двойной $$ для экранирования в compose
```

### 4. Database Initialization
**Chatwoot:** `rails db:chatwoot_prepare` ✅  
**Избегать:** `rails db:schema:load` + `db:seed` отдельно  
**Причина:** `chatwoot_prepare` - официальная команда, выполняет всё сразу

**GLPI:** Веб-установщик при первом запуске  
**После установки:** `docker exec v2_glpi rm /var/www/html/install/install.php`

### 5. Параллельное развертывание
**Стратегия изоляции:**
```
Старая система          Новая система v2
────────────────        ────────────────
glpi                    v2_glpi
glpi_db                 v2_glpi_db
glpi.yapomogu.com       glpi2.yapomogu.com
./data/glpi/files       v2_glpi_files (volume)
```
**Результат:** Zero-downtime migration

---

## 🔐 БЕЗОПАСНОСТЬ

### Секреты
1. **Все секреты в .env** (исключен из Git)
2. **Redis защищен паролем** (`--requirepass`)
3. **GLPI installer удаляется** после установки
4. **Chatwoot ENABLE_ACCOUNT_SIGNUP=false** по умолчанию

### Сеть
```yaml
networks:
  npm_default:    # External, NPM для проксирования
    external: true
  backend:        # Internal, inter-service communication
    driver: bridge
```

### Resource Limits
```yaml
deploy:
  resources:
    limits:
      cpus: '${SERVICE_CPU_LIMIT}'
      memory: ${SERVICE_MEMORY_LIMIT}
    reservations:
      cpus: '0.25'
      memory: 256m
```

---

## 📝 ENVIRONMENT VARIABLES

### Обязательные (критичные)
```bash
# GLPI Database
GLPI_DB_ROOT_PASSWORD=       # MariaDB root
GLPI_DB_PASSWORD=            # GLPI user password

# Chatwoot
CHATWOOT_SECRET_KEY_BASE=    # 64 bytes hex (openssl rand -hex 64)
CHATWOOT_FRONTEND_URL=       # https://chat2.yapomogu.com
CHATWOOT_DB_PASSWORD=        # PostgreSQL password

# Redis
REDIS_PASSWORD=              # Redis auth password

# SMTP
SMTP_ADDRESS=                # SMTP server
SMTP_USERNAME=               # SMTP login
SMTP_PASSWORD=               # SMTP password
```

### Опциональные (с дефолтами)
```bash
TZ=Asia/Omsk
CHATWOOT_DEFAULT_LOCALE=ru
GLPI_MEMORY_LIMIT=2g
CHATWOOT_MEMORY_LIMIT=2g
DB_MEMORY_LIMIT=1g
```

### НЕ используемые (удалены из конфига)
```bash
REDIS_URL=                   # ❌ Формируется в compose
INSTALLATION_ENV=docker      # ❌ Недокументированная
FORCE_SSL=true               # ❌ Недокументированная
```

---

## 🚀 DEPLOYMENT FLOW

### First-time Installation
```bash
1. cp .env.example .env && nano .env  # Заполнить пароли
2. chmod +x *.sh
3. docker network create npm_default  # Если нет NPM
4. ./quick-start.sh                   # Или следовать DEPLOY.md
```

### Database Initialization
```bash
# Запустить только БД
docker compose up -d v2_glpi_db v2_chatwoot_db v2_chatwoot_redis
sleep 60  # Ждать healthy

# Инициализировать Chatwoot
docker compose run --rm chatwoot bundle exec rails db:chatwoot_prepare

# Запустить всё
docker compose up -d
```

### NPM Configuration
**GLPI:**
- Domain: glpi2.yapomogu.com
- Forward: v2_glpi:80
- SSL: ✅, WebSocket: ❌

**Chatwoot:**
- Domain: chat2.yapomogu.com
- Forward: v2_chatwoot:3000
- SSL: ✅, **WebSocket: ✅ ОБЯЗАТЕЛЬНО**

---

## 🐛 ИЗВЕСТНЫЕ ПРОБЛЕМЫ И РЕШЕНИЯ

### 1. Chatwoot unhealthy после запуска
**Симптом:** Container shows unhealthy, но логи "Listening on 0.0.0.0:3000"  
**Причина:** Долгая инициализация Rails (webpack compile, migrations)  
**Решение:** Подождать 2-5 минут, проверить логи  
**Не проблема если:** Логи показывают "Listening on", нет ошибок

### 2. GLPI marketplace путь
**Старая ошибка:** `/var/www/html/marketplace`  
**Правильно:** `/var/www/html/glpi/marketplace`  
**Источник:** https://github.com/Diouxx/docker-glpi

### 3. Redis connection refused
**Причина:** REDIS_URL в .env с вложенной интерполяцией  
**Решение:** Удалить REDIS_URL из .env, формировать в compose

### 4. Volume permissions на Windows
**Решение:** Named volumes решают автоматически  
**Альтернатива (Linux):** `chown -R www-data:www-data` в entrypoint

---

## 🔄 MAINTENANCE OPERATIONS

### Backup
```bash
./backup.sh
# Создаёт: backups/backup_YYYY-MM-DD_HH-MM-SS.tar.gz
# Содержит: все volumes + database dumps
```

### Restore
```bash
./restore.sh backups/backup_YYYY-MM-DD_HH-MM-SS.tar.gz
```

### Update Images
```bash
docker compose pull
docker compose up -d
docker compose run --rm chatwoot bundle exec rails db:chatwoot_prepare
```

### Logs
```bash
docker compose logs -f [service]
docker logs v2_chatwoot --tail 100 --follow
```

### Database Access
```bash
# MariaDB (GLPI)
docker exec -it v2_glpi_db mysql -u glpi -p glpi

# PostgreSQL (Chatwoot)
docker exec -it v2_chatwoot_db psql -U chatwoot -d chatwoot
```

---

## 🎯 ТОЧКИ РАСШИРЕНИЯ (TODO для следующего ИИ)

### Приоритет 1: Функциональность
- [ ] **Telegram Bot интеграция** с Chatwoot
  - API Channel в Chatwoot
  - Bot webhook → Chatwoot inbox
  - Двусторонняя коммуникация

- [ ] **GLPI ↔ Chatwoot bridge**
  - Создание тикета GLPI из Chatwoot conversation
  - Синхронизация статусов
  - API: GLPI REST API + Chatwoot Platform API

### Приоритет 2: Мониторинг
- [ ] **Prometheus + Grafana**
  - Экспорт метрик контейнеров
  - Дашборды для GLPI/Chatwoot
  - Алерты на disk space, memory, CPU

- [ ] **Loki для логов**
  - Централизованное хранение логов
  - Поиск и аналитика

### Приоритет 3: Отказоустойчивость
- [ ] **Database replication**
  - MariaDB primary/replica
  - PostgreSQL streaming replication
  - Автоматический failover (Patroni)

- [ ] **Redis Sentinel** для HA

- [ ] **Traefik вместо NPM** (опционально)
  - Автоматические SSL сертификаты
  - Load balancing
  - Better WebSocket support

### Приорит 4: CI/CD
- [ ] **GitHub Actions**
  - Lint docker-compose.yml
  - Test backup/restore
  - Automated deployments

- [ ] **Версионирование**
  - Semantic versioning
  - Release notes automation

---

## 📚 ИСТОЧНИКИ (OFFICIAL DOCS)

### GLPI Docker
- **Repo:** https://github.com/Diouxx/docker-glpi
- **Image:** docker.io/diouxx/glpi:latest
- **Paths:** Документация в glpi-start.sh скрипте
- **Env vars:** `TIMEZONE` (основная)

### Chatwoot Docker
- **Official:** https://developers.chatwoot.com/self-hosted/deployment/docker
- **Env vars:** https://developers.chatwoot.com/self-hosted/configuration/environment-variables
- **Image:** docker.io/chatwoot/chatwoot:latest
- **DB init:** `rails db:chatwoot_prepare` (не migrate!)

### Docker Compose
- **Version:** Modern syntax (no `version:` field)
- **Requires:** Docker 20.10+, Compose v2+
- **Networks:** External + internal pattern
- **Health checks:** CMD-SHELL format обязателен

---

## 🧪 TESTING CHECKLIST

### Before Commit
- [ ] `docker compose config` без ошибок
- [ ] Все paths в volumes правильные
- [ ] .env.example без реальных паролей
- [ ] .gitignore включает .env и data/
- [ ] Документация обновлена (CHANGELOG.md)

### After Deploy
- [ ] Все контейнеры healthy: `docker compose ps`
- [ ] GLPI доступен через glpi2.yapomogu.com
- [ ] Chatwoot доступен через chat2.yapomogu.com
- [ ] WebSocket работает (test chat widget)
- [ ] Backup/restore работает: `./backup.sh && ./restore.sh`
- [ ] Логи без критичных ошибок

### Stress Test
- [ ] Resource limits работают (не OOM)
- [ ] Database под нагрузкой (ab, siege)
- [ ] Disk space monitoring
- [ ] Restart устойчивость: `docker compose restart`

---

## 💡 BEST PRACTICES ПРИ МОДИФИКАЦИИ

### Docker Compose
1. **Всегда используй named volumes** с префиксом v2_
2. **Health checks обязательны** для всех сервисов
3. **depends_on с condition: service_healthy** вместо просто depends_on
4. **Resource limits** для production
5. **restart: unless-stopped** для автовосстановления

### Environment Variables
1. **Секреты только в .env**, никогда в docker-compose.yml
2. **.env.example** с placeholder значениями
3. **Документировать** каждую переменную в комментариях
4. **Избегать** вложенной интерполяции (${VAR_${OTHER}})

### Volumes
1. **Префикс v2_** для всех volumes
2. **Explicit name:** в секции volumes
3. **Backup strategy** тестировать регулярно
4. **Пути** проверять по официальной документации

### Scripts
1. **Bash -e** для exit on error
2. **set -u** для undefined variables error
3. **Логирование** всех операций
4. **Цветной вывод** для UX (но не в CI)

### Documentation
1. **CHANGELOG.md** при каждом изменении
2. **Inline comments** в docker-compose.yml
3. **Commit messages** описательные (Conventional Commits)
4. **README.md** актуальный (single source of truth)

---

## 🔍 DEBUG КОМАНДЫ

```bash
# Проверить конфиг
docker compose config

# Проверить интерполяцию env
docker compose config | grep REDIS_URL

# Список volumes
docker volume ls | grep v2_

# Инспекция volume
docker volume inspect v2_glpi_files

# Проверка сети
docker network inspect npm_default

# Logs troubleshooting
docker compose logs --tail=100 --follow v2_chatwoot

# Container inspection
docker inspect v2_chatwoot | jq '.[0].State.Health'

# Resource usage
docker stats --no-stream v2_glpi v2_chatwoot

# Cleanup (ОСТОРОЖНО!)
docker compose down -v  # Удаляет volumes!
```

---

## 📊 METRICS & KPIs

### Performance Targets
- **GLPI:** < 500ms page load
- **Chatwoot:** < 200ms API response
- **Database:** < 100ms query time (avg)
- **Uptime:** 99.5% (допустимо 3.6h downtime/month)

### Resource Usage (expected)
```
Container          CPU      Memory
v2_glpi            0.5-2.0  512M-2G
v2_glpi_db         0.25-1.0 256M-1G
v2_chatwoot        0.5-2.0  512M-2G
v2_chatwoot_db     0.25-1.0 256M-1G
v2_chatwoot_redis  0.1-0.5  128M-512M
v2_chatwoot_sidekiq 0.25-1.0 256M-1G
```

---

## 🎓 LEARNING RESOURCES

### For AI Assistants
- Прочитать DEPLOY.md полностью перед deployment изменениями
- Изучить CHANGELOG.md для понимания эволюции проекта
- Проверить git log для контекста решений
- Тестировать на копии перед production

### For Humans
- CHEATSHEET.md - быстрая справка команд
- README.md - общий обзор проекта
- MIGRATION.md - миграция со старой версии

---

## ✅ VALIDATION CHECKLIST (перед передачей задачи)

ИИ должен проверить:

- [ ] Все команды в документации актуальны
- [ ] docker-compose.yml валиден (`docker compose config`)
- [ ] .env.example содержит все нужные переменные
- [ ] Нет hardcoded секретов в коде
- [ ] Volumes с префиксом v2_
- [ ] Контейнеры с префиксом v2_
- [ ] Домены *2.yapomogu.com
- [ ] Health checks работают
- [ ] Backup/restore протестированы
- [ ] Документация обновлена
- [ ] CHANGELOG.md содержит новую версию
- [ ] Commit messages описательные
- [ ] Старая система не затронута изменениями

---

## 🚨 RED FLAGS (что НЕЛЬЗЯ делать)

❌ **Удалять volumes без backup**  
❌ **Коммитить .env файл**  
❌ **Менять префикс v2_ (конфликты со старой системой)**  
❌ **Удалять health checks**  
❌ **Bind mounts вместо named volumes**  
❌ **Хардкодить секреты в docker-compose.yml**  
❌ **Использовать `latest` в production без freeze версий**  
❌ **Игнорировать официальную документацию**  

---

## 📞 КОНТАКТНАЯ ИНФОРМАЦИЯ

**Проект:** helpdesk-stack-npm  
**Версия:** 2.0.1  
**Репозиторий:** https://github.com/yofomoose/helpdesk-stack-npm  
**Домены:**
- GLPI: glpi2.yapomogu.com
- Chatwoot: chat2.yapomogu.com

**Старая система (параллельно работает):**
- GLPI: glpi.yapomogu.com
- Chatwoot: chat.yapomogu.com

---

**Последнее обновление:** 2026-02-15  
**Автор документации:** GitHub Copilot (Claude Sonnet 4.5)  
**Для вопросов:** См. git log и commit history
