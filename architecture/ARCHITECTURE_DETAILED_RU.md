## Общий обзор

Проект состоит из двух основных приложений — **frontend** (`robbo_personal_account_frontend`) и **backend** (`robbo_personal_account_backend`), а также **PostgreSQL** как основной СУБД. Сервисы локально и в docker-compose взаимодействуют по HTTP. Авторизация реализована по **JWT**, клиент общается с сервером через **GraphQL**-API.

Существует **монорепо-обёртка** [`gamr416/robbo_personal_account`](https://github.com/gamr416/robbo_personal_account): в ней `frontend/` и `backend/` — git-субмодули на указанные коммиты; на GitHub в корне видны именно эти SHA. Актуальная ветка `main` кода — по прямым ссылкам на репозитории субмодулей (см. `README` монорепо и `change_log.md`).

- **Frontend**: одностраничное приложение на React с использованием `react-router-dom`, `redux`/`redux-saga`, Ant Design, `styled-components`. Собирается через Webpack, отдается Node/Express-сервером на порту `3030`.
- **Backend**: Go-приложение на базе Gin, GraphQL реализован через `gqlgen`. Работает на порту `8080`, использует `GORM` для доступа к PostgreSQL.
- **Database**: PostgreSQL 13, порт `5432`, база данных `robbo_db`.

## Frontend: robbo_personal_account_frontend

### Технологический стек

- **React SPA**: UI построен как одностраничное приложение, маршрутизация внутри происходит через `react-router-dom`.
- **Состояние и сайд-эффекты**:
  - `redux` отвечает за глобальное состояние приложения (пользователь, токены, список юнитов, статусы загрузки и т.п.).
  - `redux-saga` управляет асинхронными операциями (запросы к GraphQL API, обновление токенов, последовательные цепочки эффектов).
- **UI-библиотека**: Ant Design (компоненты форм, таблиц, модальных окон и т.п.).
- **Стили**: `styled-components` для модульного и переиспользуемого оформления компонентов.
- **Сборка**: Webpack-конфигурация (`webpack.common.js` и окружения) формирует bundle, поддерживает алиасы путей, загрузчики для JS/JSX, стилей и ассетов.
- **Сервер разработки**: Node/Express-сервер на `:3030` (команда `yarn start`), который:
  - отдает собранный frontend-бандл,
  - проксирует API-запросы на backend (порт `8080`, путь `/graphql` либо аналогичный).

### Структура страниц и модулей

- **Маршрутизация**:
  - Используется `react-router-dom` для определения маршрутов (например, `/login`, `/robbo-units`, `/profile` и т.д.).
  - Каждая страница имеет контейнерный компонент (`*Container.jsx`) и презентационный компонент (`*.jsx`).
  - Для public-части в `robbo_personal_account_frontend` добавлены отдельные маршруты: `"/"` (landing) и `"/register"` (страница регистрации); маршрут `"/"` вынесен в роут-константу `LANDING_PAGE_ROUTE` для единообразной навигации.
  - Успешный вход (`SignInForm`) сохраняет `accessToken` в `localStorage` и выполняет переход на защищенный маршрут `"/home"` (а не на `"/"`), чтобы исключить возврат на публичный landing после авторизации.
  - На auth-страницах реализован явный путь возврата в публичную зону: кнопка «Назад на лэндинг» на `Login` и `Register`.
  - `Home` (`src/pages/Home/index.jsx`) выступает как авторизованная стартовая панель: показывает приветствие на основе JWT-пейлоада, роль пользователя и role-based быстрые действия (переходы в профиль, курсы, проекты и административные разделы в зависимости от прав).
  - Переходы из карточек `Home` передают `location.state.selectedNavBarKey`, чтобы `SideBar` (`Ant Menu`) корректно подсвечивал текущий раздел после навигации через быстрые действия.
  - В `SideBar` для всех ролей добавлен пункт меню «Главная» с переходом на `"/home"`; при открытии `"/home"` напрямую `PageLayout` выставляет активный ключ `home`, чтобы подсветка меню совпадала с текущей страницей.
  - Состояние сворачивания бокового меню (`collapsed`) в `PageLayout` сохраняется в `localStorage` (`lk_sidebar_collapsed`), поэтому после переходов между разделами меню не разворачивается автоматически.
  - `Landing` использует статические медиа из `materials/` (в рантайме доступны как `/materials/*`) и проигрывает видео в цикле как “гифки”; для блока 1.2 реализован эффект “кадр в кадре”.
  - Страница `Register` отправляет данные формы в `signUpRequest({ user, role })`; saga вызывает `auth/sign-up`, после успешного ответа редиректит пользователя на защищенную зону (`/home`).
  - Страница `ProjectPage` (`/projects/:projectPageId`) при сохранении диспатчит `updateProjectPage(token, payload)`; после успешного обновления фронт делает refetch `GetProjectPageById`, чтобы UI сразу отобразил сохраненные данные.
  - На backend доступ к `ProjectPage` защищен проверкой владельца: для чтения/обновления `ProjectPage` проверяется, что связанный `Project` принадлежит текущему `user_id` (owner-check). При отсутствии доступа возвращается ошибка `403` (GraphQL) / `403` (REST).
- **Пример страницы Robbo Units**:
  - `RobboUnitsContainer.jsx`: подключен к Redux, диспатчит действия для загрузки списка юнитов и пробрасывает данные/колбэки в презентационный компонент.
  - `RobboUnits.jsx`: отвечает за отображение таблицы или списка юнитов, использует компоненты AntD (например, `Table`, `Button`, `Form`) и стили через `styled-components`.
- **Actions/Reducers**:
  - В файле `src/actions/app.js` и других action-файлах определяются action creators для:
    - загрузки данных с backend,
    - изменения фильтров/пагинации,
    - управления состоянием приложения (загрузка, ошибка, успешный ответ).
  - Reducers хранят нормализованные данные (по id), флаги загрузки и текущие настройки пользователя.

### Взаимодействие с backend

- **Тип транспорта**: GraphQL over HTTP.
- **Точка входа**: как правило, `/graphql` на backend-сервере `:8080`.
- **Слой API**:
  - Выделенный модуль(и) для выполнения GraphQL-запросов/мутаций (через `fetch`/`axios` или специализированный GraphQL-клиент).
  - Все сетевые вызовы оборачиваются в саги:
    - саги слушают действия вида `FETCH_*_REQUEST`,
    - выполняют запрос, затем диспатчат `SUCCESS` или `FAILURE`,
    - при необходимости триггерят показ уведомлений/модальных окон.
- **Авторизация на клиенте**:
  - JWT-токен хранится в `localStorage`/`sessionStorage` или Redux (в зависимости от реализации).
  - При наличии токена он добавляется в заголовок `Authorization: Bearer <token>` для всех GraphQL-запросов.
  - При истечении срока действия токена либо вызывается endpoint обновления токена, либо пользователь перенаправляется на страницу логина.

## Backend: robbo_personal_account_backend

### Технологический стек

- **Язык**: Go.
- **Web-фреймворк**: Gin (HTTP-сервер).
- **GraphQL**: `gqlgen` (генерация схемы и резолверов).
- **ORM**: `GORM` для взаимодействия с PostgreSQL.
- **Конфигурация**:
  - Файлы в `package/config` (`config.yml`, `init.go`) описывают схему конфигурации, значения по умолчанию и логику загрузки.
  - Конфиг содержит параметры подключения к БД, порты, секреты JWT, флаги окружения и настройки логирования.
- **Авторизация**: JWT (подпись и валидация токена, хранение user id / ролей).

### Загрузка конфигурации

- **`config.yml`**:
  - Описывает базовые настройки приложения: порт HTTP-сервера (`8080`), параметры подключения к PostgreSQL (host, port, dbname, user, password), а также настройки внешних интеграций (например, EDX, SMTP и т.п. если используются).
- **`init.go`**:
  - Читает `config.yml` и значения переменных окружения.
  - Валидирует конфигурацию (обязательные поля).
  - Инициализирует глобальный объект конфигурации, доступный другим пакетам backend’а.

### HTTP/GraphQL слой

- **Gin HTTP сервер**:
  - Поднимает HTTP-сервер на порту `8080`.
  - Регистрирует:
    - endpoint GraphQL (`POST /graphql`, часто также `GET /graphql` для Playground),
    - технические endpoints (например, `/healthz`, `/metrics` при наличии),
    - middleware для логирования, CORS, восстановления после паники.
- **GraphQL через `gqlgen`**:
  - Схема (`schema.graphql` или аналогичный файл) описывает типы, запросы и мутации:
    - сущности (пользователь, RobboUnit и т.п.),
    - корневые операции (`Query`, `Mutation`),
    - возможные входные типы (filters, pagination, input objects).
  - Сгенерированные резолверы реализуются в папке `package/*`:
    - каждый резолвер вызывает соответствующие usecase’ы/сервисы доменного слоя,
    - маппит доменные модели в GraphQL-типы.

### Доменный и usecase-слой

- **Пакет `package/edx/usecase/edx.go` и другие usecase-пакеты**:
  - Описывают бизнес-логику (например, интеграцию с EDX, управление курсами, синхронизацию статусов и т.п.).
  - Не зависят напрямую от HTTP/GraphQL; работают с интерфейсами репозиториев и внешних сервисов.
- **Usecase-подход**:
  - Каждый usecase реализует конкретный сценарий (примерно по паттерну Clean Architecture / Hexagonal Architecture):
    - принимает DTO/команды от резолвера,
    - оркестрирует вызовы репозиториев (работа с БД через GORM) и внешних API,
    - возвращает доменные сущности или ошибки.
  - Это позволяет тестировать бизнес-логику отдельно от транспорта (HTTP/GraphQL).

### Слой доступа к данным (репозитории)

- **GORM**:
  - Используется для описания моделей таблиц (структуры Go с тегами `gorm:"..."`).
  - Репозитории инкапсулируют:
    - создание, чтение, обновление и удаление записей,
    - сложные выборки (фильтрация, сортировка, пагинация),
    - транзакции.
- **Подключение к БД**:
  - Настраивается при старте приложения на основе данных из `config.yml`.
  - Инициализированный `*gorm.DB` передается в репозитории и usecase’ы.

### Авторизация и безопасность

- **JWT**:
  - При логине backend:
    - проверяет учетные данные пользователя,
    - формирует JWT с id пользователя и, возможно, ролями/правами,
    - подписывает токен секретом/ключом из конфигурации,
    - возвращает токен frontend’у.
  - При каждом защищенном запросе:
    - middleware читает заголовок `Authorization`,
    - валидирует токен и кладет информацию о пользователе в контекст запроса (Gin/GraphQL context),
    - резолверы и usecase’ы получают идентификатор пользователя из контекста.
- **Права доступа**:
  - На уровне usecase’ов и/или резолверов реализуются проверки ролей/прав (например, доступ к определенным Robbo Units только для учителей/администраторов).

## Database: PostgreSQL 13

- **СУБД**: PostgreSQL версии 13.
- **Схема**:
  - Таблицы для пользователей, Robbo Units, курсов, привязок пользователей к юнитам/курсам и т.п.
  - Внешние ключи обеспечивают целостность связей между сущностями.
  - Для часто используемых выборок могут быть настроены индексы.
- **Подключение**:
  - Backend подключается к БД на `:5432` с использованием параметров из `config.yml`.
  - В docker-compose БД описана как сервис `postgres`/`PGsvc` с volume для персистентности данных.

## Docker Compose и локальная разработка

### Сервисы в docker-compose

- **Frontend-сервис**:
  - Сервис **`web`** собирает frontend из `robbo_personal_account_frontend`; в compose задано `name: robbo_personal_account_frontend` (стабильное имя проекта).
  - В workspace может существовать вторая копия фронта — `robbo_personal_account/frontend/`; если контейнер на проде поднят из неё, пересборка должна выполняться **в том же каталоге**, иначе изменений не будет.
  - После `docker compose build web` для применения образа нужен **`docker compose up -d --build web`**, иначе запущенный контейнер остаётся на старом image id.
  - Публикует порт `3030:3030`.
  - Может использовать `network_mode: host` для упрощения доступа к backend’у.
- **Backend-сервис**:
  - Сервис **`app`** (Go backend) билдится из `robbo_personal_account_backend`; в compose задано `name: rpa2`, образ **`rpa2-app`** (совместимость со стеком `-p rpa2`).
  - После сборки — **`docker compose up -d --build app`** для пересоздания контейнера.
  - Публикует порт `8080:8080`.
  - Имеет зависимость `depends_on: postgres` с `healthcheck` для БД.
- **Postgres-сервис**:
  - Официальный образ `postgres:13`.
  - Порт `5432:5432`.
  - Volume `postgres_data` для хранения данных.

### Поток запросов в runtime

1. Пользователь в браузере открывает URL фронтенда (`http://localhost:3030`).
2. Node/Express-сервер фронтенда отдает React-бандл.
3. React-приложение загружается, инициализирует Redux-store и саги.
4. При необходимости загрузить данные (например, список Robbo Units) компонент диспатчит действие `FETCH_ROBBO_UNITS_REQUEST`.
5. Сага перехватывает действие, формирует GraphQL запрос и отправляет его на backend по HTTP (`http://localhost:8080/graphql`).
6. Gin-сервер backend’а принимает запрос, `gqlgen` маршрутизирует его к нужному резолверу.
7. Резолвер вызывает соответствующий usecase, который:
   - при необходимости проверяет права пользователя,
   - делает запрос(ы) к PostgreSQL через репозитории и GORM,
   - собирает доменную модель.
8. Результат преобразуется в GraphQL-ответ и возвращается frontend’у.
9. Сага получает ответ, диспатчит `FETCH_ROBBO_UNITS_SUCCESS`, reducer обновляет состояние.
10. Компонент `RobboUnits` получает обновленные пропсы и перерисовывает UI.

## Расширение и эволюция архитектуры

- **Добавление новых сущностей и фич**:
  - На backend:
    - описать новые доменные модели и репозитории,
    - реализовать usecase’ы,
    - расширить GraphQL-схему и резолверы.
  - На frontend:
    - добавить новые GraphQL-запросы/мутации,
    - расширить redux-actions/reducers/sagas,
    - создать новые страницы/компоненты.
- **Интеграции (например, EDX)**:
  - Выделяются в отдельные пакеты (`package/edx/*`),
  - usecase-слой координирует взаимодействие между внутренними моделями и внешним API.
- **Тестирование**:
  - Юнит-тесты для usecase’ов (без HTTP/GraphQL),
  - интеграционные тесты для GraphQL-слоя и работы с БД,
  - e2e-тесты для frontend (по необходимости).

## Robbo Scratch projects DB (`robbo_projects_db/`)

- В workspace каталог **`robbo_projects_db/`** — отдельный PostgreSQL под хранение Scratch-проектов и карточек «Мои проекты» для ЛК (**hard switch**: backend больше не хранит ученический проект в `project_dbs` / `project_page_dbs` для этого контура API).
- **Запуск:** из `robbo_projects_db/` — `docker compose up -d`; `.env.example` при необходимости. Скрипты `init/*.sql` на **новом** томе выполняются при первой инициализации автоматически.
- **Порты:** хост **`5433`** по умолчанию (`ROBBO_PROJECTS_DB_PORT`), чтобы не конфликтовать с ЛК Postgres на **`5432`**.
- **Схема:** `init/01_schema.sql` — `scratch_projects` (метаданные + `scratch_vm_json` для виртуальной машины Scratch в REST `/project/` + поля версий), `scratch_project_versions`, `scratch_project_audit_events`, `scratch_project_legacy_map`; `init/02_upgrade_pre_meta_projects.sql` — безопасно применять к уже существующим томам (расширение колонок, индекс `owner_user_id, updated_at`, приведение `created_by_user_id` версий к `TEXT`):  
  `docker exec <projects_container> psql -U robbo_projects -d robbo_projects -v ON_ERROR_STOP=1 -f /docker-entrypoint-initdb.d/02_upgrade_pre_meta_projects.sql`
- **Backfill из прежней ЛК БД** (`project_dbs` / `project_page_dbs`): `python3 robbo_projects_db/scripts/backfill_lk_projects.py` (по умолчанию контейнеры `rpa2-postgres-1` и `robbo_projects_postgres`).
- **Backend ЛК (`robbo_personal_account_backend`):** в `package/config/config.yml` — `projectsPostgres.postgresDsn`; переопределение через **`PROJECTS_POSTGRES_DSN`**. Основная ЛК БД остаётся для пользователей, курсов, уведомлений и др.

## Обновление по хранению Scratch-проектов

- В упрощенной целевой схеме `Projects Storage Service` становится частью `scratchEditor` (отдельный сервис не выделяется).
- Карточка «Мои проекты», JSON для REST `/project/`, версии `.sb3` хранятся в **PROJECT DB** (`scratch_projects`, `scratch_project_versions`, см. **`robbo_projects_db/`**).
- Связь наставник–ученик и прочая непроектная метадата ЛК остаются в контуре **ЛК Postgres** или **IdentityDB** по дорожной карте доменов — отдельно от STORAGE ученических `.sb3`.
- Открытие проекта остается только через `scratch.ru`:
  - ЛК проверяет доступ и делает редирект `scratch.ru/editor?projectRef={storage_project_id}`,
  - `scratch.ru` загружает/сохраняет проект в PostgreSQL (`BYTEA`) через свой встроенный storage API.
- Такой вариант минимизирует количество сервисов и инфраструктуры, сохраняя единый пользовательский путь открытия проектов.

## OAuth для LMS и scratch.ru

- В качестве центра аутентификации используется единый `Identity/Auth` как OAuth2/OIDC provider.
- Регистрируются отдельные OAuth-клиенты:
  - `lk-web` (SPA ЛК, public client),
  - `lms-web` (SPA LMS, public client),
  - `scratch-web` (SPA редактора, public client).
- API-ресурсы описываются как resource servers:
  - `lms-api` (данные курсов и прогресса),
  - `scratch-api` (чтение/сохранение проектов в PostgreSQL `BYTEA`).
- Для браузерных приложений используется только `Authorization Code + PKCE`.
- После логина в ЛК при переходе в `scratch.ru` применяется SSO-сценарий:
  - либо redirect в authorize endpoint с `prompt=none`,
  - либо выдача audience-специфичного токена через BFF/token exchange.
- Рекомендуемые scopes:
  - `lms.read`, `lms.write`,
  - `scratch.project.read`, `scratch.project.write`,
  - `profile.read`.
- Каждый backend валидирует JWT по `JWKS`, а также проверяет:
  - `aud` (соответствие своему API),
  - `scope` (минимально необходимые права),
  - `sub` (идентификатор пользователя) для owner-check.
- Сроки жизни и безопасность токенов:
  - короткий `access_token` (10-15 минут),
  - refresh token rotation,
  - отзыв refresh token при logout/инциденте.

### Текущая реализация в ЛК (апрель 2026)

- В боковом меню ЛК раздел `Мои курсы` заменен на `LMS` для ролей student/parent/unit admin/super admin/free listener.
- Пункт `LMS` открывает новую вкладку и ведет на `https://lms2.robbo.world`.
- На странице `Home` быстрые действия также используют карточку `LMS` вместо `Мои курсы`.
- Маршрут `/mycourses` не показывает старый раздел «Мои курсы»: сразу выполняется редирект в LMS в текущей вкладке (`src/pages/LmsRedirect`, `navigateToLmsSameTab` из `src/helpers/lmsSso.js`).
- В frontend добавлен задел под OIDC Authorization Code + PKCE:
  - `src/constants/oauth.js` — контракт параметров `authorize` (`client_id`, `redirect_uri`, `scope`);
  - `src/helpers/lmsSso.js` — генерация `state`, `nonce`, `code_verifier`, `code_challenge` и сборка authorize URL.
- До заполнения OIDC-параметров (`LMS_OAUTH_AUTHORIZE_URL`, `LMS_OAUTH_CLIENT_ID`, `LMS_OAUTH_REDIRECT_URI`) используется безопасный fallback: прямое открытие LMS URL в новой вкладке.
- На странице регистрации при ответе backend о дублирующемся email (`email is already used`/`user already exist`) показывается UI-уведомление: «Пользователь с таким email уже зарегистрирован» (`src/sagas/login.js`).
- **Мои проекты (ученик):** список и карточка читаются/пишутся в **PROJECT DB** (`scratch_projects`); те же контракты API (`PUT /projectPage/`, GraphQL `GetProjectPageById`). Идентификатор строки после миграции — UUID (равен `projectId`/`storage_project_id`); для старых закладок с числовым id поддерживается `scratch_project_legacy_map`. Последнее изменение — поле `updated_at` строки проекта.

### Inbox уведомлений (апрель 2026)

- **Источники:** LMS (HTTP ingest) и админы ЛК (HTTP JSON API с JWT). Контракт LMS → ЛК описан в [ADR_LK_LMS_notifications_ingest.md](ADR_LK_LMS_notifications_ingest.md).
- **Backend (`robbo_personal_account/backend`):**
  - Таблицы PostgreSQL: `user_notifications` (персональные, поле `source`: `lms` \| `admin`), `system_announcements` (broadcast одной строкой), `announcement_reads` (прочтение объявлений без fan-out по всем пользователям).
  - `POST /internal/lms/notifications` — приём от LMS, Bearer-токен из конфига `lmsNotifications.ingestBearerToken`, флаг `lmsNotifications.enabled`; маршрут пропускается без JWT middleware.
  - `GET/POST /api/notifications/*` — лента, счётчик непрочитанных, отметка прочитанного, админские `POST .../admin/personal` и `.../admin/announcement` (broadcast только `SuperAdmin`).
  - Логика в пакете `package/notifications`, HTTP-обработчики в `package/notifications/http`.
- **Frontend (`robbo_personal_account_frontend`):**
  - Колокольчик в шапке `PageLayout`: в одной правой flex-группе с переключателем языка (`margin-left: auto` у контейнера), порядок — язык, затем колокольчик у правого края.
  - Пункт меню «Отправить уведомление» и страница `/send-notification` для ролей super admin и unit admin (broadcast — только super admin).
  - На маршруте `/home` для **unit admin** и **super admin** над `Ant Menu` в `SideBar` показывается блок с кнопкой «Отправить уведомление» (`Button` на всю ширину сайдбара): переход на `/send-notification` с `location.state.selectedNavBarKey: 'send_notification'`, чтобы подсветка пункта меню совпадала с переходом из меню.

