# Информационная система городской телефонной сети (ГТС)

Учебный проект: веб-приложение для управления данными городской телефонной сети
(АТС, абоненты, номера, биллinг, межгород, очереди на установку, таксофоны) с
аналитикой по 13 запросам варианта, аутентификацией и настраиваемой ролевой моделью.

## Технологический стек

| Слой | Технология |
|------|------------|
| Backend | Rust, **Axum** (Tokio), **SeaORM** (CRUD + пагинация) + **sqlx** (аналитика, сырые запросы) |
| СУБД | **PostgreSQL 18** (целостность на триггерах/констрейнтах) |
| Миграции | `.sql` (sqlx-cli compatible) |
| Auth | Argon2 + серверные сессии (tower-sessions), свой RBAC в БД |
| Frontend | **Vue 3 + TypeScript**, Vite, Pinia, Vue Router, Element Plus |
| DevOps | Docker Compose |

## Структура репозитория

```
backend/
  migrations/   -- SQL-схема: таблицы, enum-типы, триггеры, представления, справочники
  seeds/        -- демо-данные (dev_seed.sql)
  (src/ и Cargo — добавляются на следующем этапе)
frontend/       -- Vue SPA (добавляется позже)
docker-compose.yml
Makefile
docs/schema.md  -- описание модели данных и привязка к 13 запросам
```

## Быстрый старт (база данных)

### Вариант А — локальный PostgreSQL

```bash
make reset DB=gts_dev      # drop + create + migrate + seed
make psql  DB=gts_dev      # подключиться
```

### Вариант Б — Docker

```bash
cp .env.example .env                 # порт 5433, чтобы не конфликтовать с локальным PG на 5432
make db-up                           # PostgreSQL на :5433, Adminer на http://localhost:8081
# применить миграции + сид к контейнерной БД (psql принимает URL в -d):
make migrate seed DB="$(grep '^DATABASE_URL=' .env | cut -d= -f2-)"
```

Adminer (http://localhost:8081): System `PostgreSQL`, Server `db`, User/Pass/DB `gts`.

## Состояние проекта

- [x] Схема БД: 20+ таблиц, enum-типы, 6 триггеров целостности, 4 представления, справочники RBAC
- [x] Демо-данные и валидация всех триггеров + ключевых аналитических запросов
- [x] Backend: Cargo workspace (entity + server), конфиг, пул БД, маппинг ошибок БД→HTTP
- [x] Аутентификация (Argon2 + серверные сессии) + RBAC (права из БД) + bootstrap суперадмина
- [x] Generic CRUD по 13 сущностям (пагинация, права `entity:action`, чистый enum I/O)
- [x] Выполнение сырых SELECT-запросов (READ ONLY tx, statement_timeout)
- [x] Аналитика: все 13 запросов варианта (Q1–Q13)
- [x] Админка RBAC: управление пользователями/ролями/правами суперадмином (req. 7)
- [ ] Frontend: Vue SPA (CRUD, аналитика, админка ролей)

### Запуск backend

```bash
make db-up                       # PostgreSQL :5433 + Adminer
make migrate seed DB="postgres://gts:gts@localhost:5433/gts"
cd backend && cargo run          # API на http://localhost:8080
# логин: admin / admin
```

См. [docs/schema.md](docs/schema.md) — модель данных, [docs/api.md](docs/api.md) — эндпоинты.
