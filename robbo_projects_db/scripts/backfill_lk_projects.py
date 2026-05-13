#!/usr/bin/env python3
"""
One-off: ЛК Postgres (project_dbs + project_page_dbs) -> PROJECT DB scratch_projects + scratch_project_legacy_map.

 Preconditions:
 - Контейнеры по умолчанию: LK=rpa2-postgres-1, PROJECT=robbo_projects_postgres (переменные окружения см. ниже).
 - Применить миграцию на уже существующий том PROJECT DB:

   docker exec robbo_projects_postgres psql -U robbo_projects -d robbo_projects -v ON_ERROR_STOP=1 \\
     -f /docker-entrypoint-initdb.d/02_upgrade_pre_meta_projects.sql

Запуск из каталога robbo_projects_db:
   python3 scripts/backfill_lk_projects.py

Переменные окружения:
   LK_PG_CONTAINER, LK_PG_USER, LK_PG_DB
   PROJECTS_PG_CONTAINER, PROJECTS_PG_USER, PROJECTS_PG_DB
"""

from __future__ import annotations

import csv
import io
import os
import subprocess
import uuid

LK_CONTAINER = os.environ.get("LK_PG_CONTAINER", "rpa2-postgres-1")
LK_USER = os.environ.get("LK_PG_USER", "robbo")
LK_DB = os.environ.get("LK_PG_DB", "robbo_db")

PR_CONTAINER = os.environ.get("PROJECTS_PG_CONTAINER", "robbo_projects_postgres")
PR_USER = os.environ.get("PROJECTS_PG_USER", "robbo_projects")
PR_DB = os.environ.get("PROJECTS_PG_DB", "robbo_projects")


def dq_lit(value: str) -> str:
    if "\x00" in value:
        raise ValueError("NUL bytes not supported")
    return "'" + value.replace("'", "''") + "'"


def subprocess_out(args: list[str]) -> bytes:
    return subprocess.check_output(args, stderr=subprocess.PIPE)


def load_existing_legacy_ids() -> set[str]:
    try:
        out = subprocess_out(
            [
                "docker",
                "exec",
                PR_CONTAINER,
                "psql",
                "-U",
                PR_USER,
                "-d",
                PR_DB,
                "-t",
                "-A",
                "-c",
                "SELECT legacy_project_id::text FROM scratch_project_legacy_map;",
            ]
        ).decode()
    except subprocess.CalledProcessError:
        return set()
    return {ln.strip() for ln in out.splitlines() if ln.strip()}


def fetch_lk_csv() -> str:
    inner_copy = """\
COPY (
  SELECT DISTINCT ON (p.id)
    p.id::text,
    COALESCE(pp.id::text, ''),
    p.author_id::text,
    COALESCE(NULLIF(pp.title, ''), p.name)::text AS title,
    COALESCE(pp.instruction, '')::text,
    COALESCE(pp.notes, '')::text,
    COALESCE(pp.is_shared, false),
    p.created_at::timestamptz::text AS created_at_iso,
    GREATEST(
      p.updated_at,
      COALESCE(pp.updated_at, p.updated_at)
    )::timestamptz::text AS updated_iso,
    p.json::text
  FROM project_dbs p
  LEFT JOIN project_page_dbs pp
    ON pp.project_id = p.id AND pp.deleted_at IS NULL
  WHERE p.deleted_at IS NULL
  ORDER BY p.id, pp.id NULLS LAST
) TO STDOUT WITH CSV
"""
    return subprocess_out(
        [
            "docker",
            "exec",
            "-i",
            LK_CONTAINER,
            "psql",
            "-U",
            LK_USER,
            "-d",
            LK_DB,
            "-v",
            "ON_ERROR_STOP=1",
            "-c",
            inner_copy,
        ]
    ).decode("utf-8")


def exec_projects_sql(sql: str) -> None:
    subprocess.run(
        [
            "docker",
            "exec",
            "-i",
            PR_CONTAINER,
            "psql",
            "-U",
            PR_USER,
            "-d",
            PR_DB,
            "-v",
            "ON_ERROR_STOP=1",
        ],
        input=sql.encode("utf-8"),
        check=True,
    )


def main() -> None:
    existing = load_existing_legacy_ids()
    csv_text = fetch_lk_csv()
    reader = csv.reader(io.StringIO(csv_text))
    done = 0
    skipped = 0
    for row in reader:
        if len(row) < 9:
            continue
        legacy_pid = row[0]
        legacy_page_id = row[1]
        author_id = row[2]
        title = row[3]
        instruction = row[4]
        note = row[5]
        shared_raw = row[6]
        created_at_iso = row[7]
        updated_iso = row[8]
        vm_json = row[9] if len(row) > 9 else "{}"
        if legacy_pid in existing:
            skipped += 1
            continue
        is_public = shared_raw.upper() == "TRUE" or shared_raw == "t"
        storage_id = str(uuid.uuid4())

        pg_page = dq_lit(legacy_page_id.strip()) if legacy_page_id.strip() else "NULL"

        sql = "".join(
            [
                "BEGIN;\n",
                "INSERT INTO scratch_projects (\n",
                "  id, owner_user_id, title, instruction, note, scratch_vm_json, is_public, created_at, updated_at\n",
                ") VALUES (\n",
                f"  '{storage_id}'::uuid,\n",
                f"  {dq_lit(author_id)},\n",
                f"  {dq_lit(title)},\n",
                f"  {dq_lit(instruction)},\n",
                f"  {dq_lit(note)},\n",
                f"  {dq_lit(vm_json)},\n",
                f"  {'TRUE' if is_public else 'FALSE'},\n",
                f"  {dq_lit(created_at_iso)}::timestamptz,\n",
                f"  {dq_lit(updated_iso)}::timestamptz\n",
                ");\n",
                "INSERT INTO scratch_project_legacy_map (legacy_project_id, legacy_project_page_id, storage_project_id)\n",
                "VALUES (\n",
                f"  {dq_lit(legacy_pid)},\n",
                f"  {pg_page},\n",
                f"  '{storage_id}'::uuid\n",
                ");\n",
                "COMMIT;\n",
            ]
        )
        exec_projects_sql(sql)
        existing.add(legacy_pid)
        done += 1

    print(f"backfill_done={done} skipped_existing={skipped}")


if __name__ == "__main__":
    main()
