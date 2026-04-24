# robbo_personal_account

Monorepo-wrapper with submodules:

- `frontend/` (git submodule) → [robbo_personal_account_frontend](https://github.com/gamr416/robbo_personal_account_frontend)
- `backend/` (git submodule) → [robbo_personal_account_backend](https://github.com/gamr416/robbo_personal_account_backend)
- `architecture/` (tracked files in this repo)

## Актуальная «основная» версия кода (ветка `main`)

В корне этого репозитория GitHub показывает **конкретные коммиты**, на которые указывают субмодули (запись в последнем коммите монорепо). Это не «автопереход» на последний `main`: ссылка в UI ведёт на **тот** снимок `frontend`/`backend`, который зафиксирован в монорепо.

Чтобы открыть **текущую основную линию разработки**, используйте прямые ссылки на ветку `main` в репозиториях с кодом:

| Компонент | Всегда актуальный `main` |
|-----------|-------------------------|
| Frontend | [github.com/gamr416/robbo_personal_account_frontend/tree/main](https://github.com/gamr416/robbo_personal_account_frontend/tree/main) |
| Backend | [github.com/gamr416/robbo_personal_account_backend/tree/main](https://github.com/gamr416/robbo_personal_account_backend/tree/main) |

Апстрим-организация (при наличии доступа): [robboworld/robbo_personal_account_frontend](https://github.com/robboworld/robbo_personal_account_frontend), [robboworld/robbo_personal_account_backend](https://github.com/robboworld/robbo_personal_account_backend).

Обновить закреплённые коммиты субмодулей в этом монорепо после релиза в дочерних репо:

```bash
git submodule update --remote --merge frontend backend
git add frontend backend
git commit -m "chore: bump frontend/backend submodules"
git push
```

(`branch = main` задан в `.gitmodules`, чтобы `--remote` тянул именно `main`.)

## Clone

```bash
git clone https://github.com/gamr416/robbo_personal_account.git
cd robbo_personal_account
git submodule update --init --recursive
```

После клона, чтобы сразу встать на последний `main` субмодулей:

```bash
git submodule update --remote --merge
```
