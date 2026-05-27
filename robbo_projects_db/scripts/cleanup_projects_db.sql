-- One-off cleanup: keep only the three Scratch tables in PROJECT DB.
-- Run against an existing volume, e.g.:
--   docker exec -i robbo_projects_postgres psql -U robbo_projects -d robbo_projects -v ON_ERROR_STOP=1 \
--     < robbo_projects_db/scripts/cleanup_projects_db.sql

BEGIN;

DROP TABLE IF EXISTS scratch_project_legacy_map CASCADE;

-- Portal / legacy LK metadata (may exist from prior cutover or GORM AutoMigrate)
DROP TABLE IF EXISTS robbo_portal_notifications CASCADE;
DROP TABLE IF EXISTS robbo_portal_integration_outbox CASCADE;
DROP TABLE IF EXISTS robbo_portal_parent_child CASCADE;
DROP TABLE IF EXISTS robbo_portal_group_member CASCADE;
DROP TABLE IF EXISTS robbo_portal_group_membership CASCADE;
DROP TABLE IF EXISTS robbo_portal_group CASCADE;
DROP TABLE IF EXISTS robbo_portal_role CASCADE;
DROP TABLE IF EXISTS robbo_portal_user_link CASCADE;

DROP TABLE IF EXISTS children_of_parent_dbs CASCADE;
DROP TABLE IF EXISTS students_of_teacher_dbs CASCADE;
DROP TABLE IF EXISTS teachers_robbo_groups_dbs CASCADE;
DROP TABLE IF EXISTS unit_admins_robbo_units_dbs CASCADE;
DROP TABLE IF EXISTS course_relation_dbs CASCADE;
DROP TABLE IF EXISTS course_relations CASCADE;
DROP TABLE IF EXISTS cohort_dbs CASCADE;
DROP TABLE IF EXISTS course_packet_dbs CASCADE;
DROP TABLE IF EXISTS course_dbs CASCADE;
DROP TABLE IF EXISTS robbo_group_dbs CASCADE;
DROP TABLE IF EXISTS robbo_unit_dbs CASCADE;
DROP TABLE IF EXISTS student_dbs CASCADE;
DROP TABLE IF EXISTS teacher_dbs CASCADE;
DROP TABLE IF EXISTS parent_dbs CASCADE;
DROP TABLE IF EXISTS free_listener_dbs CASCADE;
DROP TABLE IF EXISTS unit_admin_dbs CASCADE;
DROP TABLE IF EXISTS super_admin_dbs CASCADE;
DROP TABLE IF EXISTS project_page_dbs CASCADE;
DROP TABLE IF EXISTS project_dbs CASCADE;
DROP TABLE IF EXISTS media_dbs CASCADE;
DROP TABLE IF EXISTS image_dbs CASCADE;
DROP TABLE IF EXISTS absolute_media_dbs CASCADE;
DROP TABLE IF EXISTS course_api_media_collection_dbs CASCADE;

COMMIT;
