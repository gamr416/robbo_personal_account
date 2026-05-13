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