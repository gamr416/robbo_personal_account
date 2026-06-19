#!/usr/bin/env bash
# Локальный стек ЛК после git clone монорепо robbo_personal_account.
# Поднимает: Projects Postgres (:5433), LMS MySQL (:3307), mock OIDC (:8081),
# backend (:8080), frontend (:3030), Scratch player (:5001).
#
# Использование:
#   git clone --recurse-submodules https://github.com/gamr416/robbo_personal_account.git
#   cd robbo_personal_account
#   ./setup.sh
#
# Или без --recurse-submodules:
#   git clone https://github.com/gamr416/robbo_personal_account.git
#   cd robbo_personal_account
#   ./setup.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DB_DIR="${ROOT}/robbo_projects_db"
BACKEND_DIR="${ROOT}/backend"
FRONTEND_DIR="${ROOT}/frontend"
SCRATCH_GUI_DIR="${ROOT}/robboscratch3_gui"

PULL_SUBMODULES=false
SKIP_BUILD=false

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!>\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
setup.sh — развернуть локальный стек ЛК (БД + backend + frontend + Scratch player)

Опции:
  --pull           Обновить субмодули frontend/backend/robboscratch3_gui
  --skip-build     Не пересобирать образы app/web/scratch-gui (только docker compose up -d)
  -h, --help       Эта справка

Требования: git, Docker Engine, Docker Compose v2.

После успешного запуска:
  Frontend       http://localhost:3030
  Backend        http://localhost:8080
  GraphQL        http://localhost:8080/query
  Scratch Player http://localhost:5001/player.html

Тестовый вход (LMS MySQL): 1@1.ru / 123
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pull) PULL_SUBMODULES=true; shift ;;
    --skip-build) SKIP_BUILD=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Неизвестный аргумент: $1 (см. --help)" ;;
  esac
done

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Не найдена команда «$1». Установите её и повторите."
}

check_docker_access() {
  if docker info >/dev/null 2>&1; then
    return 0
  fi
  if [[ ! -S /var/run/docker.sock ]]; then
    die "Docker не запущен. Выполните: sudo systemctl start docker && sudo systemctl enable docker"
  fi
  die "$(cat <<EOF
Нет доступа к Docker (permission denied на /var/run/docker.sock).

Добавьте пользователя в группу docker и перелогиньтесь:

  sudo usermod -aG docker $USER
  newgrp docker          # или выйти из SSH и зайти снова

Проверка: docker info

Не запускайте ./setup.sh через sudo — файлы .env получат права root.
EOF
)"
}

wait_for_container_healthy() {
  local name="$1"
  local timeout="${2:-120}"
  local elapsed=0

  log "Ожидание healthcheck контейнера ${name} (до ${timeout}s)..."
  while [[ "$elapsed" -lt "$timeout" ]]; do
    local status
    status="$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || echo missing)"
    case "$status" in
      healthy) log "Контейнер ${name} — healthy"; return 0 ;;
      unhealthy) die "Контейнер ${name} в состоянии unhealthy" ;;
      missing) die "Контейнер ${name} не найден" ;;
    esac
    sleep 3
    elapsed=$((elapsed + 3))
  done
  die "Таймаут ожидания healthcheck для ${name}"
}

wait_for_tcp() {
  local host="$1"
  local port="$2"
  local timeout="${3:-60}"
  local elapsed=0

  log "Ожидание порта ${host}:${port} (до ${timeout}s)..."
  while [[ "$elapsed" -lt "$timeout" ]]; do
    if (echo >/dev/tcp/"$host"/"$port") >/dev/null 2>&1; then
      log "Порт ${host}:${port} доступен"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  die "Таймаут ожидания порта ${host}:${port}"
}

ensure_env_file() {
  local dir="$1"
  local example="${dir}/.env.example"
  local target="${dir}/.env"

  if [[ -f "$target" ]]; then
    return 0
  fi
  if [[ -f "$example" ]]; then
    cp "$example" "$target"
    log "Создан ${target} из .env.example"
  fi
}

compose_up() {
  local dir="$1"
  shift
  local build_flag=()
  if [[ "$SKIP_BUILD" == false ]]; then
    build_flag=(--build)
  fi
  (cd "$dir" && docker compose "$@" up -d "${build_flag[@]}")
}

grant_lms_readonly() {
  if ! docker ps --format '{{.Names}}' | grep -qx 'lms_mysql_local'; then
    return 0
  fi
  log "Права SELECT для lk_readonly@'%' на openedx.*"
  docker exec lms_mysql_local mysql -uroot -plms_root_change_me -e \
    "GRANT SELECT ON openedx.* TO 'lk_readonly'@'%'; FLUSH PRIVILEGES;" \
    >/dev/null 2>&1 || warn "Не удалось выдать GRANT (возможно, уже выдано)"
}

main() {
  require_cmd git
  require_cmd docker
  check_docker_access
  docker compose version >/dev/null 2>&1 || die "Нужен Docker Compose v2 (команда «docker compose»)"

  log "Корень монорепо: ${ROOT}"

  if [[ ! -d "${ROOT}/.git" ]]; then
    die "Скрипт нужно запускать из корня git-репозитория robbo_personal_account"
  fi

  log "Инициализация git-субмодулей (frontend, backend, robboscratch3_gui)..."
  if [[ "$PULL_SUBMODULES" == true ]]; then
    git -C "$ROOT" submodule update --init --recursive
    git -C "$ROOT" submodule update --remote --merge frontend backend robboscratch3_gui
  else
    git -C "$ROOT" submodule update --init --recursive
  fi

  for dir in "$PROJECTS_DB_DIR" "$BACKEND_DIR" "$FRONTEND_DIR" "$SCRATCH_GUI_DIR"; do
    [[ -d "$dir" ]] || die "Каталог не найден: ${dir}. Проверьте субмодули: git submodule update --init --recursive"
  done

  ensure_env_file "$PROJECTS_DB_DIR"
  ensure_env_file "$BACKEND_DIR"
  ensure_env_file "$FRONTEND_DIR"

  log "[1/5] Projects Postgres (порт 5433)..."
  compose_up "$PROJECTS_DB_DIR"
  wait_for_container_healthy robbo_projects_postgres 60

  log "[2/5] LMS MySQL из дампа (порт 3307, первый запуск может занять несколько минут)..."
  compose_up "$BACKEND_DIR" -f docker-compose.lms_mysql.yml
  wait_for_container_healthy lms_mysql_local 360
  grant_lms_readonly

  log "[3/5] Mock OIDC для локального SSO (порт 8081)..."
  compose_up "$BACKEND_DIR" -f docker-compose.oidc.dev.yml
  wait_for_tcp 127.0.0.1 8081 90

  log "[4/5] Backend Go API (порт 8080)..."
  if [[ "$SKIP_BUILD" == false ]]; then
    (cd "$BACKEND_DIR" && docker compose build app)
    (cd "$BACKEND_DIR" && docker compose up -d --force-recreate app)
  else
    (cd "$BACKEND_DIR" && docker compose up -d app)
  fi
  wait_for_tcp 127.0.0.1 8080 120

  log "[5/5] Frontend React + Scratch player (порты 3030, 5001)..."
  if [[ "$SKIP_BUILD" == false ]]; then
    (cd "$FRONTEND_DIR" && docker compose build scratch-gui web)
    (cd "$FRONTEND_DIR" && docker compose up -d --force-recreate web scratch-gui)
  else
    (cd "$FRONTEND_DIR" && docker compose up -d web)
  fi
  wait_for_tcp 127.0.0.1 3030 180
  wait_for_tcp 127.0.0.1 5001 120

  cat <<EOF

Готово. Локальный стек поднят.

  Frontend:       http://localhost:3030
  Backend:        http://localhost:8080
  GraphQL:        http://localhost:8080/query
  Scratch Player: http://localhost:5001/player.html

Базы данных:
  Projects Postgres — localhost:5433 (robbo_projects)
  LMS MySQL         — localhost:3307 (openedx)

Повторный запуск без пересборки: ./setup.sh --skip-build
Обновить субмодули до main:       ./setup.sh --pull

EOF
}

main "$@"
