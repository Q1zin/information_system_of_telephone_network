// Гайд по миграциям БД (ГТС) — что делает каждый SQL-файл
// Компиляция:  typst compile docs/migrations.typ docs/migrations.pdf

#set document(title: "ГТС — разбор миграций базы данных", author: "")
#set page(
  paper: "a4",
  margin: (x: 2cm, y: 1.9cm),
  numbering: "1",
  footer: context [
    #set text(size: 8pt, fill: gray)
    ГТС — разбор миграций базы данных
    #h(1fr)
    #counter(page).display("1")
  ],
)
#set text(font: "PT Sans", size: 10.5pt, lang: "ru")
#set par(justify: true, leading: 0.6em)
#show raw: set text(font: "PT Mono", size: 8.6pt)
#show raw.where(block: true): set par(justify: false)
#show heading: set block(above: 1.05em, below: 0.55em)
#set heading(numbering: "1.1")
#show heading.where(level: 1): it => [
  #set text(size: 15pt)
  #block(stroke: (bottom: 1pt + rgb("#cfd8e3")), inset: (bottom: 4pt), width: 100%)[#it]
]

#let note(body) = block(width: 100%, fill: rgb("#fff8e6"), stroke: 0.5pt + rgb("#e6c34a"), inset: 9pt, radius: 5pt, spacing: 1em)[
  #text(weight: "bold", fill: rgb("#92700e"))[Важно. ] #body
]
#let creates(body) = block(width: 100%, fill: rgb("#eefcf3"), stroke: 0.5pt + rgb("#86d6a8"), inset: 8pt, radius: 5pt, spacing: 0.9em)[
  #text(weight: "bold", fill: rgb("#0f766e"))[Создаёт. ] #body
]
#let term(t) = text(weight: "bold", fill: rgb("#0f766e"))[#t]

#align(center)[
  #v(1.3cm)
  #text(size: 25pt, weight: "bold")[Разбор миграций\ базы данных]
  #v(0.3cm)
  #text(size: 14pt, fill: gray)[Информационная система городской телефонной сети]
  #v(0.5cm)
  #text(size: 11pt)[Что делает каждый файл `backend/migrations/0001…0012` — простыми словами]
  #v(0.8cm)
  #line(length: 40%, stroke: 0.5pt + gray)
]
#v(0.3cm)
#outline(title: [Содержание], indent: auto, depth: 1)
#pagebreak()

= Что такое миграции

#term[Миграции] — это пронумерованные SQL-файлы (`0001_…`, `0002_…`, … `0012_…`), которые #term[по очереди] строят базу данных с нуля: создают типы, таблицы, связи, ограничения, триггеры, представления и заливают начальные данные. Порядок важен: нельзя сослаться на таблицу, которой ещё нет, поэтому, например, типы (`0001`) идут раньше таблиц, а таблицы — раньше триггеров.

#note[Кто их применяет: в Docker — отдельный сервис `migrate` (прогоняет все файлы по порядку на свежей базе), локально — команда `make migrate`. Каждый файл выполняется один раз.]

== Базовый словарь (читать перед разбором)

Команды, которые меняют #term[структуру] БД, называют #term[DDL] (Data Definition Language). Вот всё, что встретится:

#table(
  columns: (auto, 1fr),
  inset: 5.5pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Конструкция*], [*Что значит*]),
  [`CREATE TYPE x AS ENUM (...)`], [создать #term[перечисление] — тип, который принимает только значения из списка],
  [`CREATE TABLE t (...)`], [создать таблицу с колонками],
  [`CREATE INDEX ...`], [создать #term[индекс] — ускоряет поиск/фильтрацию по колонке],
  [`CREATE VIEW v AS SELECT ...`], [создать #term[представление] — сохранённый запрос как «виртуальная таблица»],
  [`CREATE TRIGGER ...`], [создать #term[триггер] — авто-проверку при изменении таблицы],
  [`INSERT INTO t ...`], [добавить строки (заливка начальных данных)],
  [`ALTER TABLE t ADD COLUMN ...`], [изменить уже существующую таблицу (добавить колонку)],
)

Типы данных колонок:

#table(
  columns: (auto, 1fr),
  inset: 5.5pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Тип*], [*Что хранит*]),
  [`BIGSERIAL`], [целое, которое #term[само растёт] (1, 2, 3, …). Используется для `id`],
  [`BIGINT`], [большое целое (для ссылок на чужой `id`)],
  [`INTEGER` / `SMALLINT`], [целые поменьше (счётчики, год/месяц)],
  [`TEXT`], [строка любой длины],
  [`BOOLEAN`], [`true` / `false`],
  [`DATE`], [дата без времени],
  [`TIMESTAMPTZ`], [дата + время с часовым поясом],
  [`NUMERIC(12,2)`], [#term[точное] десятичное число (для денег — никогда не `float`!): 12 знаков, 2 после запятой],
)

Ограничения (правила на данные):

#table(
  columns: (auto, 1fr),
  inset: 5.5pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Ограничение*], [*Что гарантирует*]),
  [`PRIMARY KEY`], [уникальный идентификатор строки (`id`)],
  [`REFERENCES t(id)` (FOREIGN KEY)], [#term[внешний ключ] — значение должно ссылаться на существующую строку в `t`],
  [`NOT NULL`], [поле обязательно],
  [`UNIQUE`], [значение не повторяется],
  [`DEFAULT x`], [значение по умолчанию, если не передано],
  [`CHECK (...)`], [условие, которому обязано удовлетворять значение],
)

Что делать при удалении строки, на которую ссылаются (`ON DELETE …`):

#table(
  columns: (auto, 1fr),
  inset: 5.5pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Действие*], [*Поведение (пример)*]),
  [`CASCADE`], [удалить и зависимые строки (удалили АТС → удалилась её строка-подтип)],
  [`RESTRICT`], [#term[запретить] удаление, пока есть ссылки (нельзя удалить номер, если на нём есть абонент)],
  [`SET NULL`], [обнулить ссылку (удалили город → у звонка `dest_city_id` станет `NULL`)],
)

#pagebreak()

= 0001 — типы (enum) и расширение

#creates[Расширение `btree_gist` и 15 enum-типов: `pbx_type`, `line_type`, `intercity_status`, `gender`, `subscriber_category` и др.]

```sql
CREATE TYPE line_type AS ENUM ('main', 'parallel', 'paired');
CREATE TYPE intercity_status AS ENUM ('none', 'open', 'closed');
```

- #term[enum] (перечисление) — это тип-«выпадающий список»: колонка такого типа примет только перечисленные значения. Например, тип линии может быть только `main` / `parallel` / `paired`, а не произвольная строка. Это первая линия защиты от мусора в данных.
- Типы создаются #term[раньше] таблиц, потому что таблицы будут на них ссылаться (колонка `line_type line_type`).
- `CREATE EXTENSION btree_gist` — подключает доп. возможности PostgreSQL (нужно для некоторых видов ограничений).

= 0002 — города, адреса и АТС

#creates[Таблицы `city`, `address`, `pbx` и три подтипа АТС: `pbx_city`, `pbx_department`, `pbx_institution`.]

```sql
CREATE TABLE city (
    id         BIGSERIAL PRIMARY KEY,
    name       TEXT NOT NULL UNIQUE,
    is_home    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_city_home ON city (is_home) WHERE is_home;
```

- `id BIGSERIAL PRIMARY KEY` — авто-номер строки.
- `name TEXT NOT NULL UNIQUE` — имя обязательно и не повторяется.
- `is_home` — флаг «свой город». Хитрый #term[частичный уникальный индекс] `... WHERE is_home` гарантирует, что строк с `is_home = true` будет #term[не больше одной] (своих городов один).

Таблица `pbx` (АТС) хранит общее для всех типов: имя, код, район, ёмкость, каналы. А три таблицы-подтипа добавляют специфичные поля:

```sql
CREATE TABLE pbx_city (
    pbx_id BIGINT PRIMARY KEY REFERENCES pbx(id) ON DELETE CASCADE,
    intercity_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    region_code TEXT
);
```

- Это #term[наследование] таблицами (class-table inheritance): `pbx_city.pbx_id` одновременно и первичный ключ, и ссылка на `pbx(id)`. То есть строка-подтип «расширяет» строку `pbx` в отношении один-к-одному.
- `ON DELETE CASCADE` — удалили АТС → её строка-подтип удалится автоматически.
- `CHECK (free_channels <= total_channels)` в `pbx` — свободных каналов не может быть больше, чем всего.

= 0003 — номера и абоненты

#creates[Таблицы `phone_number` и `subscriber` — сердце предметной области.]

```sql
CREATE TABLE phone_number (
    id        BIGSERIAL PRIMARY KEY,
    number    TEXT NOT NULL UNIQUE,
    pbx_id    BIGINT NOT NULL REFERENCES pbx(id) ON DELETE RESTRICT,
    line_type line_type NOT NULL DEFAULT 'main',
    intercity intercity_status NOT NULL DEFAULT 'none',
    status    number_status NOT NULL DEFAULT 'free',
    address_id BIGINT REFERENCES address(id) ON DELETE RESTRICT, ...
);
```

- `number UNIQUE` — номер уникален.
- `pbx_id … REFERENCES pbx ON DELETE RESTRICT` — каждый номер принадлежит АТС; нельзя удалить АТС, пока у неё есть номера.
- `line_type`, `intercity`, `status` — это enum-колонки из `0001`, со значениями по умолчанию.

```sql
CREATE TABLE subscriber (
    ...
    birth_date DATE NOT NULL CHECK (birth_date > DATE '1900-01-01' AND birth_date < CURRENT_DATE),
    category   subscriber_category NOT NULL DEFAULT 'regular',
    privilege  privilege_kind,
    phone_number_id BIGINT NOT NULL REFERENCES phone_number(id) ON DELETE RESTRICT,
    CONSTRAINT chk_privilege CHECK (
        (category = 'privileged' AND privilege IS NOT NULL) OR
        (category = 'regular'    AND privilege IS NULL))
);
```

- `birth_date … CHECK (…)` — дата рождения должна быть «в прошлом» и не раньше 1900 года.
- `phone_number_id` — абонент ссылается на номер. Несколько абонентов могут ссылаться на #term[один] номер (параллельный/спаренный телефон).
- `CONSTRAINT chk_privilege` — #term[важное правило]: если абонент льготник (`category='privileged'`), у него #term[обязан] быть указан вид льготы; если простой — вид льготы #term[не указывается]. Так данные не противоречат друг другу.
- Множество `CREATE INDEX` ниже — ускоряют типовые выборки (по фамилии, по категории, по номеру).

= 0004 — журнал звонков (CDR)

#creates[Таблицу `call_record` — все звонки (местные, внутренние, внешние, межгород).]

```sql
CREATE TABLE call_record (
    id BIGSERIAL PRIMARY KEY,
    from_number_id BIGINT NOT NULL REFERENCES phone_number(id) ON DELETE CASCADE,
    call_type call_type NOT NULL,
    dest_city_id   BIGINT REFERENCES city(id) ON DELETE SET NULL,
    dest_number_id BIGINT REFERENCES phone_number(id) ON DELETE SET NULL,
    started_at TIMESTAMPTZ NOT NULL,
    duration_sec INTEGER NOT NULL CHECK (duration_sec >= 0),
    cost NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (cost >= 0),
    CONSTRAINT chk_intercity_city CHECK (call_type <> 'intercity' OR dest_city_id IS NOT NULL)
);
```

- `from_number_id` — с какого номера звонок (`ON DELETE CASCADE` — удалили номер → его звонки тоже удалятся).
- `dest_city_id` — город назначения (для межгорода), `dest_number_id` — вызываемый номер (для местных).
- `cost NUMERIC(12,2)` — стоимость деньгами (точный тип).
- `chk_intercity_city` — если звонок межгородний, у него #term[обязан] быть указан город (`dest_city_id IS NOT NULL`). Читается так: «либо тип не межгород, либо город задан».

= 0005 — биллинг

#creates[Таблицы `tariff`, `billing_settings`, `invoice`, `payment`, `penalty`, `notification`.]

- #term[`tariff`] — стоимость абонплаты по (тип линии × наличие межгорода). `UNIQUE (line_type, with_intercity, valid_from)` — не больше одного тарифа на комбинацию.
- #term[`billing_settings`] — таблица-#term[одиночка] (`id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1)` — единственная строка с `id=1`). Хранит скидку льготникам, пеню, день оплаты (20), отсрочку.
- #term[`invoice`] (счёт) — `kind` (абонплата/межгород), период (год+месяц), сумма, срок (`due_date`), статус. `UNIQUE (subscriber_id, kind, period_year, period_month)` — один счёт на абонента/вид/месяц (чтобы не было дублей за один период).
- #term[`payment`] (оплата), #term[`penalty`] (пеня), #term[`notification`] (письменное уведомление с дедлайном). У уведомления `CHECK (deadline >= sent_at)` — срок не раньше даты отправки.
- Везде `ON DELETE CASCADE` на `subscriber_id`: удалили абонента → удалились его счета/оплаты/пени.

= 0006 — очередь установки и таксофоны

#creates[Таблицы `installation_queue` (очередь на установку) и `public_phone` (таксофоны/общественные).]

- #term[`installation_queue`] — заявка на установку: ФИО заявителя, тип очереди (`regular`/`privileged` — обычная/льготная), адрес, желаемая АТС, статус (`waiting` → `installed`), выделенный номер.
- #term[`public_phone`] — вид (`public`/`payphone`), АТС, адрес, флаг `active`.
- Внешние ключи `ON DELETE RESTRICT` на адрес/АТС — нельзя удалить адрес/АТС, пока на них ссылается заявка или таксофон.

= 0007 — пользователи и права (RBAC)

#creates[Таблицы `app_user`, `role`, `permission`, `role_permission`, `user_role`.]

Это #term[ролевая система] (как ACL). Идея: пользователю назначают #term[роли], роли содержат #term[права].

```sql
CREATE TABLE permission (
    id BIGSERIAL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,   -- 'subscriber:read'
    description TEXT
);
CREATE TABLE role_permission (
    role_id       BIGINT NOT NULL REFERENCES role(id) ON DELETE CASCADE,
    permission_id BIGINT NOT NULL REFERENCES permission(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);
```

- `app_user` — оператор/админ. `password_hash` — пароль хранится не в открытом виде, а как Argon2-хеш. `is_superadmin` — обходит проверки прав.
- `permission.code` — право вида `сущность:действие` (`subscriber:read`).
- #term[`role_permission`] и #term[`user_role`] — это #term[таблицы-связки] (многие-ко-многим): «роли ↔ права» и «пользователи ↔ роли». У них #term[составной первичный ключ] `PRIMARY KEY (a, b)` — пара не повторяется.
- Роли и права лежат #term[в БД], поэтому суперадмин может всё перенастроить без правки кода (требование «роли не прибиты гвоздями»).

= 0008 — триггеры (целостность)

#creates[6 функций и 7 триггеров, которые автоматически проверяют сложные правила при изменении данных.]

#term[Триггер] — функция, которая срабатывает #term[сама] при вставке/изменении строки. Нужен там, где простого `CHECK` мало (правило затрагивает другие строки/таблицы). `BEFORE INSERT OR UPDATE` — «перед» записью; `NEW` — новая строка; `RAISE EXCEPTION` — бросить ошибку (отменить операцию).

Пример — лимит абонентов на номер по типу линии:

```sql
CREATE FUNCTION trg_subscriber_count_check() RETURNS trigger AS $$
DECLARE lt line_type; cnt INTEGER; max_subs INTEGER;
BEGIN
    SELECT line_type INTO lt FROM phone_number WHERE id = NEW.phone_number_id;
    SELECT count(*) INTO cnt FROM subscriber
        WHERE phone_number_id = NEW.phone_number_id AND id <> NEW.id;
    max_subs := CASE lt WHEN 'main' THEN 1 WHEN 'paired' THEN 2 WHEN 'parallel' THEN 2147483647 END;
    IF cnt + 1 > max_subs THEN
        RAISE EXCEPTION 'Number % (line type %) allows at most % subscriber(s)', ...;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;
```

Все 7 триггеров (что проверяют):
+ соответствие подтипа АТС её типу (×3 — на `pbx_city/department/institution`);
+ межгород только у городских АТС; у замкнутых сетей — `none`;
+ лимит абонентов на номер по типу линии (пример выше);
+ параллельные/спаренные абоненты — обязательно в одном доме;
+ авто-синхронизация статуса номера (`free` ↔ `active`) при появлении/удалении абонента.

#note[Если запрос нарушит триггер, PostgreSQL отменит операцию и бросит ошибку, а сервер превратит её в ответ `400` с понятным текстом. Так данные остаются корректными при любом доступе к базе.]

= 0009 — функция и представления

#creates[Функцию `fn_subscriber_monthly_fee` и представления `v_subscriber_full`, `v_subscriber_debt`, `v_pbx_stats`.]

#term[Представление] (`VIEW`) — это сохранённый `SELECT`, к которому обращаются как к таблице. Нужно, чтобы не повторять одни и те же `JOIN`-ы в каждом запросе.

- `v_subscriber_full` — «плоский» абонент: абонент + его номер + АТС + адрес + вычисленный возраст. На нём стоят запросы 1, 3, 6, 7, 10, 13.
- `v_subscriber_debt` — долг абонента, разбитый на абонплату / межгород / пени (суммирует неоплаченные счета). Запросы 3, 4, 13.
- `v_pbx_stats` — по каждой АТС: число свободных номеров, всего номеров, абонентов.
- `fn_subscriber_monthly_fee(id)` — #term[функция] (мини-программа в БД): считает абонплату по тарифу и применяет скидку 50% льготнику.

#note[Подробный построчный разбор этих представлений и всех 13 запросов — в отдельном PDF `docs/queries.pdf`.]

= 0010 — начальные данные (справочники)

#creates[Каталог прав, системные роли, настройки биллинга и тарифы.]

Здесь не структура, а #term[данные], без которых приложение не работает. Первый блок — это маленькая программа на языке БД (`DO $$ … $$`), которая в двух циклах создаёт права для всех сущностей × действий:

```sql
DO $$
DECLARE ent TEXT; act TEXT;
    ents TEXT[] := ARRAY['pbx','subscriber', ... ,'role'];
    acts TEXT[] := ARRAY['read','create','update','delete'];
BEGIN
    FOREACH ent IN ARRAY ents LOOP
        FOREACH act IN ARRAY acts LOOP
            INSERT INTO permission(code, description)
            VALUES (ent || ':' || act, ...) ON CONFLICT (code) DO NOTHING;
        END LOOP;
    END LOOP;
    ...
END $$;
```

- `ent || ':' || act` — склейка строк: получаются коды `pbx:read`, `pbx:create`, … (15 сущностей × 4 действия = 60 прав) + спец-права `analytics:read`, `raw_query:run`, `rbac:manage`.
- `ON CONFLICT (code) DO NOTHING` — если право уже есть, не падать (можно запускать повторно — #term[идемпотентность]).
- Дальше создаются 3 роли (`superadmin`, `operator`, `viewer`) и им раздаются права через `INSERT … SELECT`: суперадмину — все; `viewer` — все `…:read`; `operator` — read/create/update, кроме управления пользователями/ролями.
- В конце — одна строка `billing_settings` и 6 тарифов.

= 0011 — права для оставшихся ресурсов

#creates[Права для подтипов АТС (`pbx_city/department/institution`) и настроек биллинга, и выдаёт их ролям.]

Когда позже добавили CRUD для подтипов АТС и страницу настроек, понадобились новые права (`pbx_city:read` и т.д.). Этот файл их создаёт и раздаёт ролям тем же приёмом, что и `0010` (циклом + `INSERT … SELECT … ON CONFLICT DO NOTHING`).

= 0012 — личный кабинет абонента

#creates[Таблицу `customer` (аккаунт абонента) и добавляет связи в `subscriber` и `installation_queue`.]

```sql
CREATE TABLE customer (
    id BIGSERIAL PRIMARY KEY,
    login TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    last_name TEXT NOT NULL, first_name TEXT NOT NULL, middle_name TEXT,
    gender gender NOT NULL, birth_date DATE NOT NULL CHECK (...),
    category subscriber_category NOT NULL DEFAULT 'regular',
    privilege privilege_kind,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_customer_privilege CHECK (...)
);

ALTER TABLE subscriber          ADD COLUMN customer_id BIGINT REFERENCES customer(id) ON DELETE SET NULL;
ALTER TABLE installation_queue  ADD COLUMN customer_id BIGINT REFERENCES customer(id) ON DELETE SET NULL;
```

- `customer` — отдельный аккаунт горожанина (логин/пароль + личные данные), не путать с `app_user` (это сотрудники).
- #term[`ALTER TABLE … ADD COLUMN`] — изменяет #term[уже существующую] таблицу: добавляет в `subscriber` и `installation_queue` ссылку на аккаунт абонента. Так заявку и линию можно связать с тем, кто её подал.
- `ON DELETE SET NULL` — удалили аккаунт → у абонента/заявки ссылка просто обнулится (сама линия/заявка не пропадёт).

#note[Эта миграция показывает, как развивать схему: новые возможности добавляют #term[новым] файлом-миграцией (`ALTER`/`CREATE`), не трогая старые. Старые миграции после применения не меняют.]

#v(0.4cm)
#align(center)[#text(fill: gray, size: 9pt)[См. также: схема БД — `docs/schema.dbml`, разбор запросов — `docs/queries.pdf`, общий разбор — `docs/guide.pdf`.]]
