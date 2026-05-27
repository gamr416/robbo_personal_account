# Cutover: две БД (Projects Postgres + LMS MySQL)

## Целевое состояние

| Хранилище | DSN | Содержимое |
|-----------|-----|------------|
| **Projects Postgres** (`:5433`) | `PROJECTS_POSTGRES_DSN` | Только 3 таблицы: `scratch_projects`, `scratch_project_versions`, `scratch_project_audit_events` |
| **LMS MySQL** (`:3307`) | `LMS_MYSQL_DSN` (read), `LMS_MYSQL_WRITE_DSN` (profile) | `openedx.auth_user` — вход, профиль, роли (`is_staff` / `is_superuser`) |

**Не используется:**
- Legacy `robbo_db` (Postgres `:5432`) — не поднимаем.
- `robbo_portal_*`, `*_dbs` в Projects DB — удалены (`scripts/cleanup_projects_db.sql`).
- `scratch_project_legacy_map` — снята; старые проекты из `robbo_db` **не переносим**.
- Portal outbox / notifications Postgres — отключены (`portalOutbox.enabled: false`).

## Runtime backend

- `legacyPostgres.enabled: false` — `PostgresClient` не подключается к БД; portal gateway = noop.
- `auth.mode: oidc_bff` + `auth.lmsPasswordFallback: true` — OAuth и/или email+пароль по LMS.
- Профиль Get/Update — `lmsdb` → `auth_user` (`first_name`, `last_name`, `email`; `username` read-only).
- JWT `Id` = `edx_user_id` из LMS.

## Очистка существующего тома Projects DB

```bash
docker exec -i robbo_projects_postgres psql -U robbo_projects -d robbo_projects -v ON_ERROR_STOP=1 \
  < robbo_projects_db/scripts/cleanup_projects_db.sql
docker exec robbo_projects_postgres psql -U robbo_projects -d robbo_projects -v ON_ERROR_STOP=1 \
  -f /docker-entrypoint-initdb.d/02_upgrade_pre_meta_projects.sql
```

## Smoke

1. `\dt` в `robbo_projects` — ровно 3 таблицы `scratch_*`.
2. Вход `1@1` / `123` → JWT с `edx_user_id`.
3. Профиль: сохранить ФИО → re-login → данные из `auth_user`.
4. Новый проект — UUID в `scratch_projects`.

## Историческое

Скрипты `export_robbo_db_users.py`, `backfill_lk_projects.py`, `03_portal_schema.sql` — deprecated, не часть cutover.
