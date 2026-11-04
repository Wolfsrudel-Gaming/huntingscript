-- =====================================================================
--  wr_hunting – Installation
--  Die Tabellen hunting_trophies und hunting_tanning werden beim Start
--  der Ressource auch automatisch angelegt.
--  Die Items werden nur für das ESX-Standardinventar benötigt
--  (ox_inventory: siehe install/ox_inventory_items.lua).
-- =====================================================================

CREATE TABLE IF NOT EXISTS `hunting_trophies` (
    `id`         INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64) NOT NULL,
    `item`       VARCHAR(50) NOT NULL,
    `x`          FLOAT NOT NULL,
    `y`          FLOAT NOT NULL,
    `z`          FLOAT NOT NULL,
    `heading`    FLOAT NOT NULL DEFAULT 0,
    `bucket`     INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hunting_tanning` (
    `id`         INT NOT NULL AUTO_INCREMENT,
    `rack`       VARCHAR(64) NOT NULL,
    `slot`       INT NOT NULL,
    `identifier` VARCHAR(64) NOT NULL,
    `input`      VARCHAR(50) NOT NULL,
    `output`     VARCHAR(50) NOT NULL,
    `amount`     INT NOT NULL DEFAULT 1,
    `finish_at`  INT NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `rack_slot` (`rack`, `slot`),
    KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
    -- Rohes Fleisch
    ('meat_deer',      'Rohes Hirschfleisch',          1, 0, 1),
    ('meat_boar',      'Rohes Wildschweinfleisch',     1, 0, 1),
    ('meat_coyote',    'Rohes Kojotenfleisch',         1, 0, 1),
    ('meat_rabbit',    'Rohes Kaninchenfleisch',       1, 0, 1),
    -- Gegrilltes Fleisch
    ('cooked_deer',    'Gegrilltes Hirschsteak',       1, 0, 1),
    ('cooked_boar',    'Gegrillter Wildschweinbraten', 1, 0, 1),
    ('cooked_coyote',  'Gegrilltes Kojotenfleisch',    1, 0, 1),
    ('cooked_rabbit',  'Gegrilltes Kaninchen',         1, 0, 1),
    -- Rohe Felle
    ('pelt_deer',      'Rohes Hirschfell',             3, 0, 1),
    ('pelt_boar',      'Rohes Wildschweinfell',        3, 0, 1),
    ('pelt_coyote',    'Rohes Kojotenfell',            2, 0, 1),
    ('pelt_rabbit',    'Rohes Kaninchenfell',          1, 0, 1),
    -- Gegerbte Felle
    ('leather_deer',   'Gegerbtes Hirschfell',         2, 0, 1),
    ('leather_boar',   'Gegerbtes Wildschweinfell',    2, 0, 1),
    ('leather_coyote', 'Gegerbtes Kojotenfell',        1, 0, 1),
    ('leather_rabbit', 'Gegerbtes Kaninchenfell',      1, 0, 1),
    -- Trophäen (Drop-Chance 1 zu 250)
    ('trophy_deer',    'Hirschkopf (Trophäe)',         4, 1, 1),
    ('trophy_boar',    'Wildschweinkopf (Trophäe)',    4, 1, 1),
    ('trophy_coyote',  'Kojotenkopf (Trophäe)',        3, 1, 1),
    -- Sonstiges
    ('campfire_kit',   'Lagerfeuer-Set',               3, 0, 1);
