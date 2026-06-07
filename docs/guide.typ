// Разбор проекта: БД, запросы, CRUD, Rust + SeaORM
// Компиляция:  typst compile docs/guide.typ docs/guide.pdf

#set document(title: "ГТС — разбор БД, запросов и архитектуры", author: "")
#set page(
  paper: "a4",
  margin: (x: 2cm, y: 2cm),
  numbering: "1",
  footer: context [
    #set text(size: 8pt, fill: gray)
    Информационная система ГТС — учебный разбор
    #h(1fr)
    #counter(page).display("1")
  ],
)
#set text(font: "PT Sans", size: 10.5pt, lang: "ru")
#set par(justify: true, leading: 0.62em)
#show raw: set text(font: "PT Mono", size: 9pt)
#show heading: set block(above: 1.1em, below: 0.6em)
#set heading(numbering: "1.1")
#show heading.where(level: 1): it => [
  #set text(size: 16pt)
  #block(stroke: (bottom: 1pt + rgb("#cfd8e3")), inset: (bottom: 4pt), width: 100%)[#it]
]

// helper-боксы
#let where(body) = block(width: 100%, fill: rgb("#eef5ff"), stroke: 0.5pt + rgb("#9bbcf0"), inset: 9pt, radius: 5pt, spacing: 1em)[
  #text(weight: "bold", fill: rgb("#1d4ed8"))[Где смотреть. ] #body
]
#let note(body) = block(width: 100%, fill: rgb("#fff8e6"), stroke: 0.5pt + rgb("#e6c34a"), inset: 9pt, radius: 5pt, spacing: 1em)[
  #text(weight: "bold", fill: rgb("#92700e"))[Важно. ] #body
]
#let term(t) = text(weight: "bold", fill: rgb("#0f766e"))[#t]

// ─────────────────────────────────────────── титул
#align(center)[
  #v(1.5cm)
  #text(size: 26pt, weight: "bold")[Информационная система\ городской телефонной сети]
  #v(0.3cm)
  #text(size: 14pt, fill: gray)[Разбор для защиты: база данных, запросы, CRUD, Rust и SeaORM]
  #v(0.6cm)
  #text(size: 11pt)[Объяснение «с нуля» — что, зачем и где в коде]
  #v(1cm)
  #line(length: 40%, stroke: 0.5pt + gray)
]
#v(0.5cm)

#outline(title: [Содержание], indent: auto, depth: 2)
#pagebreak()

= Как устроен проект целиком

Проект — это #term[веб-приложение] для городской телефонной сети (ГТС). Оно состоит из трёх частей («слоёв»), которые общаются друг с другом:

#table(
  columns: (auto, 1fr, auto),
  inset: 7pt,
  align: (left, left, left),
  stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Слой*], [*Что делает*], [*Технологии*]),
  [База данных], [Хранит все данные: АТС, абонентов, номера, счета, звонки. Сама следит за правильностью данных.], [PostgreSQL],
  [Backend (сервер)], [Принимает запросы из браузера по HTTP, проверяет права, ходит в БД, отдаёт JSON.], [Rust, Axum, SeaORM, sqlx],
  [Frontend (сайт)], [То, что видит пользователь в браузере: таблицы, формы, кнопки.], [Vue 3, TypeScript],
)

Поток данных всегда один и тот же: #term[браузер] → (HTTP-запрос) → #term[backend] → (SQL-запрос) → #term[база данных] → и обратно ответом.

#where[Карта репозитория:
- `backend/migrations/` — SQL-файлы, которые создают базу (таблицы, триггеры, представления).
- `backend/seeds/dev_seed.sql` — демо-данные.
- `backend/entity/` — «отражение» таблиц в виде структур Rust (SeaORM).
- `backend/server/src/` — код сервера (логика, запросы, права).
- `frontend/src/` — сайт на Vue.
- `docs/schema.dbml` — визуальная схема БД (открыть на dbdiagram.io).
]

= База данных: что это и как устроена

== Реляционная БД и PostgreSQL простыми словами

#term[Реляционная база данных] — это набор #term[таблиц]. Каждая таблица — как лист Excel: есть колонки (поля) и строки (записи). Например, таблица `subscriber` (абонент) — это список людей, где у каждого есть фамилия, имя, дата рождения и т.д.

У каждой строки есть #term[первичный ключ] (`PRIMARY KEY`, обычно колонка `id`) — уникальный номер строки, по которому на неё можно сослаться. Таблицы связаны #term[внешними ключами] (`FOREIGN KEY`): например, у абонента есть поле `phone_number_id`, которое указывает на строку в таблице `phone_number`. Так данные «склеиваются» без дублирования.

#term[PostgreSQL] — это конкретная СУБД (программа, которая управляет такой базой). Она умеет не только хранить данные, но и сама проверять правила (ограничения и триггеры), о чём ниже.

== Сущности предметной области и их таблицы

Предметная область («что моделируем») — городская телефонная сеть. Главные понятия превратились в таблицы:

#table(
  columns: (auto, 1fr),
  inset: 6pt,
  stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Таблица*], [*Что хранит*]),
  [`pbx`], [АТС (телефонная станция). Бывает трёх типов: городская, ведомственная, учрежденческая.],
  [`pbx_city` / `pbx_department` / `pbx_institution`], [Доп. поля для каждого типа АТС (см. «наследование» ниже).],
  [`phone_number`], [Телефонный номер: на какой АТС, тип линии (основной/параллельный/спаренный), есть ли межгород.],
  [`subscriber`], [Абонент (человек): ФИО, пол, дата рождения, льготник или нет. Ссылается на номер.],
  [`address`], [Адрес: индекс, район, улица, дом, квартира.],
  [`call_record`], [Журнал звонков (CDR): откуда, тип, город назначения, длительность, стоимость.],
  [`tariff`, `invoice`, `payment`, `penalty`, `notification`, `billing_settings`], [Биллинг: тарифы, счета, оплаты, пени, уведомления, настройки.],
  [`installation_queue`], [Очередь на установку телефона (обычная/льготная).],
  [`public_phone`], [Таксофоны и общественные телефоны.],
  [`customer`], [Аккаунт абонента для личного кабинета (логин/пароль).],
  [`app_user`, `role`, `permission`, ...], [Сотрудники (операторы) и их права (ролевая система).],
)

#where[Все таблицы создаются в `backend/migrations/0001…0012_*.sql`. Каждый файл — отдельный «шаг» создания базы. Визуально всю схему со связями видно в `docs/schema.dbml`.]

== Наследование АТС (один из «хитрых» моментов)

По заданию АТС бывает 3 типов, и у каждого типа — свои атрибуты. Это классическая ситуация «наследования». Мы решили её приёмом #term[class-table inheritance]:

- общая таблица `pbx` хранит то, что есть у всех АТС (имя, код, район, ёмкость, каналы);
- три таблицы-«наследника» (`pbx_city`, `pbx_department`, `pbx_institution`) связаны с `pbx` один-к-одному (их ключ `pbx_id` = `pbx.id`) и хранят только специфичные поля (например, у городской — `region_code`, у ведомственной — `department_name`).

Чтобы нельзя было приписать городской АТС «ведомственные» поля, стоит #term[триггер] (см. ниже), который сверяет тип.

== Виды ограничений целостности

«Целостность» = данные всегда корректны. По заданию это требование №1, и почти всё вынесено на уровень БД (а не в код), чтобы никакой кривой запрос не испортил данные. Виды ограничений:

#table(
  columns: (auto, 1fr),
  inset: 6pt,
  stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Ограничение*], [*Что гарантирует (пример из проекта)*]),
  [`PRIMARY KEY`], [Уникальный id строки.],
  [`FOREIGN KEY`], [Ссылка ведёт на существующую строку (нельзя создать абонента с несуществующим номером).],
  [`UNIQUE`], [Нет дублей (номер телефона уникален; логин пользователя уникален).],
  [`NOT NULL`], [Поле обязательно (у абонента обязана быть фамилия).],
  [`CHECK`], [Условие на значения. Напр. `chk_privilege`: если абонент льготник — у него указан вид льготы, если простой — не указан.],
  [`ENUM` (перечисление)], [Поле принимает только значения из списка (тип линии = только `main`/`parallel`/`paired`).],
  [Частичный `UNIQUE`], [Хитрость: только один город помечен «свой» (`is_home`).],
)

== Триггеры — что это и зачем

#term[Триггер] — это маленькая функция, которая #term[автоматически срабатывает] при изменении таблицы (вставка/обновление/удаление). Нужна там, где обычного `CHECK` мало — когда правило затрагивает несколько строк или таблиц.

В проекте 7 триггеров (файл `0008_triggers.sql`). Например, правило «на основном номере максимум 1 абонент, на спаренном — 2, на параллельном — много» нельзя выразить простым `CHECK` (надо посчитать другие строки). Делаем триггером:

```sql
CREATE OR REPLACE FUNCTION trg_subscriber_count_check() RETURNS trigger AS $$
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

CREATE TRIGGER subscriber_count_check BEFORE INSERT OR UPDATE ON subscriber
    FOR EACH ROW EXECUTE FUNCTION trg_subscriber_count_check();
```

Читается так: «#term[перед] (`BEFORE`) вставкой/обновлением строки в `subscriber` посчитай, сколько абонентов уже на этом номере; если станет больше лимита для типа линии — брось ошибку (`RAISE EXCEPTION`)». `NEW` — это новая строка, которую пытаются записать.

Наши 7 триггеров (что проверяют):
+ соответствие подтипа АТС её типу (городская ≠ ведомственные поля);
+ межгород только у городских АТС; у замкнутых сетей — `none`;
+ лимит абонентов на номер по типу линии (пример выше);
+ параллельные/спаренные абоненты — обязательно в одном доме;
+ автоматическая синхронизация статуса номера (free/active) при появлении/удалении абонента.

#note[На защите частый вопрос: «почему не проверять в коде?» Ответ: правило в БД работает #term[всегда], даже если кто-то полезет в базу напрямую или другой программой. Это надёжнее и соответствует требованию «целостность максимально на уровне БД».]

== Представления (VIEW) и функция расчёта абонплаты

#term[Представление] (`VIEW`) — это «сохранённый запрос», к которому можно обращаться как к таблице. Удобно, когда один и тот же сложный `SELECT` нужен в разных местах.

Главный пример — `v_subscriber_debt` (долг абонента). Он собирает долг из трёх источников (неоплаченные счета за абонплату, за межгород, и пени) в одну «виртуальную таблицу»:

```sql
CREATE VIEW v_subscriber_debt AS
SELECT s.id AS subscriber_id,
       COALESCE(sub.amt,0)   AS subscription_debt,
       COALESCE(inter.amt,0) AS intercity_debt,
       COALESCE(pen.amt,0)   AS penalty_debt,
       COALESCE(sub.amt,0)+COALESCE(inter.amt,0)+COALESCE(pen.amt,0) AS total_debt,
       LEAST(sub.oldest, inter.oldest) AS oldest_due_date
FROM subscriber s
LEFT JOIN (SELECT subscriber_id, sum(amount) amt, min(due_date) oldest
           FROM invoice WHERE kind='subscription' AND status IN ('pending','overdue')
           GROUP BY subscriber_id) sub ON sub.subscriber_id = s.id
LEFT JOIN (...intercity...) inter ON ...
LEFT JOIN (SELECT subscriber_id, sum(amount) amt FROM penalty WHERE NOT paid
           GROUP BY subscriber_id) pen ON ...;
```

Теперь в любом запросе про должников мы просто пишем `FROM v_subscriber_debt` — и не повторяем эту логику.

Ещё есть #term[функция] `fn_subscriber_monthly_fee(id)` — считает абонплату по тарифу (тип линии × наличие межгорода) и применяет скидку 50% льготникам.

#where[Представления и функция — в `0009_views.sql`. Триггеры — в `0008_triggers.sql`. Краткое описание модели — в `docs/schema.md`.]

= Запросы к базе

== SQL по-простому

Запрос на чтение данных пишется командой `SELECT`. Основные кусочки:

#table(
  columns: (auto, 1fr),
  inset: 6pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Часть*], [*Смысл*]),
  [`SELECT a, b`], [какие колонки вернуть],
  [`FROM t`], [из какой таблицы],
  [`JOIN t2 ON ...`], [приклеить связанную таблицу (напр. к номеру — его АТС)],
  [`WHERE ...`], [условие-фильтр (только нужные строки)],
  [`GROUP BY x`], [сгруппировать строки (напр. по городу) для подсчёта],
  [`count(*)`, `sum(...)`], [агрегаты: посчитать количество / сумму внутри группы],
  [`ORDER BY ... DESC`], [сортировка],
)

== Разбор запроса №9: «город-лидер по межгороду»

Один из 13 запросов варианта. Задача: найти город, в который больше всего междугородних звонков.

```sql
SELECT c.name AS city, count(*) AS calls
FROM call_record cr
JOIN city c ON c.id = cr.dest_city_id
WHERE cr.call_type = 'intercity'
GROUP BY c.name
ORDER BY calls DESC;
```

Построчно: берём журнал звонков `call_record`, приклеиваем к каждому звонку его город (`JOIN city`), оставляем только межгород (`WHERE`), группируем по названию города (`GROUP BY`), в каждой группе считаем число звонков (`count(*)`), сортируем по убыванию. Первая строка — город-лидер.

== Разбор запроса №3: «должники»

Более «боевой» запрос — с параметрами и представлением `v_subscriber_debt`:

```sql
SELECT vf.last_name, vf.number, vf.pbx_name,
       d.subscription_debt, d.intercity_debt, d.total_debt,
       (CURRENT_DATE - d.oldest_due_date) AS days_overdue
FROM v_subscriber_debt d
JOIN v_subscriber_full vf ON vf.id = d.subscriber_id
WHERE d.total_debt > 0
  AND ($1::bigint  IS NULL OR vf.pbx_id = $1)          -- фильтр по АТС
  AND ($3::int     IS NULL OR (CURRENT_DATE - d.oldest_due_date) >= $3)  -- просрочка > N дней
  AND ($5::numeric IS NULL OR d.total_debt >= $5)      -- долг >= суммы
ORDER BY d.total_debt DESC;
```

Хитрость с `($1 IS NULL OR ...)`: если параметр не передан (NULL) — условие «выключается» и фильтр не применяется. Так один запрос обслуживает все варианты («по АТС / по всей сети / по сроку / по размеру долга») без копирования кода.

== Параметры и защита от SQL-инъекций

`$1`, `$2`, ... — это #term[параметры] (placeholders). Значения подставляет драйвер #term[отдельно] от текста запроса (#term[prepared statements]). Это защищает от #term[SQL-инъекций]: даже если пользователь введёт `'; DROP TABLE ...`, это попадёт как обычная строка-значение, а не как команда. Мы #term[никогда] не склеиваем SQL из строк руками.

== Где живут запросы в коде

13 аналитических запросов — в `backend/server/src/analytics.rs`. Каждый — это маленький обработчик: берёт параметры из URL, строит SQL, оборачивает результат в JSON прямо средствами PostgreSQL (`json_agg`), отдаёт массив.

#where[
- Аналитика (Q1–Q13): `backend/server/src/analytics.rs`
- Соответствие запрос → таблицы: таблица в конце `docs/schema.md`
- Произвольные запросы пользователя: `backend/server/src/raw_query.rs` — разрешён только один `SELECT`, выполняется в режиме «только чтение» (`READ ONLY`) с тайм-аутом, чтобы пользователь ничего не сломал.
]

= CRUD: создание, чтение, изменение, удаление

== Что такое CRUD

#term[CRUD] = Create / Read / Update / Delete — четыре базовые операции над любой сущностью. Для каждой таблицы (АТС, абоненты, тарифы…) нужны: список (с постранично — пагинацией), просмотр одной записи, создание, изменение, удаление. По заданию это требование №4, и важна мысль «переиспользование кода» — не писать одно и то же 16 раз.

== Поток одного запроса (например, список абонентов)

+ Браузер запрашивает `GET /api/subscribers?page=1&page_size=20`.
+ Сервер (Axum) находит обработчик, проверяет #term[право] `subscriber:read`.
+ Обработчик через SeaORM делает `Entity::find().paginate(...)` — SeaORM превращает это в SQL `SELECT ... LIMIT 20 OFFSET 0`.
+ PostgreSQL возвращает строки; SeaORM превращает их в структуры Rust; сервер отдаёт JSON.
+ Vue рисует таблицу.

== Главная идея: один generic-код на все сущности

Вместо 16 копий написан #term[один] обобщённый («generic») набор обработчиков. Он работает с #term[любой] сущностью `E`. Сердце — функция `crud_routes::<E>()`, которая выдаёт 5 маршрутов:

```rust
pub fn crud_routes<E>() -> Router<AppState>
where E: Resource, /* ...ограничения на тип... */ {
    Router::new()
        .route("/",      get(list::<E>).post(create::<E>))
        .route("/{id}",  get(get_one::<E>).put(update::<E>).delete(delete::<E>))
}
```

`Resource` — наш маленький «интерфейс», который связывает сущность с её именем-правом:

```rust
pub trait Resource: EntityTrait { const NAME: &'static str; }
```

А подключаются все сущности в одном месте — списком (`resources.rs`):

```rust
.nest("/subscribers",  crud_routes::<entity::subscriber::Entity>())
.nest("/pbx",          crud_routes::<entity::pbx::Entity>())
.nest("/cities",       crud_routes::<entity::city::Entity>())
// ...и так все 16 ресурсов
```

Внутри `list` есть пагинация и проверка права:

```rust
user.require(&format!("{}:read", E::NAME))?;        // право subscriber:read и т.п.
let paginator = E::find().paginate(&st.db, page_size);
let items = paginator.fetch_page(page - 1).await?;  // SELECT ... LIMIT .. OFFSET ..
```

#term[Пагинация] — это выдача данных страницами (по 20 строк), чтобы не тянуть всю таблицу разом. SeaORM делает это сам через `LIMIT`/`OFFSET`.

== Права (RBAC)

Каждая операция требует право вида `сущность:действие` (`subscriber:read`, `pbx:create`, ...). Права хранятся в БД и собираются в #term[роли]; роли назначаются пользователям. Суперадмин может всё настроить через админку (это требование №7 — роли «не прибиты гвоздями»). Проверка — строка `user.require("subscriber:create")?` внутри обработчика.

#where[
- Generic CRUD: `backend/server/src/crud.rs`
- Подключение сущностей: `backend/server/src/resources.rs`
- Права/роли (управление): `backend/server/src/admin.rs`, таблицы `role`/`permission`
- На фронте: один компонент `frontend/src/views/CrudView.vue` рисует таблицу+форму для любой сущности по «описанию» из `frontend/src/config/resources.ts`.
]

== Как добавить новую сущность (рецепт)

+ Добавить таблицу в новую миграцию.
+ Сгенерировать entity (см. след. раздел) — появится `entity/src/новая.rs`.
+ В `resources.rs` дописать `resource!(новая, "новая")` и `.nest("/новая", crud_routes::<...>())`.
+ Добавить права `новая:read/create/...` (миграция) — и всё, CRUD готов и на бэке, и на фронте.

= Rust и SeaORM: как это устроено

== Rust в двух словах

#term[Rust] — компилируемый язык с очень строгим #term[компилятором], который ловит большинство ошибок #term[до запуска] (несовпадение типов, обращение к пустому значению, гонки данных). Если проект скомпилировался — он, как правило, уже не «упадёт» на ерунде. Главные идеи:
- #term[Сильная типизация]: у каждого значения известен тип; нельзя случайно сложить число и строку.
- #term[Владение и заимствование] (ownership/borrowing): компилятор сам следит за памятью без «сборщика мусора», поэтому Rust быстрый и безопасный.
- `Result<T, E>` вместо исключений: функция явно возвращает «успех или ошибку», и её приходится обработать (отсюда `?` в коде — «если ошибка, верни её выше»).

== Что такое ORM

#term[ORM] (Object-Relational Mapping) — «переходник» между таблицами БД и объектами/структурами языка. Без ORM вы пишете SQL руками и сами раскладываете результат по полям. С ORM таблица превращается в структуру, а строки — в её экземпляры; типичные операции (найти по id, вставить, обновить) пишутся на языке, а ORM сам генерирует SQL. Преподаватель рекомендовал ORM (как Hibernate в Java) — у нас это #term[SeaORM].

== SeaORM: 4 понятия на примере абонента

Для каждой таблицы SeaORM описывает её четырьмя связанными вещами (файл `entity/src/subscriber.rs`):

#table(
  columns: (auto, 1fr),
  inset: 6pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Понятие*], [*Что это*]),
  [`Model`], [структура Rust = одна строка таблицы (поля `id`, `last_name`, `gender`, ...). Именно её мы отдаём в JSON.],
  [`Entity`], [сама таблица (к ней зовём `find()`, `find_by_id()`, `delete_by_id()`).],
  [`ActiveModel`], [«редактируемая» строка для вставки/обновления: у каждого поля состояние «задано / не задано».],
  [`Column`], [перечисление колонок (для сортировки/фильтров), `Relation` — связи с другими таблицами.],
)

Сам `Model` выглядит так (сокращённо):

```rust
#[derive(Clone, Debug, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "subscriber")]
pub struct Model {
    #[sea_orm(primary_key)] pub id: i64,
    pub last_name: String,
    pub gender: Gender,            // это наш ENUM-тип
    pub birth_date: Date,
    pub phone_number_id: i64,      // внешний ключ на phone_number
    // ...
}
```

`#[derive(...)]` и `#[sea_orm(...)]` — это #term[макросы/атрибуты]: они говорят SeaORM «сгенерируй за меня код для работы с этой таблицей». Поэтому одной структуры достаточно, чтобы появились `Entity`, `ActiveModel` и т.д.

== Откуда берутся entity: генерация из схемы

Мы не пишем эти структуры руками. Сначала создаём таблицы SQL-миграциями, потом #term[генерируем] entity прямо из живой базы командой:

```bash
sea-orm-cli generate entity -u postgres://... -o entity/src --lib --with-serde both
```

После генерации запускаем небольшой скрипт `backend/scripts/postprocess_entities.py`, который дорабатывает сгенерированный код: делает так, чтобы JSON отдавал значения ENUM в «нижнем регистре как в БД» (`male`, а не `Male`) и чтобы при создании можно было прислать частичные данные. Это инженерная мелочь, но на защите полезно знать, зачем скрипт нужен.

== SeaORM поверх sqlx: почему и ORM, и сырой SQL

SeaORM построен поверх библиотеки #term[sqlx] (она держит #term[пул соединений] с базой и реально отправляет запросы). Мы используем оба инструмента осознанно:

- #term[SeaORM] — для типового #term[CRUD] (мало кода, безопасно, переиспользуемо).
- #term[sqlx] (сырой SQL) — для 13 аналитических запросов, личного кабинета и произвольных запросов, где сложный SQL писать напрямую проще и нагляднее, чем через «конструктор» ORM.

Достаём пул sqlx прямо из SeaORM-соединения:

```rust
pub fn pool(&self) -> &sqlx::PgPool { self.db.get_postgres_connection_pool() }
```

== Как `find().paginate()` превращается в SQL

Когда мы пишем на Rust:

```rust
let paginator = entity::subscriber::Entity::find().paginate(&db, 20);
let page1 = paginator.fetch_page(0).await?;   // страница 0 = первые 20
```

SeaORM строит и выполняет примерно такой SQL:

```sql
SELECT "subscriber"."id", "subscriber"."last_name", ...
FROM "subscriber"
ORDER BY "subscriber"."id" ASC
LIMIT 20 OFFSET 0;
```

То есть `.find()` → `SELECT FROM subscriber`, `.paginate(.., 20).fetch_page(0)` → `LIMIT 20 OFFSET 0`. Результат (строки) SeaORM раскладывает обратно в `Vec<Model>`, который сервер сериализует в JSON. `.await?` — потому что обращение к базе #term[асинхронное] (сервер не «зависает», ожидая ответ БД, а обслуживает другие запросы).

#where[
- Entity (сгенерированы): `backend/entity/src/*.rs`
- Подключение к БД и пул: `backend/server/src/db.rs`, `state.rs`
- Generic CRUD на SeaORM: `backend/server/src/crud.rs`
- Зависимости и версии: `backend/server/Cargo.toml`
]

= Шпаргалка к защите

#table(
  columns: (1fr, 1.2fr),
  inset: 7pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Вопрос*], [*Короткий ответ + где код*]),
  [Где обеспечивается целостность данных?], [На уровне БД: PK/FK/UNIQUE/CHECK/ENUM + 7 триггеров. `migrations/0008_triggers.sql`.],
  [Зачем триггеры, а не проверки в коде?], [Работают всегда, при любом доступе к БД; требование «целостность максимально в БД».],
  [Как реализованы 13 запросов варианта?], [Параметризованный SQL в `analytics.rs`; сложную логику долга вынесли в VIEW `v_subscriber_debt`.],
  [Как защищены от SQL-инъекций?], [Только prepared statements (`$1, $2`); строки руками не склеиваем.],
  [Что такое CRUD и где переиспользование?], [Один generic `crud_routes::<E>()` на все 16 сущностей. `crud.rs` + `resources.rs`.],
  [Что такое пагинация?], [Выдача страницами через `LIMIT/OFFSET`; в SeaORM — `.paginate().fetch_page()`.],
  [Как устроена авторизация/роли?], [Права `сущность:действие` в БД, роли настраивает суперадмин. `admin.rs`, таблицы `role/permission`.],
  [Что такое SeaORM?], [ORM для Rust: таблица → `Model/Entity/ActiveModel`. Генерируем из схемы `sea-orm-cli`.],
  [ORM или сырой SQL?], [Оба: SeaORM для CRUD, sqlx для аналитики и кабинета. SeaORM работает поверх sqlx.],
  [Конфигурация подключения к БД?], [В `backend/config.toml` (host/port/user/password/name) + переопределение через переменные окружения.],
)

#v(0.4cm)
#align(center)[#text(fill: gray, size: 9pt)[Полная визуальная схема БД — `docs/schema.dbml` (импортировать на dbdiagram.io). Описание API — `docs/api.md`.]]
