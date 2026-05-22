# Cutover: отключение `robbo_db`

## Текущее состояние

- **Projects DB** — единственный источник для Scratch (`PROJECTS_POSTGRES_DSN` обязателен).
- **`robbo_portal_*`** — метаданные ЛК в Projects DB (`init/03_portal_schema.sql`, без AutoMigrate).
- **`legacyPostgres.enabled: false`** — `PostgresClient` → Projects DSN.
- **`auth.mode: oidc_bff`** + **`auth.lmsPasswordFallback: true`** (рекомендуется) — сначала OAuth (`/auth/oidc/start`), иначе email+пароль по `openedx.auth_user` (`LMS_MYSQL_DSN`).
- **`auth.mode: lms_db`** — только пароль по LMS MySQL, без OAuth.
- **LMS MySQL** — локально `docker-compose.lms_mysql.yml` + `dump.sql` (см. `lms_dump/README.md`).

## Шаги cutover

1. Заполнить `robbo_portal_user_link` (скрипты `export_robbo_db_users.py`, `link_users_from_lms_mysql.py`).
2. Включить `AUTH_MODE=oidc_bff`, пройти smoke SSO ([LMS_HANDOFF.md](LMS_HANDOFF.md)).
3. Backfill `scratch_projects.owner_user_id` (`backfill_owner_from_portal_link.py`).
4. Установить `legacyPostgres.enabled: false` и удалить `postgres.postgresDsn` из runtime (отдельный PR).

## Не удалять

- Таблицы `robbo_db` на диске до подтверждения бэкапа и сверки ссылок.
