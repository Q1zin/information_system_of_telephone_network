// Подробный разбор CRUD-операций проекта ГТС
// Компиляция:  typst compile docs/crud.typ docs/crud.pdf

#set document(title: "ГТС — как работают CRUD-операции", author: "")
#set page(
  paper: "a4",
  margin: (x: 2cm, y: 2cm),
  numbering: "1",
  footer: context [
    #set text(size: 8pt, fill: gray)
    ГТС — как работают CRUD-операции
    #h(1fr)
    #counter(page).display("1")
  ],
)
#set text(font: "PT Sans", size: 10.5pt, lang: "ru")
#set par(justify: true, leading: 0.62em)
#show raw: set text(font: "PT Mono", size: 8.7pt)
#show heading: set block(above: 1.1em, below: 0.6em)
#set heading(numbering: "1.1")
#show heading.where(level: 1): it => [
  #set text(size: 16pt)
  #block(stroke: (bottom: 1pt + rgb("#cfd8e3")), inset: (bottom: 4pt), width: 100%)[#it]
]

#let where(body) = block(width: 100%, fill: rgb("#eef5ff"), stroke: 0.5pt + rgb("#9bbcf0"), inset: 9pt, radius: 5pt, spacing: 1em)[
  #text(weight: "bold", fill: rgb("#1d4ed8"))[Где смотреть. ] #body
]
#let note(body) = block(width: 100%, fill: rgb("#fff8e6"), stroke: 0.5pt + rgb("#e6c34a"), inset: 9pt, radius: 5pt, spacing: 1em)[
  #text(weight: "bold", fill: rgb("#92700e"))[Важно. ] #body
]
#let term(t) = text(weight: "bold", fill: rgb("#0f766e"))[#t]

#align(center)[
  #v(1.5cm)
  #text(size: 26pt, weight: "bold")[Как работают CRUD-операции]
  #v(0.3cm)
  #text(size: 14pt, fill: gray)[Информационная система городской телефонной сети]
  #v(0.6cm)
  #text(size: 11pt)[Подробный разбор: от клика в браузере до SQL и обратно]
  #v(1cm)
  #line(length: 40%, stroke: 0.5pt + gray)
]
#v(0.4cm)
#outline(title: [Содержание], indent: auto, depth: 2)
#pagebreak()

= Идея: один обобщённый CRUD на все сущности

#term[CRUD] = Create / Read / Update / Delete (создать / прочитать / изменить / удалить) — четыре базовые операции над данными. Плюс «список с постраничной выдачей» (#term[пагинация]).

В проекте 16 справочных сущностей (АТС и её 3 подтипа, абоненты, номера, адреса, города, звонки, тарифы, счета, платежи, пени, уведомления, очередь, таксофоны). Если писать CRUD для каждой отдельно — это 16 копий почти одинакового кода. Вместо этого написан #term[один обобщённый («generic») набор из 5 обработчиков], который работает с #term[любой] сущностью. Это и есть выполнение требования «CRUD по всем сущностям + переиспользование кода».

#where[
Серверная часть CRUD — всего два файла:
- `backend/server/src/crud.rs` — обобщённые обработчики (`list/get_one/create/update/delete`) и сборщик маршрутов `crud_routes`.
- `backend/server/src/resources.rs` — подключение каждой сущности к этому обобщённому коду.

Данные о таблицах (сущности SeaORM) — в `backend/entity/src/*.rs`.
Клиентская часть — один компонент `frontend/src/views/CrudView.vue` + «описания» сущностей в `frontend/src/config/resources.ts`.
]

= Полный путь запроса (на примере «список абонентов»)

Когда оператор открывает страницу «Абоненты», происходит следующее:

#table(
  columns: (auto, 1fr),
  inset: 7pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Шаг*], [*Что происходит*]),
  [1. Браузер], [Vue отправляет HTTP-запрос `GET /api/subscribers?page=1&page_size=20` (через axios, `frontend/src/api/crud.ts`).],
  [2. Прокси], [В разработке Vite, в Docker — nginx; перенаправляют `/api/...` на backend (порт 8080). Куки сессии едут вместе с запросом.],
  [3. Роутер Axum], [`main.rs` монтирует всё под `/api`; `resources.rs` направляет `/subscribers` в обобщённый обработчик `list::<subscriber::Entity>`.],
  [4. Проверка прав], [Обработчик требует право `subscriber:read`. Нет права → ответ `403`.],
  [5. SeaORM], [`Entity::find().paginate(...)` строит и выполняет SQL `SELECT ... LIMIT 20 OFFSET 0` (+ запрос на общее число строк).],
  [6. PostgreSQL], [Возвращает строки; SeaORM раскладывает их в структуры Rust (`Vec<Model>`).],
  [7. Ответ], [Обработчик отдаёт JSON `{ items, total, page, page_size, total_pages }`.],
  [8. Браузер], [Vue рисует таблицу и постраничную навигацию.],
)

= Каркас: `crud_routes` — 5 маршрутов одной функцией

Точка входа — обобщённая функция. Для сущности `E` она выдаёт `Router` с пятью маршрутами:

```rust
pub fn crud_routes<E>() -> Router<AppState>
where
    E: Resource + 'static,
    E::Model: Serialize + Send + Sync + IntoActiveModel<E::ActiveModel> + for<'de> Deserialize<'de>,
    E::ActiveModel: ActiveModelTrait<Entity = E> + ActiveModelBehavior + Send + Sync + Default,
    E::PrimaryKey: PrimaryKeyToColumn<Column = E::Column> + PrimaryKeyTrait<ValueType = i64>,
{
    Router::new()
        .route("/",     get(list::<E>).post(create::<E>))
        .route("/{id}", get(get_one::<E>).put(update::<E>).delete(delete::<E>))
}
```

#term[Как читать]. `crud_routes<E>` — функция, #term[обобщённая по типу] `E` (entity-таблица). Блок `where { ... }` — это #term[ограничения на тип] `E`: «`E` должна быть таблицей SeaORM (`Resource`), её строка (`Model`) должна уметь превращаться в JSON (`Serialize`) и обратно (`Deserialize`), её первичный ключ — целое число (`ValueType = i64`)». Эти ограничения нужны, чтобы внутри можно было звать `find()`, `insert()`, `paginate()` и т.п. Маршруты:

#table(
  columns: (auto, auto, 1fr),
  inset: 6pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Метод + путь*], [*Обработчик*], [*Операция*]),
  [`GET /`], [`list`], [список (с пагинацией)],
  [`POST /`], [`create`], [создать],
  [`GET /{id}`], [`get_one`], [получить одну запись],
  [`PUT /{id}`], [`update`], [изменить],
  [`DELETE /{id}`], [`delete`], [удалить],
)

#note[`list::<E>` — это «подставить конкретную сущность в обобщённый обработчик». Например, `crud_routes::<subscriber::Entity>()` создаёт пять маршрутов именно для абонентов. Компилятор Rust генерирует отдельную версию кода под каждую сущность — это называется #term[мономорфизация].]

= READ — чтение

== Список с пагинацией (`GET /api/{resource}`)

```rust
async fn list<E>(user: CurrentUser, State(st): State<AppState>, Query(p): Query<Pagination>)
    -> AppResult<Json<Page<E::Model>>> { ...
    user.require(&format!("{}:read", E::NAME))?;          // право <name>:read
    let page = p.page.max(1);
    let page_size = p.page_size.clamp(1, 200);            // не больше 200 на страницу

    let mut select = E::find();                          // SELECT * FROM таблица
    for pk in E::PrimaryKey::iter() {
        select = select.order_by_asc(pk.into_column());  // ORDER BY первичный ключ
    }
    let paginator = select.paginate(&st.db, page_size);
    let total = paginator.num_items().await?;            // всего записей
    let total_pages = paginator.num_pages().await?;
    let items = paginator.fetch_page(page - 1).await?;   // нужная страница (0-based)
    Ok(Json(Page { items, total, page, page_size, total_pages }))
}
```

Что важно понять:
- #term[Извлечение параметров]. `user: CurrentUser` — Axum сам достаёт пользователя из сессии (если не залогинен — `401`). `Query(p)` — параметры из строки запроса (`page`, `page_size`). Если их нет — берутся значения по умолчанию (1 и 20).
- #term[Пагинация]. `paginate(db, page_size)` + `fetch_page(n)` SeaORM превращает в `LIMIT page_size OFFSET n*page_size`. Отдельно `num_items()` делает `SELECT COUNT(*)`, чтобы фронт знал, сколько всего страниц.

Сгенерированный SQL для абонентов, страница 1 по 20:

```sql
SELECT COUNT(*) FROM "subscriber";                       -- num_items()
SELECT "subscriber"."id", "subscriber"."last_name", ...  -- fetch_page(0)
FROM "subscriber" ORDER BY "subscriber"."id" ASC
LIMIT 20 OFFSET 0;
```

== Одна запись (`GET /api/{resource}/{id}`)

```rust
async fn get_one<E>(user, State(st), Path(id): Path<i64>) -> AppResult<Json<E::Model>> {
    user.require(&format!("{}:read", E::NAME))?;
    let model = E::find_by_id(id).one(&st.db).await?.ok_or(AppError::NotFound)?;
    Ok(Json(model))
}
```

`Path(id)` — это часть URL (`/api/subscribers/7` → `id = 7`). `find_by_id(id).one(db)` → `SELECT ... WHERE id = 7 LIMIT 1`. Если ничего не нашли (`None`) — `ok_or(AppError::NotFound)` превращает это в ответ `404`.

= CREATE — создание (`POST /api/{resource}`)

```rust
async fn create<E>(user, State(st), Json(payload): Json<Value>) -> AppResult<Json<E::Model>> {
    user.require(&format!("{}:create", E::NAME))?;
    let mut am = E::ActiveModel::default();        // «пустая» редактируемая строка
    am.set_from_json(payload.clone())?;            // заполнить поля из присланного JSON
    if !E::PrimaryKey::auto_increment() {          // для не-автоинкрементных ключей
        for pk in E::PrimaryKey::iter() {          // (подтипы АТС: pbx_id) проставить ключ вручную
            let col = pk.into_column();
            if let Some(v) = payload.get(col.as_str()).and_then(|x| x.as_i64()) {
                am.set(col, v.into());
            }
        }
    }
    let model = am.insert(&st.db).await?;          // INSERT ... RETURNING *
    Ok(Json(model))
}
```

Ключевое понятие — #term[ActiveModel] («активная модель»). Это «редактируемая» версия строки: у #term[каждого] поля есть состояние #term[Set] (значение задано) или #term[NotSet] (не трогаем — в БД сработает значение по умолчанию). Работает так:
- `ActiveModel::default()` — все поля `NotSet`.
- `set_from_json(payload)` — берёт присланный JSON и помечает `Set` только те поля, что в нём есть. Поэтому клиент может прислать #term[частичные] данные, а `id`, `created_at`, статусы и т.п. подставит сама БД (defaults).
- `insert(db)` — формирует `INSERT INTO ... (только Set-поля) VALUES (...) RETURNING *` и возвращает уже сохранённую строку (с присвоенным `id`).

#note[Блок с `auto_increment()` нужен только для подтипов АТС (`pbx_city/department/institution`), где первичный ключ `pbx_id` задаёт клиент (это id существующей АТС), а не база. У обычных таблиц ключ `id` генерируется автоматически, и этот блок пропускается.]

Пример: `POST /api/cities` с телом `{"name":"Казань"}` →
```sql
INSERT INTO "city" ("name") VALUES ('Казань') RETURNING "id", "name", "is_home", "created_at";
```
`is_home` и `created_at` клиент не присылал — у них сработали значения по умолчанию из схемы.

= UPDATE — изменение (`PUT /api/{resource}/{id}`)

```rust
async fn update<E>(user, State(st), Path(id): Path<i64>, Json(payload): Json<Value>) -> ... {
    user.require(&format!("{}:update", E::NAME))?;
    let existing = E::find_by_id(id).one(&st.db).await?.ok_or(AppError::NotFound)?; // 1) найти
    let mut am = existing.into_active_model();   // 2) превратить в редактируемую
    am.set_from_json(payload)?;                  // 3) применить присланные поля
    let model = am.update(&st.db).await?;        // 4) UPDATE ... WHERE id = ?
    Ok(Json(model))
}
```

Логика: сначала #term[находим] запись (нет → `404`), превращаем её в `ActiveModel`, накладываем присланные поля (`set_from_json` помечает `Set` только их — остальные остаются как были), и `update(db)` делает `UPDATE таблица SET изменённые_поля WHERE id = ? RETURNING *`. То есть можно прислать только то, что меняем.

= DELETE — удаление (`DELETE /api/{resource}/{id}`)

```rust
async fn delete<E>(user, State(st), Path(id): Path<i64>) -> AppResult<Json<Value>> {
    user.require(&format!("{}:delete", E::NAME))?;
    let res = E::delete_by_id(id).exec(&st.db).await?;   // DELETE FROM таблица WHERE id = ?
    if res.rows_affected == 0 {                          // ничего не удалили → не было такой записи
        return Err(AppError::NotFound);
    }
    Ok(Json(serde_json::json!({ "deleted": id })))
}
```

`delete_by_id(id)` → `DELETE FROM таблица WHERE id = ?`. `rows_affected` — сколько строк удалено; если `0`, значит записи не было → `404`.

#note[Если на запись кто-то ссылается (внешний ключ с `ON DELETE RESTRICT`, например на абонента ссылается счёт), PostgreSQL не даст удалить и вернёт ошибку — мы превращаем её в понятный ответ `409 Conflict` (см. раздел про ошибки).]

= Как сущности подключаются к CRUD

Чтобы обобщённый код узнал «имя» сущности (для прав), есть крошечный «интерфейс» `Resource` и макрос, который реализует его для каждой entity:

```rust
pub trait Resource: EntityTrait { const NAME: &'static str; }

macro_rules! resource {
    ($module:ident, $name:expr) => {
        impl Resource for entity::$module::Entity { const NAME: &'static str = $name; }
    };
}
resource!(subscriber, "subscriber");
resource!(pbx, "pbx");
resource!(city, "city");
// ...все 16
```

А дальше — список «путь → обобщённый CRUD для сущности»:

```rust
pub fn api_router() -> Router<AppState> {
    Router::new()
        .nest("/subscribers", crud_routes::<entity::subscriber::Entity>())
        .nest("/pbx",         crud_routes::<entity::pbx::Entity>())
        .nest("/cities",      crud_routes::<entity::city::Entity>())
        // ...и так все ресурсы
}
```

`NAME` («subscriber», «pbx», ...) используется для прав: `subscriber:read`, `pbx:create` и т.д.

= Права (RBAC)

В каждом обработчике первая строка — проверка права вида `сущность:действие`:

```rust
user.require(&format!("{}:read",   E::NAME))?;   // в list / get_one
user.require(&format!("{}:create", E::NAME))?;   // в create
user.require(&format!("{}:update", E::NAME))?;   // в update
user.require(&format!("{}:delete", E::NAME))?;   // в delete
```

`CurrentUser` подгружается из сессии вместе со списком прав (через роли). `require` пропускает дальше, если право есть (или пользователь — суперадмин), иначе возвращает `403 Forbidden`. Роли и права настраиваются суперадмином в админке (таблицы `role`, `permission`).

= Ошибки базы данных → понятные HTTP-ответы

Самое ценное: ограничения целостности (триггеры, `CHECK`, `UNIQUE`, внешние ключи) живут в БД. Если запрос их нарушает, PostgreSQL бросает ошибку, а файл `error.rs` превращает её в #term[осмысленный] HTTP-ответ, а не «500».

#table(
  columns: (auto, auto, 1fr),
  inset: 6pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Нарушение*], [*HTTP*], [*Пример*]),
  [Триггер (`RAISE EXCEPTION`)], [400], [Создать 2-го абонента на основном номере → «Number 1 (line type main) allows at most 1 subscriber»],
  [`CHECK`-ограничение], [400], [Простой абонент с указанной льготой → нарушение `chk_privilege`],
  [`UNIQUE`], [409], [Номер телефона уже существует],
  [Внешний ключ], [409], [Удаление записи, на которую ссылаются],
  [Запись не найдена], [404], [`GET/PUT/DELETE /{id}` несуществующего id],
)

Поэтому форма на фронте показывает абоненту/оператору понятную причину отказа, а данные в БД остаются корректными при любом раскладе.

= Фронтенд: один компонент на все таблицы

CRUD на клиенте тоже #term[обобщённый]. Есть один компонент `CrudView.vue`, который по «описанию» сущности рисует таблицу, пагинацию и форму создания/редактирования. Описания — в `config/resources.ts`:

```ts
{ key: 'subscribers', path: 'subscribers', title: 'Абоненты', perm: 'subscriber',
  columns: [ { prop: 'last_name', label: 'Фамилия' }, ... ],
  fields:  [ { prop: 'last_name', label: 'Фамилия', type: 'text', required: true },
             { prop: 'category', label: 'Категория', type: 'select', options: categoryOptions }, ... ] }
```

`CrudView` берёт текущий ресурс из URL, дёргает те же эндпоинты (`GET/POST/PUT/DELETE /api/<path>`), показывает кнопки «Добавить/Изменить/Удалить» только если у пользователя есть соответствующее право. Поле `idField` позволяет работать с подтипами АТС, у которых ключ называется `pbx_id`, а не `id`.

#where[
- Таблица + форма: `frontend/src/views/CrudView.vue`
- Описания всех ресурсов: `frontend/src/config/resources.ts`
- Вызовы API: `frontend/src/api/crud.ts`
]

= Рецепт: добавить новую сущность в CRUD

+ Создать таблицу в новой SQL-миграции (`backend/migrations/`).
+ Сгенерировать entity: `sea-orm-cli generate entity ...` → появится `entity/src/новая.rs`.
+ В `resources.rs`: дописать `resource!(новая, "новая")` и `.nest("/новая", crud_routes::<entity::новая::Entity>())`.
+ Добавить права `новая:read/create/update/delete` (миграция со вставкой в `permission` + выдача ролям).
+ На фронте: добавить описание в `config/resources.ts` — таблица, форма и меню появятся сами.

Готово — полноценный CRUD на бэке и на фронте без копирования логики.

= Шпаргалка к защите (по CRUD)

#table(
  columns: (1fr, 1.3fr),
  inset: 7pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Вопрос*], [*Короткий ответ + где код*]),
  [Как реализован CRUD по всем сущностям?], [Один обобщённый `crud_routes::<E>()` на 16 ресурсов. `crud.rs` + `resources.rs`.],
  [Где переиспользование кода?], [5 generic-обработчиков работают с любой сущностью; подключение — списком в `resources.rs`.],
  [Что такое ActiveModel?], [Редактируемая строка: у каждого поля `Set`/`NotSet`; `set_from_json` помечает только присланные поля → частичный ввод и работа default-ов БД.],
  [Как сделана пагинация?], [`paginate().fetch_page()` → `LIMIT/OFFSET`, плюс `num_items()` → `COUNT(*)`. Параметры `page`, `page_size` из строки запроса.],
  [Как защищён доступ?], [Каждый обработчик: `user.require("сущность:действие")` → иначе `403`. Права из БД, настраивает суперадмин.],
  [Что будет при нарушении правил БД?], [Триггер/`CHECK` → `400`, `UNIQUE`/FK → `409`, нет записи → `404`. Маппинг в `error.rs`.],
  [Где здесь ORM (SeaORM)?], [Именно в CRUD: `find`, `find_by_id`, `paginate`, `insert`, `update`, `delete_by_id`. Аналитика — на sqlx.],
)

#v(0.4cm)
#align(center)[#text(fill: gray, size: 9pt)[См. также общий разбор — `docs/guide.pdf`, схему БД — `docs/schema.dbml`, описание API — `docs/api.md`.]]
