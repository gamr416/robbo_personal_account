## Robbo Scratch projects DB (`robbo_projects_db/`)

- Отдельный PostgreSQL под Scratch-проекты ЛК: **только 3 таблицы** — `scratch_projects`, `scratch_project_versions`, `scratch_project_audit_events`.
- **Запуск:** из `robbo_projects_db/` — `docker compose up -d`; `.env.example` при необходимости. Скрипты `init/*.sql` на **новом** томе выполняются при первой инициализации автоматически.
- **Порты:** хост **`5433`** по умолчанию (`ROBBO_PROJECTS_DB_PORT`).
- **Схема:** `init/01_schema.sql`; `init/02_upgrade_pre_meta_projects.sql` — идемпотентно для существующих томов (колонки метаданных, `DROP scratch_project_legacy_map` если была).
- **Очистка старого тома** (portal, `*_dbs`, legacy map): `scripts/cleanup_projects_db.sql`.
- **Backend:** `PROJECTS_POSTGRES_DSN` → `projectsPostgres.postgresDsn` в [`robbo_personal_account_backend`](../robbo_personal_account_backend/).
- **Не используется:** `scratch_project_legacy_map`, backfill из `robbo_db`, portal-таблицы в этой БД. Старые проекты из legacy **не переносим**.
- **Пользователи и профиль** — LMS MySQL (`openedx.auth_user`), см. [architecture/LEGACY_POSTGRES_CUTOVER.md](../architecture/LEGACY_POSTGRES_CUTOVER.md).

## Контракт

- `scratch_projects` — карточка проекта, `owner_user_id` = `edx_user_id`, UUID в `id`.
- `scratch_project_versions` — снимки `.sb3` (BYTEA).
- `scratch_project_audit_events` — журнал действий (запись в коде — отдельный этап).

Открытие редактора: ЛК проверяет доступ → `scratch.ru/editor?projectRef={uuid}`.
