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
- [ ] Backend: Cargo workspace, entity, repository/service/api, auth/RBAC
- [ ] 13 аналитических запросов + выполнение сырых запросов
- [ ] Frontend: Vue SPA (CRUD, аналитика, админка ролей)

См. [docs/schema.md](docs/schema.md) для описания модели данных.
