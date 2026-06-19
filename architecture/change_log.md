# Журнал изменений архитектуры

## 2026-06-19

- **Scratch embed-плеер в ЛК:** `robboscratch3_gui` — режим `player.html` с `EmbedProjectLoaderHOC`, Docker-образ Nginx (`:5001`). Frontend: компонент `ScratchPlayerEmbed`, play-токен через backend. Субмодуль `robboscratch3_gui/` в монорепо; `setup.sh` собирает `scratch-gui` перед `web`.
- **Публичная галерея проектов:** маршрут `/projects/public`, API `GET /projectPage/public`, управление доступом (`access/`), JWT play-токен (`playtoken/`), навигация `HeaderExploreNav`.

## 2026-05-27 (инвентаризация)

- Добавлен **[FUNCTIONALITY_RU.md](FUNCTIONALITY_RU.md)** — полный перечень маршрутов фронта, HTTP/GraphQL backend, хранилищ, интеграций и технического долга (inbox REST не смонтирован; админка юнитов требует legacy Postgres).
- Обновлены **[ARCHITECTURE_DETAILED_RU.md](ARCHITECTURE_DETAILED_RU.md)** (i18n, Help, OIDC BFF, CoursePage, актуальный статус уведомлений), **[ARCHITECTURE.md](ARCHITECTURE.md)** (ссылка на инвентарь), **[ADR_LK_TWO_DATABASES.md](ADR_LK_TWO_DATABASES.md)**, **[ADR_LK_LMS_notifications_ingest.md](ADR_LK_LMS_notifications_ingest.md)**.

## 2026-05-27

- **Профиль и регистрация через `auth_userprofile.name`:** полное имя (GraphQL `fullName`) читается/пишется в `auth_userprofile.name`; пароль и email остаются в `auth_user`. LMS-регистрация (`signUpLMS`) создаёт обе строки. UI: одно поле «Полное имя» в профиле и регистрации. Backfill: `scripts/backfill_auth_userprofile_name/`.

## 2026-05-22

- **Две БД (финальный cutover):** Projects Postgres — только `scratch_projects`, `scratch_project_versions`, `scratch_project_audit_events`; LMS MySQL — `auth_user` (вход, профиль). Сняты `robbo_portal_*`, `scratch_project_legacy_map`, backfill проектов. Backend: `PostgresClient` off при `legacyPostgres.enabled=false`, portal noop, профиль через `lmsdb`. См. [LEGACY_POSTGRES_CUTOVER.md](LEGACY_POSTGRES_CUTOVER.md).

## 2026-05-20

- **ЛК ↔ Open edX (2 БД):** Projects PostgreSQL — `scratch_*` + `robbo_portal_*` (`robbo_projects_db/init/03_portal_schema.sql`); LMS MySQL — read-only через `LMS_MYSQL_DSN` / пакет `lmsdb`; без DDL в `openedx`. Backend: OIDC `/auth/oidc/start`, `/auth/oidc/callback`, BFF cookie `lk_bff_session`, `AUTH_MODE=legacy_jwt|oidc_bff`, ingest `POST /internal/lms/notifications` → `robbo_portal_notifications`, outbox worker. Документы: [LMS_HANDOFF.md](LMS_HANDOFF.md), [ADR_LK_TWO_DATABASES.md](ADR_LK_TWO_DATABASES.md), [LEGACY_POSTGRES_CUTOVER.md](LEGACY_POSTGRES_CUTOVER.md). Mock OIDC: `robbo_personal_account_backend/docker-compose.oidc.dev.yml`. Проекты: fallback на `robbo_db` в gateway отключён.

## 2026-05-09

- **Мои проекты → PROJECT DB (hard switch):** `robbo_personal_account_backend` читает и обновляет проекты через отдельный DSN (`projectsPostgres` / env `PROJECTS_POSTGRES_DSN`), таблица `scratch_projects` в Postgres из [`robbo_projects_db/`](../robbo_projects_db/) включает `title`, `instruction`, `note`, `is_public`, `scratch_vm_json` и маппинг `scratch_project_legacy_map`. Файлы: `package/projects/gateway/projects.go`, `package/projectPage/gateway/projectPage.go`, `package/models/scratchProject*.go`, `package/config/config.yml`. На уже поднятый том добавлен скрипт `init/02_upgrade_pre_meta_projects.sql`; однократный перенос из ЛК БД — `scripts/backfill_lk_projects.py`. Обновлена документация [`архитектура_3_сервисов.md`](архитектура_3_сервисов.md), [`ARCHITECTURE_DETAILED_RU.md`](ARCHITECTURE_DETAILED_RU.md), [`ARCHITECTURE.md`](ARCHITECTURE.md).

## 2026-05-06

- **Robbo Scratch projects DB:** в корне workspace добавлен каталог `robbo_projects_db/` — `docker-compose.yml` (PostgreSQL 13, порт хоста по умолчанию `5433`), `.env.example`, SQL-схема `init/01_schema.sql` (`scratch_projects`, `scratch_project_versions`, `scratch_project_audit_events`). В `architecture/ARCHITECTURE.md`, `architecture/архитектура_3_сервисов.md`, `architecture/ARCHITECTURE_DETAILED_RU.md` добавлены ссылки и краткое описание контракта БД.

## 2026-04-25

- **Корень workspace `work/`:** добавлена человекоориентированная копия матрицы ролей `user_roles_capabilities_простая_таблица.csv` (рядом с `user_roles_capabilities.csv`): обычные формулировки вместо жаргона (API, пути в коде), дружелюбные заголовки ролей и сфер; исходный файл не менялся. Добавлены `user_roles_capabilities_простая_таблица.xlsx` (оформление: шапка, зебра по строкам, заливка да/нет/частично) и `build_friendly_roles_xlsx.py` для пересборки; локальное venv `work/.venv_xlsx` (openpyxl) не в репозиторий.
- **Монорепо `gamr416/robbo_personal_account`:** в `README.md` добавлены прямые ссылки на ветку `main` субмодулей frontend/backend (GitHub в корне монорепо показывает только закреплённые SHA субмодулей). В `.gitmodules` указано `branch = main`; закрепления субмодулей обновлены до актуальных коммитов на `main`.
- **ЛК, сайдбар на `/home`:** для unit admin и super admin над боковым меню отображается кнопка быстрого перехода «Отправить уведомление» (`src/components/SideBar/SideBar.jsx`).

## 2026-04-24

- **Docker Compose:** в `robbo_personal_account_backend/docker-compose.yml` задано верхнеуровневое `name: rpa2`, чтобы `docker compose build` из каталога бэкенда собирал образ **`rpa2-app`** (как у уже запущенного стека), а не отдельный `robbo_personal_account_backend-app`. Во фронте — `name: robbo_personal_account_frontend`, сервис **`web`**. После `build` для обновления кода на проде нужен **`docker compose up -d --build`** (пересоздание контейнера), иначе процесс продолжает работать на старом image id. Агентам: каталоги и сервисы зафиксированы в `.cursor/rules/Rebuilding.mdc`; учитывать дубликат фронта `robbo_personal_account/frontend/`, если прод поднят оттуда.
- **ЛК, боковое меню и страница проекта:** активный пункт меню вычисляется по `pathname` (в т.ч. `/projects/:id` → «Мои проекты» для ученика), если не передан `state.selectedNavBarKey`; на странице проекта добавлена кнопка «К моим проектам».
- **ЛК (ученик), карточка проекта**: исправлено сохранение инструкции и примечания. На бэкенде обновление страницы проекта выполняется по `id` записи с явным `UPDATE` полей (map), проверка владельца идёт по `project_id` из БД для данного `projectPageId`, а не по полю из тела запроса (раньше при рассинхроне `projectPageId` и `projectId` условие GORM не совпадало со строкой, обновлялось 0 строк при HTTP 200). На фронте при смене `/projects/:id` перезагружаются данные страницы; таймаут axios для REST увеличен с 1 с до 30 с.
- Добавлен inbox уведомлений в ЛК: таблицы `user_notifications`, `system_announcements`, `announcement_reads`; HTTP API на бэкенде (`/api/notifications`, `/internal/lms/notifications`); UI колокольчик и страница отправки для админов. Вёрстка шапки `PageLayout`: `Header` на flex — слева иконка меню, справа одна группа (`margin-left: auto`) с языком и колокольчиком в ряд, оба у правого края.
- Новый ADR: [ADR_LK_LMS_notifications_ingest.md](ADR_LK_LMS_notifications_ingest.md).
