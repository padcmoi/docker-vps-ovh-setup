 
CREATE DATABASE gp3_test_pg;
\c gp3_test_pg;

-- ============================
-- TABLE immeuble
-- ============================
CREATE TABLE immeuble (
    id SERIAL PRIMARY KEY,
    nom TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ============================
-- TABLE adresse
-- ============================
CREATE TABLE adresse (
    id SERIAL PRIMARY KEY,
    immeuble_id INT NOT NULL REFERENCES immeuble(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    ligne1 TEXT NOT NULL,
    ligne2 TEXT,
    code_postal TEXT NOT NULL,
    ville TEXT NOT NULL
);

-- ============================
-- TABLE lot
-- ============================
CREATE TABLE lot (
    id SERIAL PRIMARY KEY,
    immeuble_id INT NOT NULL REFERENCES immeuble(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    numero TEXT NOT NULL,
    type TEXT DEFAULT 'habitation'
);

-- ============================
-- INSERTS DE TEST
-- ============================
INSERT INTO immeuble (nom) VALUES ('Résidence PG Test');

INSERT INTO adresse (immeuble_id, ligne1, code_postal, ville)
VALUES (1, '2 Avenue PostgreSQL', '75000', 'Paris');

INSERT INTO lot (immeuble_id, numero) VALUES (1, 'B201'), (1, 'B202');
