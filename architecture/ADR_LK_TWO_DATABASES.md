# ADR: две БД (Projects PostgreSQL + LMS MySQL)

## Status

Accepted (May 2026)

## Context

- ЛК интегрируется с Open edX (Tutor).
- LMS MySQL (`openedx`) нельзя менять схемой (без DDL, без DELETE/UPDATE чужих данных).
- Учебные и учётные данные — master в LMS; Robbo-специфика и Scratch — в Projects DB.

## Decision

1. **Projects PostgreSQL** (`robbo_projects_db`): `scratch_*`, `robbo_portal_*` (user_link, outbox, notifications, groups).
2. **LMS MySQL**: только чтение в worker/скриптах (`LMS_MYSQL_DSN`); UI — edx REST API.
3. **SSO**: Open edX (или mock) = IdP; ЛК = OIDC client; направления ЛК↔LMS через `/auth/oidc/start` и кнопку LMS.
4. **Legacy `robbo_db`**: deprecated; `legacyPostgres.enabled` до завершения миграции в portal.

## Consequences

- Outbox и идемпотентность — в `robbo_portal_integration_outbox` (Projects DB).
- Handoff для edx: [LMS_HANDOFF.md](LMS_HANDOFF.md).
