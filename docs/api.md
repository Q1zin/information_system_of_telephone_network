# HTTP API

Базовый префикс: `/api`. Аутентификация — серверная сессия в cookie
(`tower-sessions`, стор в Postgres). Все эндпоинты, кроме `/health` и
`/api/auth/login`, требуют валидной сессии; доступ ограничен правами RBAC.

> **Интерактивная документация (Swagger UI):** http://localhost:8080/swagger-ui/
> Спецификация OpenAPI 3.1: http://localhost:8080/api-docs/openapi.json
> Сначала войдите через `POST /api/auth/login` — cookie-сессия подхватится для «Try it out».

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

## Аналитика — все 13 запросов варианта (право `analytics:read`)

| Путь | Запрос | Параметры |
|------|--------|-----------|
| `/api/analytics/subscribers` | Q1 — абоненты АТС | `pbx_id, category, min_age, max_age, surname` |
| `/api/analytics/free-numbers` | Q2 — свободные номера | `pbx_id, district` |
| `/api/analytics/debtors` | Q3 — должники | `pbx_id, district, min_days, kind, min_amount` |
| `/api/analytics/pbx-debt-ranking` | Q4 — АТС по долгам | `pbx_type` |
| `/api/analytics/public-phones` | Q5 — таксофоны/общественные | `pbx_id, district, kind` |
| `/api/analytics/category-ratio` | Q6 — доля простых/льготных (%) | `pbx_id, district, pbx_type` |
| `/api/analytics/parallel-subscribers` | Q7 — абоненты с параллельными | `pbx_id, district, pbx_type, privileged_only` |
| `/api/analytics/phones-by-address` | Q8 — телефоны по адресу/дому/улице | `district, street, house` |
| `/api/analytics/top-intercity-city` | Q9 — город-лидер межгорода | — |
| `/api/analytics/subscriber-by-number` | Q10 — инфо по номеру | `number` |
| `/api/analytics/splittable-paired` | Q11 — расспариваемые спаренные | `pbx_id` |
| `/api/analytics/low-external-call-numbers` | Q12 — внутр. номера с < N внешних звонков | `pbx_id, from, to, max_calls` |
| `/api/analytics/action-needed-debtors` | Q13 — кандидаты на уведомление/отключение | `pbx_id, district` |

## Админка RBAC (права `user:*`, `role:*`, `rbac:manage`)

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/api/admin/permissions` | каталог прав |
| GET / POST | `/api/admin/roles` | список ролей (с правами) / создать роль |
| PUT / DELETE | `/api/admin/roles/{id}` | изменить / удалить (системные нельзя) |
| POST | `/api/admin/roles/{id}/permissions` | задать права роли `{permission_ids}` |
| GET / POST | `/api/admin/users` | список пользователей (с ролями) / создать |
| PUT / DELETE | `/api/admin/users/{id}` | изменить (в т.ч. пароль) / удалить |
| POST | `/api/admin/users/{id}/roles` | задать роли пользователю `{role_ids}` |

## Сырые запросы (право `raw_query:run`)

| Метод | Путь | Тело |
|-------|------|------|
| POST | `/api/raw-query` | `{sql}` — один SELECT/WITH; выполняется в READ ONLY транзакции с таймаутом 5 c |
