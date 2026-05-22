#!/usr/bin/env python3
"""Set scratch_projects.owner_user_id from robbo_portal_user_link.edx_user_id."""
import os
import sys

try:
    import psycopg2
except ImportError:
    print("pip install psycopg2-binary", file=sys.stderr)
    sys.exit(1)

PG_DSN = os.environ.get(
    "PROJECTS_POSTGRES_DSN",
    "host=localhost port=5433 user=robbo_projects password=robbo_projects_change_me dbname=robbo_projects sslmode=disable",
)


def main():
    conn = psycopg2.connect(PG_DSN)
    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE scratch_projects sp
            SET owner_user_id = l.edx_user_id
            FROM robbo_portal_user_link l
            WHERE l.legacy_lk_user_id = sp.owner_user_id
              AND l.edx_user_id IS NOT NULL
              AND sp.deleted_at IS NULL
            """
        )
        updated = cur.rowcount
        conn.commit()
    conn.close()
    print(f"updated owner_user_id rows: {updated}")


if __name__ == "__main__":
    main()
