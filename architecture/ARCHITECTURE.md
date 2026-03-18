```mermaid
flowchart LR
  U[User Browser]

  subgraph FE[Frontend: robbo_personal_account_frontend]
    FEUI[React SPA react-router-dom + redux/saga AntD + styled-components]
    FESRV[Node/Express server `yarn start` exposes :3030]
  end

  subgraph BE[Backend: robbo_personal_account_backend]
    API[Go app Gin HTTP server GraphQL via gqlgen exposes :8080]
    CFG[Config/Env]
    AUTH[Auth JWT]
    ORM[GORM]
  end

  subgraph DB[Database]
    PG[(PostgreSQL 13 :5432 robbo_db)]
  end

  U --> FEUI
  FEUI -->|HTTP serves bundle| FESRV

  FEUI -->|GraphQL over HTTP| API
  API -->|SQL via GORM| ORM --> PG
  API --> CFG
  API --> AUTH
```

```mermaid
flowchart TB
  subgraph DockerCompose[Docker Compose]
    subgraph FEc[Frontend compose]
      FEsvc[web build: . ports: 3030:3030 network_mode: host]
    end

    subgraph BEc[Backend compose]
      BEsvc[app build: . ports: 8080:8080 depends_on: postgres(healthy)]
      PGsvc[postgres image: postgres:13 ports: 5432:5432 volume: postgres_data]
    end
  end

  FEsvc -->|calls backend (GraphQL)| BEsvc
  BEsvc --> PGsvc
```

