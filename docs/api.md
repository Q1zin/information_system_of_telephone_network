# HTTP API

Базовый префикс: `/api`. Аутентификация — серверная сессия в cookie
(`tower-sessions`, стор в Postgres). Все эндпоинты, кроме `/health` и
`/api/auth/login`, требуют валидной сессии; доступ ограничен правами RBAC.

## Аутентификация

| Метод | Путь | Описание | Право |
|-------|------|----------|-------|
| POST | `/api/auth/login` | `{username, password}` → пользователь + права | — |
| POST | `/api/auth/logout` | завершить сессию | сессия |
| GET | `/api/auth/me` | текущий пользователь + права | сессия |

## CRUD (одинаковый контракт для всех ресурсов)

Ресурсы: `pbx`, `subscribers`, `phone-numbers`, `addresses`, `cities`,
`calls`, `tariffs`, `invoices`, `payments`, `penalties`, `notifications`,
`queue`, `public-phones`.

| Метод | Путь | Описание | Право |
|-------|------|----------|-------|
| GET | `/api/<res>?page=1&page_size=20` | страница `{items,total,page,page_size,total_pages}` | `<name>:read` |
| GET | `/api/<res>/{id}` | одна запись | `<name>:read` |
| POST | `/api/<res>` | создать (частичный JSON, DEFAULT из БД применяются) | `<name>:create` |
| PUT | `/api/<res>/{id}` | обновить присланные поля | `<name>:update` |
| DELETE | `/api/<res>/{id}` | удалить | `<name>:delete` |

Имя права (`<name>`) для `calls` — `call`, для `queue` — `queue`,
для `phone-numbers` — `phone_number` и т.д. (см. `permission` в БД).

Нарушения целостности БД (триггеры, CHECK/UNIQUE/FK) возвращаются как
`400/409` с человекочитаемым сообщением, а не `500`.

## Аналитика (право `analytics:read`)

| Путь | Запрос варианта | Параметры |
|------|-----------------|-----------|
| `/api/analytics/subscribers` | Q1 — абоненты АТС | `pbx_id, category, min_age, max_age, surname` |
| `/api/analytics/free-numbers` | Q2 — свободные номера | `pbx_id, district` |
| `/api/analytics/debtors` | Q3 — должники | `pbx_id, district, min_days, kind, min_amount` |
| `/api/analytics/pbx-debt-ranking` | Q4 — АТС по долгам | `pbx_type` |
| `/api/analytics/top-intercity-city` | Q9 — город-лидер межгорода | — |
| `/api/analytics/subscriber-by-number` | Q10 — инфо по номеру | `number` |

_Планируются:_ Q5 (таксофоны), Q6 (доля льготников), Q7 (параллельные),
Q8 (телефоны по адресу), Q11 (расспаривание), Q12 (внешние звонки),
Q13 (кандидаты на уведомление/отключение).

## Сырые запросы (право `raw_query:run`)

| Метод | Путь | Тело |
|-------|------|------|
| POST | `/api/raw-query` | `{sql}` — один SELECT/WITH; выполняется в READ ONLY транзакции с таймаутом 5 c |
