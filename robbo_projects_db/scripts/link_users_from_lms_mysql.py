#!/usr/bin/env python3
"""
Read auth_user from Open edX MySQL (read-only) and upsert robbo_portal_user_link in Projects DB.
Requires: LMS_MYSQL_DSN, PROJECTS_POSTGRES_DSN, export_lk_users.csv from export_robbo_db_users.py
"""
import csv
import os
import sys

try:
    import mysql.connector
    import psycopg2
except ImportError:
    print("pip install mysql-connector-python psycopg2-binary", file=sys.stderr)
    sys.exit(1)

LMS_DSN = os.environ.get("LMS_MYSQL_DSN", "")
PG_DSN = os.environ.get(
    "PROJECTS_POSTGRES_DSN",
    "host=localhost port=5433 user=robbo_projects password=robbo_projects_change_me dbname=robbo_projects sslmode=disable",
)
CSV_IN = os.environ.get("CSV_IN", "export_lk_users.csv")


def parse_mysql_dsn(dsn: str):
    # user:pass@tcp(host:port)/db
    if "://" in dsn:
        dsn = dsn.split("://", 1)[1]
    user_pass, rest = dsn.split("@", 1)
    user, password = user_pass.split(":", 1)
    host_port, database = rest.split("/", 1)
    host, port = host_port.split(":")
    return dict(user=user, password=password, host=host, port=int(port), database=database)


def main():
    if not LMS_DSN:
        print("set LMS_MYSQL_DSN", file=sys.stderr)
        sys.exit(1)
    mysql_cfg = parse_mysql_dsn(LMS_DSN) if "@" in LMS_DSN else None
    if mysql_cfg is None:
        print("LMS_MYSQL_DSN must be user:pass@host:port/db", file=sys.stderr)
        sys.exit(1)

    pg = psycopg2.connect(PG_DSN)
    my = mysql.connector.connect(**mysql_cfg)
    linked = 0
    missing = 0
    with open(CSV_IN, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        with pg.cursor() as pg_cur, my.cursor() as my_cur:
            for row in reader:
                email = row["email"].strip().lower()
                my_cur.execute(
                    "SELECT id, username FROM auth_user WHERE lower(email)=lower(%s) AND is_active=1 LIMIT 1",
                    (email,),
                )
                hit = my_cur.fetchone()
                if not hit:
                    missing += 1
                    continue
                edx_id, username = str(hit[0]), hit[1]
                pg_cur.execute(
                    """
                    INSERT INTO robbo_portal_user_link (legacy_lk_user_id, edx_user_id, email, display_name)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (legacy_lk_user_id) DO UPDATE SET
                      edx_user_id = EXCLUDED.edx_user_id,
                      email = EXCLUDED.email,
                      display_name = EXCLUDED.display_name,
                      updated_at = now()
                    """,
                    (row["legacy_lk_user_id"], edx_id, email, username),
                )
                if pg_cur.rowcount:
                    linked += 1
            pg.commit()
    pg.close()
    my.close()
    print(f"linked={linked} missing_in_lms={missing}")


if __name__ == "__main__":
    main()
