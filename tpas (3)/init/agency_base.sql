-- =========================================================
-- Base de test GP3 (simplifiée, PostgreSQL)
-- Tables :
--   addresses, tiers, proprietaires, locataires,
--   immeubles, lots, baux
-- =========================================================

-- =========================
-- 1. ADDRESSES
-- =========================
CREATE TABLE addresses (
  id      BIGSERIAL PRIMARY KEY,
  ligne1  TEXT        NOT NULL,
  ligne2  TEXT,
  cp      VARCHAR(10) NOT NULL,
  ville   TEXT        NOT NULL,
  pays    TEXT        NOT NULL DEFAULT 'FRANCE'
);

-- =========================
-- 2. IMMEUBLES
-- =========================
CREATE TABLE immeubles (
  id         BIGSERIAL PRIMARY KEY,
  nom        TEXT   NOT NULL,
  address_id BIGINT NOT NULL REFERENCES addresses(id)
);

-- =========================
-- 3. LOTS
-- =========================
CREATE TABLE lots (
  id          BIGSERIAL PRIMARY KEY,
  immeuble_id BIGINT NOT NULL REFERENCES immeubles(id) ON DELETE CASCADE,
  reference   TEXT   NOT NULL,   -- ex : "A12"
  etage       TEXT,
  surface_m2  NUMERIC(8,2)
);

-- =========================
-- 4. TIERS (générique)
-- =========================
CREATE TABLE tiers (
  id         BIGSERIAL PRIMARY KEY,
  nom        TEXT NOT NULL,
  type_tier  TEXT NOT NULL CHECK (type_tier IN ('PROPRIETAIRE','LOCATAIRE','AUTRE')),
  address_id BIGINT REFERENCES addresses(id)
);

-- =========================
-- 5. PROPRIETAIRES (spécialisation de tiers)
-- =========================
CREATE TABLE proprietaires (
  id      BIGSERIAL PRIMARY KEY,
  tier_id BIGINT NOT NULL UNIQUE REFERENCES tiers(id) ON DELETE CASCADE
);

-- =========================
-- 6. LOCATAIRES (spécialisation de tiers)
-- =========================
CREATE TABLE locataires (
  id      BIGSERIAL PRIMARY KEY,
  tier_id BIGINT NOT NULL UNIQUE REFERENCES tiers(id) ON DELETE CASCADE
);

-- =========================
-- 7. BAUX
-- =========================
CREATE TABLE baux (
  id              BIGSERIAL PRIMARY KEY,
  lot_id          BIGINT NOT NULL REFERENCES lots(id),
  proprietaire_id BIGINT NOT NULL REFERENCES proprietaires(id),
  locataire_id    BIGINT NOT NULL REFERENCES locataires(id),
  date_debut      DATE   NOT NULL,
  date_fin        DATE,
  loyer_mensuel   NUMERIC(10,2) NOT NULL
);
