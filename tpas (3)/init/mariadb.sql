CREATE DATABASE IF NOT EXISTS gp3_test_maria;
USE gp3_test_maria;

-- ============================
-- TABLE immeuble
-- ============================
CREATE TABLE immeuble (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================
-- TABLE adresse
-- ============================
CREATE TABLE adresse (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    immeuble_id INT UNSIGNED NOT NULL,
    ligne1 VARCHAR(255) NOT NULL,
    ligne2 VARCHAR(255),
    code_postal VARCHAR(10) NOT NULL,
    ville VARCHAR(255) NOT NULL,
    FOREIGN KEY (immeuble_id) REFERENCES immeuble(id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================
-- TABLE lot
-- ============================
CREATE TABLE lot (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    immeuble_id INT UNSIGNED NOT NULL,
    numero VARCHAR(50) NOT NULL,
    type VARCHAR(50) DEFAULT 'habitation',
    FOREIGN KEY (immeuble_id) REFERENCES immeuble(id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================
-- INSERTS DE TEST
-- ============================
INSERT INTO immeuble (nom) VALUES ("Résidence Test");

INSERT INTO adresse (immeuble_id, ligne1, code_postal, ville)
VALUES (1, "1 Rue du Test", "83000", "Toulon");

INSERT INTO lot (immeuble_id, numero) VALUES (1, "A101"), (1, "A102");
