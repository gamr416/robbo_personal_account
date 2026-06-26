# OAuth / OIDC в личном кабинете (текущее состояние)

Документ описывает **что реализовано в коде ЛК** на момент июня 2026, после отката двусторонней интеграции с LMS (ссылка «Личный кабинет» в MFE, регистрация OAuth-клиента на прод-LMS и т.п.).  
Архитектурное решение зафиксировано в [ADR_LK_LMS_SSO_OIDC.md](./ADR_LK_LMS_SSO_OIDC.md). Операционные подсказки — в [runbooks/lk_lms_sso_runbook.md](./runbooks/lk_lms_sso_runbook.md).

## Роли

| Участник | Роль в OIDC | Репозиторий |
|----------|-------------|-------------|
| **Open edX (LMS)** | Identity Provider (IdP) | `robbo-openedx-stack` |
| **ЛК backend** | OAuth client (BFF) + обмен code→token | `robbo_personal_account_backend` |
| **ЛК frontend** | SPA: UI входа, частично свой PKCE для перехода в LMS | `robbo_personal_account_frontend` |

Клиент: `lk-web` (public, Authorization Code + PKCE).

## Режимы аутентификации

В `config.yml` / env backend:

| Параметр | Значение по умолчанию | Смысл |
|----------|----------------------|--------|
| `auth.mode` | `oidc_bff` | Основной вход через OIDC на backend |
| `auth.lmsPasswordFallback` | `true` | Допускается email/password через MySQL LMS (`openedx.auth_user`) |
| `oidc.enabled` | `true` | Включён пакет `package/oidc` |
| `legacyPostgres.enabled` | `false` | Старая БД ЛК для логина не используется |

Флаг frontend `LK_SSO_WITH_LMS_ENABLED=true` включает OIDC-логику в SPA (кнопка OIDC на `/login`, проверка BFF-сессии, переход в LMS через OAuth).

### Гибридный вход (hybrid)

При `oidc_bff` + `lmsPasswordFallback`:

1. На странице `/login` показываются **кнопка OIDC** и **форма email/password**.
2. OIDC ведёт на backend `/auth/oidc/start`.
3. Password — GraphQL `SingIn` / REST `POST /auth/sign-in` → JWT в `localStorage.token` (legacy-путь для API).

## Два независимых потока OIDC

В ЛК одновременно существуют **два** потока. Они используют одни и те же env-имена, но разные точки callback и разное хранилище PKCE.

```mermaid
sequenceDiagram
  participant U as Пользователь
  participant FE as ЛК frontend :3030
  participant BE as ЛК backend :8080
  participant IdP as IdP (LMS / mock)

  Note over U,IdP: Поток A — вход в ЛК (BFF, основной)
  U->>FE: /login → «Войти через LMS»
  FE->>BE: GET /auth/oidc/start?return_to=/home&prompt=login
  BE->>IdP: authorize (PKCE state в памяти backend)
  IdP->>BE: GET /auth/oidc/callback?code&state
  BE->>BE: cookie lk_bff_session
  BE->>FE: redirect /home

  Note over U,IdP: Поток B — кнопка «LMS» в шапке (frontend PKCE)
  U->>FE: openLms() / /mycourses
  FE->>IdP: authorize (PKCE в sessionStorage)
  IdP->>BE: callback на OIDC_REDIRECT_URI из env
  Note right of BE: redirect_uri должен совпадать с зарегистрированным client; при uri на backend срабатывает поток A, не страница OidcCallback
```

### Поток A — вход в ЛК через backend (BFF)

**Назначение:** авторизовать пользователя в ЛК и выдать серверную сессию.

| Шаг | Компонент | Действие |
|-----|-----------|----------|
| 1 | `PageLayoutLogin` | `redirectToOidcStart('/home', 'login')` |
| 2 | `GET /auth/oidc/start` | Backend создаёт PKCE (in-memory, TTL ~10 мин), редирект на IdP |
| 3 | IdP | Пользователь логинится |
| 4 | `GET /auth/oidc/callback` | Обмен code→tokens, валидация `id_token`, lookup роли в LMS MySQL |
| 5 | Backend | Cookie `lk_bff_session` (HttpOnly JWT, TTL `auth.access_token_ttl`, по умолчанию 5 мин) |
| 6 | Backend | Redirect на `oidc.frontendBaseUrl` + `return_to` (например `http://localhost:3030/home`) |

**Обработка `login_required`:** если IdP вернул `error=login_required` при `prompt=none`, backend повторно вызывает `/auth/oidc/start?prompt=login`.

**Файлы backend:** `package/oidc/http/handler.go`, `package/oidc/pkce.go`, `package/oidc/session.go`, `package/oidc/validate.go`, `package/oidc/token.go`.

### Поток B — переход ЛК → LMS (frontend PKCE)

**Назначение:** открыть LMS с уже активной сессией IdP (`prompt=none`), без повторного логина.

| Шаг | Компонент | Действие |
|-----|-----------|----------|
| 1 | `HeaderExploreNav`, `SideBar`, `Home`, `/mycourses` | `openLms()` или `navigateToLmsSameTab()` |
| 2 | `lmsSso.js` | Строит authorize URL с PKCE в `sessionStorage` |
| 3 | IdP | Silent или interactive login |
| 4 | Callback | Зависит от `OIDC_REDIRECT_URI` в env frontend (см. ниже) |

При успехе на **frontend callback** (`/auth/oidc/callback`):

- `OidcCallback` обменивает code на tokens, валидирует claims, пишет `localStorage.lk_lms_identity_link`.
- Редирект на `/home`.

**Файлы frontend:** `src/helpers/lmsSso.js`, `src/pages/OidcCallback/index.jsx`, `docs/sso-test-harness.md`.

Если `LK_SSO_WITH_LMS_ENABLED=false` или OIDC env не заполнены — fallback на прямой `LMS_URL` (новая вкладка или `location.replace`).

## Backend API (`/auth/oidc/*`)

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/auth/oidc/start` | Старт BFF-потока. Query: `return_to`, `prompt` (`none` \| `login` \| `consent`) |
| GET | `/auth/oidc/callback` | Callback IdP для BFF; выдаёт cookie, редирект на frontend |
| GET | `/auth/oidc/status` | JSON: есть ли активная BFF-сессия (`authenticated`, `sub`, `email`, `edx_user_id`, `role`, флаги режима) |
| GET | `/auth/oidc/logout` | Сброс cookie; опционально редирект на `oidc.logoutEndpoint` |

Cookie сессии: **`lk_bff_session`** (`package/oidc/session.go`).

Claims в BFF JWT: `sub`, `edx_user_id`, `email`, `role`, `typ=lk_bff`.

Роль определяется:

1. По email из LMS MySQL (`auth_user` / profile), если найден;
2. Иначе из claims `id_token` (`is_staff` → teacher, `is_superuser` → super_admin, иначе student).

## Frontend: защита маршрутов

При `LK_SSO_WITH_LMS_ENABLED=true`:

| Компонент | Где | Поведение |
|-----------|-----|-----------|
| `PublicAuthGate` | `/login`, `/register` | `GET /auth/oidc/status`; при `authenticated` → `/home`; иначе форма входа |
| `RequireAuth` → `OidcSessionProvider` | Защищённые страницы | Проверка BFF; без сессии — login или auto `/auth/oidc/start` |
| `ProtectedRoute` | Внутри shell | Доступ по BFF-сессии или `localStorage.token` (JWT) |
| `PageLayoutLogin` | Кнопка OIDC | `redirectToOidcStart` → backend |

**Важно:** в `PublicAuthGate` есть модульный кэш `cachedGateResult` — при смене состояния сессии может понадобиться hard refresh.

## GraphQL / middleware

`TokenAuthMiddleware` (`server/middleware.go`):

- Маршруты `/auth/oidc/*` — без обязательной авторизации.
- В режиме `oidc_bff` + fallback: сначала cookie `lk_bff_session`, иначе `Authorization: Bearer` (legacy JWT).
- В чистом `oidc_bff` без fallback — только BFF-cookie.

## Конфигурация

### Backend (`robbo_personal_account_backend`)

Основные переменные (`docker-compose.yml`, `.env.example`, `package/config/config.yml`):

```env
AUTH_MODE=oidc_bff
AUTH_LMS_PASSWORD_FALLBACK=true

OIDC_ISSUER=http://localhost:8081/default
OIDC_AUTHORIZATION_ENDPOINT=http://localhost:8081/default/authorize
OIDC_TOKEN_ENDPOINT=http://localhost:8081/default/token
OIDC_JWKS_URI=http://localhost:8081/default/jwks
OIDC_CLIENT_ID=lk-web
OIDC_REDIRECT_URI=http://localhost:8080/auth/oidc/callback
OIDC_FRONTEND_BASE_URL=http://localhost:3030
OIDC_SCOPES=openid profile email

AUTH_ACCESS_SIGNING_KEY=...
```

Локально по умолчанию — **mock IdP** на порту `8081`:

```bash
cd robbo_personal_account_backend
docker compose -f docker-compose.oidc.dev.yml up -d
```

### Frontend (`robbo_personal_account_frontend`)

Build-time env (`.env`, `.env.example`):

```env
LK_SSO_WITH_LMS_ENABLED=true
LMS_URL=https://online.robbo.ru

OIDC_ISSUER=...
OIDC_AUTHORIZATION_ENDPOINT=...
OIDC_TOKEN_ENDPOINT=...
OIDC_JWKS_URI=...
OIDC_USERINFO_ENDPOINT=...   # опционально
OIDC_CLIENT_ID=lk-web
OIDC_REDIRECT_URI=...        # см. примечание ниже
OIDC_SCOPES=openid profile email
```

Константы: `src/constants/oauth.js`.  
Запрос статуса BFF: `src/helpers/oidcSession.js` → `credentials: 'include'` на backend (нужен CORS с credentials).

### Примечание про `OIDC_REDIRECT_URI`

| Сценарий | Рекомендуемый redirect URI |
|----------|---------------------------|
| Вход в ЛК (BFF) | `http://<lk-api>/auth/oidc/callback` |
| Frontend callback (`OidcCallback`) | `http://<lk-spa>/auth/oidc/callback` |

В `.env.example` frontend и backend сейчас указан **backend** URI — это корректно для потока A. Для потока B (`openLms`) redirect должен быть согласован с тем, кто обрабатывает callback (backend или SPA), и зарегистрирован в IdP.

### Подключение к реальному Open edX (Tutor)

Для prod/staging IdP обычно:

```env
OIDC_ISSUER=https://<lms-host>/oauth2
OIDC_AUTHORIZATION_ENDPOINT=https://<lms-host>/oauth2/authorize
OIDC_TOKEN_ENDPOINT=https://<lms-host>/oauth2/access_token
OIDC_JWKS_URI=https://<lms-host>/auth/jwks.json
```

**Критично:** `iss` в `id_token` Open edX часто **без порта** (`http://local.openedx.io/oauth2`), даже если LMS открыт на `:8000`. `OIDC_ISSUER` должен совпадать с `iss`.

На LMS нужно:

- `FEATURES['ENABLE_OAUTH2_PROVIDER'] = True` (в Tutor dev часто уже в `lms.env.yml`);
- OAuth application `lk-web` с redirect URI на backend ЛК.

Скрипт регистрации клиента и ссылка из MFE в ЛК **сейчас не в репозитории** (откачены).

## Что не реализовано / откачено

- Ссылка «Личный кабинет» в header LMS MFE (`LK_PORTAL_URL`).
- Единый BFF-поток для кнопки «LMS» (`openLms` через `/auth/oidc/start?return_to=<LMS_URL>`).
- Документ handoff для прод-LMS (`LMS_OAUTH_HANDOFF_PRODUCTION.md`).
- Скрипт `register-lk-oauth-client.sh`.

## Локальная проверка

1. Mock IdP: `docker compose -f docker-compose.oidc.dev.yml up -d` (backend repo).
2. Backend + frontend ЛК с env из примеров выше.
3. **Вход в ЛК:** `/login` → кнопка OIDC → `/home`, cookie `lk_bff_session` на `:8080`.
4. **Статус:** `curl -b cookies.txt http://localhost:8080/auth/oidc/status`.
5. **LMS:** кнопка в шапке при настроенном OIDC и зарегистрированном client — см. `docs/sso-test-harness.md`.

Логи в консоли браузера: `[lms-sso] authorize_redirect_started`, `sso_success`, `sso_error`.

## Ограничения и техдолг

| Тема | Описание |
|------|----------|
| PKCE на backend | In-memory map; сбрасывается при рестарте контейнера |
| TTL BFF cookie | 5 мин по умолчанию; короткая сессия без refresh |
| Два PKCE-потока | Backend и frontend не разделяют state — важно не смешивать redirect URI |
| `cachedGateResult` | Может давать устаревший редирект login ↔ home |
| Logout | Полный SLO только при настроенном `OIDC_LOGOUT_ENDPOINT` |
| Identity link | `lk_lms_identity_link` в localStorage — не замена BFF-сессии для API |

## Связанные файлы

**Backend**

- `package/oidc/` — OIDC client, PKCE, session, JWKS validation
- `package/oidc/http/handler.go` — HTTP handlers
- `server/middleware.go` — авторизация GraphQL
- `docker-compose.oidc.dev.yml` — mock IdP

**Frontend**

- `src/helpers/oidcSession.js` — BFF status / start
- `src/helpers/lmsSso.js` — LK → LMS PKCE
- `src/helpers/OidcSessionContext.jsx`, `PublicAuthGate.jsx`, `ProtectedRoute.jsx`, `RequireAuth.jsx`
- `src/pages/OidcCallback/index.jsx`
- `src/components/PageLayoutLogin/PageLayoutLogin.jsx`

**Документация**

- [ADR_LK_LMS_SSO_OIDC.md](./ADR_LK_LMS_SSO_OIDC.md)
- [runbooks/lk_lms_sso_runbook.md](./runbooks/lk_lms_sso_runbook.md)
- `robbo_personal_account_frontend/docs/sso-test-harness.md`
