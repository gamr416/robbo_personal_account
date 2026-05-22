#!/usr/bin/env python3
"""Dry-run export of LK users from legacy robbo_db to CSV (no writes to LMS)."""
import csv
import os
import sys

try:
    import psycopg2
except ImportError:
    print("pip install psycopg2-binary", file=sys.stderr)
    sys.exit(1)

DSN = os.environ.get(
    "ROBBO_DB_DSN",
    "host=localhost port=5432 user=robbo password=robbo_pwd dbname=robbo_db sslmode=disable",
)
OUT = os.environ.get("OUT", "export_lk_users.csv")

TABLES = [
    ("student", "student_dbs"),
    ("teacher", "teacher_dbs"),
    ("parent", "parent_dbs"),
    ("unit_admin", "unit_admin_dbs"),
    ("super_admin", "super_admin_dbs"),
]


def main():
    conn = psycopg2.connect(DSN)
    rows_out = []
    with conn.cursor() as cur:
        for role, table in TABLES:
            cur.execute(
                f"""
                SELECT id::text, email, COALESCE(first_name,''), COALESCE(last_name,'')
                FROM {table}
                WHERE email IS NOT NULL AND trim(email) <> ''
                """
            )
            for lid, email, fn, ln in cur.fetchall():
                rows_out.append(
                    {
                        "role": role,
                        "legacy_lk_user_id": lid,
                        "email": email.strip().lower(),
                        "first_name": fn,
                        "last_name": ln,
                    }
                )
    conn.close()
    with open(OUT, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(
            f,
            fieldnames=["role", "legacy_lk_user_id", "email", "first_name", "last_name"],
        )
        w.writeheader()
        w.writerows(rows_out)
    print(f"wrote {len(rows_out)} rows to {OUT}")


if __name__ == "__main__":
    main()
