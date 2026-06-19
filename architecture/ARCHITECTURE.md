```mermaid
flowchart LR
  U[User Browser]

  subgraph FE[Frontend robbo_personal_account_frontend]
    FEUI[React Apollo + redux-saga AntD]
    FESRV[Express yarn start :3030]
    SCRgui[Scratch player :5001]
  end

  subgraph BE[Backend robbo_personal_account_backend]
    API[Gin GraphQL POST /query + REST]
    CFG[config.yml + env]
    AUTH[JWT + OIDC BFF]
  end

  subgraph DB[Хранилища]
    PGProj[(Projects Postgres :5433 scratch_*)]
    LMS[(LMS MySQL :3307 auth_user)]
    PGLegacy[(Legacy Postgres :5432 — опционально)]
  end

  U --> FEUI
  FEUI --> FESRV
  FEUI --> SCRgui
  FEUI -->|GraphQL + REST| API
  API --> PGProj
  API --> LMS
  API --> PGLegacy
  API --> CFG
  API --> AUTH
```

```mermaid
flowchart TB
  subgraph LocalStack[Локальный стек setup.sh]
    PP[robbo_projects_db :5433]
    MySQL[docker-compose.lms_mysql.yml :3307]
    MockOIDC[docker-compose.oidc.dev.yml :8081]
    BEapp[rpa2 app :8080]
    FEweb[frontend web :3030]
    Scratch[scratch-gui :5001]
  end

  FEweb --> BEapp
  BEapp --> PP
  BEapp --> MySQL
  BEapp --> MockOIDC
  FEweb --> Scratch
```

```mermaid
flowchart LR
  user[UserBrowser] --> lk[LKFrontend]
  lk -->|new tab openLms| lmsUrl[LMS_URL online.robbo.ru]
  lk -->|BFF login| beOidc[Backend /auth/oidc]
  beOidc --> idp[Open edX OIDC IdP]
  lk -->|PKCE вкладка LMS| feCb[Frontend /auth/oidc/callback]
  feCb --> idp
```

Пересборка контейнеров ЛК: фронт — сервис `web` в `robbo_personal_account_frontend`; бэкенд — сервис `app`, проект `rpa2`. После `build` — `up -d --build`. См. `ARCHITECTURE_DETAILED_RU.md`, `change_log.md`.

**Где править код:** только `robbo_personal_account_frontend/` и `robbo_personal_account_backend/`. `robbo_personal_account/` — монорепо с субмодулями (`setup.sh`); исходный код там не менять.

**Инвентарь функционала:** [FUNCTIONALITY_RU.md](FUNCTIONALITY_RU.md).

Монорепо: [github.com/gamr416/robbo_personal_account](https://github.com/gamr416/robbo_personal_account).

**БД:** Projects — [`robbo_projects_db/`](../robbo_projects_db/) (`PROJECTS_POSTGRES_DSN`, `:5433`). Пользователи — LMS MySQL (`LMS_MYSQL_DSN`). Legacy — `legacyPostgres.enabled`. См. [LEGACY_POSTGRES_CUTOVER.md](LEGACY_POSTGRES_CUTOVER.md).
