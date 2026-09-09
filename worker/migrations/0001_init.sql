CREATE TABLE products (
  stripe_price_id   TEXT PRIMARY KEY,
  license_type      TEXT NOT NULL,
  entitlements_json TEXT NOT NULL,
  max_devices       INTEGER NOT NULL,
  created_at        INTEGER NOT NULL
);

CREATE TABLE licenses (
  id                    TEXT PRIMARY KEY,
  key_hash              TEXT NOT NULL UNIQUE,
  encrypted_key         TEXT NOT NULL,
  email                 TEXT NOT NULL,
  license_type          TEXT NOT NULL,
  entitlements_json     TEXT NOT NULL,
  max_devices           INTEGER NOT NULL,
  org_id                TEXT,
  status                TEXT NOT NULL,
  stripe_session_id     TEXT NOT NULL UNIQUE,
  stripe_customer_id    TEXT,
  email_state           TEXT NOT NULL,
  email_attempts        INTEGER NOT NULL DEFAULT 0,
  email_last_attempt_at INTEGER,
  created_at            INTEGER NOT NULL,
  updated_at            INTEGER NOT NULL
);
CREATE INDEX idx_licenses_email  ON licenses(email);
CREATE INDEX idx_licenses_status ON licenses(status);
CREATE INDEX idx_licenses_email_state ON licenses(email_state);
CREATE INDEX idx_licenses_customer ON licenses(stripe_customer_id);

CREATE TABLE fulfillments (
  stripe_session_id TEXT PRIMARY KEY,
  license_id        TEXT,
  state             TEXT NOT NULL,
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL
);

CREATE TABLE events (
  stripe_event_id TEXT PRIMARY KEY,
  type            TEXT NOT NULL,
  received_at     INTEGER NOT NULL
);

CREATE TABLE devices (
  license_id  TEXT NOT NULL,
  device_id   TEXT NOT NULL,
  device_name TEXT,
  first_seen  INTEGER NOT NULL,
  last_seen   INTEGER NOT NULL,
  released_at INTEGER,
  PRIMARY KEY (license_id, device_id)
);
CREATE INDEX idx_devices_active ON devices(license_id) WHERE released_at IS NULL;

INSERT INTO products (stripe_price_id, license_type, entitlements_json, max_devices, created_at)
VALUES ('price_diskprune_personal', 'personal', '["cleanup"]', 3, 0);
