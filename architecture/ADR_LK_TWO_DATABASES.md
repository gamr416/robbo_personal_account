# ADR: две БД (Projects PostgreSQL + LMS MySQL)

## Status

Accepted (May 2026), уточнено после cutover 2026-05-22

## Context

- ЛК интегрируется с Open edX (Tutor).
- LMS MySQL (`openedx`) нельзя менять схемой (без DDL, без DELETE/UPDATE чужих данных без согласования).
- Учебные данные — master в LMS; ученические Scratch-проекты — в Projects Postgres.

## Decision

1. **Projects PostgreSQL** (`robbo_projects_db`, `:5433`): только **`scratch_projects`**, **`scratch_project_versions`**, **`scratch_project_audit_events`**. DSN `PROJECTS_POSTGRES_DSN`.
2. **LMS MySQL**: `LMS_MYSQL_DSN` (read), `LMS_MYSQL_WRITE_DSN` (профиль, регистрация) — `auth_user`, `auth_userprofile.name` (полное имя).
3. **SSO**: Open edX = IdP; ЛК = OIDC client (`/auth/oidc/*`, BFF cookie).
4. **Legacy `robbo_db` Postgres (`:5432`)**: опционально через `legacyPostgres.enabled`. Содержит `*_dbs` (юниты, группы, роли ЛК), `robbo_portal_*` (notifications, outbox, user links). **В целевом compose выключен** — см. [LEGACY_POSTGRES_CUTOVER.md](LEGACY_POSTGRES_CUTOVER.md).

## Consequences

- При `legacyPostgres.enabled=false`: работают вход/профиль/проекты; **не работают** GraphQL-админка (юниты, группы, клиенты) и portal (уведомления, outbox).
- Роли Parent / UnitAdmin / FreeListener в LMS-password режиме не выводятся из `auth_user` — только legacy или будущий маппинг.
- Handoff для edx: [LMS_HANDOFF.md](LMS_HANDOFF.md).
- Сверка с кодом: [FUNCTIONALITY_RU.md](FUNCTIONALITY_RU.md).
