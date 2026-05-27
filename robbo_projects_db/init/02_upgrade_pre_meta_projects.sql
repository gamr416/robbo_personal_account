-- Idempotent migrations for PROJECT DB volumes created before scratch_projects had LK metadata.
-- Safe to run on fresh DB (no-op) or upgraded schema.

ALTER TABLE scratch_projects
  ALTER COLUMN owner_user_id TYPE TEXT USING owner_user_id::TEXT;

ALTER TABLE scratch_projects
  ADD COLUMN IF NOT EXISTS title TEXT NOT NULL DEFAULT 'Untitled',
  ADD COLUMN IF NOT EXISTS instruction TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS note TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS scratch_vm_json TEXT NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_scratch_projects_owner_updated
  ON scratch_projects (owner_user_id, updated_at DESC)
  WHERE deleted_at IS NULL;

DROP TABLE IF EXISTS scratch_project_legacy_map;

-- Normalize author ids on versions (historically UUID).
ALTER TABLE scratch_project_versions
  ALTER COLUMN created_by_user_id TYPE TEXT USING created_by_user_id::TEXT;
