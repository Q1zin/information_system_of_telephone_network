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
  entity/       -- SeaORM entity (сгенерированы + post-process)
  server/       -- Axum: config, auth, RBAC, crud, analytics, raw_query, admin
  scripts/      -- postprocess_entities.py
frontend/
  src/api/      -- HTTP-клиент, типы
  src/stores/   -- Pinia (auth)
  src/router/   -- маршруты + guard по правам
  src/config/   -- дескрипторы ресурсов, каталог 13 запросов, enum-справочники
  src/views/    -- Login, Dashboard, Crud, Analytics, RawQuery, admin/{Users,Roles}
docker-compose.yml
Makefile
docs/schema.md  -- модель данных и привязка к 13 запросам
docs/api.md     -- HTTP API
docs/schema.dbml-- ER-диаграмма (dbdiagram.io)
docs/guide.pdf  -- учебный разбор «для защиты» (БД, запросы, CRUD, Rust, SeaORM)
docs/crud.pdf   -- подробный разбор CRUD-операций (от браузера до SQL)
docs/queries.pdf-- построчный разбор всех 13 SQL-запросов варианта
docs/migrations.pdf -- разбор каждой миграции БД (0001–0012)
docs/data-model-story.pdf -- рассказ по схеме (talk-track для защиты по ER-диаграмме)
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
- [x] Generic CRUD по **всем** сущностям: 16 ресурсов (вкл. подтипы АТС) + настройки биллинга + админка (пагинация, права `entity:action`, чистый enum I/O)
- [x] Выполнение сырых SELECT-запросов (READ ONLY tx, statement_timeout)
- [x] Аналитика: все 13 запросов варианта (Q1–Q13)
- [x] Админка RBAC: управление пользователями/ролями/правами суперадмином (req. 7)
- [x] Swagger / OpenAPI 3.1 (utoipa) — интерактивная документация всего API на `/swagger-ui/`
- [x] **Операторская панель** (Vue SPA): CRUD по всем сущностям, аналитика, SQL-консоль, заявки, админка
- [x] **Личный кабинет абонента**: регистрация, заявка на подключение, управление тарифом/межгородом, звонки, счета и оплата — оператор подключает заявку (выдаёт номер, создаёт абонента)

**Проект функционально завершён** по всем требованиям задания.

### Запуск — всё одной командой (Docker)

```bash
docker compose up --build
```

Поднимаются: PostgreSQL → сервис миграций (схема + демо-данные) → backend → frontend → Adminer.

| Сервис | URL |
|--------|-----|
| **Сайт** (лендинг) | http://localhost:8090 |
| → Личный кабинет абонента | http://localhost:8090/portal (регистрация прямо там) |
| → Вход для сотрудников | http://localhost:8090/staff/login (**admin / admin**) |
| Backend API | http://localhost:8080 |
| Swagger UI | http://localhost:8080/swagger-ui/ |
| Adminer | http://localhost:8081 |

**Демо-сценарий «запуск в городе»:** зарегистрируйтесь в личном кабинете → подайте
заявку на подключение → войдите как сотрудник (`admin/admin`) → «Заявки на
подключение» → «Подключить» (выдаётся номер) → вернитесь в кабинет: появилась
линия, можно включить межгород, позвонить и оплатить счёт.

### Локальная разработка (без Docker)

```bash
make db-up                                  # только PostgreSQL :5433 + Adminer
make migrate seed DB="postgres://gts:gts@localhost:5433/gts"
cd backend  && cargo run                    # API :8080 (+ Swagger /swagger-ui/)
cd frontend && npm install && npm run dev   # SPA :5173 (прокси на :8080)
```

См. [docs/schema.md](docs/schema.md) — модель данных, [docs/api.md](docs/api.md) — эндпоинты.
