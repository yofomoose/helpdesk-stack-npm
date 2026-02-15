# 🤖 БЫСТРЫЙ СТАРТ ДЛЯ ИИ-АССИСТЕНТА

> **TL;DR для ИИ:** Production-ready GLPI + Chatwoot stack с named volumes, health checks, параллельным развертыванием.

## ⚡ КРИТИЧНОЕ (прочитать первым)

### Система: 2 параллельные версии
```
Старая (prod):              Новая v2 (эта):
glpi                    →   v2_glpi
glpi.yapomogu.com       →   glpi2.yapomogu.com
./data/ (bind mounts)   →   v2_glpi_files (named volumes)
```

**ВАЖНО:** Префикс `v2_` для ВСЕХ ресурсов (контейнеры + volumes) — иначе конфликт!

### Архитектура за 30 секунд
```yaml
6 контейнеров:
  - v2_glpi (diouxx/glpi, port 80)
  - v2_glpi_db (mariadb:10.11)
  - v2_chatwoot (chatwoot/chatwoot, port 3000)  
  - v2_chatwoot_db (pgvector/pg15)
  - v2_chatwoot_redis (redis:7-alpine + password)
  - v2_chatwoot_sidekiq (chatwoot worker)

8 named volumes (все с префиксом v2_):
  - v2_glpi_files, v2_glpi_plugins, v2_glpi_config, v2_glpi_marketplace, v2_glpi_db_data
  - v2_chatwoot_storage, v2_chatwoot_db_data, v2_chatwoot_redis_data

2 сети:
  - npm_default (external, для NPM)
  - backend (internal, inter-service)
```

### Файлы структура
```
docker-compose.yml   ← Main config (278 lines)
.env                 ← Secrets (NOT in Git)
.env.example         ← Template (IN Git)

Scripts: init.sh, install.sh, quick-start.sh, backup.sh, restore.sh, status.sh

Docs: 
  README.md        ← General overview
  DEPLOY.md        ← Step-by-step deployment (297 lines)
  TECHNICAL.md     ← Full tech docs for AI (THIS IS KEY!)
  CHEATSHEET.md    ← Quick commands reference
  MIGRATION.md     ← Bind mounts → named volumes migration
  CHANGELOG.md     ← Version history (v2.0 → v2.0.1)
  AI_CONTEXT.md    ← This file (quickstart)
```

## 🚨 ОБЯЗАТЕЛЬНО ЗНАТЬ

### 1. REDIS_URL НЕ в .env
```yaml
# ❌ WRONG (.env):
REDIS_URL=redis://:${REDIS_PASSWORD}@...  # Вложенная интерполяция не работает

# ✅ RIGHT (.env только пароль):
REDIS_PASSWORD=secret

# ✅ RIGHT (docker-compose.yml формирует URL):
environment:
  - REDIS_URL=redis://:${REDIS_PASSWORD}@chatwoot_redis:6379
```

### 2. GLPI marketplace путь
```yaml
# ❌ WRONG:
- glpi_marketplace:/var/www/html/marketplace

# ✅ RIGHT:
- glpi_marketplace:/var/www/html/glpi/marketplace
```

### 3. Chatwoot DB init
```bash
# ❌ WRONG:
docker compose run --rm chatwoot bundle exec rails db:schema:load
docker compose run --rm chatwoot bundle exec rails db:seed

# ✅ RIGHT (одна команда делает всё):
docker compose run --rm chatwoot bundle exec rails db:chatwoot_prepare
```

### 4. Health checks формат
```yaml
# ✅ GLPI (не используй /status.php - может отсутствовать):
healthcheck:
  test: ["CMD-SHELL", "curl -f http://localhost/ || exit 1"]

# ✅ Chatwoot (/api не требует auth):
healthcheck:
  test: ["CMD-SHELL", "wget -q --spider http://localhost:3000/api || exit 1"]
```

### 5. NPM WebSocket для Chatwoot
**ОБЯЗАТЕЛЬНО включить WebSocket Support** в NPM для chat2.yapomogu.com, иначе чат не работает!

## 📖 КАК НАЧАТЬ РАБОТУ

### Вариант A: Нужен общий контекст
```bash
1. Прочитай TECHNICAL.md (полная техническая документация)
2. Посмотри CHANGELOG.md (что было исправлено и почему)
3. git log --oneline -10 (последние изменения)
```

### Вариант B: Конкретная задача
```bash
# Deployment → читай DEPLOY.md
# Quick commands → читай CHEATSHEET.md
# Migration data → читай MIGRATION.md
# Bug fixing → grep error в логах, см. "Known issues" в TECHNICAL.md
```

### Вариант C: Debugging
```bash
docker compose ps              # Статус контейнеров
docker compose logs -f service # Логи в реальном времени
docker compose config          # Проверка конфига
./status.sh                    # Общий статус системы
```

## 🎯 ЧАСТЫЕ ЗАДАЧИ

### Добавить новую env переменную
1. Добавь в `.env.example` с placeholder
2. Добавь в `docker-compose.yml` в `environment:`
3. Документируй в `TECHNICAL.md` → Environment Variables
4. Обнови `CHANGELOG.md`

### Изменить путь volume
1. **ПРОВЕРЬ** официальную документацию образа!
2. Обнови `docker-compose.yml` → volumes section
3. Тест: `docker compose config | grep -A5 volumes`
4. Документируй в `TECHNICAL.md`

### Добавить новый сервис
1. **ОБЯЗАТЕЛЬНО** префикс `container_name: v2_XXX`
2. Добавь в `backend` network
3. Добавь `healthcheck` (см. примеры в compose)
4. Добавь `depends_on` с `condition: service_healthy`
5. Тест деплоя на копии!

### Debugging unhealthy container
```bash
# 1. Проверь логи
docker logs v2_SERVICE_NAME --tail 100

# 2. Проверь healthcheck
docker inspect v2_SERVICE_NAME | jq '.[0].State.Health'

# 3. Ручная проверка healthcheck команды
docker exec v2_SERVICE_NAME curl -f http://localhost/

# 4. Если Chatwoot - подожди 2-5 минут (долгая инициализация)
```

## 🔄 GIT WORKFLOW

### Before commit
```bash
# 1. Validate config
docker compose config > /dev/null

# 2. Check for secrets
grep -r "password.*=" docker-compose.yml  # Должно быть пусто

# 3. Update docs
nano CHANGELOG.md  # Добавь версию и изменения

# 4. Commit
git add .
git commit -m "type: краткое описание" -m "Подробности"
```

### Commit message format
```
feat: Новая функциональность
fix: Исправление бага
docs: Обновление документации
refactor: Рефакторинг без изменения функциональности
chore: Обслуживание (обновление зависимостей и т.п.)
```

## ⚠️ КРАСНЫЕ ФЛАГИ

Если видишь это — **СТОП**, нужно переделать:

- ❌ Volumes без префикса `v2_`
- ❌ Containers без префикса `v2_`
- ❌ Домены `*.yapomogu.com` (должно быть `*2.yapomogu.com`)
- ❌ Секреты в `docker-compose.yml` (должны быть в `.env`)
- ❌ `REDIS_URL` в `.env` файле
- ❌ Bind mounts (`./data/...`) вместо named volumes
- ❌ Health checks отсутствуют
- ❌ `depends_on` без `condition: service_healthy`

## 🧪 ТЕСТИРОВАНИЕ ИЗМЕНЕНИЙ

### Локально (Windows)
```bash
docker compose up -d
docker compose ps        # Все healthy?
docker compose logs -f   # Нет ошибок?
curl http://localhost:XXX  # Отвечает?
```

### На сервере (production)
```bash
# 1. ОБЯЗАТЕЛЬНО backup перед изменениями
./backup.sh

# 2. Deploy изменений
git pull
docker compose up -d

# 3. Проверка
./status.sh
docker compose logs --tail 50

# 4. Rollback если проблемы
docker compose down
./restore.sh backups/latest_backup.tar.gz
docker compose up -d
```

## 📚 КЛЮЧЕВЫЕ ДОКУМЕНТЫ

**Если код не понятен:**
1. `TECHNICAL.md` → Критические технические решения
2. `git show <commit-hash>` → Почему это было изменено
3. Официальные доки (ссылки в TECHNICAL.md)

**Если нужно развернуть:**
`DEPLOY.md` — пошаговая инструкция

**Если нужно мигрировать данные:**
`MIGRATION.md` — миграция со старой версии

**Если нужна быстрая команда:**
`CHEATSHEET.md` — команды без объяснений

## 💡 ПОЛЕЗНЫЕ КОМАНДЫ

```bash
# Config validation
docker compose config

# Show interpolated values
docker compose config | grep REDIS

# Volume operations
docker volume ls | grep v2_
docker volume inspect v2_glpi_files

# Container operations
docker compose ps
docker compose logs -f v2_chatwoot
docker exec -it v2_glpi_db mysql -u glpi -p

# Cleanup (ОСТОРОЖНО - удаляет volumes!)
docker compose down -v

# Backup/Restore
./backup.sh
./restore.sh backups/backup_YYYY-MM-DD.tar.gz
```

## 🎓 ИСТОЧНИКИ ПРАВДЫ

1. **Официальные доки** (приоритет #1):
   - https://github.com/Diouxx/docker-glpi
   - https://developers.chatwoot.com/self-hosted/deployment/docker
   
2. **Этот проект**:
   - `TECHNICAL.md` — полная документация
   - `docker-compose.yml` — source of truth для конфигурации
   - `.env.example` — все переменные окружения
   - `git log` — история решений

3. **Тестирование**:
   - Всё что не задокументировано — тестируй на копии!

---

## ✅ CHECKLIST: Я готов работать с проектом

- [ ] Прочитал этот файл (AI_CONTEXT.md)
- [ ] Просмотрел TECHNICAL.md (хотя бы "Критические решения")
- [ ] Посмотрел структуру проекта (`ls -la`, `tree -L 2`)
- [ ] Проверил `docker compose config` (работает ли)
- [ ] Понимаю систему префиксов `v2_`
- [ ] Знаю где искать логи (`docker compose logs`)
- [ ] Помню про backup перед изменениями (`./backup.sh`)
- [ ] Понимаю что `.env` НЕ в Git
- [ ] Готов обновлять `CHANGELOG.md` при изменениях

---

**Следующий шаг:** Читай `TECHNICAL.md` для глубокого понимания системы!

**Дата:** 2026-02-15  
**Версия:** 2.0.1  
**Автор:** GitHub Copilot (Claude Sonnet 4.5)
