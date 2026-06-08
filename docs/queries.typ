// Подробный разбор 13 аналитических SQL-запросов варианта (ГТС)
// Компиляция:  typst compile docs/queries.typ docs/queries.pdf

#set document(title: "ГТС — разбор 13 SQL-запросов", author: "")
#set page(
  paper: "a4",
  margin: (x: 2cm, y: 1.9cm),
  numbering: "1",
  footer: context [
    #set text(size: 8pt, fill: gray)
    ГТС — разбор 13 SQL-запросов варианта
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

#let where(body) = block(width: 100%, fill: rgb("#eef5ff"), stroke: 0.5pt + rgb("#9bbcf0"), inset: 9pt, radius: 5pt, spacing: 1em)[
  #text(weight: "bold", fill: rgb("#1d4ed8"))[Где смотреть. ] #body
]
#let note(body) = block(width: 100%, fill: rgb("#fff8e6"), stroke: 0.5pt + rgb("#e6c34a"), inset: 9pt, radius: 5pt, spacing: 1em)[
  #text(weight: "bold", fill: rgb("#92700e"))[Важно. ] #body
]
#let res(body) = block(width: 100%, fill: rgb("#eefcf3"), stroke: 0.5pt + rgb("#86d6a8"), inset: 9pt, radius: 5pt, spacing: 1em)[
  #text(weight: "bold", fill: rgb("#0f766e"))[Что вернёт. ] #body
]
#let term(t) = text(weight: "bold", fill: rgb("#0f766e"))[#t]
#let task(body) = block(width: 100%, fill: rgb("#f5f3ff"), stroke: 0.5pt + rgb("#c4b5fd"), inset: 9pt, radius: 5pt, spacing: 1em)[
  #text(weight: "bold", fill: rgb("#6d28d9"))[Задача варианта. ] #body
]

#align(center)[
  #v(1.2cm)
  #text(size: 25pt, weight: "bold")[13 запросов варианта:\ подробный разбор SQL]
  #v(0.3cm)
  #text(size: 14pt, fill: gray)[Информационная система городской телефонной сети]
  #v(0.5cm)
  #text(size: 11pt)[Каждый запрос — построчно: что, зачем и как]
  #v(0.8cm)
  #line(length: 40%, stroke: 0.5pt + gray)
]
#v(0.3cm)
#outline(title: [Содержание], indent: auto, depth: 1)
#pagebreak()

= Как устроены все 13 запросов (общее)

Все аналитические запросы лежат в одном файле `backend/server/src/analytics.rs`. Каждый — это маленький обработчик HTTP-запроса: берёт параметры из строки URL, подставляет их в SQL и отдаёт результат как JSON-массив.

#where[Запросы: `backend/server/src/analytics.rs`. Представления и функция, на которых они стоят: `backend/migrations/0009_views.sql`. Привязка «запрос → таблицы»: таблица в конце `docs/schema.md`.]

Во всех запросах повторяются три приёма — разберём их один раз, чтобы потом не повторяться.

== Приём 1. Результат сразу как JSON (`wrap`)

Любой `SELECT` оборачивается функцией `wrap`, чтобы PostgreSQL сам собрал все строки в один JSON-массив:

```rust
fn wrap(inner: &str) -> String {
    format!("SELECT coalesce(json_agg(row_to_json(q)), '[]'::json) FROM ({inner}) q")
}
```

`row_to_json(q)` превращает строку в объект `{...}`, `json_agg(...)` собирает их в массив `[ {...}, {...} ]`, `coalesce(..., '[]')` отдаёт пустой массив, если строк нет. Благодаря этому Rust-код просто забирает одно готовое JSON-значение и возвращает его в ответ — не нужно описывать структуру под каждый запрос.

== Приём 2. «Выключаемый» фильтр `($1 IS NULL OR …)`

Почти все параметры необязательные. Чтобы один запрос обслуживал и «по конкретной АТС», и «по всей сети», используется такая конструкция:

```sql
AND ($1::bigint IS NULL OR pbx_id = $1)
```

Если параметр `$1` не передан (`NULL`) — левая часть `IS NULL` истинна, и всё условие истинно (фильтр «выключен»). Если передан — работает правая часть `pbx_id = $1`. Так не нужно плодить десяток почти одинаковых запросов.

== Приём 3. Параметры и приведение типов

`$1`, `$2`, … — это #term[параметры] (подставляются драйвером отдельно от текста — защита от SQL-инъекций). Запись `$1::bigint`, `$2::text` — это #term[приведение типа] (cast): мы заранее говорим, какого типа параметр. А `category::text` приводит enum-колонку к тексту, чтобы сравнить со строковым параметром.

= Фундамент: представления и функция

Чтобы не повторять одни и те же `JOIN`-ы в каждом запросе, заранее созданы #term[представления] (сохранённые запросы, к которым обращаются как к таблице).

== `v_subscriber_full` — «плоский» абонент

Склеивает абонента с его номером, АТС и адресом и добавляет вычисленный возраст:

```sql
CREATE VIEW v_subscriber_full AS
SELECT s.id, s.last_name, s.first_name, s.gender, s.birth_date,
       date_part('year', age(s.birth_date))::int AS age,
       s.category, s.privilege, s.status,
       pn.number, pn.line_type, pn.intercity,
       p.id AS pbx_id, p.name AS pbx_name, p.pbx_type, p.district AS pbx_district,
       a.district, a.street, a.house, a.apartment
FROM subscriber s
JOIN phone_number pn ON pn.id = s.phone_number_id
JOIN pbx p          ON p.id = pn.pbx_id
JOIN address a      ON a.id = s.address_id;
```

Используется в запросах 1, 3, 6, 7, 10, 13. `age` считается из даты рождения функцией `age()` + `date_part('year', …)`.

== `v_subscriber_debt` — долг абонента

Считает долг каждого абонента, разбитый на три части (абонплата / межгород / пени):

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
           GROUP BY subscriber_id) sub   ON sub.subscriber_id = s.id
LEFT JOIN (/* то же для kind='intercity' */) inter ON inter.subscriber_id = s.id
LEFT JOIN (SELECT subscriber_id, sum(amount) amt FROM penalty WHERE NOT paid
           GROUP BY subscriber_id) pen   ON pen.subscriber_id = s.id;
```

Каждый подзапрос суммирует неоплаченные счета (`status IN ('pending','overdue')`) по виду. `COALESCE(...,0)` — если долгов нет, подставить 0 (а не NULL). `oldest_due_date` — самый ранний срок оплаты (для расчёта просрочки). Используется в запросах 3, 4, 13.

== `v_pbx_stats` — сводка по АТС

По каждой АТС считает свободные номера, всего номеров и число абонентов:

```sql
count(pn.id) FILTER (WHERE pn.status = 'free') AS free_numbers,
count(pn.id)                                   AS total_numbers,
count(DISTINCT s.id)                           AS subscribers
```

`FILTER (WHERE …)` — посчитать только подходящие. Используется в запросе 11.

== `fn_subscriber_monthly_fee(id)` — абонплата

Функция: берёт тариф по (тип линии × открыт ли межгород) и применяет скидку 50% льготнику. Возвращает сумму абонплаты. Используется при подключении и в личном кабинете.

= Мини-справочник по SQL

#table(
  columns: (auto, 1fr),
  inset: 5.5pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Конструкция*], [*Смысл*]),
  [`JOIN t ON …`], [приклеить связанную таблицу (только совпавшие строки)],
  [`LEFT JOIN t ON …`], [приклеить, сохранив все левые строки; нет пары → справа `NULL`],
  [`WHERE`], [фильтр строк (до группировки)],
  [`GROUP BY x`], [сгруппировать строки по `x`],
  [`count(*)`, `sum(c)`], [агрегаты: число строк / сумма по группе],
  [`count(*) FILTER (WHERE …)`], [посчитать только подходящие внутри группы],
  [`HAVING …`], [фильтр уже по группам (после агрегации)],
  [`COALESCE(x, 0)`], [заменить `NULL` на `0`],
  [`NULLIF(x, 0)`], [превратить `0` в `NULL` (защита от деления на ноль)],
  [`ILIKE 'Ив%'`], [регистронезависимый поиск по префиксу],
  [`EXISTS (…)`], [есть ли хотя бы одна строка в подзапросе],
  [`CURRENT_DATE - d`], [разница дат в днях],
  [`col::text`], [привести значение (напр. enum) к тексту],
)

#pagebreak()

= Q1. Абоненты АТС

#task[Получить перечень и общее число абонентов указанной АТС: полностью, только льготников, по возрастному признаку, по группе фамилий.]

Параметры: `pbx_id`, `category` (regular/privileged), `min_age`, `max_age`, `surname` (префикс).

```sql
SELECT * FROM v_subscriber_full
WHERE ($1::bigint IS NULL OR pbx_id = $1)
  AND ($2::text   IS NULL OR category::text = $2)
  AND ($3::int    IS NULL OR age >= $3)
  AND ($4::int    IS NULL OR age <= $4)
  AND ($5::text   IS NULL OR last_name ILIKE $5 || '%')
ORDER BY last_name, first_name;
```

Разбор:
- База — `v_subscriber_full`, где уже есть ФИО, номер, АТС, адрес и вычисленный `age`.
- `($1 … pbx_id = $1)` — «указанная АТС». Не передали — значит по всей ГТС.
- `($2 … category::text = $2)` — «только льготники» (`privileged`) или простые (`regular`).
- `age >= $3` и `age <= $4` — «по возрастному признаку» (диапазон).
- `last_name ILIKE $5 || '%'` — «по группе фамилий»: `$5='Ив'` найдёт Иванов, Иванова, Иващенко (`||'%'` — любое окончание).
- `ORDER BY last_name, first_name` — по алфавиту.

#res[Массив абонентов. «Общее число» — это длина массива (фронт показывает счётчик).]

= Q2. Свободные номера

#task[Получить перечень и общее число свободных телефонных номеров на указанной АТС, по всей ГТС, по признаку возможности установки телефона в данном районе.]

Параметры: `pbx_id`, `district`.

```sql
SELECT pn.id, pn.number, pn.line_type, pn.intercity, p.name AS pbx_name, p.district
FROM phone_number pn JOIN pbx p ON p.id = pn.pbx_id
WHERE pn.status = 'free'
  AND ($1::bigint IS NULL OR pn.pbx_id = $1)
  AND ($2::text   IS NULL OR p.district = $2)
ORDER BY pn.number;
```

Разбор:
- `pn.status = 'free'` — свободный номер (без абонента; статус поддерживается триггером автоматически).
- `JOIN pbx` — чтобы вернуть имя и район АТС.
- `pbx_id` — на конкретной АТС; пусто — по всей ГТС; `district` — по району.
- Наличие свободных номеров в районе и есть «признак возможности установки телефона».

= Q3. Должники

#task[Должники на указанной АТС, по всей ГТС, по району; те, кто должен уже больше недели (месяца); по признаку долга за межгород и/или абонплату; по размеру долга.]

Параметры: `pbx_id`, `district`, `min_days`, `kind` (any/subscription/intercity), `min_amount`.

```sql
SELECT vf.last_name, vf.number, vf.pbx_name,
       d.subscription_debt, d.intercity_debt, d.total_debt,
       (CURRENT_DATE - d.oldest_due_date) AS days_overdue
FROM v_subscriber_debt d JOIN v_subscriber_full vf ON vf.id = d.subscriber_id
WHERE d.total_debt > 0
  AND ($1::bigint  IS NULL OR vf.pbx_id = $1)
  AND ($2::text    IS NULL OR vf.pbx_district = $2)
  AND ($3::int     IS NULL OR (CURRENT_DATE - d.oldest_due_date) >= $3)
  AND ($5::numeric IS NULL OR d.total_debt >= $5)
  AND ($4::text IS NULL OR $4 = 'any'
       OR ($4 = 'subscription' AND d.subscription_debt > 0)
       OR ($4 = 'intercity'    AND d.intercity_debt > 0))
ORDER BY d.total_debt DESC;
```

Разбор:
- `v_subscriber_debt d` даёт суммы долга, `JOIN v_subscriber_full vf` — ФИО/номер/АТС.
- `d.total_debt > 0` — оставить только должников.
- `pbx_id` / `pbx_district` — «на АТС / по району»; пусто — по всей ГТС.
- `days_overdue = CURRENT_DATE - oldest_due_date` (просрочка в днях); `>= $3` — «больше недели/месяца» (передаём 7 или 30).
- `total_debt >= $5` — «по размеру долга».
- Блок `$4` — «по признаку долга»: `subscription` (есть долг по абонплате), `intercity` (по межгороду), `any` или пусто — любой.
- `ORDER BY total_debt DESC` — крупнейшие должники сверху.

#res[На демо-данных: Кузнецов — 1250 ₽ (просрочка 47 дн.), Васильева — 100 ₽ (17 дн.).]

= Q4. Рейтинг АТС по долгам

#task[Определить АТС (любого или конкретного типа), на которой самое большое (маленькое) число должников и самая большая сумма задолженности.]

Параметры: `pbx_type`.

```sql
SELECT p.id AS pbx_id, p.name AS pbx_name, p.pbx_type::text AS pbx_type,
       count(d.subscriber_id) AS debtors,
       COALESCE(sum(d.total_debt), 0) AS debt_sum
FROM pbx p
LEFT JOIN phone_number pn ON pn.pbx_id = p.id
LEFT JOIN subscriber s    ON s.phone_number_id = pn.id
LEFT JOIN v_subscriber_debt d ON d.subscriber_id = s.id AND d.total_debt > 0
WHERE ($1::text IS NULL OR p.pbx_type::text = $1)
GROUP BY p.id
ORDER BY debt_sum DESC;
```

Разбор:
- Начинаем с `pbx` и идём цепочкой `LEFT JOIN`: АТС → её номера → абоненты → их долг (только `total_debt > 0`).
- Почему `LEFT JOIN`, а не `JOIN`: чтобы в рейтинг попали #term[все] АТС, даже те, где должников нет (у них `debtors = 0`).
- `count(d.subscriber_id)` — число должников (значения `NULL`, появившиеся из-за `LEFT JOIN`, в `count(колонка)` не считаются — это и даёт ноль для «чистых» АТС).
- `sum(d.total_debt)` — суммарный долг по АТС.
- `pbx_type` — ограничить конкретным типом АТС.
- `ORDER BY debt_sum DESC` — сверху АТС-лидер по долгу, снизу — минимум.

= Q5. Таксофоны и общественные телефоны

#task[Получить перечень и число общественных телефонов и таксофонов во всём городе, принадлежащих указанной АТС, по признаку нахождения в данном районе.]

Параметры: `pbx_id`, `district`, `kind` (public/payphone).

```sql
SELECT pp.id, pp.kind::text AS kind, p.name AS pbx_name,
       a.district, a.street, a.house, pp.active
FROM public_phone pp
JOIN pbx p     ON p.id = pp.pbx_id
JOIN address a ON a.id = pp.address_id
WHERE ($1::bigint IS NULL OR pp.pbx_id = $1)
  AND ($2::text   IS NULL OR a.district = $2)
  AND ($3::text   IS NULL OR pp.kind::text = $3)
ORDER BY pp.kind, a.district, a.street;
```

Разбор:
- `public_phone` хранит вид (`public` — общественный, `payphone` — таксофон), его АТС и адрес.
- `JOIN pbx` и `JOIN address` — чтобы вернуть имя АТС и адрес (улица/дом/район).
- Фильтры: `pbx_id` — «принадлежащих указанной АТС»; `district` — «в данном районе»; `kind` — отдельно таксофоны или общественные; всё пусто — по всему городу.

= Q6. Доля простых и льготных

#task[Найти процентное соотношение обычных и льготных абонентов на указанной АТС, по всей ГТС, по данному району, по типам АТС.]

Параметры: `pbx_id`, `district`, `pbx_type`.

```sql
SELECT count(*) AS total,
       count(*) FILTER (WHERE category = 'regular')    AS regular,
       count(*) FILTER (WHERE category = 'privileged') AS privileged,
       round(100.0 * count(*) FILTER (WHERE category='regular')    / NULLIF(count(*),0), 2) AS regular_pct,
       round(100.0 * count(*) FILTER (WHERE category='privileged') / NULLIF(count(*),0), 2) AS privileged_pct
FROM v_subscriber_full
WHERE ($1::bigint IS NULL OR pbx_id = $1)
  AND ($2::text   IS NULL OR district = $2)
  AND ($3::text   IS NULL OR pbx_type::text = $3);
```

Разбор:
- `count(*)` — всего абонентов в выбранной области.
- `count(*) FILTER (WHERE category='regular')` — сколько простых; аналогично — льготных.
- Процент: `100.0 * простых / всего`, округление `round(…, 2)` до 2 знаков.
- `NULLIF(count(*), 0)` — если абонентов нет (0), превращаем делитель в `NULL`, чтобы не было #term[деления на ноль] (результат станет `NULL`, а не ошибка).
- Фильтры `pbx_id` / `district` / `pbx_type` задают область: АТС / район / тип АТС / вся ГТС.

#res[Одна строка, напр.: `total=9, regular=7 (77.78%), privileged=2 (22.22%)`.]

= Q7. Абоненты с параллельными телефонами

#task[Абоненты, имеющие параллельные телефоны (по АТС / ГТС / району / типам АТС); только льготники с параллельными.]

Параметры: `pbx_id`, `district`, `pbx_type`, `privileged_only` (bool).

```sql
SELECT * FROM v_subscriber_full
WHERE line_type = 'parallel'
  AND ($1::bigint IS NULL OR pbx_id = $1)
  AND ($2::text   IS NULL OR district = $2)
  AND ($3::text   IS NULL OR pbx_type::text = $3)
  AND ($4::bool   IS NULL OR $4 = false OR category = 'privileged')
ORDER BY number, last_name;
```

Разбор:
- `line_type = 'parallel'` — берём только абонентов на параллельных линиях.
- Обычные фильтры по АТС / району / типу АТС.
- `($4 IS NULL OR $4 = false OR category='privileged')` — если `privileged_only=true`, оставить #term[только льготников]; если `false` или не передан — всех.

= Q8. Телефоны по адресу

#task[Определить, есть ли по данному адресу телефон; общее количество телефонов и/или количество с выходом на межгород, с открытым выходом на межгород — в данном доме, на конкретной улице.]

Параметры: `district`, `street`, `house`.

```sql
SELECT a.district, a.street, a.house,
       count(pn.id) AS phones,
       count(pn.id) FILTER (WHERE pn.intercity IN ('open','closed')) AS with_intercity,
       count(pn.id) FILTER (WHERE pn.intercity = 'open')             AS with_open_intercity
FROM phone_number pn JOIN address a ON a.id = pn.address_id
WHERE ($1::text IS NULL OR a.district = $1)
  AND ($2::text IS NULL OR a.street = $2)
  AND ($3::text IS NULL OR a.house = $3)
GROUP BY a.district, a.street, a.house
ORDER BY a.district, a.street, a.house;
```

Разбор:
- `JOIN address` — каждый номер привязан к адресу установки.
- `GROUP BY district, street, house` — группируем по #term[дому].
- `phones = count(*)` — всего телефонов в доме (если `> 0` — телефон по адресу есть).
- `with_intercity` — у скольких есть выход на межгород: `intercity IN ('open','closed')` (есть техническая возможность — открыт или закрыт).
- `with_open_intercity` — у скольких межгород именно открыт.
- Фильтры: указать дом (`house`) → одна строка; указать только улицу → по всем домам улицы.

= Q9. Город — лидер по межгороду

#task[Определить город, с которым происходит большее количество междугородных переговоров.]

Без параметров.

```sql
SELECT c.name AS city, count(*) AS calls
FROM call_record cr JOIN city c ON c.id = cr.dest_city_id
WHERE cr.call_type = 'intercity'
GROUP BY c.name
ORDER BY calls DESC;
```

Разбор:
- `call_record` — журнал всех звонков; `JOIN city` — приклеить город назначения.
- `WHERE call_type = 'intercity'` — только междугородние.
- `GROUP BY c.name` + `count(*)` — для каждого города посчитать число звонков.
- `ORDER BY calls DESC` — первая строка и есть город-лидер.

#res[На демо-данных: Москва — 6 звонков (лидер), Екатеринбург — 1, Новосибирск — 1.]

= Q10. Полная информация по номеру

#task[Получить полную информацию об абонентах с заданным телефонным номером.]

Параметр: `number` (обязательный).

```sql
SELECT * FROM v_subscriber_full WHERE number = $1;
```

Разбор:
- Простой запрос к `v_subscriber_full` по номеру.
- На один номер может приходиться #term[несколько] абонентов (параллельный/спаренный телефон) — тогда вернётся несколько строк, по строке на каждого, со всей информацией (ФИО, адрес, АТС, тип линии, межгород).

= Q11. Спаренные, которые можно расспарить

#task[Получить перечень спаренных телефонов, для которых есть техническая возможность заменить их на обычные (выделить дополнительный номер).]

Параметр: `pbx_id`.

```sql
SELECT pn.id, pn.number, p.name AS pbx_name, p.district,
       st.free_numbers, p.free_channels
FROM phone_number pn
JOIN pbx p          ON p.id = pn.pbx_id
JOIN v_pbx_stats st ON st.pbx_id = p.id
WHERE pn.line_type = 'paired'
  AND st.free_numbers > 0 AND p.free_channels > 0
  AND ($1::bigint IS NULL OR pn.pbx_id = $1)
ORDER BY pn.number;
```

Разбор:
- `line_type = 'paired'` — берём спаренные номера.
- «Техническая возможность» = на их АТС есть, что выделить: `st.free_numbers > 0` (свободный номер, из `v_pbx_stats`) и `p.free_channels > 0` (свободный канал).
- Если оба условия выполнены — спаренный телефон можно «расспарить», выделив второму абоненту отдельный номер.

= Q12. Внутренние номера с малым числом внешних звонков

#task[Получить перечень и число внутренних номеров определённой ведомственной или учрежденческой АТС, с которых за некоторый период было сделано менее определённого числа внешних звонков.]

Параметры: `pbx_id`, `from`, `to` (период), `max_calls` (N).

```sql
SELECT pn.id, pn.number, p.name AS pbx_name, p.pbx_type::text AS pbx_type,
       count(cr.id) AS external_calls
FROM phone_number pn
JOIN pbx p ON p.id = pn.pbx_id AND p.pbx_type IN ('departmental','institutional')
LEFT JOIN call_record cr ON cr.from_number_id = pn.id AND cr.call_type = 'external'
     AND ($2::timestamptz IS NULL OR cr.started_at >= $2::timestamptz)
     AND ($3::timestamptz IS NULL OR cr.started_at <  $3::timestamptz)
WHERE ($1::bigint IS NULL OR pn.pbx_id = $1)
GROUP BY pn.id, pn.number, p.name, p.pbx_type
HAVING count(cr.id) < $4
ORDER BY external_calls, pn.number;
```

Разбор:
- `JOIN pbx … AND p.pbx_type IN ('departmental','institutional')` — берём номера только #term[замкнутых] (ведомственных/учрежденческих) АТС.
- `LEFT JOIN call_record` на внешние звонки (`call_type='external'`) в периоде. `LEFT` — чтобы номера #term[без] звонков тоже попали (у них `count = 0`).
- `GROUP BY` по номеру + `count(cr.id)` — сколько внешних звонков у каждого номера.
- `HAVING count(cr.id) < $4` — оставить тех, у кого внешних звонков #term[меньше] N. `HAVING` — это фильтр уже по группам (после подсчёта), в отличие от `WHERE`.

#note[Условия на период стоят #term[внутри] `LEFT JOIN` (после `ON`), а не в `WHERE`. Это важно: если поставить условие на правую таблицу (`call_record`) в `WHERE`, то `LEFT JOIN` фактически превратится в обычный `JOIN`, и номера без звонков потеряются. В `ON` — фильтруем звонки, но строки-номера сохраняем.]

= Q13. Должники: кого уведомить / отключить / заблокировать

#task[Должники на АТС / по всей ГТС / по району, которым следует послать письменное уведомление, отключить телефон и/или выход на межгород.]

Параметры: `pbx_id`, `district`.

```sql
SELECT vf.last_name, vf.number, vf.pbx_name, vf.status, vf.intercity,
       d.subscription_debt, d.intercity_debt, d.total_debt,
       (d.subscription_debt > 0 AND NOT EXISTS (
           SELECT 1 FROM notification n WHERE n.subscriber_id = vf.id
           AND n.kind='subscription_debt' AND NOT n.resolved)) AS notice_subscription,
       (d.intercity_debt > 0 AND NOT EXISTS (
           SELECT 1 FROM notification n WHERE n.subscriber_id = vf.id
           AND n.kind='intercity_debt' AND NOT n.resolved)) AS notice_intercity,
       (d.subscription_debt > 0 AND vf.status <> 'disconnected' AND EXISTS (
           SELECT 1 FROM notification n WHERE n.subscriber_id = vf.id
           AND n.kind='subscription_debt' AND NOT n.resolved
           AND n.deadline < CURRENT_DATE)) AS should_disconnect,
       (d.intercity_debt > 0 AND vf.intercity = 'open' AND EXISTS (
           SELECT 1 FROM notification n WHERE n.subscriber_id = vf.id
           AND n.kind='intercity_debt' AND NOT n.resolved
           AND n.deadline < CURRENT_DATE)) AS should_block_intercity
FROM v_subscriber_debt d JOIN v_subscriber_full vf ON vf.id = d.subscriber_id
WHERE d.total_debt > 0
  AND ($1::bigint IS NULL OR vf.pbx_id = $1)
  AND ($2::text   IS NULL OR vf.pbx_district = $2)
ORDER BY d.total_debt DESC;
```

Разбор. Для каждого должника считаются 4 булевых флага-рекомендации (через `EXISTS` / `NOT EXISTS` — «существует ли уведомление с такими условиями»):
- #term[notice_subscription] — есть долг по абонплате И ещё #term[нет] активного уведомления (`NOT EXISTS … NOT resolved`) → нужно #term[послать письменное уведомление].
- #term[notice_intercity] — то же для долга по межгороду.
- #term[should_disconnect] — есть долг по абонплате, абонент ещё не отключён, И уже есть уведомление с #term[истёкшим] сроком (`deadline < CURRENT_DATE`) → пора #term[отключать телефон].
- #term[should_block_intercity] — есть долг по межгороду, межгород ещё открыт, И уведомление просрочено → пора #term[блокировать межгород].

Это реализует всю логику задания: «при неуплате после письменного уведомления в течение N суток — отключение»; запрос находит, на каком этапе каждый должник.

#res[На демо-данных: Кузнецов → `should_disconnect = true`, `notice_intercity = true` (по межгороду уведомления ещё не было).]

#v(0.4cm)
#align(center)[#text(fill: gray, size: 9pt)[См. также: общий разбор — `docs/guide.pdf`, разбор CRUD — `docs/crud.pdf`, схема БД — `docs/schema.dbml`.]]
