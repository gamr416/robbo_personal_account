-- Robbo Scratch projects storage (PostgreSQL 13+)
-- Applied automatically on first container start via docker-entrypoint-initdb.d

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- Projects: one row per storage_project_id / projectRef
-- ---------------------------------------------------------------------------
CREATE TABLE scratch_projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT 'Untitled',
  instruction TEXT NOT NULL DEFAULT '',
  note TEXT NOT NULL DEFAULT '',
  scratch_vm_json TEXT NOT NULL DEFAULT '{}',
  is_public BOOLEAN NOT NULL DEFAULT FALSE,
  version_counter BIGINT NOT NULL DEFAULT 0,
  current_version_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ NULL,
  CONSTRAINT scratch_projects_version_counter_nonnegative CHECK (version_counter >= 0)
);

-- ---------------------------------------------------------------------------
-- Versions: .sb3 payload in BYTEA; optimistic concurrency via version_seq
-- ---------------------------------------------------------------------------
CREATE TABLE scratch_project_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES scratch_projects (id) ON DELETE CASCADE,
  version_seq BIGINT NOT NULL,
  archive BYTEA NOT NULL,
  size_bytes BIGINT NOT NULL,
  checksum_sha256 BYTEA NOT NULL,
  created_by_user_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  save_source TEXT,
  CONSTRAINT scratch_project_versions_size_positive CHECK (size_bytes > 0),
  CONSTRAINT scratch_project_versions_version_seq_positive CHECK (version_seq > 0),
  CONSTRAINT scratch_project_versions_checksum_len CHECK (octet_length(checksum_sha256) = 32),
  UNIQUE (project_id, version_seq),
  UNIQUE (project_id, checksum_sha256)
);

ALTER TABLE scratch_projects
  ADD CONSTRAINT fk_scratch_projects_current_version
  FOREIGN KEY (current_version_id) REFERENCES scratch_project_versions (id) ON DELETE SET NULL;

CREATE INDEX idx_scratch_projects_owner_active
  ON scratch_projects (owner_user_id)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_scratch_projects_owner_updated
  ON scratch_projects (owner_user_id, updated_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_scratch_project_versions_project_created
  ON scratch_project_versions (project_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Audit: opens, new versions, head promotion (optional but recommended in NFR)
-- ---------------------------------------------------------------------------
CREATE TABLE scratch_project_audit_events (
  id BIGSERIAL PRIMARY KEY,
  project_id UUID NOT NULL REFERENCES scratch_projects (id) ON DELETE CASCADE,
  actor_user_id TEXT,
  event_type TEXT NOT NULL,
  version_id UUID REFERENCES scratch_project_versions (id) ON DELETE SET NULL,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT scratch_project_audit_events_event_type_nonempty CHECK (length(trim(event_type)) > 0)
);

CREATE INDEX idx_scratch_audit_project_created
  ON scratch_project_audit_events (project_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Keep scratch_projects.updated_at in sync on UPDATE
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION scratch_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_scratch_projects_updated_at
  BEFORE UPDATE ON scratch_projects
  FOR EACH ROW
  EXECUTE PROCEDURE scratch_set_updated_at();

COMMENT ON TABLE scratch_projects IS 'Scratch storage project (projectRef) plus LK project metadata (title, instruction, note, access)';
COMMENT ON TABLE scratch_project_versions IS 'Immutable .sb3 snapshots; UNIQUE(project_id, checksum_sha256) for idempotent saves';
COMMENT ON TABLE scratch_project_audit_events IS 'Audit trail for editor/storage (open, save, head promoted)';
