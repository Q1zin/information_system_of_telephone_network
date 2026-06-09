// Гайд по фронтенду (ГТС): из чего собран SPA и откуда что появляется
// Компиляция:  typst compile docs/frontend.typ docs/frontend.pdf

#set document(title: "ГТС — фронтенд: что откуда появляется", author: "")
#set page(
  paper: "a4",
  margin: (x: 2cm, y: 1.9cm),
  numbering: "1",
  footer: context [
    #set text(size: 8pt, fill: gray)
    ГТС — фронтенд: что откуда появляется
    #h(1fr)
    #counter(page).display("1")
  ],
)
#set text(font: "PT Sans", size: 10.5pt, lang: "ru")
#set par(justify: true, leading: 0.62em)
#show raw: set text(font: "PT Mono", size: 8.8pt)
#show raw.where(block: true): set par(justify: false)
#show heading: set block(above: 1.1em, below: 0.6em)
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
#let src(body) = block(width: 100%, fill: rgb("#eefcf3"), stroke: 0.5pt + rgb("#86d6a8"), inset: 8pt, radius: 5pt, spacing: 0.9em)[
  #text(weight: "bold", fill: rgb("#0f766e"))[Откуда берётся. ] #body
]
#let term(t) = text(weight: "bold", fill: rgb("#0f766e"))[#t]

#align(center)[
  #v(1.4cm)
  #text(size: 25pt, weight: "bold")[Фронтенд:\ что откуда появляется]
  #v(0.3cm)
  #text(size: 14pt, fill: gray)[Информационная система городской телефонной сети]
  #v(0.5cm)
  #text(size: 11pt)[Как из горстки конфигов и универсальных компонентов рождается весь интерфейс]
  #v(0.8cm)
  #line(length: 40%, stroke: 0.5pt + gray)
]
#v(0.3cm)
#outline(title: [Содержание], indent: auto, depth: 2)
#pagebreak()

= Картина целиком

Фронтенд — это #term[SPA] (single-page application): один HTML-файл и JavaScript, который сам рисует все страницы и общается с бэкендом по HTTP (JSON). Перезагрузки страниц нет — меняется только содержимое.

#table(
  columns: (auto, 1fr),
  inset: 6pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Технология*], [*Зачем*]),
  [#term[Vue 3] + TypeScript], [компоненты интерфейса (`.vue`), типобезопасность],
  [#term[Vite]], [дев-сервер с горячей перезагрузкой и сборка в статику],
  [#term[Vue Router]], [маршруты (какой компонент на каком URL) + охрана доступа],
  [#term[Pinia]], [хранилище состояния (кто вошёл, его права)],
  [#term[Element Plus]], [готовые UI-компоненты: таблицы, формы, диалоги, меню],
  [#term[axios]], [HTTP-клиент к API],
)

Главная идея проекта: операторская часть #term[не написана страница за страницей]. Есть #term[конфиги-описания] (какие сущности, какие поля, какие запросы) и #term[универсальные компоненты], которые по этим описаниям сами рисуют таблицы, формы и меню. Добавить сущность — значит дописать строчку в конфиг, а не верстать новый экран.

== Поток данных (как страница получает данные)

```
Компонент (views/*.vue)
   │  вызывает функцию
   ▼
api/*.ts  ──>  api/client.ts (axios: baseURL '/api', шлёт cookie)
                   │
   dev:  Vite-прокси /api → http://localhost:8080      prod: nginx /api → backend:8080
                   ▼
                Axum (бэкенд)  ──JSON──>  обратно в компонент (ref / Pinia)
```

#where[Корень фронта — `frontend/`. Исходники — `frontend/src/`: `main.ts` (вход), `App.vue`, `router/`, `stores/`, `api/`, `config/`, `layouts/`, `views/`.]

= Точка входа: `main.ts` и `App.vue`

`main.ts` создаёт приложение и #term[подключает плагины] — после этого они доступны во всех компонентах:

```ts
const app = createApp(App)
for (const [name, icon] of Object.entries(ElementPlusIconsVue)) app.component(name, icon) // иконки
app.use(createPinia())     // хранилище
app.use(router)            // маршруты
app.use(ElementPlus)       // UI-кит + стили
app.use(VueQueryPlugin)    // (подключён на будущее; экраны грузят данные напрямую через api)
app.mount('#app')
```

`App.vue` предельно прост — это «рамка», в которую роутер подставляет текущую страницу:

```vue
<template><router-view /></template>
```

#note[В `main.ts` также стоит «глушилка» безобидной ошибки `ResizeObserver loop …`, которую иногда эмитит браузер при перерисовке таблиц Element Plus (см. гайд/историю). Она ничего не ломает.]

= Маршрутизация: `router/index.ts`

Роутер сопоставляет URL и компонент. Страницы грузятся #term[лениво] (`() => import(...)`) — код экрана подтягивается, только когда на него заходят. Маршруты разбиты на #term[три зоны]:

#table(
  columns: (auto, 1fr),
  inset: 6pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Зона*], [*Что внутри*]),
  [Публичная (`meta.public`)], [лендинг `/`, вход сотрудника `/staff/login`, вход абонента `/portal/login`],
  [Операторская (`/app`, `MainLayout`)], [`dashboard`, `crud/:resource`, `applications`, `analytics`, `raw-query`, `settings`, `admin/*`],
  [Кабинет (`/portal`, `PortalLayout`)], [`portal-home`, `apply`, `line/:id`],
)

Перед каждым переходом срабатывает #term[охранник] `router.beforeEach`: публичные пускает; для `/app` требует входа сотрудника и (если у страницы есть `meta.perm`) нужного права; для `/portal` — входа абонента. Подробности — в `docs/auth.pdf`.

#src[Один параметрический маршрут `crud/:resource` обслуживает #term[все] справочники: `:resource` (`cities`, `pbx`, …) — это `key` из конфига ресурсов. Поэтому новый справочник не требует нового маршрута.]

= Состояние: Pinia-сторы

Два независимых хранилища держат «кто вошёл»:

#table(
  columns: (auto, 1fr),
  inset: 6pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Стор*], [*Что хранит и умеет*]),
  [`stores/auth.ts` (сотрудник)], [`user` (+ права); геттер `can(perm)`; `fetchMe` / `login` / `logout`],
  [`stores/customer.ts` (абонент)], [`customer`; геттер `fullName`; `fetchMe` / `login` / `register` / `logout`],
)

`can(perm)` — главный инструмент UI: `is_superadmin || permissions.includes(perm)`. По нему скрываются пункты меню и кнопки. `fetchMe` нужен, чтобы после перезагрузки страницы понять, жива ли сессия (cookie уже в браузере).

= API-слой: `api/`

Все обращения к бэкенду — тонкие функции поверх одного axios-клиента.

```ts
// api/client.ts
const api = axios.create({ baseURL: '/api', withCredentials: true })
// + перехватчик: любую ошибку превращает в человеко-читаемый русский текст (humanMessage)
```

- `baseURL: '/api'` — все пути относительные; куда реально идёт `/api`, решают прокси (см. раздел 9).
- `withCredentials: true` — слать cookie сессии (без этого каждый запрос был бы «не авторизован»).
- Перехватчик ошибок даёт единый русский текст (`401` → «Требуется авторизация», нет связи и т.д.).

Дальше — модули по областям (каждый просто дёргает `api.get/post/...`):

#table(
  columns: (auto, 1fr),
  inset: 6pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Модуль*], [*Эндпоинты*]),
  [`api/crud.ts`], [generic CRUD `/{path}`, аналитика, raw-query, настройки биллинга],
  [`api/ops.ts`], [очередь заявок и подключение (`/ops/...`)],
  [`api/portal.ts`], [личный кабинет (`/portal/...`)],
  [`api/admin.ts`], [пользователи, роли, права (`/admin/...`)],
  [`api/types.ts`], [общие типы (`Row`, `Page<T>`, `CurrentUser`)],
)

= Конфиг-движок — сердце фронта

Здесь и кроется ответ «откуда что появляется». Три файла-описания превращаются в готовый UI универсальными компонентами.

== `config/enums.ts` — справочники значений

Списки вариантов (`Opt = { label, value }`) для выпадающих списков: типы линий, статусы, пол, категории и т.д. #term[Подписи русские], значения совпадают с enum в БД.

```ts
export const lineTypeOptions: Opt[] = [
  { label: 'Основной', value: 'main' }, { label: 'Параллельный', value: 'parallel' }, ...
]
```

== `config/resources.ts` — описания 16 справочников

Каждый ресурс — это `key`, `path` (REST-путь), `title`, `perm` (право), `columns` (что в таблице) и `fields` (что в форме). Поле формы бывает `text`/`number`/`select`/`switch`/`date`/`reference`.

```ts
{ key: 'subscribers', path: 'subscribers', title: 'Абоненты', perm: 'subscriber',
  columns: [ { prop: 'last_name', label: 'Фамилия' }, ... ],
  fields:  [ t('last_name', 'Фамилия', true),
             sel('category', 'Категория', E.categoryOptions),
             ref('phone_number_id', 'Номер', 'phone-numbers', numberLabel, true) ] }
```

- #term[`select`] — выбор из `enums.ts`; #term[`reference`] — выбор из #term[другого справочника] (по `refPath`), с человекочитаемой подписью (`refLabel`). Так в формах не вводят «голый id», а выбирают из списка.

== `config/analytics.ts` — 13 запросов варианта

Каждый запрос — `key`, `title`, `path` и список `params` (фильтры с типами). Из этого строится форма фильтров на странице аналитики.

== Как из конфигов рождается интерфейс

#src[
- #term[Пункты меню «Справочники»] ← `resources` (только те, где есть право `perm:read`).
- #term[Таблица справочника] ← `columns`; #term[форма] ← `fields`; всё рисует один `CrudView.vue`.
- #term[Выпадающие списки в форме] ← `select` (из `enums.ts`) или `reference` (подгружает другой справочник).
- #term[Читаемые подписи в таблице] (id → имя, `active` → «Активен», `true` → «Да») ← `CrudView` сопоставляет колонку с полем.
- #term[Страница «Аналитика»] и её фильтры ← `analyticsQueries`; рисует `AnalyticsView.vue`.
]

#note[Рецепт «добавить справочник на фронте»: дописать один объект в `resources.ts`. Таблица, форма, выпадающие списки и пункт меню появятся #term[сами] — отдельный экран писать не нужно.]

= Универсальные экраны и каталог страниц

`CrudView.vue` (таблица + пагинация + диалог-форма) и `AnalyticsView.vue` (выбор запроса + фильтры + результат) — это «движки», работающие по конфигу. Остальные экраны — точечные.

#table(
  columns: (auto, 1fr),
  inset: 6pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Экран*], [*Что делает / откуда данные*]),
  [`LandingView`], [выбор «кабинет / сотрудник» (публичная)],
  [`LoginView`, `portal/PortalLoginView`], [формы входа; пишут в Pinia-стор],
  [`DashboardView`], [приветствие + профиль из `auth.user`],
  [`CrudView`], [любой справочник по `resources.ts` (16 ресурсов)],
  [`AnalyticsView`], [13 запросов по `analytics.ts`; колонки результата — по ключам ответа],
  [`RawQueryView`], [одно поле SQL → `/api/raw-query` (READ ONLY, 5 c)],
  [`SettingsView`], [настройки биллинга (одна запись)],
  [`ApplicationsView`], [очередь заявок + кнопка «Подключить» (`/ops`)],
  [`admin/UsersView`, `admin/RolesView`], [пользователи и роли/права (`/admin`)],
  [`portal/PortalDashboard`, `PortalApply`, `PortalLine`], [кабинет: линии, заявка, звонки/межгород/оплата (`/portal`)],
)

#note[Таблицы аналитики и SQL-консоли #term[не знают заранее] своих колонок: компонент берёт `Object.keys` первой строки ответа и строит столбцы динамически. Поэтому любой новый запрос отрисуется без правок.]

= Оболочки (layouts) — где появляется «что видно»

#table(
  columns: (auto, 1fr),
  inset: 6pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Layout*], [*Роль*]),
  [`MainLayout` (`/app`)], [боковое меню + шапка оператора; пункты скрыты через `v-if="auth.can(...)"`],
  [`PortalLayout` (`/portal`)], [простая шапка кабинета (имя абонента, «Выйти»)],
)

```vue
// MainLayout: меню справочников строится из конфига и прав
const visibleResources = computed(() => resources.filter((r) => auth.can(`${r.perm}:read`)))
...
<el-menu-item v-if="auth.can('analytics:read')" index="/app/analytics">Аналитика</el-menu-item>
```

#note[`v-if="auth.can(...)"` — это #term[удобство], а не защита: пункт просто не показывают. Настоящая проверка прав — на сервере (см. `docs/auth.pdf`).]

= Сборка и отдача: Vite и nginx

#term[В деве] (`npm run dev`): Vite поднимает SPA на `:5173` и #term[проксирует] `/api` на бэкенд `:8080`. Благодаря прокси фронт и API — #term[один origin], cookie работают без возни с CORS.

```ts
// vite.config.ts
server: { port: 5173, proxy: { '/api': { target: 'http://localhost:8080', changeOrigin: true } } }
resolve: { alias: { '@': './src' } }   // '@/...' = 'src/...'
```

#term[В проде] (Docker): `npm run build` (`vue-tsc` проверяет типы + `vite build`) собирает статику, её отдаёт #term[nginx]. Он же проксирует `/api`, `/swagger-ui`, `/api-docs` на контейнер бэкенда, а на всё остальное отдаёт `index.html`:

```nginx
location /api/         { proxy_pass http://backend:8080; }
location /             { try_files $uri $uri/ /index.html; }   # SPA-роутинг
```

#note[`try_files … /index.html` — ключ для SPA: на любой «глубокий» URL (`/app/crud/pbx`) сервер отдаёт тот же `index.html`, а дальше маршрут разбирает Vue Router в браузере. Иначе при перезагрузке такой страницы был бы `404`.]

= Сводка: что откуда появляется

#table(
  columns: (1fr, 1.3fr),
  inset: 6pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Элемент на экране*], [*Откуда взялся*]),
  [Пункт меню справочника], [строка в `config/resources.ts` (+ право `perm:read`)],
  [Колонки и форма справочника], [`columns` / `fields` того же ресурса → `CrudView.vue`],
  [Выпадающий список в форме], [`select` (из `enums.ts`) или `reference` (другой справочник)],
  [Имена вместо id / «Да-Нет» / enum по-русски], [`cellLabel` в `CrudView` (по описанию поля)],
  [Страница и фильтры аналитики], [`config/analytics.ts` → `AnalyticsView.vue`],
  [Столбцы результата аналитики/SQL], [ключи первой строки JSON-ответа (динамически)],
  [Видимость пунктов меню/кнопок], [`auth.can(perm)` из Pinia (права из БД)],
  [Имя пользователя, бейдж «Суперадмин»], [`auth.user` (ответ `/api/auth/me`)],
  [Куда идёт `/api`], [Vite-прокси (дев) или nginx (прод) → бэкенд :8080],
  [Русский текст ошибки], [перехватчик `humanMessage` в `api/client.ts`],
)

= Шпаргалка к защите (по фронту)

#table(
  columns: (1fr, 1.4fr),
  inset: 7pt, stroke: 0.5pt + rgb("#dddddd"),
  table.header([*Вопрос*], [*Короткий ответ + где код*]),
  [Как устроен фронт?], [Vue 3 SPA; маршруты (`router`), состояние (`pinia`), API (`axios`), UI (Element Plus).],
  [Почему мало кода на 16 справочников?], [Конфиг-движок: `config/resources.ts` + один `CrudView.vue` рисуют таблицу/форму/меню.],
  [Как добавить справочник?], [Дописать объект в `resources.ts` — экран и пункт меню появятся сами.],
  [Откуда выпадающие списки?], [`select` → `enums.ts`; `reference` → другой справочник (выбор вместо ввода id).],
  [Как защищён UI?], [`auth.can(perm)` прячет пункты/кнопки; реально решает сервер.],
  [Как фронт общается с API?], [`api/client.ts` (axios, `/api`, cookie); прокси Vite/nginx ведёт на :8080.],
  [Почему cookie работают без CORS?], [Прокси делает фронт и API одним origin (и в деве, и в проде).],
  [Почему «глубокие» URL не 404?], [nginx `try_files → index.html`; маршрут разбирает Vue Router.],
)

#v(0.4cm)
#align(center)[#text(fill: gray, size: 9pt)[См. также: авторизация — `docs/auth.pdf`, CRUD изнутри — `docs/crud.pdf`, операции — `docs/operations.pdf`.]]
