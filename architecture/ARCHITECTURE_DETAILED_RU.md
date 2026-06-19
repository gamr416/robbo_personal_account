## Общий обзор

Проект состоит из двух основных приложений — **frontend** (`robbo_personal_account_frontend`) и **backend** (`robbo_personal_account_backend`), а также **PostgreSQL** как основной СУБД. Сервисы локально и в docker-compose взаимодействуют по HTTP. Авторизация реализована по **JWT**, клиент общается с сервером через **GraphQL**-API.

**Полный перечень маршрутов, API и расхождений с cutover:** [FUNCTIONALITY_RU.md](FUNCTIONALITY_RU.md).

Существует **монорепо-обёртка** [`gamr416/robbo_personal_account`](https://github.com/gamr416/robbo_personal_account): в ней `frontend/` и `backend/` — git-субмодули на указанные коммиты; на GitHub в корне видны именно эти SHA. Актуальная ветка `main` кода — по прямым ссылкам на репозитории субмодулей (см. `README` монорепо и `change_log.md`).

**Где вносить изменения:** весь код ЛК правится только в **`robbo_personal_account_frontend/`** и **`robbo_personal_account_backend/`**. Каталог **`robbo_personal_account/`** — репозиторий с субмодулями для полного локального стека (`setup.sh`); **исходный код в нём не менять** — правки в `frontend/` и `backend/` внутри монорепо не синхронизируются с рабочими копиями автоматически.

- **Frontend**: одностраничное приложение на React с использованием `react-router-dom`, `redux`/`redux-saga`, Ant Design, `styled-components`. Собирается через Webpack, отдается Node/Express-сервером на порту `3030`.
- **Backend**: Go-приложение на базе Gin, GraphQL реализован через `gqlgen`. Работает на порту `8080`, использует `GORM` для доступа к PostgreSQL.
- **Database**: PostgreSQL 13, порт `5432`, база данных `robbo_db`.

## Frontend: robbo_personal_account_frontend

### Технологический стек

- **React SPA**: UI построен как одностраничное приложение, маршрутизация внутри происходит через `react-router-dom`.
- **Состояние и сайд-эффекты**:
  - `redux` — глобальное состояние (пользователь, токены, проекты, загрузки).
  - `redux-saga` — асинхронные цепочки (REST projectPage, login, админские списки).
  - **Apollo Client** — GraphQL (профиль, юниты, группы, курсы, мутации ролей).
- **UI-библиотека**: Ant Design (компоненты форм, таблиц, модальных окон и т.п.).
- **Стили**: `styled-components` для модульного и переиспользуемого оформления компонентов.
- **Сборка**: Webpack-конфигурация (`webpack.common.js` и окружения) формирует bundle, поддерживает алиасы путей, загрузчики для JS/JSX, стилей и ассетов.
- **Сервер разработки**: Node/Express-сервер на `:3030` (команда `yarn start`), который:
  - отдаёт собранный frontend-бандл (dev: webpack-dev-server `:3030`; prod: Express `server.js`).

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
  - **i18n:** переключатель языка в шапке — `ru`, `en`, `zh` (`react-intl`, Redux `changeLanguage`).
  - **Глобальная кнопка «Помощь»** на всех маршрутах → `https://support.robbo.world/` (новая вкладка).
  - **Login:** `GET /auth/oidc/status`; «Войти через LMS» → `/auth/oidc/start`; email/пароль при `lmsPasswordFallback`.
  - **Публичные проекты:** `/projects/public`, `HeaderExploreNav`; embed — `ScratchPlayerEmbed` + play-token.
  - **Профиль:** одно поле «Полное имя» (`fullName` ↔ `auth_userprofile.name`); доп. поля LMS (страна, год рождения, пол, язык, уровень образования) — см. `lmsProfileOptions`.
  - **Курсы в ЛК:** маршрут `/courses/:coursePageId` — карточка курса, ссылка на `edx-test.ru`, модал **CourseAccess** (выдача доступа student/teacher/unit/group); списка «Мои курсы» в ЛК нет — `/mycourses` редиректит в LMS.
  - **Админ-разделы:** `/clients` (родители, super admin), `/teachers`, `/unitAdmins`, `/robboUnits`, `/robboGroups` — данные через GraphQL (требуют legacy Postgres, см. [FUNCTIONALITY_RU.md](FUNCTIONALITY_RU.md)).
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

- **Тип транспорта**: GraphQL (`POST /query`) + REST (`/auth`, `/projectPage`, `/course`).
- **GraphQL**: Apollo Client (`src/index.js`, `graphQL/`).
- **REST / проекты**: redux-saga + `api/` (axios).
- **Авторизация на клиенте**:
  - JWT в `localStorage` + заголовок `Authorization: Bearer` (Apollo link, axios).
  - OIDC BFF: cookie-сессия backend; вкладка LMS — PKCE + `localStorage` identity link.
  - Refresh: `GET /auth/refresh` (cookie `refresh_token`).

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
    - GraphQL Playground `GET /`, executor `POST /query`,
    - REST `/auth/*`, `/auth/oidc/*` (BFF SSO), `/internal/lms/notifications`, `/project*`, `/course/*`,
    - middleware: CORS, `TokenAuthMiddleware` (режимы `legacy_jwt` | `oidc_bff` | `lms_db`),
    - часть REST (`/users`, `/robboUnits`, …) **закомментирована** — сценарии перенесены в GraphQL.
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
  - Legacy: backend на `:5432` при `legacyPostgres.enabled=true` (`postgres.postgresDsn`).
  - Projects DB — отдельный compose `robbo_projects_db/` на `:5433`.
  - LMS MySQL — `docker-compose.lms_mysql.yml` на `:3307`.

## Docker Compose и локальная разработка

### Локальный стек (`robbo_personal_account/setup.sh`)

| Шаг | Compose-файл | Порт | Сервис |
|-----|--------------|------|--------|
| Projects DB | `robbo_projects_db/docker-compose.yml` | 5433 | `postgres` |
| LMS MySQL | `backend/docker-compose.lms_mysql.yml` | 3307 | `lms_mysql` |
| Mock OIDC | `backend/docker-compose.oidc.dev.yml` | 8081 | `mock-oauth2` |
| Backend | `backend/docker-compose.yml` (`name: rpa2`) | 8080 | `app` |
| Frontend | `frontend/docker-compose.yml` | 3030, 5001 | `web`, `scratch-gui` |

**Важно:** `robbo_personal_account_backend/docker-compose.yml` содержит **только** сервис `app` — без Postgres. Legacy `robbo_db` подключается отдельно при `legacyPostgres.enabled=true`.

### Сервисы по отдельности

- **Frontend `web`**: `name: robbo_personal_account_frontend`, порт `3030`, `network_mode: host`, зависит от `scratch-gui` (:5001).
- **Backend `app`**: `name: rpa2`, образ `rpa2-app`, порт `8080`. После `build` — `up -d --build app`.
- **Projects Postgres**: `robbo_projects_db/`, порт `5433`, volume + `init/*.sql`.

### Поток запросов в runtime

1. Пользователь в браузере открывает URL фронтенда (`http://localhost:3030`).
2. Node/Express-сервер фронтенда отдает React-бандл.
3. React-приложение загружается, инициализирует Redux-store и саги.
4. При необходимости загрузить данные (например, список Robbo Units) компонент диспатчит действие `FETCH_ROBBO_UNITS_REQUEST`.
5. Сага или Apollo перехватывает действие, формирует REST или GraphQL запрос на backend (`http://localhost:8080/query` или `/projectPage/...`).
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
- **Схема:** `init/01_schema.sql` — **3 таблицы:** `scratch_projects`, `scratch_project_versions`, `scratch_project_audit_events`; `init/02_upgrade_pre_meta_projects.sql` — идемпотентно для существующих томов (в т.ч. `DROP scratch_project_legacy_map`).
- **Очистка старого тома:** `scripts/cleanup_projects_db.sql` (portal, `*_dbs`, legacy map).
- **Backend ЛК:** `PROJECTS_POSTGRES_DSN` — только Scratch; профиль/вход — `LMS_MYSQL_DSN` / `LMS_MYSQL_WRITE_DSN` → `auth_user`.

## Обновление по хранению Scratch-проектов

- В упрощенной целевой схеме `Projects Storage Service` становится частью `scratchEditor` (отдельный сервис не выделяется).
- Карточка «Мои проекты», JSON для REST `/project/`, версии `.sb3` хранятся в **PROJECT DB** (`scratch_projects`, `scratch_project_versions`, см. **`robbo_projects_db/`**).
- Связь наставник–ученик и курсы в UI — вне Projects DB (LMS API / отдельный этап); пользователи и профиль — **LMS MySQL**.
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
- Пункт `LMS` открывает новую вкладку и ведет на `https://online.robbo.ru`.
- На странице `Home` быстрые действия также используют карточку `LMS` вместо `Мои курсы`.
- Маршрут `/mycourses` не показывает старый раздел «Мои курсы»: сразу выполняется редирект в LMS в текущей вкладке (`src/pages/LmsRedirect`, `navigateToLmsSameTab` из `src/helpers/lmsSso.js`).
- В frontend добавлен задел под OIDC Authorization Code + PKCE:
  - `src/constants/oauth.js` — контракт параметров `authorize` (`client_id`, `redirect_uri`, `scope`);
  - `src/helpers/lmsSso.js` — генерация `state`, `nonce`, `code_verifier`, `code_challenge` и сборка authorize URL.
- До заполнения OIDC-параметров (`LMS_OAUTH_AUTHORIZE_URL`, `LMS_OAUTH_CLIENT_ID`, `LMS_OAUTH_REDIRECT_URI`) используется безопасный fallback: прямое открытие LMS URL в новой вкладке.
- На странице регистрации при ответе backend о дублирующемся email (`email is already used`/`user already exist`) показывается UI-уведомление: «Пользователь с таким email уже зарегистрирован» (`src/sagas/login.js`).
- **Мои проекты (ученик):** список и карточка в **PROJECT DB** (`scratch_projects`); UUID. Публичный каталог — `/projects/public`, REST `GET /projectPage/public`. Embed-плеер — play-token + `ScratchPlayerEmbed` (:5001).

### Inbox уведомлений (апрель 2026, статус май 2026)

- **Контракт LMS → ЛК:** [ADR_LK_LMS_notifications_ingest.md](ADR_LK_LMS_notifications_ingest.md).
- **Backend (факт):**
  - Реализован только **`POST /internal/lms/notifications`** (`package/portal/http/notifications.go`) → таблица **`robbo_portal_notifications`** в **legacy Postgres** через `package/portal/gateway`.
  - Работает при **`legacyPostgres.enabled=true`** и **`lmsNotifications.enabled=true`**; при cutover (`legacyPostgres.enabled=false`) portal gateway = **noop**, ingest возвращает ошибку хранения.
  - Публичный REST **`/api/notifications/*`** (лента, mark-read, admin send) на backend **не смонтирован**; черновик схемы — `notifications_graphql_sketch.graphqls`.
- **Frontend (факт):**
  - UI готов: колокольчик в `PageLayout`, страница `/send-notification`, клиент `src/api/notifications.js` ожидает `/api/notifications/*` — до реализации backend запросы завершатся ошибкой.
  - Колокольчик и язык — одна flex-группа справа; на `/home` у unit admin и super admin — кнопка «Отправить уведомление» над меню.
- **Целевое состояние после cutover:** либо вернуть `robbo_portal_notifications` в отдельное хранилище, либо реализовать `/api/notifications` без legacy Postgres — см. [FUNCTIONALITY_RU.md](FUNCTIONALITY_RU.md).

### OIDC BFF и режимы auth (май 2026)

- **`/auth/oidc/start`** — Authorization Code + PKCE (`prompt=none` по умолчанию; `?prompt=login` для формы IdP).
- **`/auth/oidc/callback`**, **`/auth/oidc/logout`**, **`/auth/oidc/status`** — сессия BFF (cookie), поля `authenticated`, `edx_user_id`, `role`.
- **`auth.mode`:** `legacy_jwt` | `oidc_bff` | `lms_db`; в compose по умолчанию `oidc_bff` + `lmsPasswordFallback`.
- **LMS password login:** `signInLMS` — роль из `auth_user.is_superuser` / `is_staff` (иначе Student); JWT `Id` = `edx_user_id`.
- **Регистрация без legacy:** `signUpLMS` → INSERT в `auth_user` + `auth_userprofile`.

