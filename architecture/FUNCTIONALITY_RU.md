# Инвентарь функционала ЛК (сверка с кодом, июнь 2026)

Документ фиксирует **фактическое** поведение репозиториев в workspace. Целевая архитектура — в [архитектура_3_сервисов.md](архитектура_3_сервисов.md), [ADR_LK_TWO_DATABASES.md](ADR_LK_TWO_DATABASES.md), [LEGACY_POSTGRES_CUTOVER.md](LEGACY_POSTGRES_CUTOVER.md).

## Репозитории

| Каталог | Назначение |
|---------|------------|
| `robbo_personal_account_frontend/` | React SPA (основной фронт для compose `web`) |
| `robbo_personal_account/frontend/` | Дубликат фронта (субмодуль монорепо); пересборка — из того каталога, откуда поднят прод |
| `robbo_personal_account_backend/` | Go backend (compose `rpa2`, сервис `app`) |
| `robbo_personal_account/backend/` | Тот же backend (субмодуль) |
| `robbo_projects_db/` | PostgreSQL Scratch-проектов (`:5433`, DSN `PROJECTS_POSTGRES_DSN`) |
| `robboscratch3_gui/` | Scratch embed player (compose `scratch-gui`, :5001) |
| `robbo-openedx-stack/` | Meta-repo Open edX + Tutor (отдельный контур) |
| `gamr416/robbo_personal_account` | Монорепо-обёртка с субмодулями |

Связка ЛК ↔ Open edX: [LMS_HANDOFF.md](LMS_HANDOFF.md), [ADR_LK_LMS_SSO_OIDC.md](ADR_LK_LMS_SSO_OIDC.md).

---

## Роли

| Код | Роль | Константа backend |
|-----|------|-------------------|
| 0 | Ученик | `Student` |
| 1 | Преподаватель | `Teacher` |
| 2 | Родитель | `Parent` |
| 3 | Свободный слушатель | `FreeListener` |
| 4 | Админ юнита | `UnitAdmin` |
| 5 | Суперадмин | `SuperAdmin` |

**Режим `legacyPostgres.enabled=false` (целевой cutover):** вход по email/паролю через LMS MySQL (`signInLMS`) выставляет роль только из флагов edx: `is_superuser` → SuperAdmin, `is_staff` → Teacher, иначе → Student. Роли Parent, UnitAdmin, FreeListener в этом режиме **не назначаются** при LMS-логине; админские GraphQL-разделы (юниты, группы, клиенты) требуют legacy Postgres (`PostgresClient.Db == nil` → операции с `*_dbs` недоступны).

---

## Frontend: маршруты

| Путь | Страница | Роли (ProtectedRoute) | Примечание |
|------|----------|----------------------|------------|
| `/` | Landing | публичный | маркетинг, `/materials/*`, тёмная/светлая тема |
| `/login` | Login | публичный | OIDC BFF + опционально email/пароль |
| `/register` | Register | публичный | только регистрация ученика → `POST /auth/sign-up` |
| `/auth/oidc/callback` | OidcCallback | публичный | PKCE вкладки LMS: обмен code на IdP, `localStorage` identity link |
| `/home` | Home | все 6 | дашборд, быстрые действия (в т.ч. публичные проекты) |
| `/profile` | Profile | все 6 | свой или peek через `location.state` |
| `/myprojects` | MyProjects | ученик | пункт «Мои проекты» в сайдбаре ученика (`SideBarData.jsx`) |
| `/projects/public` | PublicProjects | все 6 | каталог публичных проектов; также ссылка в `HeaderExploreNav` |
| `/projects/:projectPageId` | ProjectPage | все 6 | просмотр; CRUD — student/unit admin/super admin; embed `ScratchPlayerEmbed` |
| `/mycourses` | LmsRedirect | все 6 | редирект в LMS (вкладка), не список курсов ЛК |
| `/courses/:coursePageId` | CoursePage | все 6 | карточка курса, CourseAccess, ссылка на edx-test |
| `/clients` | Clients | super admin | родители (CRUD) |
| `/teachers` | Teachers | super admin, unit admin | |
| `/unitAdmins` | UnitAdmins | super admin | |
| `/robboUnits` | RobboUnits | super admin, unit admin | |
| `/robboUnits/:robboUnitId/groups` | RobboGroups | super admin, unit admin | группы одного юнита |
| `/robboGroups` | RobboGroups | super admin, unit admin | все группы |
| `/send-notification` | SendNotification | super admin, unit admin | UI есть, backend user API см. ниже |
| `/*` | → `/home` | | |

**Сайдбар:** `SideBarData.jsx` — по ролям «Главная», «Профиль», у ученика «Мои проекты», «LMS» (внешняя вкладка через `openLms`), для админов юниты/группы/учителя/уведомления; у free listener — «Платежи», «Программа», «Информер» **без маршрутов**.

**Шапка (авторизованная зона):** `HeaderExploreNav` — «Создать» (scratch.ru), «Обзор» → `/projects/public`, «LMS».

**Глобально:** кнопка «Помощь» → `https://support.robbo.world/`; i18n `ru` / `en` / `zh`; колокольчик в `PageLayout`.

**Стек UI:** GraphQL через **Apollo Client** (`graphQL/`, HOC/`useMutation`); проекты — **redux-saga + REST** (`sagas/myProjects.js`, `api/projectPage.js`).

---

## Frontend: ключевые сценарии

### Авторизация (два OIDC-потока)
- **BFF вход в ЛК:** `helpers/oidcSession.js` → `GET /auth/oidc/{status,start}` на backend → callback **`http://localhost:8080/auth/oidc/callback`** → cookie-сессия (`package/oidc`, имя cookie в `SessionCookieName`).
- **Вкладка LMS:** `helpers/lmsSso.js` (PKCE) → IdP authorize → фронт `/auth/oidc/callback` → прямой `POST` на `OIDC_TOKEN_ENDPOINT` → `saveLmsIdentityLink` в `localStorage`.
- Legacy JWT: `localStorage.token`, GraphQL `SingIn` / `SingOut` / `Refresh`; email/пароль → `POST /auth/sign-in` (`signInLMS`).
- Регистрация: `POST /auth/sign-up` → LMS INSERT `auth_user` + `auth_userprofile`.
- После входа редирект на `/home`.

### Профиль
- Поля LMS: email, **полное имя** (`fullName` → `auth_userprofile.name`), уровень образования, страна, год рождения, пол, язык.
- В cutover: чтение/запись через `users/gateway/lms_profile.go` → `package/lmsdb`.
- Обновление: GraphQL `UpdateStudent` / `UpdateTeacher` / … (резолверы → delegate → gateway).
- Родитель: список детей → peek профиля ученика (требует legacy для связей).

### Scratch-проекты
- REST `projectPage/*` + GraphQL; хранение в **Projects Postgres** (`scratch_*`).
- Публичный каталог: `GET /projectPage/public`.
- Embed-плеер: `GET /projectPage/:id/play-token`, `GET .../play?token=` (`ScratchPlayerEmbed`, `projectPage/playtoken/`).
- Скачивание/загрузка: `GET .../download`, `POST .../upload` (multipart `.sb3`).
- Создание карточки: роли Student, UnitAdmin, SuperAdmin.

### LMS
- Меню «LMS» / Home: `openLms()` — новая вкладка, OIDC authorize + PKCE `prompt=none` или fallback URL.
- `/mycourses`: тот же SSO в **текущей** вкладке.
- Курсы в ЛК: только страница `/courses/:id` (не каталог); данные через REST `/course/*` и GraphQL access-мутации.

### Уведомления (UI)
- `NotificationBell`, `/send-notification`, REST `/api/notifications/*` на фронте.
- **Backend:** публичного REST `/api/notifications/*` **нет** (см. раздел «Технический долг»).

---

## Backend: HTTP (Gin, порт 8080)

### Активные маршруты

| Группа | Методы | Назначение |
|--------|--------|------------|
| `GET /`, `POST /query` | Playground, GraphQL | основной API организационных сущностей |
| `/auth/*` | sign-up, sign-in, sign-out, refresh, check-auth | JWT + LMS password |
| `/auth/oidc/*` | start, callback, logout, status | BFF SSO |
| `POST /internal/lms/notifications` | ingest LMS | `lmsNotifications.enabled` (по умолчанию **false**) + legacy portal |
| `/project` | POST/GET/POST/DELETE | JSON проекта (legacy REST, student) |
| `/projectPage` | CRUD, `public`, `download`, `upload`, `play-token`, `play` | Projects Postgres |
| `/course/*` | create, get, enrollments, public list, update, delete | edX REST + legacy courses gateway |

Детали `/projectPage` (из `projectPage/http/handler.go`):

| Метод | Путь | Назначение |
|-------|------|------------|
| POST | `/projectPage/` | создать карточку |
| GET | `/projectPage/public` | публичный каталог |
| GET | `/projectPage/:id` | карточка (+ `playToken` в ответе) |
| GET | `/projectPage/:id/play-token` | JWT для embed |
| GET | `/projectPage/:id/play` | inline `.sb3` (Bearer или `?token=`) |
| GET | `/projectPage/:id/download` | attachment `.sb3` |
| POST | `/projectPage/:id/upload` | multipart upload |
| PUT | `/projectPage/` | обновить метаданные |
| DELETE | `/projectPage/:projectId` | удалить |
| GET | `/projectPage/` | список своих (student+) |

### Закомментированы в `SetupGinRouter` (код есть, не смонтированы)

`/cohort/*`, `/users/*` (полный CRUD по ролям), `/robboUnits/*`, `/robboGroup/*`, `/coursePacket/*` — для этих сценариев используется **GraphQL**.

### Auth middleware (`auth.mode`)

| Режим | Поведение |
|-------|-----------|
| `legacy_jwt` | Bearer access JWT |
| `oidc_bff` | cookie BFF или Bearer; при `lmsPasswordFallback` — fallthrough на JWT; иначе anonymous `user_id=0` |
| `lms_db` | как oidc_bff + обязательный fallback пароль LMS |

Пропуск middleware-логики OIDC/JWT: `/internal/lms/*`, `/auth/oidc/*`. `TokenAuthMiddleware` на engine применяется и к `/query`.

---

## Backend: GraphQL (кратко)

- **~47 Query**, **~38 Mutation** — пользователи по ролям, Robbo units/groups, курсы и access relations, project pages.
- **Нет** GraphQL `SignUp` (только REST `/auth/sign-up`).
- Резолверы курсов/юнитов/групп при `legacyPostgres.enabled=false` обращаются к `PostgresClient` с `Db=nil` → **фактически неработоспособны** до включения legacy или переноса метаданных.

Пакеты: `auth`, `oidc`, `lmsdb`, `users`, `portal`, `projects`, `projectPage`, `courses`, `edx`, `robboUnits`, `robboGroup`, `cohorts`, `coursePacket`.

---

## Хранилища и конфигурация (runtime)

| Хранилище | DSN / флаг | Содержимое | Когда используется |
|-----------|------------|------------|-------------------|
| **Projects Postgres** | `PROJECTS_POSTGRES_DSN` | `scratch_projects`, `scratch_project_versions`, `scratch_project_audit_events` | всегда для проектов |
| **LMS MySQL** | `LMS_MYSQL_DSN`, `LMS_MYSQL_WRITE_DSN` | `auth_user`, `auth_userprofile` | вход, профиль, регистрация |
| **Legacy Postgres** | `postgres.postgresDsn`, `legacyPostgres.enabled` | `*_dbs`, `robbo_portal_*`, курсы-метаданные ЛК | опционально; в compose по умолчанию **выкл** |
| **Portal** | `portalOutbox.enabled`, gateway | outbox, notifications, user links | только при `legacyPostgres.enabled=true` |

Переменные: `package/config/config.yml`, `.env.example`, `docker-compose.yml` (`rpa2` — **только** сервис `app`, без Postgres).

Локальный стек: `robbo_personal_account/setup.sh` поднимает Projects DB, `docker-compose.lms_mysql.yml` (:3307), `docker-compose.oidc.dev.yml` (:8081), backend, frontend+scratch.

Скрипты: `scripts/seed_lms_dev_user`, `scripts/backfill_auth_userprofile_name`, `robbo_projects_db/scripts/cleanup_projects_db.sql`.

---

## Интеграции

| Система | Направление | Реализация |
|---------|-------------|------------|
| Open edX LMS | ЛК → LMS (SSO) | OIDC BFF `/auth/oidc/*`, фронт PKCE для вкладки LMS |
| Open edX LMS | LMS → ЛК | ingest `POST /internal/lms/notifications` (контракт ADR) |
| edX REST | ЛК backend → edx-test.ru | `package/edx`, `api_urls`, client credentials |
| Scratch player | ЛК → :5001 | `ScratchPlayerEmbed`, play-token; compose `scratch-gui` |
| Scratch editor (внешний) | ЛК → scratch.ru | ссылка в `HeaderExploreNav` |
| Поддержка | ЛК UI → support.robbo.world | фиксированная кнопка |

---

## Технический долг и расхождения с документацией

| Тема | Факт в коде | Было в architecture |
|------|-------------|---------------------|
| **Inbox REST** | Фронт вызывает `/api/notifications/*`; в backend **нет** handlers (только sketch `notifications_graphql_sketch.graphqls`) | Описаны `user_notifications` и полный REST API |
| **Ingest уведомлений** | `POST /internal/lms/notifications` → `robbo_portal_notifications` через portal gateway | ADR указывает Projects DB; при cutover portal = **noop** |
| **Админка юнитов/групп** | Таблицы в legacy Postgres | В cutover legacy выключен — разделы UI без БД |
| **Роли при LMS-login** | superuser/staff/student | Parent, UnitAdmin — только legacy |
| **GraphQL admin** | Требует `PostgresClient` | В 2-DB режиме не документировано явно |

---

## Связанные документы

- [ARCHITECTURE.md](ARCHITECTURE.md) — диаграммы
- [ARCHITECTURE_DETAILED_RU.md](ARCHITECTURE_DETAILED_RU.md) — стек и потоки
- [LMS_HANDOFF.md](LMS_HANDOFF.md) — чеклист для edx
- [ADR_LK_LMS_SSO_OIDC.md](ADR_LK_LMS_SSO_OIDC.md)
- [ADR_LK_LMS_notifications_ingest.md](ADR_LK_LMS_notifications_ingest.md)
- [runbooks/lk_lms_sso_runbook.md](runbooks/lk_lms_sso_runbook.md)
- [change_log.md](change_log.md)
