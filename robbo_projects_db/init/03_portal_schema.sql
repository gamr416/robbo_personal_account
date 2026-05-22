-- Robbo portal metadata (LK-specific, NOT in Open edX MySQL)
-- Apply after 01_schema.sql on existing volumes: run manually or via entrypoint script

-- ---------------------------------------------------------------------------
-- User link: legacy LK id / OIDC sub ↔ edx auth_user.id (string)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS robbo_portal_user_link (
  id BIGSERIAL PRIMARY KEY,
  edx_user_id TEXT,
  legacy_lk_user_id TEXT,
  oidc_sub TEXT,
  email TEXT NOT NULL,
  display_name TEXT,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT robbo_portal_user_link_email_nonempty CHECK (length(trim(email)) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_robbo_portal_user_link_email
  ON robbo_portal_user_link (lower(email));

CREATE UNIQUE INDEX IF NOT EXISTS uq_robbo_portal_user_link_legacy
  ON robbo_portal_user_link (legacy_lk_user_id)
  WHERE legacy_lk_user_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_robbo_portal_user_link_sub
  ON robbo_portal_user_link (oidc_sub)
  WHERE oidc_sub IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_robbo_portal_user_link_edx
  ON robbo_portal_user_link (edx_user_id)
  WHERE edx_user_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Roles in LK portal (not edx course roles)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS robbo_portal_role (
  id BIGSERIAL PRIMARY KEY,
  user_link_id BIGINT NOT NULL REFERENCES robbo_portal_user_link (id) ON DELETE CASCADE,
  role_code TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_link_id, role_code)
);

-- ---------------------------------------------------------------------------
-- Parent ↔ child (Robbo-specific)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS robbo_portal_parent_child (
  id BIGSERIAL PRIMARY KEY,
  parent_user_link_id BIGINT NOT NULL REFERENCES robbo_portal_user_link (id) ON DELETE CASCADE,
  child_user_link_id BIGINT NOT NULL REFERENCES robbo_portal_user_link (id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (parent_user_link_id, child_user_link_id)
);

-- ---------------------------------------------------------------------------
-- Robbo groups
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS robbo_portal_group (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  unit_ref TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS robbo_portal_group_membership (
  id BIGSERIAL PRIMARY KEY,
  group_id BIGINT NOT NULL REFERENCES robbo_portal_group (id) ON DELETE CASCADE,
  user_link_id BIGINT NOT NULL REFERENCES robbo_portal_user_link (id) ON DELETE CASCADE,
  membership_role TEXT NOT NULL DEFAULT 'student',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (group_id, user_link_id)
);

-- ---------------------------------------------------------------------------
-- Integration outbox (ACID per Projects DB; worker calls LMS API / SQL read)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS robbo_portal_integration_outbox (
  id BIGSERIAL PRIMARY KEY,
  idempotency_key TEXT NOT NULL,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'pending',
  attempts INT NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ,
  CONSTRAINT robbo_portal_outbox_status_check
    CHECK (status IN ('pending', 'processing', 'done', 'failed')),
  UNIQUE (idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_robbo_portal_outbox_pending
  ON robbo_portal_integration_outbox (created_at)
  WHERE status = 'pending';

-- ---------------------------------------------------------------------------
-- Notifications inbox (LMS ingest + admin)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS robbo_portal_notifications (
  id BIGSERIAL PRIMARY KEY,
  recipient_user_link_id BIGINT REFERENCES robbo_portal_user_link (id) ON DELETE CASCADE,
  recipient_edx_user_id TEXT,
  recipient_email TEXT,
  source TEXT NOT NULL DEFAULT 'admin',
  kind TEXT,
  severity TEXT NOT NULL DEFAULT 'INFO',
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  action_url TEXT,
  dedupe_key TEXT,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT robbo_portal_notifications_severity_check
    CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_robbo_portal_notifications_dedupe
  ON robbo_portal_notifications (recipient_email, dedupe_key)
  WHERE dedupe_key IS NOT NULL AND recipient_email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_robbo_portal_notifications_recipient_unread
  ON robbo_portal_notifications (recipient_user_link_id, created_at DESC)
  WHERE read_at IS NULL;

COMMENT ON TABLE robbo_portal_user_link IS 'Maps LK legacy id and OIDC sub to edx auth_user.id';
COMMENT ON TABLE robbo_portal_integration_outbox IS 'Idempotent async jobs toward LMS (enrollment etc.)';
