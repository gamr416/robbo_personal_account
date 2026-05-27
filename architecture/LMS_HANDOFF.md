# LMS handoff checklist (Open edX ↔ ЛК)

Документ для владельцев edx/Tutor. Команда ЛК **не** меняет схему `openedx` (без DDL, без DELETE/UPDATE чужих строк).

## OIDC (обязательно)

- [ ] `issuer` (например `https://lms.example.com`)
- [ ] `authorization_endpoint`
- [ ] `token_endpoint`
- [ ] `jwks_uri`
- [ ] Зарегистрирован client **`lk-web`**
  - [ ] `client_id`
  - [ ] `redirect_uri`: `https://<lk-host>/auth/oidc/callback`
  - [ ] scopes: `openid profile email`
- [ ] Один issuer для SSO **ЛК → LMS** и **LMS → ЛК**
- [ ] (опционально) `end_session_endpoint`, `post_logout_redirect_uri`

## Направление LMS → ЛК

- [ ] В MFE/навигации ссылка «Личный кабинет»:
  - `https://<lk-host>/auth/oidc/start?return_to=/home`

## DevOps: доступ к MySQL (read)

- [ ] `LMS_MYSQL_DSN` или отдельно: host, port, database=`openedx`, user, password
- [ ] Роль **SELECT** на таблицы: `auth_user`, `auth_userprofile`, `student_courseenrollment`, `course_overviews_courseoverview`, …
- [ ] Для ЛК runtime (регистрация/профиль): **INSERT/UPDATE** на `auth_user` (email) и `auth_userprofile` (`name`) через `LMS_MYSQL_WRITE_DSN`
- [ ] VPN / allowlist с хостов ЛК и worker
- [ ] Staging LMS URL для smoke SSO

## Server-to-server (позже)

- [ ] Service user / OAuth credentials для Enrollment API (если ЛК инициирует зачисление)
- [ ] Bearer token для webhook уведомлений: `POST https://<lk-backend>/internal/lms/notifications`
- [ ] Список `course_id` для каталога в ЛК

## Явно не требуется от ЛК

- Миграции/plugin в MySQL `openedx`
- Массовый импорт в `auth_user`
- Кастомные таблицы `robbo_*` в LMS (метаданные ЛК — в Projects PostgreSQL)

## Cutover на staging (после выдачи LMS-доступа)

1. Зарегистрировать OAuth client **`lk-web`** в edx admin (`oauth2_provider_application`).
2. Выставить в ЛК backend:
   - `LK_SSO_WITH_LMS_ENABLED=true`
   - `AUTH_MODE=oidc_bff`
   - `OIDC_*` endpoints и `OIDC_REDIRECT_URI=https://<lk-backend>/auth/oidc/callback`
3. Smoke SSO:
   - `GET /auth/oidc/start` → authorize → callback → cookie `lk_bff_session`
   - `GET /auth/oidc/status` → `{ "authenticated": true }`
   - Кнопка LMS в ЛК (SSO A) и ссылка «Личный кабинет» в LMS (SSO B)
4. ETL (Projects DB):
   - `robbo_projects_db/scripts/link_users_from_lms_mysql.py`
   - `robbo_projects_db/scripts/backfill_owner_from_portal_link.py`
5. Отключить legacy:
   - `legacyPostgres.enabled: false`
   - убрать `postgres.postgresDsn` из runtime

## Контакты / окружения

| Поле | Staging | Production |
|------|---------|------------|
| LMS URL | | |
| OIDC issuer | | |
| lk-web client_id | | |
| LMS_MYSQL read host | | |
| notifications ingest token | | |
