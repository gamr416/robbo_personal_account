#!/usr/bin/env python3
"""
Upsert all active auth_user rows from Open edX MySQL into robbo_portal_user_link + default role.
No dependency on legacy robbo_db.
Requires: LMS_MYSQL_DSN, PROJECTS_POSTGRES_DSN
"""
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


def parse_mysql_dsn(dsn: str):
    if "://" in dsn:
        dsn = dsn.split("://", 1)[1]
    user_pass, rest = dsn.split("@", 1)
    user, password = user_pass.split(":", 1)
    rest = rest.replace("tcp(", "").replace(")", "")
    host_port, database = rest.split("/", 1)
    if ":" in host_port:
        host, port = host_port.rsplit(":", 1)
    else:
        host, port = host_port, "3306"
    return dict(user=user, password=password, host=host, port=int(port), database=database)


def role_code_for_user(is_staff: int, is_superuser: int) -> str:
    if is_superuser:
        return "super_admin"
    if is_staff:
        return "teacher"
    return "student"


def main():
    if not LMS_DSN:
        print("set LMS_MYSQL_DSN", file=sys.stderr)
        sys.exit(1)
    mysql_cfg = parse_mysql_dsn(LMS_DSN)
    pg = psycopg2.connect(PG_DSN)
    my = mysql.connector.connect(**mysql_cfg)

    linked = 0
    roles = 0
    with pg.cursor() as pg_cur, my.cursor() as my_cur:
        my_cur.execute(
            """
            SELECT id, username, email, is_staff, is_superuser
            FROM auth_user
            WHERE is_active = 1 AND email IS NOT NULL AND trim(email) <> ''
            """
        )
        for uid, username, email, is_staff, is_superuser in my_cur.fetchall():
            email = email.strip().lower()
            edx_id = str(uid)
            pg_cur.execute(
                "SELECT id FROM robbo_portal_user_link WHERE lower(email) = lower(%s) LIMIT 1",
                (email,),
            )
            existing = pg_cur.fetchone()
            if existing:
                user_link_id = existing[0]
                pg_cur.execute(
                    """
                    UPDATE robbo_portal_user_link
                    SET edx_user_id = %s, display_name = %s, updated_at = now()
                    WHERE id = %s
                    """,
                    (edx_id, username, user_link_id),
                )
            else:
                pg_cur.execute(
                    """
                    INSERT INTO robbo_portal_user_link (edx_user_id, email, display_name)
                    VALUES (%s, %s, %s)
                    RETURNING id
                    """,
                    (edx_id, email, username),
                )
                user_link_id = pg_cur.fetchone()[0]
            linked += 1
            code = role_code_for_user(int(is_staff or 0), int(is_superuser or 0))
            pg_cur.execute(
                """
                INSERT INTO robbo_portal_role (user_link_id, role_code)
                VALUES (%s, %s)
                ON CONFLICT (user_link_id, role_code) DO NOTHING
                """,
                (user_link_id, code),
            )
            if pg_cur.rowcount:
                roles += 1
        pg.commit()
    pg.close()
    my.close()
    print(f"linked={linked} roles_inserted={roles}")


if __name__ == "__main__":
    main()
